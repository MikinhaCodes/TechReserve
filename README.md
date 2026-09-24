# TechReserve — Sistema de Reserva de Salas FATEC Franco da Rocha

Sistema de reserva de salas e laboratórios desenvolvido para a **FATEC Franco da Rocha**, combinando uma arquitetura web estática de alto desempenho (HTML5, Tailwind CSS, JS ES Modules via CDN) com o backend serverless **Supabase** (PostgreSQL, Row Level Security, Auth e Realtime).

---

## 🛠️ Stack & Arquitetura

- **Front-end**: HTML5 + CSS (Tailwind CSS via CDN + `css/styles.css` Brutalist Dark) + JavaScript ES Modules.
- **Backend**: Supabase (PostgreSQL 15 + RLS + Triggers + RPCs).
- **Endpoint**: `https://qlskreplbrytqimlpzsb.supabase.co`
- **Chave Pública**: `sb_publishable_PmpT5PmtTu6rx0k_XpI3ow_BmOYQA6P`

---

## 🚀 Checklist de Setup (Instalação)

1. **Configuração de Banco de Dados**:
   - Abra o Dashboard do Supabase -> **SQL Editor**.
   - Copie e execute o conteúdo de `supabase/schema.sql`.
   - Copie e execute o conteúdo de `supabase/seed.sql` para cadastrar as salas iniciais.

2. **Hospedagem Estática**:
   - Faça o upload da pasta raiz para qualquer provedor estático (Netlify, Vercel, GitHub Pages). Não há processo de build ou `npm install`.

3. **Arquivos do Projeto**:
   - `js/config.js`: Contém as credenciais e flags do projeto.
   - `supabase/schema.sql`: Esqueletos de tabelas, RLS e funções do banco.
   - `supabase/seed.sql`: Dados de exemplo.
