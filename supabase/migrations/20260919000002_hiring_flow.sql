-- Hiring lifecycle additions (lowercase values are the database representation of the UI statuses).

alter table public.service_requests add column if not exists service_id uuid references public.services(id) on delete set null;
alter table public.service_requests add column if not exists professional_id uuid references public.professional_profiles(user_id) on delete set null;
alter table public.service_requests add column if not exists desired_time time;
alter table public.service_requests add column if not exists notes text;
alter table public.service_requests alter column status set default 'pending';
alter table public.quotes add column if not exists estimated_duration text;
alter table public.quotes add column if not exists status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'withdrawn'));

create table public.request_photos (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.service_requests(id) on delete cascade,
  storage_path text not null,
  created_at timestamptz not null default now()
);
create index request_photos_request_idx on public.request_photos(request_id);
alter table public.request_photos enable row level security;
create policy "request participants see request photos" on public.request_photos for select to authenticated using (exists (select 1 from public.service_requests r where r.id = request_id and (r.client_id = auth.uid() or r.professional_id = auth.uid() or public.is_admin() or (r.professional_id is null and public.current_role() = 'professional'))));
create policy "clients upload request photos" on public.request_photos for insert to authenticated with check (exists (select 1 from public.service_requests r where r.id = request_id and r.client_id = auth.uid()));
create policy "clients delete request photos" on public.request_photos for delete to authenticated using (exists (select 1 from public.service_requests r where r.id = request_id and r.client_id = auth.uid()));

insert into storage.buckets (id, name, public) values ('request-photos', 'request-photos', false) on conflict (id) do nothing;
create policy "participants read request files" on storage.objects for select to authenticated using (bucket_id = 'request-photos');
create policy "clients upload request files" on storage.objects for insert to authenticated with check (bucket_id = 'request-photos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "clients delete request files" on storage.objects for delete to authenticated using (bucket_id = 'request-photos' and owner_id = auth.uid()::text);

-- Lock down direct lifecycle changes. The following RPCs own state transitions.
drop policy "clients update own open requests" on public.service_requests;
create policy "clients edit pending requests" on public.service_requests for update to authenticated using (client_id = auth.uid() and status in ('pending', 'quoting')) with check (client_id = auth.uid() and status in ('pending', 'quoting'));
drop policy "professionals update quotes" on public.quotes;
create policy "professionals edit pending quotes" on public.quotes for update to authenticated using (professional_id = auth.uid() and status = 'pending') with check (professional_id = auth.uid() and status = 'pending');
drop policy "participants update bookings" on public.bookings;

create or replace function public.submit_quote(p_request_id uuid, p_amount numeric, p_message text, p_duration text) returns public.quotes language plpgsql security definer set search_path = public as $$
declare result public.quotes;
begin
 if auth.uid() is null or public.current_role() <> 'professional' then raise exception 'Not allowed'; end if;
 if not exists (select 1 from public.service_requests where id = p_request_id and status in ('pending','quoting') and (professional_id is null or professional_id = auth.uid())) then raise exception 'Request unavailable'; end if;
 insert into public.quotes(service_request_id, professional_id, amount, message, estimated_duration) values (p_request_id, auth.uid(), p_amount, p_message, p_duration) on conflict (service_request_id, professional_id) do update set amount = excluded.amount, message = excluded.message, estimated_duration = excluded.estimated_duration, status = 'pending' returning * into result;
 update public.service_requests set status = 'quoting' where id = p_request_id and status = 'pending';
 return result;
end; $$;

create or replace function public.accept_quote(p_quote_id uuid, p_scheduled_at timestamptz, p_address text default null) returns public.bookings language plpgsql security definer set search_path = public as $$
declare q public.quotes; result public.bookings;
begin
 select * into q from public.quotes where id = p_quote_id and status = 'pending';
 if q.id is null or not exists (select 1 from public.service_requests where id = q.service_request_id and client_id = auth.uid()) then raise exception 'Quote unavailable'; end if;
 update public.quotes set status = case when id = p_quote_id then 'accepted' else 'declined' end, accepted_at = case when id = p_quote_id then now() else accepted_at end where service_request_id = q.service_request_id and status = 'pending';
 insert into public.bookings(quote_id, client_id, professional_id, service_id, scheduled_at, address_text, status) select q.id, r.client_id, q.professional_id, coalesce(q.service_id, r.service_id), p_scheduled_at, coalesce(p_address, r.address_text), 'scheduled' from public.service_requests r where r.id = q.service_request_id returning * into result;
 update public.service_requests set status = 'scheduled', professional_id = q.professional_id where id = q.service_request_id;
 return result;
end; $$;

create or replace function public.update_booking_status(p_booking_id uuid, p_status public.booking_status) returns public.bookings language plpgsql security definer set search_path = public as $$
declare b public.bookings; result public.bookings;
begin
 select * into b from public.bookings where id = p_booking_id;
 if b.id is null then raise exception 'Booking not found'; end if;
 if p_status = 'cancelled' and auth.uid() not in (b.client_id, b.professional_id) then raise exception 'Not allowed'; end if;
 if p_status in ('in_progress', 'completed') and auth.uid() <> b.professional_id then raise exception 'Only the professional may do this'; end if;
 if p_status not in ('cancelled', 'in_progress', 'completed') then raise exception 'Invalid status'; end if;
 update public.bookings set status = p_status where id = p_booking_id returning * into result;
 update public.service_requests set status = p_status::text::public.request_status where id = (select service_request_id from public.quotes where id = b.quote_id);
 return result;
end; $$;
grant execute on function public.submit_quote(uuid,numeric,text,text), public.accept_quote(uuid,timestamptz,text), public.update_booking_status(uuid,public.booking_status) to authenticated;

create or replace function public.respond_to_direct_request(p_request_id uuid, p_accept boolean) returns void language plpgsql security definer set search_path = public as $$
declare r public.service_requests; service_price numeric;
begin
 select * into r from public.service_requests where id = p_request_id and professional_id = auth.uid() and status = 'pending';
 if r.id is null or public.current_role() <> 'professional' then raise exception 'Request unavailable'; end if;
 if not p_accept then update public.service_requests set status = 'cancelled' where id = r.id; return; end if;
 select base_price into service_price from public.services where id = r.service_id and professional_id = auth.uid() and price_type = 'fixed';
 if service_price is null then raise exception 'Only fixed-price requests can be accepted directly'; end if;
 insert into public.quotes(service_request_id, professional_id, service_id, amount, status, accepted_at) values (r.id, auth.uid(), r.service_id, service_price, 'accepted', now());
 insert into public.bookings(quote_id, client_id, professional_id, service_id, scheduled_at, address_text, status) select q.id, r.client_id, auth.uid(), r.service_id, coalesce(r.desired_date, now()), r.address_text, 'scheduled' from public.quotes q where q.service_request_id = r.id and q.professional_id = auth.uid();
 update public.service_requests set status = 'scheduled' where id = r.id;
end; $$;
grant execute on function public.respond_to_direct_request(uuid,boolean) to authenticated;
