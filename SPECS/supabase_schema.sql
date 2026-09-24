-- ============================================================
-- TechReserve — Schema completo para Supabase
-- Cole no SQL Editor do Supabase (ordem de execução garantida)
-- Idempotente: pode reexecutar sem quebrar
-- ============================================================

create extension if not exists "pgcrypto";      -- gen_random_uuid()
create extension if not exists "btree_gist";    -- constraint de exclusão (RN-01)

-- ============================================================
-- 1. ENUMS
-- ============================================================
create type app_role as enum ('solicitante','coordenadora','admin');
create type reservation_status as enum ('PENDENTE','CONFIRMADA','CANCELADA','EM_USO','CONCLUIDA','NO_SHOW');
create type channel as enum ('WHATSAPP','EMAIL');
create type notif_status as enum ('QUEUED','SENT','DELIVERED','READ','FAILED');

-- ============================================================
-- 2. TABELAS
-- ============================================================

-- Perfis (1:1 com auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  phone text,                       -- E.164 (+5511...); LGPD: nunca logar
  role app_role not null default 'solicitante',
  lgpd_consent_at timestamptz not null default now()
);

-- Salas (SEM CRUD de ambientes: seed apenas — fora de escopo)
create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity int not null check (capacity > 0),
  resources jsonb not null default '[]',
  active boolean not null default true
);

-- Disponibilidade semanal definida pela coordenadora (RF-09)
create table if not exists public.availability_slots (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),  -- 0=dom .. 6=sáb
  start_time time not null,
  end_time time not null,
  check (end_time > start_time),
  unique (room_id, weekday, start_time)
);

-- Reservas (RF-02/03)
create table if not exists public.reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id),
  user_id uuid not null references public.profiles(id),
  date date not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status reservation_status not null default 'CONFIRMADA',
  checkin_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

-- RN-01: impede sobreposição fisicamente (prova de corrida no banco)
alter table public.reservations drop constraint if exists no_overlap;
alter table public.reservations add constraint no_overlap
  exclude using gist (
    room_id with =,
    tstzrange(start_time, end_time) with &&
  ) where (status in ('CONFIRMADA','EM_USO'));

create index if not exists idx_reservations_user  on public.reservations (user_id, start_time);
create index if not exists idx_reservations_status on public.reservations (status, start_time);

-- Fila de notificações (RF-05/06/07)
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid references public.reservations(id) on delete set null,
  channel channel not null,
  template text not null,
  payload jsonb not null default '{}',
  status notif_status not null default 'QUEUED',
  provider_id text,
  delivered_at timestamptz,
  read_at timestamptz,
  attempts int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_notifications_queue on public.notifications (status, channel, created_at);

-- Parâmetros do sistema (RN-03/05 configuráveis)
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);

insert into public.app_settings (key, value) values
  ('cancel_min_hours', '2'),
  ('checkin_window_before_min', '15'),
  ('checkin_window_after_min', '15')
on conflict (key) do nothing;

-- ============================================================
-- 3. FUNÇÕES E TRIGGERS
-- ============================================================

-- 3.1 Role atual a partir do JWT (base da RLS)
create or replace function public.current_role()
returns app_role language sql stable as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role')::app_role, 'solicitante');
$$;

-- 3.2 Novo usuário -> cria profile automaticamente
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, phone)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'name', ''),
          new.raw_user_meta_data->>'phone')
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 3.3 RN-02: reserva só dentro da disponibilidade da coordenadora
create or replace function public.check_availability()
returns trigger language plpgsql as $$
declare n int;
begin
  select count(*) into n
  from public.availability_slots a
  where a.room_id = new.room_id
    and a.weekday = extract(isodow from new.date) % 7
    and a.start_time <= new.start_time::time
    and a.end_time   >= new.end_time::time;
  if n = 0 then
    raise exception 'RN-02: fora da disponibilidade definida pela coordenadora';
  end if;
  return new;
end $$;

drop trigger if exists trg_check_availability on public.reservations;
create trigger trg_check_availability
  before insert on public.reservations
  for each row execute function public.check_availability();

-- 3.4 RN-05: cancelamento com antecedência mínima
create or replace function public.check_cancel_window()
returns trigger language plpgsql as $$
declare h int;
begin
  if new.status = 'CANCELADA' and old.status = 'CONFIRMADA' then
    select value::int into h from public.app_settings where key = 'cancel_min_hours';
    if new.start_time - now() < make_interval(hours => h) then
      raise exception 'RN-05: fora do prazo de cancelamento (%)h', h;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_check_cancel on public.reservations;
create trigger trg_check_cancel
  before update on public.reservations
  for each row execute function public.check_cancel_window();

-- 3.5 RF-04/RN-03: check-in dentro da janela (chamada pelo front)
create or replace function public.checkin(p_reservation_id uuid)
returns public.reservations language plpgsql security definer set search_path = public as $$
declare r public.reservations;
begin
  select * into r from public.reservations
   where id = p_reservation_id and user_id = auth.uid()
   for update;
  if not found then raise exception 'reserva nao encontrada'; end if;
  if r.status <> 'CONFIRMADA' then raise exception 'status invalido: %', r.status; end if;
  if now() < r.start_time - (select value::int from public.app_settings where key='checkin_window_before_min') * interval '1 minute'
     or now() > r.start_time + (select value::int from public.app_settings where key='checkin_window_after_min') * interval '1 minute'
  then
    raise exception 'fora da janela de check-in';
  end if;
  update public.reservations set status='EM_USO', checkin_at=now()
   where id = r.id returning * into r;
  return r;
end $$;

-- 3.6 RF-04: no-show automático (cron a cada 5 min — Scheduled Function)
create or replace function public.expire_no_shows()
returns void language sql security definer as $$
  update public.reservations set status='NO_SHOW'
   where status='CONFIRMADA'
     and start_time + (select value::int from public.app_settings where key='checkin_window_after_min') * interval '1 minute' < now();
$$;

-- 3.7 RF-05/06: fila de notificações ao criar/cancelar reserva
create or replace function public.enqueue_notifications()
returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' and new.status = 'CONFIRMADA' then
    insert into public.notifications (reservation_id, channel, template, payload) values
      (new.id, 'WHATSAPP', 'reserva_confirmada', jsonb_build_object('reservation_id', new.id)),
      (new.id, 'EMAIL',    'reserva_confirmada', jsonb_build_object('reservation_id', new.id));
  elsif tg_op = 'UPDATE' and new.status = 'CANCELADA' and old.status <> 'CANCELADA' then
    insert into public.notifications (reservation_id, channel, template, payload) values
      (new.id, 'WHATSAPP', 'reserva_cancelada', jsonb_build_object('reservation_id', new.id)),
      (new.id, 'EMAIL',    'reserva_cancelada', jsonb_build_object('reservation_id', new.id));
  end if;
  return new;
end $$;

drop trigger if exists trg_notify on public.reservations;
create trigger trg_notify
  after insert or update on public.reservations
  for each row execute function public.enqueue_notifications();

-- 3.8 LGPD: anonimização (mantém histórico de reservas)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles
     set name = 'Usuario removido', phone = null
   where id = auth.uid();
end $$;

-- ============================================================
-- 4. ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles           enable row level security;
alter table public.rooms              enable row level security;
alter table public.availability_slots enable row level security;
alter table public.reservations       enable row level security;
alter table public.notifications      enable row level security;

-- profiles
create policy p_profiles_read on public.profiles for select to authenticated using (true);
create policy p_profiles_upd on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- rooms: só leitura (sem CRUD de ambientes)
create policy p_rooms_read on public.rooms for select to authenticated using (active);

-- availability_slots: leitura autenticada; escrita coordenadora/admin (RF-09)
create policy p_slots_read on public.availability_slots for select to authenticated using (true);
create policy p_slots_write on public.availability_slots for all to authenticated
  using (public.current_role() in ('coordenadora','admin'))
  with check (public.current_role() in ('coordenadora','admin'));

-- reservations: dono lê/escreve as próprias; coordenadora/admin vê tudo
create policy p_res_read on public.reservations for select to authenticated
  using (user_id = auth.uid() or public.current_role() in ('coordenadora','admin'));
create policy p_res_insert on public.reservations for insert to authenticated
  with check (user_id = auth.uid());
create policy p_res_update on public.reservations for update to authenticated
  using (user_id = auth.uid() or public.current_role() in ('coordenadora','admin'));

-- notifications: leitura gerencial; escrita só service_role (edge functions)
create policy p_notif_read on public.notifications for select to authenticated
  using (public.current_role() in ('coordenadora','admin'));

-- ============================================================
-- 5. SEED (ambiente de desenvolvimento)
-- ============================================================
insert into public.rooms (name, capacity, resources) values
  ('Laboratório 1', 40, '["projetor","ar-condicionado","quadro"]'),
  ('Sala de Reuniões 2', 12, '["tv","videochamada"]'),
  ('Auditório', 120, '["palco","som","projetor"]')
on conflict do nothing;

-- Grade seg–sáb 07:00–22:00 para todas as salas
insert into public.availability_slots (room_id, weekday, start_time, end_time)
select r.id, w.d, '07:00', '22:00'
from public.rooms r
cross join (values (1),(2),(3),(4),(5),(6)) as w(d)
on conflict do nothing;
