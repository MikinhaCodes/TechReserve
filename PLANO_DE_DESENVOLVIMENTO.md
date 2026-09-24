# Análise da SPEC e Plano de Desenvolvimento — TechReserve (FATEC Franco da Rocha)

---

## 1. ANÁLISE DA SPEC E DA ESTRUTURA DO PROJETO

### 1.1 Objetivo e Escopo
O **TechReserve** é um sistema web para gestão e reserva de salas e laboratórios de informática para a **FATEC Franco da Rocha**. O sistema é uma **aplicação web estática** (sem build/bundlers/npm), servida via CDN (Tailwind CSS, Supabase JS v2, FullCalendar 6, Chart.js 4, SweetAlert2 e Lucide Icons), integrada diretamente ao backend **Supabase (PostgreSQL)**.

### 1.2 Perfis de Acesso (Roles)
- **`solicitante`** (Docentes): Busca de salas, criação e cancelamento das próprias reservas, realização de check-in dentro da janela de tolerância.
- **`coordenadora`**: Todas as permissões do solicitante + edição da grade de disponibilidade de salas (`availability_slots`) e visualização de relatórios gerenciais/ocupação.
- **`admin`**: Acesso completo + gestão de usuários e troca de papéis.

---

## 2. MAPEAMENTO DAS INTERFACES DO GOOGLE STITCH (`THEME/`)

As interfaces na pasta `THEME/` definem a linguagem visual **Architectural Brutalist Dark Clean** do projeto FATEC Franco da Rocha:

1. **Tokens de Design (`THEME/techreserve_design_system/DESIGN.md`)**:
   - **Cores principais**: Canvas `#131315`, Primária Carmesim `#731717` / `#A82E2E`, Terciário Âmbar `#D19B53`, Confirmação `#4ADE80`.
   - **Geometria**: Cantos retos de 90 graus (`roundedness: 0`), bordas finas sólidas `1px #2D3039`.
   - **Tipografia**: `Space Grotesk` (títulos e códigos) e `Geist` (textos, tabelas e horários).

2. **Dashboard do Solicitante (`THEME/dashboard_techreserve_fatec_dark_clean/code.html`)**:
   - **Próxima Reserva em Destaque**: Hero card com status em tempo real, contagem regressiva e ação rápida de check-in de 1 clique.
   - **Métricas Acadêmicas**: Cards de resumo (quantidade de salas agendadas, horas de uso no mês, integração com WhatsApp).
   - **Lista de Reservas**: Tabela interativa com filtros de período (Todas, Hoje, Esta Semana).
   - **Suporte Acadêmico**: Painel lateral com ramais da zeladoria e regras de uso.

3. **Tela de Reserva (`THEME/reservar_sala_techreserve_fatec_dark_clean/code.html`)**:
   - **Passo 1 (Filtros e Horários)**: Seleção de data, bloco de horário acadêmico (ex: Tarde 14:00–16:00), capacidade mínima e chips de recursos (Projetor, Ar-condicionado, Computadores).
   - **Passo 2 (Listagem de Salas Livres)**: Cards de salas com fotos, badges de disponibilidade (`#4ADE80`), tags de periféricos e botão de seleção.
   - **Passo 3 (Gaveta de Confirmação Lateral)**: Resumo da disciplina/motivo, observações técnicas e confirmação com a constraint de sobreposição do Supabase.

---

## 3. ARQUITETURA DE BANCO DE DADOS E SUPABASE

### 3.1 Credenciais e Conexão
- **REST Endpoint**: `https://qlskreplbrytqimlpzsb.supabase.co`
- **Chave Pública (Anon/Publishable)**: `sb_publishable_PmpT5PmtTu6rx0k_XpI3ow_BmOYQA6P`
- **Client JS**: Centralizado como singleton em `js/supabase.js`.

### 3.2 Schema PostgreSQL (`supabase/schema.sql`)
- **Tabelas**: `profiles`, `rooms`, `availability_slots`, `reservations`, `notifications`, `app_settings`.
- **Prevenção Concorrente Físico-Anatomica (RN-01)**: Constraint `no_overlap` do tipo `EXCLUDE USING gist` em `reservations(room_id, tstzrange(start_time, end_time)) WHERE (status IN ('CONFIRMADA', 'EM_USO'))`.
- **Triggers de Negócio**:
  - `check_availability()`: Valida se a reserva está dentro de um slot configurado pela coordenadora (RN-02).
  - `check_cancel_window()`: Garante antecedência mínima (default 2h) para cancelamento (RN-05).
  - `enqueue_notifications()`: Insere registros na fila de notificações (`notifications`) para WhatsApp e E-mail.
- **Funções RPC**:
  - `checkin(p_reservation_id)`: Valida janela de -15min / +15min e altera status para `EM_USO`.
  - `expire_no_shows()`: Converte reservas não confirmadas após o horário para `NO_SHOW`.
  - `delete_my_account()`: Anonimiza dados conforme a LGPD.
- **Row Level Security (RLS)**: Leitura pública de salas ativas; escritas restritas ao proprietário da reserva ou perfis `coordenadora`/`admin`.

---

## 4. PLANO DE DESENVOLVIMENTO E ETAPAS DE EXECUÇÃO

### Etapa 1: Configuração de Banco e Parâmetros (`supabase/schema.sql` e `supabase/seed.sql`)
1. Executar `supabase/schema.sql` no SQL Editor do Supabase.
2. Executar `supabase/seed.sql` populando as 3 salas padrão (Laboratório de Informática 01, Sala de Reuniões 02, Auditório) e a grade semanal inicial.

### Etapa 2: Fundação Front-end e Design System (`css/styles.css`, `js/config.js`, `js/supabase.js`, `js/ui.js`)
1. `js/config.js`: Definir URL, chave pública e feature flags de notificação.
2. `css/styles.css`: Importar fontes Geist / Space Grotesk e estilizar classes brutas do tema Stitch.
3. `js/ui.js`: Implementar manipuladores de Toast, diálogos SweetAlert2 e renderização de Badges de status.

### Etapa 3: Autenticação e Perfis (`index.html`, `js/auth.js`)
1. Interface de login, cadastro com máscara IMask para telefone e checkbox LGPD.
2. Controle de sessão via Supabase Auth e redirecionamento conforme perfil do usuário.

### Etapa 4: Shell e Visões do Solicitante (`app.html`, `js/router.js`, `js/rooms.js`, `js/reservations.js`, `js/checkin.js`)
1. Reutilizar o layout em `THEME/dashboard_techreserve_fatec_dark_clean/code.html` e `THEME/reservar_sala_techreserve_fatec_dark_clean/code.html`.
2. Implementar busca dinâmica de salas com filtragem de capacidade e recursos.
3. Tratamento de inserção de reserva e exibição do erro 23505/23P01 em caso de concorrência.
4. Acionamento do botão de check-in rápido integrado à RPC `checkin()`.

### Etapa 5: Atualização em Tempo Real (`js/realtime.js`)
1. Inscrição no canal Realtime `supabase.channel('reservations')` para remoção instantânea de salas ocupadas na interface de busca.

### Etapa 6: Módulos Administrativos e Relatórios (`admin.html`, `js/availability.js`, `js/reports.js`)
1. Interface de grade semanal FullCalendar para a coordenadora gerenciar `availability_slots`.
2. Dashboard gerencial com Chart.js para percentual de ocupação por sala e relatórios de no-show com exportação CSV.

### Etapa 7: Edge Functions e Notificações (`supabase/functions/`, `docs/templates-mensagens.md`)
1. Desenvolvimento das funções Deno/TypeScript para envio de e-mails, integração com Meta Cloud API (WhatsApp) com rate limiting de 80/min, webhook de status e cron de lembretes.
