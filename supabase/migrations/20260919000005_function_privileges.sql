alter function public.touch_updated_at() set search_path = public;

revoke execute on function public.current_role(), public.is_admin(), public.handle_new_user(), public.refresh_professional_rating(), public.reject_blocked_user(), public.touch_updated_at() from anon;
revoke execute on function public.set_my_role(public.user_role), public.submit_quote(uuid,numeric,text,text), public.accept_quote(uuid,timestamptz,text), public.update_booking_status(uuid,public.booking_status), public.respond_to_direct_request(uuid,boolean), public.admin_metrics(), public.admin_set_user_block(uuid,boolean,text), public.admin_moderate(text,uuid,text) from anon;
