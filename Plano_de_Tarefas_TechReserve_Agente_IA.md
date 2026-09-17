# TechReserve — PLANO DE TAREFAS PARA AGENTE DE IA
## Execução paralela e independente | Stack: HTML + CSS + JS + Supabase

**Como ler este documento:**
- A seção **0 (Contratos Congelados)** é a ÚNICA parte comum. Nenhuma tarefa pode alterá-la.
- Cada tarefa é **autossuficiente**: traz seus próprios arquivos, seu próprio SQL e seus
  próprios testes. A tarefa corrente NÃO precisa da anterior (nem da próxima) para
  corrigir falhas — se algo falhar, a correção fica DENTRO da própria tarefa.
- Ordens sugeridas de execução são apenas para conveniência humana; o agente pode
  executar em qualquer ordem.
- Regras de comportamento do agente: seção 3. Diretrizes UI/UX: seção 2.

---

## 0. CONTRATOS CONGELADOS (não alterar sem interação humana — ver regra A-2)

Qualquer tarefa que precise de algo fora desta lista DEVE escalonar (regra A-2).

### 0.1 Banco (nomes exatos)
```sql
-- enums
app_role: 'solicitante' | 'coordenadora' | 'admin'
reservation_status: 'PENDENTE' | 'CONFIRMADA' | 'CANCELADA' | 'EM_USO' | 'CONCLUIDA' | 'NO_SHOW'
channel: 'WHATSAPP' | 'EMAIL'
notif_status: 'QUEUED' | 'SENT' | 'DELIVERED' | 'READ' | 'FAILED'

-- tabelas (colunas-chave)
profiles(id, name, phone, role, lgpd_consent_at)
rooms(id, name, capacity, resources jsonb, active)
availability_slots(id, room_id, weekday int 0-6, start_time, end_time)
reservations(id, room_id, user_id, date, start_time, end_time, status, checkin_at, created_at)
notifications(id, reservation_id, channel, template, payload jsonb, status,
              provider_id, delivered_at, read_at, attempts, created_at)
app_settings(key text PK, value text)
```

### 0.2 Funções/RPC (assinaturas exatas)
```sql
checkin(p_reservation_id uuid) returns reservations
expire_no_shows() returns void
current_role() returns app_role          -- lê JWT app_metadata.role
```

### 0.3 Constraints e triggers (já definidas, cada tarefa só as cria se não existirem)
- `reservations.no_overlap`: `EXCLUDE USING gist (room_id WITH =, tstzrange(start_time,end_time) WITH &&) WHERE (status IN ('CONFIRMADA','EM_USO'))`
- `trg_check_availability` (RN-02), `trg_check_cancel` (RN-05), `trg_notify` (fila)

### 0.4 Settings (chaves/valores default)
`cancel_min_hours=2` | `checkin_window_before_min=15` | `checkin_window_after_min=15`

### 0.5 Front-end
- `js/config.js` exporta: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `WHATSAPP_ENABLED`,
  `EMAIL_ENABLED`, `NOTIFICATIONS_ENABLED`.
- Bibliotecas via CDN (proibido npm): Tailwind, `@supabase/supabase-js@2`,
  FullCalendar 6, Chart.js 4, SweetAlert2, qrcodejs, IMask, DOMPurify, **Lucide Icons**.
- Ícones SOMENTE via Lucide: `<i data-lucide="calendar"></i>` + `lucide.createIcons()`.
- **Proibido emojis em qualquer lugar** (UI, toasts, logs, mensagens de erro).

### 0.6 Edge Functions (nomes exatos)
`whatsapp-send` | `email-send` | `whatsapp-webhook` | `lembretes` | `checkin-expire` | `set-role`

### 0.7 Arquivo de backlog
`BACKLOG.md` na raiz — ver regra A-1.

---

## 1. TAREFAS

Legenda de dependências: **(Livre)** = não depende de nenhuma outra tarefa.
As tarefas compartilham apenas os contratos da seção 0.

---

### T01 — Fundação visual e design system **(Livre)**
**Objetivo:** UI kit completo para todas as telas usarem sem decisões novas.
**Arquivos:** `css/styles.css`, `js/ui.js`, `ui-kit.html` (página de demonstração).
**Entregas:**
- Tokens CSS: cores (primária, superfícies, estados de status da reserva), tipografia
  (1 família, 3 tamanhos), espaçamento (escala 4px), raios de borda, sombras sutis.
- Componentes reutilizáveis em `ui.js`: `toast(tipo, titulo, msg)`, `badgeStatus(status)`,
  `botaoPadrao(rotulo, iconeLucide)`, `estadoVazio(titulo, msg)`, `spinner()`,
  `confirmDialog(titulo, msg)` (SweetAlert2 já estilizado com os tokens).
- `ui-kit.html` renderizando todos os componentes (referência visual).
**Aceite:** nenhum emoji no código; todos os ícones via Lucide; componentes funcionam
isoladamente abrindo `ui-kit.html`.

---

### T02 — Autenticação e perfis **(Livre)**
**Objetivo:** RF implícito — login, registro, roles. Base de `profiles`.
**Arquivos:** `index.html`, `js/auth.js`, `js/config.js`, `supabase/migrations/T02_auth.sql`.
**SQL da tarefa:**
```sql
create table if not exists profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  phone text,
  role app_role not null default 'solicitante',
  lgpd_consent_at timestamptz not null default now()
);
alter table profiles enable row level security;
create policy p_profiles_read on profiles for select to authenticated using (true);
create policy p_profiles_upd on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- trigger: ao criar auth.users, insere profiles (name/phone vindos de raw_user_meta_data)
```
**Front:** login, registro (nome, e-mail, telefone com IMask `+55 (00) 00000-0000`,
checkbox LGPD obrigatório), esqueci a senha (`resetPasswordForEmail`). Redireciona:
`solicitante → app.html`, `coordenadora/admin → admin.html`.
**Aceite:** usuário novo aparece em `profiles` automaticamente; RLS bloqueia update alheio.
**Regra:** se `app_metadata.role` não existir no JWT, assumir `solicitante` (função `current_role`).

---

### T03 — Catálogo de salas e busca (RF-01) **(Livre)**
**Objetivo:** exibir salas com filtros; base da tela "Nova reserva".
**Arquivos:** `js/rooms.js`, view em `app.html`, `supabase/migrations/T03_rooms.sql`,
`supabase/seed.sql` (3 salas + grade seg–sáb 07:00–22:00).
**SQL da tarefa:**
```sql
create table if not exists rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null, capacity int not null,
  resources jsonb not null default '[]', active boolean not null default true);
create table if not exists availability_slots (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id) on delete cascade,
  weekday int not null check (weekday between 0 and 6),
  start_time time not null, end_time time not null,
  check (end_time > start_time),
  unique (room_id, weekday, start_time));
alter table rooms enable row level security;
create policy p_rooms_read on rooms for select to authenticated using (active);
alter table availability_slots enable row level security;
create policy p_slots_read on availability_slots for select to authenticated using (true);
```
**Front:** cards de salas (nome, capacidade, recursos como chips com ícone Lucide),
filtros por capacidade/recurso; calendário FullCalendar mostrando slots de disponibilidade
como fundo e reservas ocupadas como eventos.
**Aceite:** seed sobe e a view lista 3 salas; filtros funcionam; sem CRUD de salas (botão
novo ambiente NÃO existe).

---

### T04 — Criação de reserva sem conflito (RF-02, RF-03, RN-01, RN-02) **(Livre)**
**Objetivo:** o coração do sistema. Traz TODO o SQL que precisa.
**Arquivos:** `js/reservations.js`, view em `app.html`,
`supabase/migrations/T04_reservations.sql`.
**SQL da tarefa:**
```sql
create table if not exists reservations (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references rooms(id),
  user_id uuid not null references profiles(id),
  date date not null,
  start_time timestamptz not null, end_time timestamptz not null,
  status reservation_status not null default 'CONFIRMADA',
  checkin_at timestamptz, created_at timestamptz not null default now(),
  check (end_time > start_time));
-- RN-01
alter table reservations add constraint no_overlap
  exclude using gist (room_id with =, tstzrange(start_time,end_time) with &&)
  where (status in ('CONFIRMADA','EM_USO'));
-- RN-02
create or replace function check_availability() returns trigger as $$
declare n int; begin
  select count(*) into n from availability_slots a
  where a.room_id=new.room_id
    and a.weekday = extract(isodow from new.date) % 7
    and a.start_time <= new.start_time::time
    and a.end_time >= new.end_time::time;
  if n=0 then raise exception 'RN-02: fora da disponibilidade'; end if;
  return new; end $$ language plpgsql;
drop trigger if exists trg_check_availability on reservations;
create trigger trg_check_availability before insert on reservations
for each row execute function check_availability();
-- RLS
alter table reservations enable row level security;
create policy p_res_insert on reservations for insert to authenticated
  with check (user_id = auth.uid());
create policy p_res_read on reservations for select to authenticated
  using (user_id = auth.uid()
      or coalesce((auth.jwt()->'app_metadata'->>'role')::app_role,'solicitante')
          in ('coordenadora','admin'));
```
**Front:** fluxo em 3 passos (data/horário → sala → confirmação). Tratar erros por código
Postgres: `23P01` (no_overlap) → "Sala acabou de ser reservada"; exception RN-02 →
"Fora do horário permitido".
**Aceite:** 10 inserts concorrentes do mesmo sala/horário → exatamente 1 sucesso;
insert fora da grade → exception RN-02.

---

### T05 — Minhas reservas e cancelamento (RF-03, RF-10, RN-05) **(Livre)**
**Objetivo:** listar, detalhar e cancelar.
**Arquivos:** `js/reservations.js` (seção "minhas"), view em `app.html`,
`supabase/migrations/T05_cancel.sql`.
**SQL da tarefa:**
```sql
create table if not exists app_settings (key text primary key, value text not null);
insert into app_settings values ('cancel_min_hours','2')
  on conflict (key) do nothing;
create or replace function check_cancel_window() returns trigger as $$
declare h int; begin
  if new.status='CANCELADA' and old.status='CONFIRMADA' then
    select value::int into h from app_settings where key='cancel_min_hours';
    if new.start_time - now() < make_interval(hours=>h) then
      raise exception 'RN-05: fora do prazo de cancelamento (%)h', h;
    end if;
  end if;
  return new; end $$ language plpgsql;
drop trigger if exists trg_check_cancel on reservations;
create trigger trg_check_cancel before update on reservations
for each row execute function check_cancel_window();
create policy if not exists p_res_update on reservations for update to authenticated
  using (user_id = auth.uid()
      or coalesce((auth.jwt()->'app_metadata'->>'role')::app_role,'solicitante')
          in ('coordenadora','admin'));
```
**Front:** lista com `badgeStatus`, botão cancelar desabilitado com tooltip quando dentro
do prazo mínimo (cálculo no front + validação no trigger).
**Aceite:** cancelar < 2h antes → exception RN-05; depois → status CANCELADA.

---

### T06 — Check-in e no-show automático (RF-04, RN-03) **(Livre)**
**Objetivo:** RPC de check-in + expiração por cron.
**Arquivos:** `js/checkin.js`, view em `app.html`,
`supabase/migrations/T06_checkin.sql`, edge function `supabase/functions/checkin-expire/index.ts`.
**SQL da tarefa:**
```sql
insert into app_settings values
  ('checkin_window_before_min','15'),
  ('checkin_window_after_min','15')
on conflict (key) do nothing;

create or replace function checkin(p_reservation_id uuid) returns reservations as $$
declare r reservations; begin
  select * into r from reservations
   where id=p_reservation_id and user_id=auth.uid() for update;
  if not found then raise exception 'reserva nao encontrada'; end if;
  if r.status <> 'CONFIRMADA' then raise exception 'status invalido: %', r.status; end if;
  if now() < r.start_time - (select value::int from app_settings where key='checkin_window_before_min')*interval '1 minute'
     or now() > r.start_time + (select value::int from app_settings where key='checkin_window_after_min')*interval '1 minute'
  then raise exception 'fora da janela de check-in'; end if;
  update reservations set status='EM_USO', checkin_at=now()
   where id=r.id returning * into r;
  return r; end $$ language plpgsql security definer;

create or replace function expire_no_shows() returns void as $$
update reservations set status='NO_SHOW'
 where status='CONFIRMADA'
   and start_time + (select value::int from app_settings where key='checkin_window_after_min')*interval '1 minute' < now();
$$ language sql security definer;
```
**Aceite:** `checkin()` fora da janela → exception; dentro → EM_USO; após janela,
`expire_no_shows()` marca NO_SHOW.

---

### T07 — Disponibilidade da coordenadora (RF-09) **(Livre)**
**Objetivo:** grade semanal por sala, escrita restrita.
**Arquivos:** `js/availability.js`, view em `admin.html`.
**SQL da tarefa:**
```sql
create policy if not exists p_slots_write on availability_slots for all to authenticated
  using (coalesce((auth.jwt()->'app_metadata'->>'role')::app_role,'solicitante')
           in ('coordenadora','admin'))
  with check (coalesce((auth.jwt()->'app_metadata'->>'role')::app_role,'solicitante')
           in ('coordenadora','admin'));
```
**Front:** FullCalendar com drag-and-drop criando slots semanais; salvamento faz
`delete`+`insert` da grade daquela sala (transação).
**Aceite:** solicitante grava slot → policy nega (erro 42501); coordenadora grava OK.

---

### T08 — Relatórios (RF-08) **(Livre)**
**Objetivo:** ocupação, no-shows, histórico CSV.
**Arquivos:** `js/reports.js`, view em `admin.html`.
**Front:** Chart.js — ocupação % por sala/período (horas reservadas ÷ horas disponíveis),
no-shows (contagem e %), tabela de histórico com export CSV (botão com ícone `download`).
**Aceite:** com o seed da T03 + 4 reservas de teste inseridas no próprio teste, a
ocupação calculada bate com o valor esperado (assert no teste).

---

### T09 — Fila de notificações + e-mail transacional (RF-05, RNF-04) **(Livre)**
**Objetivo:** trigger enfileira; edge function envia e-mail.
**Arquivos:** `supabase/migrations/T09_notifications.sql`,
`supabase/functions/email-send/index.ts`, `js/notifications.js` (view de status).
**SQL da tarefa:**
```sql
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid references reservations(id) on delete set null,
  channel channel not null, template text not null,
  payload jsonb not null default '{}',
  status notif_status not null default 'QUEUED',
  provider_id text, delivered_at timestamptz, read_at timestamptz,
  attempts int not null default 0, created_at timestamptz not null default now());
alter table notifications enable row level security;
create policy p_notif_read on notifications for select to authenticated
  using (coalesce((auth.jwt()->'app_metadata'->>'role')::app_role,'solicitante')
           in ('coordenadora','admin'));

create or replace function enqueue_notifications() returns trigger as $$
begin
  if tg_op='INSERT' and new.status='CONFIRMADA' then
    insert into notifications (reservation_id, channel, template, payload) values
      (new.id,'WHATSAPP','reserva_confirmada', jsonb_build_object('reservation_id',new.id)),
      (new.id,'EMAIL','reserva_confirmada',    jsonb_build_object('reservation_id',new.id));
  elsif tg_op='UPDATE' and new.status='CANCELADA' and old.status<>'CANCELADA' then
    insert into notifications (reservation_id, channel, template, payload) values
      (new.id,'WHATSAPP','reserva_cancelada', jsonb_build_object('reservation_id',new.id)),
      (new.id,'EMAIL','reserva_cancelada',    jsonb_build_object('reservation_id',new.id));
  end if;
  return new; end $$ language plpgsql;
drop trigger if exists trg_notify on reservations;
create trigger trg_notify after insert or update on reservations
for each row execute function enqueue_notifications();
```
**Edge function:** consome fila (channel=EMAIL, status=QUEUED), envia via API
transacional (Resend/SES) com templates HTML; backoff exponencial máx. 5 tentativas → FAILED.
**Aceite:** criar reserva gera 2 linhas QUEUED; function marca SENT + provider_id.

---

### T10 — Envio WhatsApp com rate limit (RF-05, RNF-03, RN-04) **(Livre)**
**Objetivo:** mesma fila, channel=WHATSAPP, com throttle.
**Arquivos:** `supabase/functions/whatsapp-send/index.ts`.
**Regras:** respeitar `WHATSAPP_RATE_LIMIT_PER_MIN` (default 80) via token bucket no
Redis (ou `pg_advisory_lock` + contador se Redis indisponível); retentativa exponencial
máx. 5; falha NUNCA derruba o fluxo de reserva; templates usados só se previamente
aprovados na Meta (se `WHATSAPP_ENABLED=false`, retorna 200 sem enviar).
**Aceite:** burst simulado de 500 notificações não excede 80/min no mock do adapter.

---

### T11 — Webhook de status WhatsApp (RF-07) **(Livre)**
**Objetivo:** atualizar entrega/leitura.
**Arquivos:** `supabase/functions/whatsapp-webhook/index.ts`.
**Regras:** GET com `hub.verify_token` (Meta); POST processa `statuses`:
sent→SENT, delivered→DELIVERED + delivered_at, read→READ + read_at; localiza a notificação
por `provider_id` (= wamid).
**Aceite:** payload de teste da Meta atualiza a linha correta.

---

### T12 — Lembretes automáticos (RF-06) **(Livre)**
**Objetivo:** enfileirar lembretes 24h e 1h antes.
**Arquivos:** `supabase/functions/lembretes/index.ts` (scheduled, a cada hora).
**Regras:** seleciona reservas CONFIRMADA com início entre 23h–24h e 0h–1h à frente;
insere notifications com templates `lembrete_24h` / `lembrete_1h` (canal duplo);
idempotente (unique implícita: não duplicar se já existe notif com mesmo reservation+template).
**Aceite:** executar com relógio mockado cria exatamente 1 lembrete por reserva elegível.

---

### T13 — Sincronização em tempo real **(Livre)**
**Objetivo:** salas ocupadas somem da busca ao vivo; status das minhas reservas atualiza.
**Arquivos:** `js/realtime.js`.
**Regras:** `supabase.channel('reservations')` com `postgres_changes` em `reservations`;
recarrega a busca ao receber INSERT/UPDATE relevante; atualiza badges por cliente.
**Aceite:** dois navegadores abertos — reserva feita em A some da busca em B em < 2s.

---

### T14 — LGPD e mascaramento (RNF-01) **(Livre)**
**Objetivo:** proteção de dados pessoais.
**Arquivos:** `js/lgpd.js`, `supabase/migrations/T14_lgpd.sql`.
**Entregas:**
- RPC `delete_my_account()`: anonimiza `profiles` (name='Usuário removido', phone=null)
  em vez de apagar reservas históricas.
- Utilitário `maskPhone(phone)` → `(**) *****-0000`; usado em toda listagem que não seja
  o próprio perfil.
- Auditoria: varredura garantindo ausência de `phone`/`email` em `console.log`
  (erro de lint manual documentado no README).
**Aceite:** máscara aplicada em listagens; RPC anonimiza e mantém histórico.

---

### T15 — QA, documentação e entrega **(Livre — exceto recomendação de rodar por último)**
**Objetivo:** fechamento.
**Arquivos:** `README.md`, `docs/templates-mensagens.md`, `supabase/seed.sql` (completo),
roteiro de testes `docs/roteiro-testes.md`.
**Entregas:** checklist de setup (Supabase, Auth redirect, cron, Meta, DNS SPF/DKIM/DMARC);
textos dos templates WhatsApp a submeter à Meta + versões HTML dos e-mails; roteiro de
testes cobrindo cada critério de aceite das tarefas T02–T14.
**Aceite:** README permite que um humano configure o sistema do zero sem ajuda.

---

## 2. DIRETRIZES UI/UX (valem para TODAS as tarefas com front-end)

1. **Interface limpa e densa sem poluir:** maximize o uso da tela (tabelas e grades com
   altura compacta, `min-h` em cards), mas com respiro — escala de espaçamento de 4px
   (4/8/12/16/24), sem elementos decorativos sem função.
2. **Sem emojis — em nenhum lugar:** nem em toasts, erros, badges, mensagens de
   confirmação, e-mails ou templates WhatsApp. Use **Lucide Icons** (CDN) via
   `<i data-lucide="nome-do-icone"></i>` + `lucide.createIcons()`.
   Sugestões de mapeamento: reservas=`calendar`, check-in=`scan-line`, salas=`door-open`,
   relatórios=`bar-chart-3`, alertas=`alert-triangle`, sucesso=`check-circle-2`,
   e-mail=`mail`, WhatsApp=`message-circle`, exportar=`download`.
3. **Estados sempre visíveis:** loading (skeleton ou spinner), vazio (ilustração simples
   em SVG + texto), erro (toast + mensagem acionável). Nunca deixar tela morta.
4. **Acessibilidade mínima:** contraste AA, foco visível, botões com `aria-label` quando
   só ícone.
5. **Mobile-first:** telas usáveis em 360px; tabelas viram cards no mobile.
6. **Consistência:** usar SOMENTE componentes de `js/ui.js` (T01). Se faltar um
   componente, criar na T01 (arquivo compartilhado) e registrar no BACKLOG.

---

## 3. REGRAS DE COMPORTAMENTO DO AGENTE

### A-1. Backlog obrigatório (`BACKLOG.md`)
- SEMPRE que corrigir um bug, ajustar comportamento, alterar escopo ou desviar da spec,
  registrar em `BACKLOG.md` ANTES de considerar a tarefa concluída.
- Formato de cada entrada:
```md
## [YYYY-MM-DD HH:MM] — <ID da tarefa>
- Tipo: correção | ajuste | alteração de escopo | dúvida resolvida
- Contexto: o que estava previsto vs. o que foi feito
- Motivo: por que o desvio foi necessário
- Impacto: contratos afetados (seção 0), tarefas impactadas
- Status: aberto | resolvido
```
- O backlog é incremental: nunca apagar entradas; resolver = mudar Status.
- Ao final de cada tarefa, incluir o diff resumido do backlog no resumo da tarefa.

### A-2. Escalação para humano
- DÚVIDA que mude comportamento, contrato (seção 0), regra de negócio ou custo:
  **PARAR e perguntar ao humano.** Apresentar: contexto, opções (mín. 2) com prós/contras
  e recomendação. Não escolher sozinho.
- DÚVIDA puramente técnica/de implementação dentro da spec: decidir, registrar no
  BACKLOG (tipo "dúvida resolvida") e seguir.
- Erro de ambiente/externo (Supabase fora, Meta, credenciais): registrar no BACKLOG e
  escalar — não inventar workaround que mude contrato.
- Erro interno da tarefa: corrigir DENTRO da tarefa (independência), registrar no BACKLOG.

### A-3. Independência entre tarefas
- Proibido editar SQL/front de outra tarefa para "consertar" algo. Se a falha é de outra
  tarefa, registrar no BACKLOG (tipo "correção", impacto = tarefa X) e seguir a própria.
- SQL sempre idempotente (`create table if not exists`, `drop trigger if exists`,
  `on conflict do nothing`) para migrações rodarem em qualquer ordem.

### A-4. Qualidade mínima por entrega
- Cada tarefa termina com: código, SQL da tarefa aplicado, teste do critério de aceite
  executado, e entrada no BACKLOG (mesmo que vazia, registrar "sem desvios").

---

## 4. ORDEM SUGERIDA (apenas conveniência — T01–T14 são Livres)
T01 → T02 → T03 → T04 → T05 → T06 → T07 → T08 → T09 → T10 → T11 → T12 → T13 → T14 → T15
