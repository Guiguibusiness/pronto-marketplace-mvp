alter type public.request_status add value if not exists 'pending';
alter type public.request_status add value if not exists 'quoting';
alter type public.request_status add value if not exists 'accepted';
alter type public.request_status add value if not exists 'scheduled';
alter type public.request_status add value if not exists 'in_progress';
alter type public.booking_status add value if not exists 'scheduled';
alter type public.booking_status add value if not exists 'accepted';
