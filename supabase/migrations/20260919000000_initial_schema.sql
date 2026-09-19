-- Enums
create type public.user_role as enum ('client', 'professional', 'admin');
create type public.request_status as enum ('open', 'quoted', 'booked', 'completed', 'cancelled');
create type public.booking_status as enum ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled');

-- Core identity (auth.users is the source of authentication)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null check (char_length(full_name) >= 2),
  phone text,
  avatar_url text,
  role public.user_role not null default 'client',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  description text,
  icon text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.professional_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  bio text,
  document_number text,
  city text,
  state text,
  service_radius_km integer check (service_radius_km > 0),
  verified_at timestamptz,
  average_rating numeric(3,2) not null default 0 check (average_rating between 0 and 5),
  review_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.services (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  category_id uuid not null references public.categories(id),
  title text not null,
  description text,
  base_price numeric(12,2) check (base_price >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.service_requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.profiles(id) on delete cascade,
  category_id uuid not null references public.categories(id),
  title text not null,
  description text not null,
  address_text text,
  desired_date timestamptz,
  status public.request_status not null default 'open',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.quotes (
  id uuid primary key default gen_random_uuid(),
  service_request_id uuid not null references public.service_requests(id) on delete cascade,
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  amount numeric(12,2) not null check (amount >= 0),
  message text,
  valid_until timestamptz,
  accepted_at timestamptz,
  created_at timestamptz not null default now(),
  unique(service_request_id, professional_id)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid unique references public.quotes(id) on delete set null,
  client_id uuid not null references public.profiles(id),
  professional_id uuid not null references public.professional_profiles(user_id),
  service_id uuid references public.services(id) on delete set null,
  scheduled_at timestamptz not null,
  status public.booking_status not null default 'pending',
  address_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.availability (
  id uuid primary key default gen_random_uuid(),
  professional_id uuid not null references public.professional_profiles(user_id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null check (end_time > start_time),
  active boolean not null default true,
  unique(professional_id, weekday, start_time, end_time)
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  client_id uuid not null references public.profiles(id),
  professional_id uuid not null references public.professional_profiles(user_id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

create index services_professional_idx on public.services(professional_id);
create index requests_client_idx on public.service_requests(client_id);
create index requests_category_status_idx on public.service_requests(category_id, status);
create index quotes_request_idx on public.quotes(service_request_id);
create index bookings_client_idx on public.bookings(client_id);
create index bookings_professional_idx on public.bookings(professional_id);

-- Helpers: security definer functions avoid recursive RLS checks
create or replace function public.current_role() returns public.user_role language sql stable security definer set search_path = public as $$ select role from public.profiles where id = auth.uid() $$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$ select coalesce(public.current_role() = 'admin', false) $$;
create or replace function public.touch_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated before update on public.profiles for each row execute procedure public.touch_updated_at();
create trigger professional_profiles_updated before update on public.professional_profiles for each row execute procedure public.touch_updated_at();
create trigger services_updated before update on public.services for each row execute procedure public.touch_updated_at();
create trigger service_requests_updated before update on public.service_requests for each row execute procedure public.touch_updated_at();
create trigger bookings_updated before update on public.bookings for each row execute procedure public.touch_updated_at();

-- Creates a profile after sign-up. Admin role can never be selected through public metadata.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
declare selected_role public.user_role;
begin
  selected_role := case when new.raw_user_meta_data->>'role' = 'professional' then 'professional'::public.user_role else 'client'::public.user_role end;
  insert into public.profiles (id, full_name, role) values (new.id, coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)), selected_role);
  if selected_role = 'professional' then insert into public.professional_profiles (user_id) values (new.id); end if;
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- The only user-invocable role transition. It deliberately excludes admin.
create or replace function public.set_my_role(new_role public.user_role) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or new_role = 'admin' then raise exception 'Role change not allowed'; end if;
  update public.profiles set role = new_role where id = auth.uid();
  if new_role = 'professional' then insert into public.professional_profiles (user_id) values (auth.uid()) on conflict (user_id) do nothing; end if;
end; $$;
grant execute on function public.set_my_role(public.user_role) to authenticated;

alter table public.profiles enable row level security;
alter table public.professional_profiles enable row level security;
alter table public.categories enable row level security;
alter table public.services enable row level security;
alter table public.service_requests enable row level security;
alter table public.quotes enable row level security;
alter table public.bookings enable row level security;
alter table public.availability enable row level security;
alter table public.reviews enable row level security;

-- Profiles: public professional cards; users edit only their profile (role immutable via policy)
create policy "profiles visible to authenticated" on public.profiles for select to authenticated using (true);
create policy "users update their non-role profile" on public.profiles for update to authenticated using (id = auth.uid() or public.is_admin()) with check ((id = auth.uid() and role = (select role from public.profiles where id = auth.uid())) or public.is_admin());
create policy "admins manage profiles" on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "professional profiles readable" on public.professional_profiles for select to authenticated using (true);
create policy "professionals manage own profile" on public.professional_profiles for all to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "categories readable" on public.categories for select to authenticated using (active or public.is_admin());
create policy "admins manage categories" on public.categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "services readable" on public.services for select to authenticated using (active or professional_id = auth.uid() or public.is_admin());
create policy "professionals manage own services" on public.services for all to authenticated using (professional_id = auth.uid() or public.is_admin()) with check (professional_id = auth.uid() or public.is_admin());
create policy "clients view own requests" on public.service_requests for select to authenticated using (client_id = auth.uid() or public.current_role() = 'professional' or public.is_admin());
create policy "clients create requests" on public.service_requests for insert to authenticated with check (client_id = auth.uid() and public.current_role() = 'client');
create policy "clients update own open requests" on public.service_requests for update to authenticated using (client_id = auth.uid() or public.is_admin()) with check (client_id = auth.uid() or public.is_admin());
create policy "clients delete own requests" on public.service_requests for delete to authenticated using (client_id = auth.uid() or public.is_admin());
create policy "request participants view quotes" on public.quotes for select to authenticated using (professional_id = auth.uid() or exists (select 1 from public.service_requests r where r.id = service_request_id and r.client_id = auth.uid()) or public.is_admin());
create policy "professionals create quotes" on public.quotes for insert to authenticated with check (professional_id = auth.uid() and public.current_role() = 'professional');
create policy "professionals update quotes" on public.quotes for update to authenticated using (professional_id = auth.uid() or public.is_admin()) with check (professional_id = auth.uid() or public.is_admin());
create policy "participants view bookings" on public.bookings for select to authenticated using (client_id = auth.uid() or professional_id = auth.uid() or public.is_admin());
create policy "clients create bookings" on public.bookings for insert to authenticated with check (client_id = auth.uid() and public.current_role() = 'client');
create policy "participants update bookings" on public.bookings for update to authenticated using (client_id = auth.uid() or professional_id = auth.uid() or public.is_admin()) with check (client_id = auth.uid() or professional_id = auth.uid() or public.is_admin());
create policy "availability readable" on public.availability for select to authenticated using (active or professional_id = auth.uid() or public.is_admin());
create policy "professionals manage availability" on public.availability for all to authenticated using (professional_id = auth.uid() or public.is_admin()) with check (professional_id = auth.uid() or public.is_admin());
create policy "reviews readable" on public.reviews for select to authenticated using (true);
create policy "clients create completed-booking reviews" on public.reviews for insert to authenticated with check (client_id = auth.uid() and exists (select 1 from public.bookings b where b.id = booking_id and b.client_id = auth.uid() and b.professional_id = professional_id and b.status = 'completed'));
create policy "clients update own reviews" on public.reviews for update to authenticated using (client_id = auth.uid() or public.is_admin()) with check (client_id = auth.uid() or public.is_admin());

-- Storage: use a non-public bucket for profile images; path must start with user id.
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', false) on conflict (id) do nothing;
create policy "avatar files are readable by authenticated users" on storage.objects for select to authenticated using (bucket_id = 'avatars');
create policy "users upload own avatar" on storage.objects for insert to authenticated with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "users update own avatar" on storage.objects for update to authenticated using (bucket_id = 'avatars' and owner_id = auth.uid()::text) with check (bucket_id = 'avatars' and owner_id = auth.uid()::text);
create policy "users delete own avatar" on storage.objects for delete to authenticated using (bucket_id = 'avatars' and owner_id = auth.uid()::text);
