-- PAS ID · Etapa 008: directorio público, consultorio y notificaciones.
-- Ejecutar UNA SOLA VEZ después de las migraciones 001–007.
begin;

alter table public.member_profiles
  add column if not exists public_directory_enabled boolean not null default false,
  add column if not exists directory_consent_at timestamptz,
  add column if not exists office_address text,
  add column if not exists office_latitude double precision,
  add column if not exists office_longitude double precision,
  add column if not exists service_modality text;

-- Extiende el envío de solicitudes de perfil para admitir campos de consultorio y consentimiento.
create or replace function public.submit_my_pas_profile_change_request(p_changes jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_member_id uuid; v_request_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  if p_changes is null or jsonb_typeof(p_changes)<>'object' or (select count(*) from jsonb_object_keys(p_changes))=0 then
    raise exception 'Indica al menos un dato para actualizar.' using errcode='22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_changes) f(key) where f.key not in
    ('contact_email','phone','professional_license','specialty','city','state','about','office_address','office_latitude','office_longitude','service_modality','public_directory_enabled','photo_path')) then
    raise exception 'La solicitud contiene campos no permitidos.' using errcode='22023';
  end if;
  if exists (select 1 from jsonb_each(p_changes) f(key,value)
    where jsonb_typeof(f.value) not in ('string','null','boolean','number')
    or length(coalesce(f.value #>> '{}',''))>1200) then
    raise exception 'Uno de los datos excede la longitud permitida o tiene un formato inválido.' using errcode='22023';
  end if;
  if p_changes ? 'office_latitude' and p_changes->>'office_latitude' is not null
    and ((p_changes->>'office_latitude')::double precision not between -90 and 90) then
    raise exception 'Latitud inválida.' using errcode='22023';
  end if;
  if p_changes ? 'office_longitude' and p_changes->>'office_longitude' is not null
    and ((p_changes->>'office_longitude')::double precision not between -180 and 180) then
    raise exception 'Longitud inválida.' using errcode='22023';
  end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=(select auth.uid()) limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  insert into public.member_profile_change_requests(member_id,requested_changes)
  values(v_member_id,p_changes) returning id into v_request_id;
  return v_request_id;
end; $$;

-- La aprobación aplica los campos públicos/consultorio; la publicación exige consentimiento explícito.
create or replace function public.review_pas_profile_change_request(p_request_id uuid,p_decision text,p_admin_response text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_request public.member_profile_change_requests%rowtype; v_changes jsonb;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decisión no válida.' using errcode='22023'; end if;
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
      public_directory_enabled=case when v_changes?'public_directory_enabled' then (v_changes->>'public_directory_enabled')::boolean else p.public_directory_enabled end,
      directory_consent_at=case when v_changes?'public_directory_enabled' and (v_changes->>'public_directory_enabled')::boolean then now()
        when v_changes?'public_directory_enabled' then null else p.directory_consent_at end,
      updated_at=now(),updated_by=(select auth.uid())
    where p.member_id=v_request.member_id;
  end if;
  update public.member_profile_change_requests set request_status=p_decision,reviewed_at=now(),
    reviewed_by=(select auth.uid()),admin_response=nullif(trim(coalesce(p_admin_response,'')),'')
  where id=p_request_id;
end; $$;


create or replace function public.get_my_pas_profile()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_member_id uuid; v_result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=(select auth.uid()) limit 1;
  if v_member_id is null then raise exception 'Esta cuenta todavía no está vinculada a un expediente PAS.' using errcode='P0002'; end if;
  select jsonb_build_object(
    'member',jsonb_build_object('id',m.id,'full_name',m.full_name,'member_type',m.member_type,'membership_status',m.membership_status,'legacy_folio',m.legacy_folio,'issued_on',m.issued_on,'expires_on',m.expires_on,'is_historical',m.is_historical),
    'profile',coalesce((select jsonb_build_object('contact_email',p.contact_email,'phone',p.phone,'professional_license',p.professional_license,'specialty',p.specialty,'city',p.city,'state',p.state,'about',p.about,'photo_path',p.photo_path,'office_address',p.office_address,'office_latitude',p.office_latitude,'office_longitude',p.office_longitude,'service_modality',p.service_modality,'public_directory_enabled',p.public_directory_enabled,'updated_at',p.updated_at) from public.member_profiles p where p.member_id=m.id),'{}'::jsonb),
    'credential',coalesce((select jsonb_build_object('id',c.id,'public_identifier',coalesce(c.public_identifier,m.legacy_folio),'credential_status',c.credential_status,'issued_at',c.issued_at,'expires_on',c.expires_on) from public.credentials c where c.member_id=m.id order by c.issued_at desc,c.created_at desc limit 1),'{}'::jsonb),
    'requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'requested_changes',r.requested_changes,'request_status',r.request_status,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at,'admin_response',r.admin_response) order by r.submitted_at desc) from public.member_profile_change_requests r where r.member_id=m.id),'[]'::jsonb)
  ) into v_result from public.members m where m.id=v_member_id;
  return v_result;
end; $$;
revoke all on function public.get_my_pas_profile() from public,anon;
grant execute on function public.get_my_pas_profile() to authenticated;

create or replace function public.list_pas_public_directory(p_search text default null,p_city text default null,p_specialty text default null)
returns table(member_id uuid,full_name text,member_type text,specialty text,city text,state text,about text,professional_license text,photo_path text,office_address text,office_latitude double precision,office_longitude double precision,service_modality text)
language sql stable security definer set search_path = '' as $$
  select m.id,m.full_name,m.member_type,p.specialty,p.city,p.state,p.about,p.professional_license,p.photo_path,
    p.office_address,p.office_latitude,p.office_longitude,p.service_modality
  from public.members m join public.member_profiles p on p.member_id=m.id
  where m.membership_status='active' and p.public_directory_enabled=true
    and (p_search is null or m.full_name ilike '%'||p_search||'%' or p.specialty ilike '%'||p_search||'%')
    and (p_city is null or p.city ilike '%'||p_city||'%')
    and (p_specialty is null or p.specialty ilike '%'||p_specialty||'%')
  order by m.full_name;
$$;
revoke all on function public.list_pas_public_directory(text,text,text) from public;
grant execute on function public.list_pas_public_directory(text,text,text) to anon,authenticated;

create table if not exists public.pas_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(trim(title)) between 1 and 140),
  body text not null check(length(trim(body)) between 1 and 2000),
  audience text not null check(audience in ('all','role')),
  member_type text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  published boolean not null default true
);
create table if not exists public.pas_notification_reads (
  notification_id uuid not null references public.pas_notifications(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(notification_id,user_id)
);
alter table public.pas_notifications enable row level security;
alter table public.pas_notification_reads enable row level security;
revoke all on public.pas_notifications,public.pas_notification_reads from anon,authenticated;
grant select on public.pas_notifications,public.pas_notification_reads to authenticated;

create or replace function public.publish_pas_notification(p_title text,p_body text,p_audience text default 'all',p_member_type text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not private.is_directiva() then raise exception 'Solo Directiva puede publicar avisos.' using errcode='42501'; end if;
  if length(trim(coalesce(p_title,''))) not between 1 and 140 or length(trim(coalesce(p_body,''))) not between 1 and 2000 then
    raise exception 'Revisa el título y el contenido del aviso.' using errcode='22023';
  end if;
  if p_audience not in ('all','role') then raise exception 'Destinatarios inválidos.' using errcode='22023'; end if;
  if p_audience='role' and p_member_type not in ('afiliado','colaborador','fundador') then raise exception 'Selecciona una categoría válida.' using errcode='22023'; end if;
  insert into public.pas_notifications(title,body,audience,member_type,created_by)
  values(trim(p_title),trim(p_body),p_audience,p_member_type,(select auth.uid())) returning id into v_id;
  return v_id;
end; $$;

create or replace function public.list_my_pas_notifications()
returns table(id uuid,title text,body text,created_at timestamptz,read_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare v_role text;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select coalesce(m.member_type,ur.role) into v_role
  from public.user_roles ur left join public.members m on m.auth_user_id=ur.user_id
  where ur.user_id=(select auth.uid()) limit 1;
  return query
  select n.id,n.title,n.body,n.created_at,r.read_at
  from public.pas_notifications n
  left join public.pas_notification_reads r on r.notification_id=n.id and r.user_id=(select auth.uid())
  where n.published=true and (n.audience='all' or (n.audience='role' and lower(n.member_type)=lower(v_role)))
  order by n.created_at desc limit 100;
end; $$;

create or replace function public.mark_pas_notification_read(p_notification_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_role text;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select coalesce(m.member_type,ur.role) into v_role
  from public.user_roles ur left join public.members m on m.auth_user_id=ur.user_id
  where ur.user_id=(select auth.uid()) limit 1;
  if not exists(select 1 from public.pas_notifications n where n.id=p_notification_id and n.published=true
    and (n.audience='all' or (n.audience='role' and lower(n.member_type)=lower(v_role)))) then
    raise exception 'Notificación no disponible.' using errcode='42501';
  end if;
  insert into public.pas_notification_reads(notification_id,user_id) values(p_notification_id,(select auth.uid()))
  on conflict(notification_id,user_id) do nothing;
end; $$;

revoke all on function public.publish_pas_notification(text,text,text,text) from public,anon;
revoke all on function public.list_my_pas_notifications() from public,anon;
revoke all on function public.mark_pas_notification_read(uuid) from public,anon;
grant execute on function public.publish_pas_notification(text,text,text,text) to authenticated;
grant execute on function public.list_my_pas_notifications() to authenticated;
grant execute on function public.mark_pas_notification_read(uuid) to authenticated;

commit;
