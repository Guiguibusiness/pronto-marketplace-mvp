-- Discovery fields and work gallery
create type public.price_type as enum ('fixed', 'quote');
alter table public.professional_profiles add column if not exists neighborhood text;
alter table public.professional_profiles add column if not exists latitude double precision;
alter table public.professional_profiles add column if not exists longitude double precision;
alter table public.professional_profiles add column if not exists completed_services_count integer not null default 0;
alter table public.services add column if not exists price_type public.price_type not null default 'quote';

create table public.professional_photos (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  storage_path text not null,
  caption text,
  position smallint not null default 0,
  created_at timestamptz not null default now()
);
create index professional_photos_professional_idx on public.professional_photos(professional_id, position);

alter table public.professional_photos enable row level security;
create policy "professional photos readable" on public.professional_photos for select to authenticated using (true);
create policy "professionals manage their photos" on public.professional_photos for all to authenticated using (professional_id = auth.uid() or public.is_admin()) with check (professional_id = auth.uid() or public.is_admin());

-- Gallery images are stored privately, and served by signed URLs in the client.
insert into storage.buckets (id, name, public) values ('professional-gallery', 'professional-gallery', false) on conflict (id) do nothing;
create policy "authenticated users read gallery" on storage.objects for select to authenticated using (bucket_id = 'professional-gallery');
create policy "professionals upload their gallery" on storage.objects for insert to authenticated with check (bucket_id = 'professional-gallery' and (storage.foldername(name))[1] = auth.uid()::text and public.current_role() = 'professional');
create policy "professionals update their gallery" on storage.objects for update to authenticated using (bucket_id = 'professional-gallery' and owner_id = auth.uid()::text) with check (bucket_id = 'professional-gallery' and owner_id = auth.uid()::text);
create policy "professionals delete their gallery" on storage.objects for delete to authenticated using (bucket_id = 'professional-gallery' and owner_id = auth.uid()::text);

-- Keeps discovery rating/count synced after a review is written or changed.
create or replace function public.refresh_professional_rating() returns trigger language plpgsql security definer set search_path = public as $$
begin
 update public.professional_profiles p set average_rating = coalesce((select round(avg(r.rating)::numeric, 2) from public.reviews r where r.professional_id = coalesce(new.professional_id, old.professional_id)), 0), review_count = (select count(*) from public.reviews r where r.professional_id = coalesce(new.professional_id, old.professional_id)) where p.user_id = coalesce(new.professional_id, old.professional_id);
 return coalesce(new, old);
end; $$;
create trigger reviews_refresh_rating after insert or update or delete on public.reviews for each row execute procedure public.refresh_professional_rating();

-- Public discovery only exposes active catalog and professional information.
drop policy "profiles visible to authenticated" on public.profiles;
create policy "public profiles readable" on public.profiles for select to anon, authenticated using (role = 'professional' or id = auth.uid() or public.is_admin());
drop policy "professional profiles readable" on public.professional_profiles;
create policy "public professional profiles readable" on public.professional_profiles for select to anon, authenticated using (true);
drop policy "categories readable" on public.categories;
create policy "public categories readable" on public.categories for select to anon, authenticated using (active or public.is_admin());
drop policy "services readable" on public.services;
create policy "public active services readable" on public.services for select to anon, authenticated using (active or professional_id = auth.uid() or public.is_admin());
drop policy "availability readable" on public.availability;
create policy "public active availability readable" on public.availability for select to anon, authenticated using (active or professional_id = auth.uid() or public.is_admin());
drop policy "reviews readable" on public.reviews;
create policy "public reviews readable" on public.reviews for select to anon, authenticated using (true);
drop policy "professional photos readable" on public.professional_photos;
create policy "public professional photos readable" on public.professional_photos for select to anon, authenticated using (true);
drop policy "authenticated users read gallery" on storage.objects;
create policy "public users read gallery" on storage.objects for select to anon, authenticated using (bucket_id = 'professional-gallery');
