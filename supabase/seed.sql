-- ============================================================
-- TechReserve — Seed Data (Ambiente de Desenvolvimento)
-- ============================================================

-- Insere as 3 salas padrão FATEC Franco da Rocha
insert into public.rooms (name, capacity, resources, active) values
  ('Laboratório de Informática 01', 40, '["projetor","ar-condicionado","computadores","lousa-digital"]', true),
  ('Sala de Reuniões & Congregação 02', 12, '["tv","videochamada","ar-condicionado"]', true),
  ('Auditório Principal FATEC', 120, '["palco","som","projetor","ar-condicionado"]', true)
on conflict do nothing;

-- Insere grade semanal padrão (Seg–Sáb, 07:00–22:00) para cada sala
insert into public.availability_slots (room_id, weekday, start_time, end_time)
select r.id, w.d, '07:00'::time, '22:00'::time
from public.rooms r
cross join (values (1),(2),(3),(4),(5),(6)) as w(d)
on conflict do nothing;
