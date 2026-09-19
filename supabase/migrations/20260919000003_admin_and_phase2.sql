-- Administrative controls and extensibility boundaries for phase 2.
alter table public.profiles add column if not exists is_blocked boolean not null default false;
alter table public.profiles add column if not exists blocked_reason text;
alter table public.services add column if not exists moderation_status text not null default 'approved' check (moderation_status in ('pending','approved','rejected'));
alter table public.service_requests add column if not exists moderation_status text not null default 'approved' check (moderation_status in ('pending','approved','rejected'));

-- Reserved data points. No payment, commission, refund, notification or chat logic is active in this MVP.
alter table public.bookings add column if not exists platform_fee_rate numeric(5,4) default null;
alter table public.bookings add column if not exists platform_fee_amount numeric(12,2) default null;
alter table public.bookings add column if not exists payment_status text default null;
alter table public.professional_profiles add column if not exists verification_status text not null default 'not_started' check (verification_status in ('not_started','pending','verified','rejected'));

create or replace function public.admin_metrics() returns jsonb language sql stable security definer set search_path = public as $$
 select jsonb_build_object(
   'users', (select count(*) from profiles),
   'clients', (select count(*) from profiles where role = 'client'),
   'professionals', (select count(*) from profiles where role = 'professional'),
   'services', (select count(*) from services where active),
   'requests', (select count(*) from service_requests),
   'bookings', (select count(*) from bookings),
   'completed', (select count(*) from bookings where status = 'completed'),
   'gmv', coalesce((select sum(q.amount) from bookings b join quotes q on q.id = b.quote_id where b.status in ('scheduled','in_progress','completed')), 0),
   'average_ticket', coalesce((select avg(q.amount) from bookings b join quotes q on q.id = b.quote_id where b.status in ('scheduled','in_progress','completed')), 0)
 ) where public.is_admin();
$$;

create or replace function public.admin_set_user_block(p_user_id uuid, p_blocked boolean, p_reason text default null) returns void language plpgsql security definer set search_path = public as $$
begin
 if not public.is_admin() then raise exception 'Not allowed'; end if;
 if p_user_id = auth.uid() then raise exception 'An administrator cannot block their own account'; end if;
 update public.profiles set is_blocked = p_blocked, blocked_reason = case when p_blocked then p_reason else null end where id = p_user_id;
end; $$;

create or replace function public.admin_moderate(p_table text, p_id uuid, p_status text) returns void language plpgsql security definer set search_path = public as $$
begin
 if not public.is_admin() or p_status not in ('approved','rejected') then raise exception 'Not allowed'; end if;
 if p_table = 'services' then update public.services set moderation_status = p_status, active = (p_status = 'approved') where id = p_id;
 elsif p_table = 'service_requests' then update public.service_requests set moderation_status = p_status where id = p_id;
 else raise exception 'Invalid resource'; end if;
end; $$;
grant execute on function public.admin_metrics(), public.admin_set_user_block(uuid,boolean,text), public.admin_moderate(text,uuid,text) to authenticated;

-- Blocked users cannot create marketplace records.
create or replace function public.reject_blocked_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
 if exists (select 1 from public.profiles where id = auth.uid() and is_blocked) then raise exception 'Account blocked'; end if;
 return new;
end; $$;
create trigger reject_blocked_requests before insert on public.service_requests for each row execute procedure public.reject_blocked_user();
create trigger reject_blocked_quotes before insert on public.quotes for each row execute procedure public.reject_blocked_user();

-- Admin read policies for data that already has participant policies.
create policy "admins read all bookings" on public.bookings for select to authenticated using (public.is_admin());
create policy "admins read all quotes" on public.quotes for select to authenticated using (public.is_admin());
