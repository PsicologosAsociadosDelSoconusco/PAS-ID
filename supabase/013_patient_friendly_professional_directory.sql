-- PAS ID · Directorio profesional centrado en las personas que buscan atención.
-- Ejecutar UNA SOLA VEZ después de las migraciones 001–012.
-- Amplía los datos públicos voluntarios y conserva privacidad de contacto.

begin;

alter table public.member_profiles
  add column if not exists service_populations text,
  add column if not exists approaches text,
  add column if not exists consultation_fee text,
  add column if not exists public_fee boolean not null default false,
  add column if not exists public_contact_enabled boolean not null default false;

-- Devuelve los nuevos campos al titular autenticado para que pueda editar su perfil.
create or replace function public.get_my_pas_profile()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_member_id uuid; v_result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=(select auth.uid()) limit 1;
  if v_member_id is null then raise exception 'Esta cuenta todavía no está vinculada a un expediente PAS.' using errcode='P0002'; end if;
  select jsonb_build_object(
    'member',jsonb_build_object('id',m.id,'full_name',m.full_name,'member_type',m.member_type,'membership_status',m.membership_status,'legacy_folio',m.legacy_folio,'issued_on',m.issued_on,'expires_on',m.expires_on,'is_historical',m.is_historical),
    'profile',coalesce((select jsonb_build_object(
      'contact_email',p.contact_email,'phone',p.phone,'professional_license',p.professional_license,
      'specialty',p.specialty,'city',p.city,'state',p.state,'about',p.about,'photo_path',p.photo_path,
      'office_address',p.office_address,'office_latitude',p.office_latitude,'office_longitude',p.office_longitude,
      'service_modality',p.service_modality,'service_populations',p.service_populations,'approaches',p.approaches,
      'consultation_fee',p.consultation_fee,'public_fee',p.public_fee,'public_contact_enabled',p.public_contact_enabled,
      'public_directory_enabled',p.public_directory_enabled,'updated_at',p.updated_at
    ) from public.member_profiles p where p.member_id=m.id),'{}'::jsonb),
    'credential',coalesce((select jsonb_build_object('id',c.id,'public_identifier',coalesce(c.public_identifier,m.legacy_folio),'credential_status',c.credential_status,'issued_at',c.issued_at,'expires_on',c.expires_on) from public.credentials c where c.member_id=m.id order by c.issued_at desc,c.created_at desc limit 1),'{}'::jsonb),
    'requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'requested_changes',r.requested_changes,'request_status',r.request_status,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at,'admin_response',r.admin_response) order by r.submitted_at desc) from public.member_profile_change_requests r where r.member_id=m.id),'[]'::jsonb)
  ) into v_result from public.members m where m.id=v_member_id;
  return v_result;
end; $$;
revoke all on function public.get_my_pas_profile() from public,anon;
grant execute on function public.get_my_pas_profile() to authenticated;

-- Añade datos de directorio al flujo de solicitud y conserva la bandeja integral.
create or replace function public.submit_my_pas_profile_change_request(p_changes jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_member_id uuid; v_request_id uuid; v_role text := public.current_pas_role();
  v_member_name text; v_email text; v_wrapper_id uuid; v_subject text;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  if v_role not in ('afiliado','colaborador','directiva') then raise exception 'Tu cuenta no tiene un rol PAS autorizado.' using errcode='42501'; end if;
  if p_changes is null or jsonb_typeof(p_changes)<>'object' or (select count(*) from jsonb_object_keys(p_changes))=0 then
    raise exception 'Indica al menos un dato para actualizar.' using errcode='22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_changes) f(key) where f.key not in
    ('contact_email','phone','professional_license','specialty','city','state','about','office_address','office_latitude','office_longitude','service_modality','public_directory_enabled','photo_path','service_populations','approaches','consultation_fee','public_fee','public_contact_enabled')) then
    raise exception 'La solicitud contiene campos no permitidos.' using errcode='22023';
  end if;
  if exists (select 1 from jsonb_each(p_changes) f(key,value)
    where jsonb_typeof(f.value) not in ('string','null','boolean','number') or length(coalesce(f.value #>> '{}',''))>1200) then
    raise exception 'Uno de los datos excede la longitud permitida o tiene un formato inválido.' using errcode='22023';
  end if;
  if p_changes ? 'office_latitude' and nullif(trim(p_changes->>'office_latitude'),'') is not null
    and ((p_changes->>'office_latitude')::double precision not between -90 and 90) then raise exception 'Latitud inválida.'; end if;
  if p_changes ? 'office_longitude' and nullif(trim(p_changes->>'office_longitude'),'') is not null
    and ((p_changes->>'office_longitude')::double precision not between -180 and 180) then raise exception 'Longitud inválida.'; end if;
  if p_changes ? 'public_fee' and jsonb_typeof(p_changes->'public_fee') not in ('boolean','null') then raise exception 'La preferencia de honorarios públicos no es válida.' using errcode='22023'; end if;
  if p_changes ? 'public_contact_enabled' and jsonb_typeof(p_changes->'public_contact_enabled') not in ('boolean','null') then raise exception 'La preferencia de contacto público no es válida.' using errcode='22023'; end if;
  if p_changes ? 'public_directory_enabled' and jsonb_typeof(p_changes->'public_directory_enabled') not in ('boolean','null') then raise exception 'El consentimiento de directorio no es válido.' using errcode='22023'; end if;
  select m.id,m.full_name,u.email into v_member_id,v_member_name,v_email
    from public.members m join auth.users u on u.id=m.auth_user_id where m.auth_user_id=auth.uid() limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  insert into public.member_profile_change_requests(member_id,requested_changes) values(v_member_id,p_changes) returning id into v_request_id;
  v_subject := case when p_changes ? 'photo_path' and (select count(*) from jsonb_object_keys(p_changes))=1
    then 'Actualización de fotografía profesional' else 'Actualización de perfil profesional y directorio' end;
  insert into public.institutional_requests(source_type,source_request_id,requester_user_id,requester_member_id,requester_email,requester_name,requester_role,category,subject,description)
    values('profile_change',v_request_id,auth.uid(),v_member_id,v_email,v_member_name,v_role,'Perfil profesional y directorio',v_subject,
      left('Cambios solicitados:' || E'\n' || jsonb_pretty(p_changes),5000)) returning id into v_wrapper_id;
  return v_request_id;
end; $$;
revoke all on function public.submit_my_pas_profile_change_request(jsonb) from public,anon;
grant execute on function public.submit_my_pas_profile_change_request(jsonb) to authenticated;

-- Aplica los datos nuevos únicamente después de que Directiva aprueba la solicitud.
create or replace function public.review_pas_profile_change_request(p_request_id uuid,p_decision text,p_admin_response text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_request public.member_profile_change_requests%rowtype; v_changes jsonb; v_owner uuid;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decisión no válida.' using errcode='22023'; end if;
  select claimed_by into v_owner from public.institutional_requests where source_type='profile_change' and source_request_id=p_request_id;
  if v_owner is distinct from auth.uid() then raise exception 'Primero debes tomar la solicitud en el centro integral.' using errcode='42501'; end if;
  select * into v_request from public.member_profile_change_requests where id=p_request_id for update;
  if not found then raise exception 'Solicitud no encontrada.' using errcode='P0002'; end if;
  if v_request.request_status<>'pending' then raise exception 'Esta solicitud ya fue atendida.' using errcode='22023'; end if;
  v_changes:=v_request.requested_changes;
  if p_decision='approved' then
    insert into public.member_profiles(member_id) values(v_request.member_id) on conflict(member_id) do nothing;
    update public.member_profiles p set
      contact_email=case when v_changes?'contact_email' then nullif(trim(v_changes->>'contact_email'),'') else p.contact_email end,
      phone=case when v_changes?'phone' then nullif(trim(v_changes->>'phone'),'') else p.phone end,
      professional_license=case when v_changes?'professional_license' then nullif(trim(v_changes->>'professional_license'),'') else p.professional_license end,
      specialty=case when v_changes?'specialty' then nullif(trim(v_changes->>'specialty'),'') else p.specialty end,
      city=case when v_changes?'city' then nullif(trim(v_changes->>'city'),'') else p.city end,
      state=case when v_changes?'state' then nullif(trim(v_changes->>'state'),'') else p.state end,
      about=case when v_changes?'about' then nullif(trim(v_changes->>'about'),'') else p.about end,
      photo_path=case when v_changes?'photo_path' then nullif(trim(v_changes->>'photo_path'),'') else p.photo_path end,
      office_address=case when v_changes?'office_address' then nullif(trim(v_changes->>'office_address'),'') else p.office_address end,
      office_latitude=case when v_changes?'office_latitude' then nullif(v_changes->>'office_latitude','')::double precision else p.office_latitude end,
      office_longitude=case when v_changes?'office_longitude' then nullif(v_changes->>'office_longitude','')::double precision else p.office_longitude end,
      service_modality=case when v_changes?'service_modality' then nullif(trim(v_changes->>'service_modality'),'') else p.service_modality end,
      service_populations=case when v_changes?'service_populations' then nullif(trim(v_changes->>'service_populations'),'') else p.service_populations end,
      approaches=case when v_changes?'approaches' then nullif(trim(v_changes->>'approaches'),'') else p.approaches end,
      consultation_fee=case when v_changes?'consultation_fee' then nullif(trim(v_changes->>'consultation_fee'),'') else p.consultation_fee end,
      public_fee=case when v_changes?'public_fee' then coalesce((v_changes->>'public_fee')::boolean,false) else p.public_fee end,
      public_contact_enabled=case when v_changes?'public_contact_enabled' then coalesce((v_changes->>'public_contact_enabled')::boolean,false) else p.public_contact_enabled end,
      public_directory_enabled=case when v_changes?'public_directory_enabled' then (v_changes->>'public_directory_enabled')::boolean else p.public_directory_enabled end,
      directory_consent_at=case when v_changes?'public_directory_enabled' and (v_changes->>'public_directory_enabled')::boolean then now()
        when v_changes?'public_directory_enabled' then null else p.directory_consent_at end,
      updated_at=now(),updated_by=auth.uid()
    where p.member_id=v_request.member_id;
  end if;
  update public.member_profile_change_requests set request_status=p_decision,reviewed_at=now(),reviewed_by=auth.uid(),admin_response=nullif(trim(coalesce(p_admin_response,'')),'') where id=p_request_id;
end; $$;
revoke all on function public.review_pas_profile_change_request(uuid,text,text) from public,anon,authenticated;
grant execute on function public.review_pas_profile_change_request(uuid,text,text) to authenticated;

-- Solo afiliados y colaboradores activos con consentimiento pueden aparecer.
-- Correo y teléfono se exponen únicamente con autorización específica de contacto público.
-- Honorarios solo se exponen si el profesional lo autorizó.
drop function if exists public.list_pas_public_directory(text,text,text);
create function public.list_pas_public_directory(p_search text default null,p_city text default null,p_specialty text default null)
returns table(
  member_id uuid,full_name text,member_type text,specialty text,city text,state text,about text,
  professional_license text,photo_path text,office_address text,office_latitude double precision,
  office_longitude double precision,service_modality text,service_populations text,approaches text,
  consultation_fee text,public_fee boolean,public_phone text,public_email text
)
language sql stable security definer set search_path = '' as $$
  select m.id,m.full_name,m.member_type,p.specialty,p.city,p.state,p.about,p.professional_license,p.photo_path,
    p.office_address,p.office_latitude,p.office_longitude,p.service_modality,p.service_populations,p.approaches,
    case when p.public_fee then nullif(trim(p.consultation_fee),'') else null end,
    (p.public_fee and nullif(trim(p.consultation_fee),'') is not null),
    case when p.public_contact_enabled then nullif(trim(p.phone),'') else null end,
    case when p.public_contact_enabled then nullif(trim(p.contact_email),'') else null end
  from public.members m join public.member_profiles p on p.member_id=m.id
  where m.membership_status='active'
    and m.member_type in ('Afiliado','Colaborador')
    and p.public_directory_enabled=true
    and (p_search is null or m.full_name ilike '%'||p_search||'%' or p.specialty ilike '%'||p_search||'%' or p.service_populations ilike '%'||p_search||'%' or p.approaches ilike '%'||p_search||'%')
    and (p_city is null or p.city ilike '%'||p_city||'%')
    and (p_specialty is null or p.specialty ilike '%'||p_specialty||'%')
  order by m.full_name;
$$;
revoke all on function public.list_pas_public_directory(text,text,text) from public;
grant execute on function public.list_pas_public_directory(text,text,text) to anon,authenticated;

commit;
