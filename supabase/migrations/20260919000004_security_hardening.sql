-- Prevent the default PUBLIC execute grant from exposing SECURITY DEFINER helpers.
revoke execute on function public.current_role(), public.is_admin(), public.handle_new_user(), public.refresh_professional_rating(), public.reject_blocked_user(), public.touch_updated_at() from public;
revoke execute on function public.set_my_role(public.user_role), public.submit_quote(uuid,numeric,text,text), public.accept_quote(uuid,timestamptz,text), public.update_booking_status(uuid,public.booking_status), public.respond_to_direct_request(uuid,boolean), public.admin_metrics(), public.admin_set_user_block(uuid,boolean,text), public.admin_moderate(text,uuid,text) from public;

grant execute on function public.current_role(), public.is_admin() to authenticated;
grant execute on function public.set_my_role(public.user_role), public.submit_quote(uuid,numeric,text,text), public.accept_quote(uuid,timestamptz,text), public.update_booking_status(uuid,public.booking_status), public.respond_to_direct_request(uuid,boolean), public.admin_metrics(), public.admin_set_user_block(uuid,boolean,text), public.admin_moderate(text,uuid,text) to authenticated;

-- Anonymous discovery policies must not invoke privileged role helpers.
drop policy "public profiles readable" on public.profiles;
create policy "public professional profiles" on public.profiles for select to anon, authenticated using (role = 'professional' or id = (select auth.uid()));
drop policy "public categories readable" on public.categories;
create policy "public active categories" on public.categories for select to anon, authenticated using (active);
drop policy "public active services readable" on public.services;
create policy "public active services" on public.services for select to anon, authenticated using (active or professional_id = (select auth.uid()));
drop policy "public active availability readable" on public.availability;
create policy "public active availability" on public.availability for select to anon, authenticated using (active or professional_id = (select auth.uid()));

create index if not exists services_category_idx on public.services(category_id);
create index if not exists requests_service_idx on public.service_requests(service_id);
create index if not exists requests_professional_idx on public.service_requests(professional_id);
create index if not exists quotes_professional_idx on public.quotes(professional_id);
create index if not exists quotes_service_idx on public.quotes(service_id);
create index if not exists bookings_service_idx on public.bookings(service_id);
create index if not exists reviews_client_idx on public.reviews(client_id);
create index if not exists reviews_professional_idx on public.reviews(professional_id);
