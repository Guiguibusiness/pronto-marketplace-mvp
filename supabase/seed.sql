-- Dados seguros para demonstração local/beta.
-- Execute depois das migrations. Crie contas no Auth primeiro e substitua os UUIDs abaixo.

insert into public.categories (name, slug, description, icon) values
  ('Elétrica', 'eletrica', 'Instalações, reparos e manutenção elétrica.', '⚡'),
  ('Hidráulica', 'hidraulica', 'Reparos, vazamentos e instalações hidráulicas.', '🔧'),
  ('Limpeza', 'limpeza', 'Limpeza residencial e comercial.', '✨'),
  ('Pintura', 'pintura', 'Pintura interna, externa e pequenos reparos.', '🎨'),
  ('Montagem', 'montagem', 'Montagem e instalação de móveis.', '🪛')
on conflict (slug) do update set name = excluded.name, description = excluded.description, icon = excluded.icon;

-- Exemplo: depois de criar um profissional no Auth, atualize seu profile e descomente/adapte.
-- update public.profiles set role = 'professional', full_name = 'Ana Souza' where id = '<UUID_DO_PROFISSIONAL>';
-- insert into public.professional_profiles (user_id, bio, city, state, neighborhood, service_radius_km, latitude, longitude)
-- values ('<UUID_DO_PROFISSIONAL>', 'Eletricista residencial com atendimento rápido.', 'Salvador', 'BA', 'Barra', 15, -13.0090, -38.5320)
-- on conflict (user_id) do update set bio = excluded.bio, city = excluded.city, state = excluded.state, neighborhood = excluded.neighborhood, service_radius_km = excluded.service_radius_km, latitude = excluded.latitude, longitude = excluded.longitude;
-- insert into public.services (professional_id, category_id, title, description, price_type, base_price)
-- select '<UUID_DO_PROFISSIONAL>', id, 'Instalação de tomada', 'Instalação de tomada simples.', 'fixed', 85 from public.categories where slug = 'eletrica';

