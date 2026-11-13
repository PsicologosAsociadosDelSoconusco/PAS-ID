-- PAS ID · Perfil profesional público en la verificación de credenciales.
-- Ejecutar UNA SOLA VEZ en Supabase SQL Editor después de las migraciones 001–005.
-- Expone únicamente especialidad, cédula, municipio/estado y presentación profesional.
-- Correo y teléfono nunca se devuelven en esta consulta pública.

begin;

create or replace function public.verify_pas_credential_public(p_identifier text)
returns table (
  found boolean,
  full_name text,
  legacy_folio text,
  member_type text,
  verification_status text,
  issued_on date,
  expires_on date,
  professional_license text,
  specialty text,
  city text,
  state text,
  about text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_base record;
  v_member_id uuid;
  v_profile public.member_profiles%rowtype;
begin
  select * into v_base
  from public.verify_pas_credential(p_identifier);

  if not coalesce(v_base.found, false) then
    return query select false, null::text, null::text, null::text, 'not_found'::text,
      null::date, null::date, null::text, null::text, null::text, null::text, null::text;
    return;
  end if;

  select m.id into v_member_id
  from public.members m
  where (m.legacy_folio = upper(trim(coalesce(p_identifier, '')))
      or exists (
        select 1 from public.credentials c
        where c.member_id = m.id
          and c.public_identifier = upper(trim(coalesce(p_identifier, '')))
      ))
  limit 1;

  select p.* into v_profile
  from public.member_profiles p
  where p.member_id = v_member_id;

  return query select
    v_base.found,
    v_base.full_name,
    v_base.legacy_folio,
    v_base.member_type,
    v_base.verification_status,
    v_base.issued_on,
    v_base.expires_on,
    nullif(trim(v_profile.professional_license), ''),
    nullif(trim(v_profile.specialty), ''),
    nullif(trim(v_profile.city), ''),
    nullif(trim(v_profile.state), ''),
    nullif(trim(v_profile.about), '');
end;
$$;

revoke all on function public.verify_pas_credential_public(text) from public;
grant execute on function public.verify_pas_credential_public(text) to anon, authenticated;

commit;
