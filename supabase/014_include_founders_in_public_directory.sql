-- PAS ID · Migración 014
-- Incluye a los miembros fundadores activos en el directorio profesional público.
-- No modifica miembros, folios, consentimientos ni aprobaciones existentes.
-- Ejecutar UNA SOLA VEZ después de la migración 013.

begin;

create or replace function public.list_pas_public_directory(
  p_search text default null,
  p_city text default null,
  p_specialty text default null
)
returns table(
  member_id uuid,
  full_name text,
  member_type text,
  specialty text,
  city text,
  state text,
  about text,
  professional_license text,
  photo_path text,
  office_address text,
  office_latitude double precision,
  office_longitude double precision,
  service_modality text,
  service_populations text,
  approaches text,
  consultation_fee text,
  public_fee boolean,
  public_phone text,
  public_email text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    m.id,
    m.full_name,
    m.member_type,
    p.specialty,
    p.city,
    p.state,
    p.about,
    p.professional_license,
    p.photo_path,
    p.office_address,
    p.office_latitude,
    p.office_longitude,
    p.service_modality,
    p.service_populations,
    p.approaches,
    case
      when p.public_fee then nullif(trim(p.consultation_fee), '')
      else null
    end,
    (p.public_fee and nullif(trim(p.consultation_fee), '') is not null),
    case
      when p.public_contact_enabled then nullif(trim(p.phone), '')
      else null
    end,
    case
      when p.public_contact_enabled then nullif(trim(p.contact_email), '')
      else null
    end
  from public.members m
  join public.member_profiles p on p.member_id = m.id
  where m.membership_status = 'active'
    -- Los fundadores tienen member_type = 'Miembro fundador'.
    -- Se admiten variantes por si existen registros históricos normalizados de otra forma.
    and lower(trim(m.member_type)) in ('afiliado', 'colaborador', 'miembro fundador', 'fundador')
    and p.public_directory_enabled = true
    and (
      p_search is null
      or m.full_name ilike '%' || p_search || '%'
      or p.specialty ilike '%' || p_search || '%'
      or p.service_populations ilike '%' || p_search || '%'
      or p.approaches ilike '%' || p_search || '%'
    )
    and (p_city is null or p.city ilike '%' || p_city || '%')
    and (p_specialty is null or p.specialty ilike '%' || p_specialty || '%')
  order by m.full_name;
$$;

revoke all on function public.list_pas_public_directory(text, text, text) from public;
grant execute on function public.list_pas_public_directory(text, text, text) to anon, authenticated;

comment on function public.list_pas_public_directory(text, text, text) is
  'Directorio público PAS: muestra integrantes activos afiliados, colaboradores y miembros fundadores con consentimiento vigente; respeta la publicación voluntaria de honorarios y datos de contacto.';

commit;
