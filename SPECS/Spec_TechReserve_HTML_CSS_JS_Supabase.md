# SPEC TÉCNICA DE DESENVOLVIMENTO — TechReserve
## Stack: HTML + CSS + JavaScript + Supabase | App web estático (sem build, sem npm)

**Projeto:** TechReserve — Sistema de Reserva de Salas
**Cliente:** FATEC Franco da Rocha
**Base:** Especificação de Requisitos (RF/RN) + TAP Rev 1
**Objetivo deste documento:** único arquivo necessário para um agente de IA implementar
o sistema completo, front-end estático + Supabase.

---

## 0. Instruções para o agente de IA

1. Implemente TODO o escopo das seções 1–9 sem parar para confirmações intermediárias.
2. Fonte da verdade: RF (funcionais), RNF (não funcionais), RN (regras de negócio).
3. **Não crie `package.json`, não use bundlers, não use frameworks JS.** Tudo via CDN
   (ver seção 2). O app é servido como arquivos estáticos (Netlify/Vercel/GitHub Pages
   ou qualquer hospedagem estática).
4. Entregue o schema SQL completo (seção 4) em `supabase/schema.sql`, pronto para rodar
   no SQL Editor do Supabase.
5. Fora de escopo (NÃO implementar): CRUD de ambientes, notas/frequência, conservação
   de patrimônio.

---

## 1. Visão geral

### 1.1 Produto
Sistema web para reserva de salas de uma unidade de ensino: disponibilidade controlada
pela coordenadora, busca de salas livres, reserva sem conflito, check-in com no-show
automático, notificações por WhatsApp e e-mail, relatórios.

### 1.2 Perfis (roles) — mapeados para `app_metadata.role` no Supabase Auth
| Role | Permissões |
|---|---|
| `solicitante` | buscar, reservar, cancelar, check-in nas próprias reservas |
| `coordenadora` | tudo do solicitante + configurar disponibilidade + relatórios |
| `admin` | tudo da coordenadora + gerenciar usuários |

> Um trigger no banco sincroniza `auth.users.app_metadata.role` → tabela `profiles`.
> Toda autorização real é feita por **RLS** (Row Level Security), nunca só no front.

---

## 2. Stack e bibliotecas (100% via CDN — proibido npm/build)

| Finalidade | Biblioteca | CDN |
|---|---|---|
| CSS utilitário | Tailwind CSS | `https://cdn.tailwindcss.com` |
| Backend/Auth/DB | Supabase JS v2 | `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2` |
| Calendário/grade | FullCalendar 6 (core+daygrid+timegrid) | `https://cdn.jsdelivr.net/npm/fullcalendar@6/index.global.min.js` |
| Gráficos (relatórios) | Chart.js 4 | `https://cdn.jsdelivr.net/npm/chart.js@4` |
| Toasts/diálogos | SweetAlert2 | `https://cdn.jsdelivr.net/npm/sweetalert2@11` |
| QR Code (check-in) | qrcodejs | `https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js` |
| Máscara de inputs | IMask | `https://cdn.jsdelivr.net/npm/imask@7` |
| Sanitização | DOMPurify | `https://cdn.jsdelivr.net/npm/dompurify@3` |

Regras:
- Carregar scripts com `defer`; app em módulos ES nativos (`<script type="module">`).
- Centralizar supabase client em `js/supabase.js` (singleton, lê `config.js`).
- Qualquer inserção de dado do usuário na DOM passa por `DOMPurify.sanitize()`.

---

## 3. Estrutura de arquivos (estáticos)

```
techreserve/
├── index.html            # login/registro (SPA shell)
├── app.html              # área logada (todas as telas como views)
├── admin.html            # painel coordenadora/admin (protegida por role)
├── css/
│   └── styles.css        # apenas customizações (Tailwind cobre o resto)
├── js/
│   ├── config.js         # SUPABASE_URL, SUPABASE_ANON_KEY, flags
│   ├── supabase.js       # client singleton
│   ├── auth.js           # login, registro, recuperação de senha
│   ├── router.js         # troca de views sem recarregar
│   ├── rooms.js          # busca de salas (RF-01)
│   ├── reservations.js   # criar/cancelar (RF-02/03/10)
│   ├── checkin.js        # check-in + no-show (RF-04)
│   ├── availability.js   # grade da coordenadora (RF-09)
│   ├── reports.js        # relatórios (RF-08)
│   ├── notifications.js  # status das notificações (RF-07, leitura)
│   └── ui.js             # toasts, estados vazio/erro/loading
├── supabase/
│   ├── schema.sql        # TODAS as tabelas, enums, constraints, triggers, RLS
│   ├── seed.sql          # 3 salas, grade semanal, 1 coordenadora, 1 admin
│   └── functions/        # edge functions (seção 7)
│       ├── whatsapp-send/index.ts
│       ├── email-send/index.ts
│       ├── checkin-expire/index.ts
│       └── whatsapp-webhook/index.ts
└── README.md             # setup (Supabase, Meta, DNS SPF/DKIM/DMARC)
```

---

## 4. Banco de dados (PostgreSQL no Supabase) — `schema.sql` completo

### 4.1 Enumerações e tabelas

```sql
create type app_role as enum ('solicitante','coordenadora','admin');
create type reservation_status as enum
  ('PENDENTE','CONFIRMADA','CANCELADA','EM_USO','CONCLUIDA','NO_SHOW');
create type channel as enum ('WHATSAPP','EMAIL');
create type notif_status as enum ('QUEUED','SENT','DELIVERED','READ','FAILED');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  phone text,                      -- E.164 (+5511...); nunca logar (LGPD)
  role app_role not null default 'solicitante',
  lgpd_consent_at timestamptz not null default now()
);

create table rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  capacity int not null,
  resources jsonb not null default '[]',
  active boolean not null default true
  -- SEM CRUD de salas (fora de escopo): seed apenas
);

create table availability_slots (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  check (end_time > start_time),
  unique (room_id, weekday, start_time)
);

create table reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id),
  user_id uuid not null references profiles(id),
  date date not null,
  start_time timestamptz not null,
  end_time timestamptz not null,
  status reservation_status not null default 'CONFIRMADA',
  checkin_at timestamptz,
  created_at timestamptz not null default now(),
  check (end_time > start_time)
);

-- RN-01: impede sobreposição FISICAMENTE (prova de corrida no banco)
alter table reservations add constraint no_overlap
  exclude using gist (
    room_id with =,
    tstzrange(start_time, end_time) with &&
  ) where (status in ('CONFIRMADA','EM_USO'));

create index on reservations (user_id, start_time);
create index on reservations (status, start_time);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid references reservations(id) on delete set null,
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

create table app_settings (
  key text primary key,
  value text not null
);
insert into app_settings (key, value) values
  ('cancel_min_hours', '2'),
  ('checkin_window_before_min', '15'),
  ('checkin_window_after_min', '15');
```

### 4.2 RN-02: reserva só dentro da disponibilidade (trigger)

```sql
create or replace function check_availability() returns trigger as $$
declare slot_count int;
begin
  select count(*) into slot_count
  from availability_slots a
  where a.room_id = new.room_id
    and a.weekday = extract(isodow from new.date) % 7
    and a.start_time <= new.start_time::time
    and a.end_time   >= new.end_time::time;
  if slot_count = 0 then
    raise exception 'RN-02: fora da disponibilidade definida pela coordenadora';
  end if;
  return new;
end $$ language plpgsql;

create trigger trg_check_availability
before insert on reservations
for each row execute function check_availability();
```

### 4.3 RN-05: cancelamento com antecedência mínima (trigger)

```sql
create or replace function check_cancel_window() returns trigger as $$
declare min_hours int;
begin
  if new.status = 'CANCELADA' and old.status = 'CONFIRMADA' then
    select value::int into min_hours from app_settings where key='cancel_min_hours';
    if new.start_time - now() < make_interval(hours => min_hours) then
      raise exception 'RN-05: cancelamento fora do prazo minimo (%)', min_hours;
    end if;
  end if;
  return new;
end $$ language plpgsql;

create trigger trg_check_cancel before update on reservations
for each row execute function check_cancel_window();
```

### 4.4 RN-03 + RF-04: janela de check-in (RPC chamada pelo front)

```sql
create or replace function checkin(p_reservation_id uuid)
returns reservations as $$
declare r reservations;
begin
  select * into r from reservations
   where id = p_reservation_id and user_id = auth.uid()
   for update;
  if not found then raise exception 'reserva nao encontrada'; end if;
  if r.status <> 'CONFIRMADA' then raise exception 'status invalido: %', r.status; end if;
  if now() < r.start_time - (select value::int from app_settings where key='checkin_window_before_min') * interval '1 minute'
     or now() > r.start_time + (select value::int from app_settings where key='checkin_window_after_min') * interval '1 minute' then
    raise exception 'fora da janela de check-in';
  end if;
  update reservations set status='EM_USO', checkin_at=now() where id=r.id returning * into r;
  return r;
end $$ language plpgsql security definer;
```

### 4.5 No-show automático (RF-04) — pg_cron ou Supabase Scheduled Function

```sql
-- executar a cada 5 minutos (pg_cron no Supabase)
create or replace function expire_no_shows() returns void as $$
update reservations set status='NO_SHOW'
 where status='CONFIRMADA'
   and start_time + (select value::int from app_settings where key='checkin_window_after_min') * interval '1 minute' < now();
$$ language sql security definer;

-- no Supabase: Database → Cron → schedule '*/5 * * * *' → select expire_no_shows();
```

### 4.6 Trigger de notificações (RF-05/06): insere fila ao criar/cancelar reserva

```sql
create or replace function enqueue_notifications() returns trigger as $$
begin
  if tg_op = 'INSERT' and new.status = 'CONFIRMADA' then
    insert into notifications (reservation_id, channel, template, payload)
    values (new.id,'WHATSAPP','reserva_confirmada', jsonb_build_object('reservation_id', new.id)),
           (new.id,'EMAIL','reserva_confirmada',    jsonb_build_object('reservation_id', new.id));
  elsif tg_op = 'UPDATE' and new.status = 'CANCELADA' and old.status <> 'CANCELADA' then
    insert into notifications (reservation_id, channel, template, payload)
    values (new.id,'WHATSAPP','reserva_cancelada', jsonb_build_object('reservation_id', new.id)),
           (new.id,'EMAIL','reserva_cancelada',    jsonb_build_object('reservation_id', new.id));
  end if;
  return new;
end $$ language plpgsql;

create trigger trg_notify after insert or update on reservations
for each row execute function enqueue_notifications();
```

### 4.7 RLS — autorização no banco (NUNCA só no front)

```sql
alter table profiles enable row level security;
alter table rooms enable row level security;
alter table availability_slots enable row level security;
alter table reservations enable row level security;
alter table notifications enable row level security;

create or replace function current_role() returns app_role as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role')::app_role, 'solicitante');
$$ language sql stable;

-- profiles: qualquer um logado lê nome/role; só o próprio atualiza nome/phone
create policy p_profiles_read on profiles for select to authenticated using (true);
create policy p_profiles_upd on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- rooms: leitura para autenticados (sem insert/update/delete → sem CRUD de ambientes)
create policy p_rooms_read on rooms for select to authenticated using (active);

-- availability_slots: leitura autenticada; escrita só coordenadora/admin (RF-09)
create policy p_slots_read on availability_slots for select to authenticated using (true);
create policy p_slots_write on availability_slots for all to authenticated
  using (current_role() in ('coordenadora','admin'))
  with check (current_role() in ('coordenadora','admin'));

-- reservations: lê as próprias; coordenadora/admin lê todas; cria como si mesmo;
-- altera se dono ou coordenadora/admin (o trigger RN-05 valida o prazo)
create policy p_res_read on reservations for select to authenticated
  using (user_id = auth.uid() or current_role() in ('coordenadora','admin'));
create policy p_res_insert on reservations for insert to authenticated
  with check (user_id = auth.uid());
create policy p_res_update on reservations for update to authenticated
  using (user_id = auth.uid() or current_role() in ('coordenadora','admin'));

-- notifications: leitura por coordenadora/admin (RF-07); escrita só via service_role (edge functions)
create policy p_notif_read on notifications for select to authenticated
  using (current_role() in ('coordenadora','admin'));
```

### 4.8 LGPD (RNF-01)
- Coluna `profiles.phone` nunca deve ir para logs do front; mascarar na UI
  (`(**) *****-` + últimos 4 dígitos) fora da tela de perfil.
- Endpoint de exclusão: RPC `delete_my_account()` faz `delete from profiles where id = auth.uid()`
  (cascade em reservations? NÃO — anonimizar: `update profiles set name='Usuário removido', phone=null`).

---

## 5. Front-end — telas e comportamentos

### 5.1 `index.html` — Autenticação
- Login (e-mail/senha), registro (nome, e-mail, telefone com máscara IMask `+55 (00) 00000-0000`,
  checkbox LGPD obrigatório), "esqueci a senha" (Supabase `auth.resetPasswordForEmail`).
- Após login: redireciona para `app.html` (solicitante) ou `admin.html` (coordenadora/admin).

### 5.2 `app.html` — Solicitante
**View "Nova reserva" (RF-01/02/03):**
1. Passo 1: FullCalendar (semana) para escolher data/horário arrastando; valida contra
   `availability_slots` (eventos cinzas = fora da disponibilidade).
2. Passo 2: lista de salas livres (cards com capacidade/recursos, filtro por ambos);
   salas ocupadas nem aparecem (o banco já garante).
3. Passo 3: confirmação → `insert` em `reservations`; erro 23505 da constraint `no_overlap`
   → toast "Sala acabou de ser reservada, escolha outro horário" (SweetAlert2) e volta ao passo 2.

**View "Minhas reservas":** lista com status (badge colorido), botão **Check-in** visível
APENAS dentro da janela (RN-03, calculada no front e revalidada na RPC `checkin`),
botão **Cancelar** desabilitado com tooltip quando dentro do prazo mínimo (RN-05).

**View "Notificações":** histórico com ícones de status (✓ enviado / ✓✓ entregue / azul lido).

### 5.3 `admin.html` — Coordenadora/Admin (RF-08/09)
- **Disponibilidade (RF-09):** FullCalendar com drag-and-drop criando `availability_slots`
  semanais; salvar chama `delete` + `insert` da grade da sala (transação).
- **Relatórios (RF-08):** Chart.js com:
  - Ocupação % por sala/período (SQL: soma de horas reservadas ÷ horas disponíveis);
  - No-shows (contagem e %) com filtro de datas;
  - Tabela de histórico com botão "Exportar CSV".
- **Usuários (admin):** lista de `profiles` com troca de role (update em `auth.users`
  via edge function `set-role` — service role; front nunca expõe service key).

---

## 6. Tempo real (diferencial)
- `supabase.channel('rooms')` com `postgres_changes` em `reservations`: sala que ficou
  ocupada some da busca **instantaneamente** para outros usuários.
- Minhas reservas atualizam status ao vivo (ex.: virou NO_SHOW).

---

## 7. Edge Functions (Deno, em `supabase/functions/`)

| Function | Gatilho | O que faz |
|---|---|---|
| `whatsapp-send` | Webhook DB em `notifications` (QUEUE com status QUEUED) | Lê fila, chama Meta Cloud API com rate limit (bucket 80/min por env), atualiza `provider_id`/`SENT`; backoff exponencial máx. 5 tentativas → `FAILED` nunca derruba reserva |
| `email-send` | Mesma fila (channel=EMAIL) | Envia via API transacional (Resend/SES) com templates HTML: `reserva_confirmada`, `reserva_cancelada`, `lembrete_24h`, `lembrete_1h`, `recuperacao_senha` |
| `checkin-expire` | Scheduled (Supabase Cron) a cada 5 min | Chama `expire_no_shows()` (se pg_cron indisponível) |
| `whatsapp-webhook` | HTTP público (`/functions/v1/whatsapp-webhook`) | Verifica token Meta; eventos `statuses` → atualiza `notifications`: sent→SENT, delivered→DELIVERED+`delivered_at`, read→READ+`read_at` (RF-07) |
| `lembretes` | Scheduled a cada hora | Enfileira `lembrete_24h`/`lembrete_1h` para reservas CONFIRMADA próximas |
| `set-role` | Chamada interna admin | Atualiza `app_metadata.role` do usuário (service role) |

Secrets (nunca no front): `META_WA_TOKEN`, `META_WA_PHONE_ID`, `META_WA_VERIFY_TOKEN`,
`EMAIL_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (reservado às functions).

### 7.1 Feature flags
`config.js`: `WHATSAPP_ENABLED`, `EMAIL_ENABLED`, `NOTIFICATIONS_ENABLED`.
Desligado → functions retornam 200 sem enviar; app funciona 100% (FASE 2 isolada).

---

## 8. Critérios de aceite (Definition of Done)

| Req | Teste aceito |
|---|---|
| RF-01 | Busca retorna somente salas livres dentro dos slots; fora do slot nem aparece |
| RF-02/RN-01 | 10 inserts concorrentes do mesmo sala/horário → 1 sucesso, 9 com erro da constraint `no_overlap` (23P01) |
| RN-02 | Insert fora da grade → exception do trigger `check_availability` |
| RF-04/RN-03 | `checkin()` fora da janela → exception; dentro → status EM_USO; após janela, cron vira NO_SHOW |
| RF-10/RN-05 | Cancelar < 2h antes → exception do trigger |
| RF-05 | Criar reserva gera 2 linhas em `notifications` (WHATSAPP+EMAIL, QUEUED) |
| RF-06 | Scheduler enfileira lembretes 24h/1h (verificar linhas criadas com template correto) |
| RF-07 | Webhook de status atualiza delivered_at/read_at |
| RF-08 | Ocupação calculada bate com seed conhecido (ex.: sala X 50% em período de teste) |
| RF-09 | Solicitante tenta gravar slot → policy nega (RLS); coordenadora grava OK |
| RNF-01 | Telefone não aparece em nenhum `console.log` (auditar código) e é mascarado fora do perfil |
| RLS | Usuário A não consegue `select` reserva do usuário B (teste direto no SQL Editor com JWT) |

---

## 9. `config.js` e setup

```js
// js/config.js — único arquivo de configuração
export const SUPABASE_URL = 'https://<projeto>.supabase.co';
export const SUPABASE_ANON_KEY = '<anon-public>';
export const WHATSAPP_ENABLED = false;   // ligar após aprovação dos templates Meta
export const EMAIL_ENABLED = true;
export const NOTIFICATIONS_ENABLED = true;
```

### Checklist de setup (README.md)
1. Criar projeto Supabase → rodar `supabase/schema.sql` e `supabase/seed.sql`.
2. Configurar Auth (e-mail, confirmação opcional) e URL de redirect do reset de senha.
3. Deploy das edge functions (`supabase functions deploy ...`).
4. Configurar Scheduled Functions (cron) para `checkin-expire` e `lembretes`.
5. Meta: criar templates no WhatsApp Manager, submeter para aprovação, configurar webhook.
6. DNS: SPF, DKIM, DMARC do domínio de e-mail (entregabilidade).
7. Hospedar front estático (Netlify/Vercel) — nenhum build, só upload dos arquivos.

---

## 10. Entregáveis do agente
1. Todos os arquivos estáticos da seção 3, funcionando com `config.js` preenchido.
2. `supabase/schema.sql` completo (seção 4, copy-paste no SQL Editor).
3. `supabase/seed.sql`: 3 salas, grade semanal (seg–sáb 07:00–22:00), 1 coordenadora,
   1 admin, 5 solicitantes (usuários do Auth criados manualmente via dashboard + seed de profiles).
4. `README.md` com o checklist de setup e prints/fluxos.
5. `docs/templates-mensagens.md`: textos dos templates WhatsApp a submeter à Meta
   (confirmacao, cancelamento, lembrete_24h, lembrete_1h) + versões HTML dos e-mails.
