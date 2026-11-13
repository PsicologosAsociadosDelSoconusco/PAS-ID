-- PAS ID · Etapa 2: portal del afiliado y expediente digital
-- Ejecutar UNA SOLA VEZ en Supabase SQL Editor, después del esquema 001.
-- No modifica folios históricos ni sustituye credenciales existentes.

begin;

create table if not exists public.member_profiles (
  member_id uuid primary key references public.members(id) on delete cascade,
  contact_email text,
  phone text,
  professional_license text,
  specialty text,
  city text,
  state text,
  about text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.member_profile_change_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  requested_changes jsonb not null check (jsonb_typeof(requested_changes) = 'object'),
  request_status text not null default 'pending' check (request_status in ('pending','approved','rejected')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  admin_response text
);

create index if not exists member_profile_requests_status_idx
  on public.member_profile_change_requests(request_status, submitted_at desc);
create index if not exists member_profile_requests_member_idx
  on public.member_profile_change_requests(member_id, submitted_at desc);

-- Migra datos de contacto que pudieran existir en la tabla privada previa.
insert into public.member_profiles (member_id, contact_email, phone)
select mp.member_id, nullif(trim(mp.contact_email), ''), nullif(trim(mp.phone), '')
from public.member_private_data mp
on conflict (member_id) do update
set contact_email = coalesce(public.member_profiles.contact_email, excluded.contact_email),
    phone = coalesce(public.member_profiles.phone, excluded.phone);

alter table public.member_profiles enable row level security;
alter table public.member_profile_change_requests enable row level security;

revoke all on table public.member_profiles, public.member_profile_change_requests from anon, authenticated;
grant select on public.member_profiles, public.member_profile_change_requests to authenticated;
-- El navegador solo puede leer su propio perfil/solicitudes. Las escrituras pasan por RPC
-- y Edge Function para impedir que el usuario cambie estados o apruebe solicitudes.


-- Una persona solo puede consultar su ficha; Directiva consulta y administra todas.
drop policy if exists "member_profiles_read_self_or_directiva" on public.member_profiles;
create policy "member_profiles_read_self_or_directiva" on public.member_profiles
for select to authenticated
using (
  (select private.is_directiva())
  or exists (
    select 1 from public.members m
    where m.id = member_profiles.member_id and m.auth_user_id = (select auth.uid())
  )
);
drop policy if exists "member_profiles_manage_directiva" on public.member_profiles;
create policy "member_profiles_manage_directiva" on public.member_profiles
for all to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));

-- El afiliado puede crear y consultar solicitudes propias, pero no aprobarlas ni editarlas.
drop policy if exists "profile_requests_read_self_or_directiva" on public.member_profile_change_requests;
create policy "profile_requests_read_self_or_directiva" on public.member_profile_change_requests
for select to authenticated
using (
  (select private.is_directiva())
  or exists (
    select 1 from public.members m
    where m.id = member_profile_change_requests.member_id and m.auth_user_id = (select auth.uid())
  )
);
drop policy if exists "profile_requests_insert_self" on public.member_profile_change_requests;
create policy "profile_requests_insert_self" on public.member_profile_change_requests
for insert to authenticated
with check (
  request_status = 'pending'
  and exists (
    select 1 from public.members m
    where m.id = member_profile_change_requests.member_id and m.auth_user_id = (select auth.uid())
  )
);
drop policy if exists "profile_requests_update_directiva" on public.member_profile_change_requests;
create policy "profile_requests_update_directiva" on public.member_profile_change_requests
for update to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));
drop policy if exists "profile_requests_delete_directiva" on public.member_profile_change_requests;
create policy "profile_requests_delete_directiva" on public.member_profile_change_requests
for delete to authenticated
using ((select private.is_directiva()));

-- Expediente resumido del usuario autenticado. No devuelve notas administrativas ni datos de otros miembros.
create or replace function public.get_my_pas_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_result jsonb;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesión.' using errcode = '42501';
  end if;

  select m.id into v_member_id
  from public.members m
  where m.auth_user_id = (select auth.uid())
  limit 1;

  if v_member_id is null then
    raise exception 'Esta cuenta todavía no está vinculada a un expediente PAS. Contacta a la Directiva.' using errcode = 'P0002';
  end if;

  select jsonb_build_object(
    'member', jsonb_build_object(
      'id', m.id,
      'full_name', m.full_name,
      'member_type', m.member_type,
      'membership_status', m.membership_status,
      'legacy_folio', m.legacy_folio,
      'issued_on', m.issued_on,
      'expires_on', m.expires_on,
      'is_historical', m.is_historical
    ),
    'profile', coalesce((
      select jsonb_build_object(
        'contact_email', p.contact_email,
        'phone', p.phone,
        'professional_license', p.professional_license,
        'specialty', p.specialty,
        'city', p.city,
        'state', p.state,
        'about', p.about,
        'updated_at', p.updated_at
      ) from public.member_profiles p where p.member_id = m.id
    ), '{}'::jsonb),
    'credential', coalesce((
      select jsonb_build_object(
        'id', c.id,
        'public_identifier', coalesce(c.public_identifier, m.legacy_folio),
        'credential_status', c.credential_status,
        'issued_at', c.issued_at,
        'expires_on', c.expires_on
      ) from public.credentials c
      where c.member_id = m.id
      order by c.issued_at desc, c.created_at desc
      limit 1
    ), '{}'::jsonb),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'requested_changes', r.requested_changes,
        'request_status', r.request_status,
        'submitted_at', r.submitted_at,
        'reviewed_at', r.reviewed_at,
        'admin_response', r.admin_response
      ) order by r.submitted_at desc)
      from public.member_profile_change_requests r where r.member_id = m.id
    ), '[]'::jsonb)
  ) into v_result
  from public.members m
  where m.id = v_member_id;

  return v_result;
end;
$$;

create or replace function public.submit_my_pas_profile_change_request(p_changes jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_request_id uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesión.' using errcode = '42501';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' or (select count(*) from jsonb_object_keys(p_changes)) = 0 then
    raise exception 'Indica al menos un dato para actualizar.' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_object_keys(p_changes) as field(key)
    where field.key not in ('contact_email','phone','professional_license','specialty','city','state','about')
  ) then
    raise exception 'La solicitud contiene campos no permitidos.' using errcode = '22023';
  end if;
  if p_changes ? 'contact_email' and nullif(trim(p_changes ->> 'contact_email'), '') is not null
     and position('@' in (p_changes ->> 'contact_email')) < 2 then
    raise exception 'El correo de contacto no tiene un formato válido.' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_each(p_changes) as field(key,value)
    where jsonb_typeof(field.value) not in ('string','null')
      or length(coalesce(field.value #>> '{}','')) > 300
  ) then
    raise exception 'Uno de los datos excede la longitud permitida.' using errcode = '22023';
  end if;

  select m.id into v_member_id from public.members m
  where m.auth_user_id = (select auth.uid()) limit 1;
  if v_member_id is null then
    raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode = '42501';
  end if;

  insert into public.member_profile_change_requests(member_id, requested_changes)
  values (v_member_id, p_changes)
  returning id into v_request_id;
  return v_request_id;
end;
$$;

create or replace function public.update_pas_member_profile(p_member_id uuid, p_changes jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_directiva() then
    raise exception 'No autorizado: se requiere Directiva PAS.' using errcode = '42501';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object' or (select count(*) from jsonb_object_keys(p_changes)) = 0 then
    raise exception 'Indica al menos un dato del expediente.' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_object_keys(p_changes) as field(key)
    where field.key not in ('contact_email','phone','professional_license','specialty','city','state','about')
  ) then
    raise exception 'El expediente contiene campos no permitidos.' using errcode = '22023';
  end if;
  if p_changes ? 'contact_email' and nullif(trim(p_changes ->> 'contact_email'), '') is not null
     and position('@' in (p_changes ->> 'contact_email')) < 2 then
    raise exception 'El correo de contacto no tiene un formato válido.' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_each(p_changes) as field(key,value)
    where jsonb_typeof(field.value) not in ('string','null')
      or length(coalesce(field.value #>> '{}','')) > 300
  ) then
    raise exception 'Uno de los datos excede la longitud permitida.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.members m where m.id = p_member_id) then
    raise exception 'Miembro no encontrado.' using errcode = 'P0002';
  end if;

  insert into public.member_profiles(member_id) values (p_member_id)
  on conflict (member_id) do nothing;
  update public.member_profiles p set
    contact_email = case when p_changes ? 'contact_email' then nullif(trim(p_changes ->> 'contact_email'),'') else p.contact_email end,
    phone = case when p_changes ? 'phone' then nullif(trim(p_changes ->> 'phone'),'') else p.phone end,
    professional_license = case when p_changes ? 'professional_license' then nullif(trim(p_changes ->> 'professional_license'),'') else p.professional_license end,
    specialty = case when p_changes ? 'specialty' then nullif(trim(p_changes ->> 'specialty'),'') else p.specialty end,
    city = case when p_changes ? 'city' then nullif(trim(p_changes ->> 'city'),'') else p.city end,
    state = case when p_changes ? 'state' then nullif(trim(p_changes ->> 'state'),'') else p.state end,
    about = case when p_changes ? 'about' then nullif(trim(p_changes ->> 'about'),'') else p.about end,
    updated_at = now(), updated_by = (select auth.uid())
  where p.member_id = p_member_id;
end;
$$;

create or replace function public.review_pas_profile_change_request(
  p_request_id uuid,
  p_decision text,
  p_admin_response text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.member_profile_change_requests%rowtype;
  v_changes jsonb;
begin
  if not private.is_directiva() then
    raise exception 'No autorizado: se requiere Directiva PAS.' using errcode = '42501';
  end if;
  if p_decision not in ('approved','rejected') then
    raise exception 'Decisión no válida.' using errcode = '22023';
  end if;
  select * into v_request from public.member_profile_change_requests
  where id = p_request_id for update;
  if not found then raise exception 'Solicitud no encontrada.' using errcode = 'P0002'; end if;
  if v_request.request_status <> 'pending' then
    raise exception 'Esta solicitud ya fue atendida.' using errcode = '22023';
  end if;

  v_changes := v_request.requested_changes;
  if p_decision = 'approved' then
    insert into public.member_profiles(member_id) values (v_request.member_id)
    on conflict (member_id) do nothing;
    update public.member_profiles p set
      contact_email = case when v_changes ? 'contact_email' then nullif(trim(v_changes ->> 'contact_email'),'') else p.contact_email end,
      phone = case when v_changes ? 'phone' then nullif(trim(v_changes ->> 'phone'),'') else p.phone end,
      professional_license = case when v_changes ? 'professional_license' then nullif(trim(v_changes ->> 'professional_license'),'') else p.professional_license end,
      specialty = case when v_changes ? 'specialty' then nullif(trim(v_changes ->> 'specialty'),'') else p.specialty end,
      city = case when v_changes ? 'city' then nullif(trim(v_changes ->> 'city'),'') else p.city end,
      state = case when v_changes ? 'state' then nullif(trim(v_changes ->> 'state'),'') else p.state end,
      about = case when v_changes ? 'about' then nullif(trim(v_changes ->> 'about'),'') else p.about end,
      updated_at = now(), updated_by = (select auth.uid())
    where p.member_id = v_request.member_id;
  end if;

  update public.member_profile_change_requests
  set request_status = p_decision,
      reviewed_at = now(),
      reviewed_by = (select auth.uid()),
      admin_response = nullif(trim(coalesce(p_admin_response,'')), '')
  where id = p_request_id;
end;
$$;

revoke all on function public.get_my_pas_profile() from public, anon;
revoke all on function public.submit_my_pas_profile_change_request(jsonb) from public, anon;
revoke all on function public.update_pas_member_profile(uuid,jsonb) from public, anon;
revoke all on function public.review_pas_profile_change_request(uuid,text,text) from public, anon;
grant execute on function public.get_my_pas_profile() to authenticated;
grant execute on function public.submit_my_pas_profile_change_request(jsonb) to authenticated;
grant execute on function public.update_pas_member_profile(uuid,jsonb) to authenticated;
grant execute on function public.review_pas_profile_change_request(uuid,text,text) to authenticated;

-- Auditoría: los cambios de perfil y las resoluciones de solicitudes quedan registrados.
drop trigger if exists audit_member_profiles_changes on public.member_profiles;
create trigger audit_member_profiles_changes after insert or update or delete on public.member_profiles
for each row execute function private.audit_row_change();
drop trigger if exists audit_profile_requests_changes on public.member_profile_change_requests;
create trigger audit_profile_requests_changes after insert or update or delete on public.member_profile_change_requests
for each row execute function private.audit_row_change();

commit;
