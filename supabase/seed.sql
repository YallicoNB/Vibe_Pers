-- Datos exclusivamente ficticios. Aplicar tras las migraciones en un entorno de prueba.
insert into public.communities (id, name, area_label, center_lat, center_lng, is_demo)
values
  ('00000000-0000-4000-8000-000000000001', 'Junta Las Palmeras', 'Zona de demostración A', -11.9380, -76.6960, true),
  ('00000000-0000-4000-8000-000000000002', 'Junta Los Olivos', 'Zona de demostración B', -11.9420, -76.7010, true)
on conflict (id) do nothing;

insert into public.emergency_resources (id, community_id, title, kind, details, is_demo)
values
  ('00000000-0000-4000-8000-000000000011', '00000000-0000-4000-8000-000000000001', 'Brigada vecinal de ejemplo', 'GRUPO', 'No responde a emergencias reales.', true),
  ('00000000-0000-4000-8000-000000000012', '00000000-0000-4000-8000-000000000001', 'Punto seguro de ejemplo', 'ZONA', 'No es una ruta de evacuación real.', true),
  ('00000000-0000-4000-8000-000000000013', '00000000-0000-4000-8000-000000000002', 'Grupo de apoyo de ejemplo', 'GRUPO', 'Solo datos de ensayo.', true)
on conflict (id) do nothing;
