-- PAS ID · Endurecimiento de la verificación pública de constancias.
-- Ejecutar una sola vez en Supabase SQL Editor.
create or replace function public.verify_pas_certificate(p_certificate_number text)
returns table (
  certificate_number text,
  title text,
  issued_at timestamptz,
  revoked_at timestamptz,
  full_name text,
  event_title text
)
language sql
stable
security definer
set search_path = ''
as $$
  select c.certificate_number, c.title, c.issued_at, c.revoked_at,
         m.full_name, e.title as event_title
  from public.certificates c
  join public.members m on m.id = c.member_id
  left join public.events e on e.id = c.event_id
  where upper(trim(c.certificate_number)) = upper(trim(p_certificate_number))
  limit 1;
$$;

revoke all on function public.verify_pas_certificate(text) from public;
grant execute on function public.verify_pas_certificate(text) to anon, authenticated;
