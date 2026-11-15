-- PAS ID · Centro integral de solicitudes, responsable por primera atención y mensajería privada
-- Ejecutar UNA SOLA VEZ después de las migraciones 001–008.
-- No modifica miembros, credenciales ni folios históricos.
begin;

alter table public.institutional_requests
  add column if not exists claimed_by uuid references auth.users(id) on delete set null,
  add column if not exists claimed_by_name text,
  add column if not exists claimed_at timestamptz,
  add column if not exists transferred_at timestamptz,
  add column if not exists last_activity_at timestamptz,
  add column if not exists closed_at timestamptz,
  add column if not exists source_type text not null default 'general',
  add column if not exists source_request_id uuid;

-- Conserva la fecha histórica de actividad de solicitudes previas a esta migración.
update public.institutional_requests r
set last_activity_at = coalesce(r.reviewed_at,r.submitted_at,now()),
    closed_at = case when r.request_status in ('approved','rejected') then coalesce(r.reviewed_at,r.submitted_at,now()) else r.closed_at end
where r.last_activity_at is null or (r.request_status in ('approved','rejected') and r.closed_at is null);
alter table public.institutional_requests alter column last_activity_at set default now();
alter table public.institutional_requests alter column last_activity_at set not null;

-- Los casos cerrados antes de la etapa 2 conservan como responsable a quien los resolvió.
update public.institutional_requests r
set claimed_by = r.reviewed_by,
    claimed_by_name = coalesce(nullif(m.full_name,''),u.email,'Directiva PAS'),
    claimed_at = coalesce(r.reviewed_at,r.submitted_at)
from auth.users u
left join public.members m on m.auth_user_id=u.id
where r.reviewed_by = u.id and r.request_status in ('approved','rejected') and r.claimed_by is null;

-- Las actualizaciones de perfil/fotografía existentes se incorporan al buzón único.
do $$ begin
  if not exists (select 1 from pg_constraint where conname='institutional_requests_source_type_check' and conrelid='public.institutional_requests'::regclass) then
    alter table public.institutional_requests add constraint institutional_requests_source_type_check
      check(source_type in ('general','profile_change'));
  end if;
end $$;
create unique index if not exists institutional_requests_source_unique_idx
  on public.institutional_requests(source_type,source_request_id)
  where source_request_id is not null;

create index if not exists institutional_requests_owner_idx
  on public.institutional_requests(claimed_by, last_activity_at desc);

create table if not exists public.institutional_request_messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.institutional_requests(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  sender_role text not null check(sender_role in ('directiva','afiliado','colaborador')),
  sender_name text not null,
  body text not null check(length(trim(body)) between 1 and 5000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists institutional_request_messages_thread_idx
  on public.institutional_request_messages(request_id, created_at);
create index if not exists institutional_request_messages_unread_idx
  on public.institutional_request_messages(request_id, read_at)
  where read_at is null;

-- Lecturas por participante (no globales), para que una transferencia genere pendientes para el nuevo responsable.
create table if not exists public.institutional_request_message_reads (
  message_id uuid not null references public.institutional_request_messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key(message_id,user_id)
);
create index if not exists institutional_request_message_reads_user_idx
  on public.institutional_request_message_reads(user_id,read_at);
alter table public.institutional_request_message_reads enable row level security;
revoke all on public.institutional_request_message_reads from anon,authenticated;

alter table public.institutional_request_messages enable row level security;
revoke all on public.institutional_request_messages from anon, authenticated;
grant select on public.institutional_request_messages to authenticated;
drop policy if exists institutional_request_messages_participants_read on public.institutional_request_messages;
create policy institutional_request_messages_participants_read
on public.institutional_request_messages for select to authenticated
using (
  exists (
    select 1 from public.institutional_requests r
    where r.id = request_id
      and (r.requester_user_id = (select auth.uid()) or r.claimed_by = (select auth.uid()))
  )
);

create table if not exists public.institutional_request_events (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.institutional_requests(id) on delete cascade,
  actor_user_id uuid not null references auth.users(id) on delete cascade,
  actor_name text not null,
  event_type text not null check(event_type in ('claimed','released','transferred','status_changed')),
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists institutional_request_events_thread_idx
  on public.institutional_request_events(request_id, created_at);
alter table public.institutional_request_events enable row level security;
revoke all on public.institutional_request_events from anon, authenticated;
grant select on public.institutional_request_events to authenticated;
drop policy if exists institutional_request_events_visible on public.institutional_request_events;
create policy institutional_request_events_visible
on public.institutional_request_events for select to authenticated
using (
  exists (
    select 1 from public.institutional_requests r
    where r.id = request_id
      and (r.requester_user_id = (select auth.uid()) or (select private.is_directiva()))
  )
);

-- Backfill de solicitudes de cambio de perfil anteriores, para que queden en el buzón integral.
insert into public.institutional_requests(
  source_type,source_request_id,requester_user_id,requester_member_id,requester_email,requester_name,requester_role,
  category,subject,description,request_status,submitted_at,reviewed_at,reviewed_by,admin_response,
  claimed_by,claimed_by_name,claimed_at,last_activity_at,closed_at
)
select 'profile_change', r.id, m.auth_user_id, m.id, u.email, m.full_name,
  coalesce((select ur.role from public.user_roles ur where ur.user_id=m.auth_user_id order by case ur.role when 'directiva' then 1 when 'afiliado' then 2 else 3 end limit 1),
    case when lower(m.member_type)='colaborador' then 'colaborador' else 'afiliado' end),
  'Perfil profesional y directorio',
  case when r.requested_changes ? 'photo_path' and (select count(*) from jsonb_object_keys(r.requested_changes))=1
    then 'Actualización de fotografía profesional' else 'Actualización de perfil profesional' end,
  left('Cambios solicitados:' || E'\n' || jsonb_pretty(r.requested_changes),5000),
  r.request_status,r.submitted_at,r.reviewed_at,r.reviewed_by,left(r.admin_response,3000),
  case when r.request_status in ('approved','rejected') then r.reviewed_by else null end,
  case when r.request_status in ('approved','rejected') then reviewer.email else null end,
  case when r.request_status in ('approved','rejected') then r.reviewed_at else null end,
  coalesce(r.reviewed_at,r.submitted_at),
  case when r.request_status in ('approved','rejected') then r.reviewed_at else null end
from public.member_profile_change_requests r
join public.members m on m.id=r.member_id
join auth.users u on u.id=m.auth_user_id
left join auth.users reviewer on reviewer.id=r.reviewed_by
where m.auth_user_id is not null
  and not exists(select 1 from public.institutional_requests ir where ir.source_type='profile_change' and ir.source_request_id=r.id)
on conflict do nothing;

-- Nuevas solicitudes de cambio de perfil también crean un expediente dentro del centro integral.
create or replace function public.submit_my_pas_profile_change_request(p_changes jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_member_id uuid;
  v_request_id uuid;
  v_role text := public.current_pas_role();
  v_member_name text;
  v_email text;
  v_wrapper_id uuid;
  v_subject text;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  if v_role not in ('afiliado','colaborador','directiva') then raise exception 'Tu cuenta no tiene un rol PAS autorizado.' using errcode='42501'; end if;
  if p_changes is null or jsonb_typeof(p_changes)<>'object' or (select count(*) from jsonb_object_keys(p_changes))=0 then
    raise exception 'Indica al menos un dato para actualizar.' using errcode='22023';
  end if;
  if exists (select 1 from jsonb_object_keys(p_changes) f(key) where f.key not in
    ('contact_email','phone','professional_license','specialty','city','state','about','office_address','office_latitude','office_longitude','service_modality','public_directory_enabled','photo_path')) then
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
  select m.id,m.full_name,u.email into v_member_id,v_member_name,v_email
    from public.members m join auth.users u on u.id=m.auth_user_id where m.auth_user_id=auth.uid() limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  insert into public.member_profile_change_requests(member_id,requested_changes)
    values(v_member_id,p_changes) returning id into v_request_id;
  v_subject := case when p_changes ? 'photo_path' and (select count(*) from jsonb_object_keys(p_changes))=1
    then 'Actualización de fotografía profesional' else 'Actualización de perfil profesional' end;
  insert into public.institutional_requests(source_type,source_request_id,requester_user_id,requester_member_id,requester_email,requester_name,requester_role,category,subject,description)
    values('profile_change',v_request_id,auth.uid(),v_member_id,v_email,v_member_name,v_role,'Perfil profesional y directorio',v_subject,
      left('Cambios solicitados:' || E'\n' || jsonb_pretty(p_changes),5000)) returning id into v_wrapper_id;
  return v_request_id;
end; $$;

create or replace function public.submit_my_pas_photo_change_request(p_photo_path text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_member_id uuid;
  v_request_id uuid;
  v_role text := public.current_pas_role();
  v_member_name text;
  v_email text;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  if v_role not in ('afiliado','colaborador','directiva') then raise exception 'Tu cuenta no tiene un rol PAS autorizado.' using errcode='42501'; end if;
  select m.id,m.full_name,u.email into v_member_id,v_member_name,v_email
    from public.members m join auth.users u on u.id=m.auth_user_id where m.auth_user_id=auth.uid() limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  if p_photo_path is null or split_part(p_photo_path,'/',1) <> v_member_id::text or p_photo_path !~ ('^'||v_member_id::text||'/[A-Za-z0-9-]+\.(jpg|png|webp)$') then
    raise exception 'La ruta de fotografía no es válida.' using errcode='22023';
  end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='pas-profile-photos' and o.name=p_photo_path) then
    raise exception 'No se encontró la fotografía cargada.' using errcode='P0002';
  end if;
  insert into public.member_profile_change_requests(member_id,requested_changes)
    values(v_member_id,jsonb_build_object('photo_path',p_photo_path)) returning id into v_request_id;
  insert into public.institutional_requests(source_type,source_request_id,requester_user_id,requester_member_id,requester_email,requester_name,requester_role,category,subject,description)
    values('profile_change',v_request_id,auth.uid(),v_member_id,v_email,v_member_name,v_role,'Perfil profesional y directorio','Actualización de fotografía profesional',
      'Se solicita revisar la nueva fotografía profesional del perfil PAS.');
  return v_request_id;
end; $$;

create or replace function public.review_pas_profile_change_request(p_request_id uuid,p_decision text,p_admin_response text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_request public.member_profile_change_requests%rowtype;
  v_changes jsonb;
  v_owner uuid;
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
      public_directory_enabled=case when v_changes?'public_directory_enabled' then (v_changes->>'public_directory_enabled')::boolean else p.public_directory_enabled end,
      directory_consent_at=case when v_changes?'public_directory_enabled' and (v_changes->>'public_directory_enabled')::boolean then now()
        when v_changes?'public_directory_enabled' then null else p.directory_consent_at end,
      updated_at=now(),updated_by=auth.uid()
    where p.member_id=v_request.member_id;
  end if;
  update public.member_profile_change_requests set request_status=p_decision,reviewed_at=now(),reviewed_by=auth.uid(),admin_response=nullif(trim(coalesce(p_admin_response,'')),'') where id=p_request_id;
end; $$;

create or replace function public.count_pas_unassigned_requests()
returns integer language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_directiva() then
    raise exception 'Solo Directiva puede consultar solicitudes sin responsable.' using errcode='42501';
  end if;
  return (select count(*)::integer from public.institutional_requests
    where claimed_by is null and request_status in ('pending','in_review','needs_info'));
end; $$;

create or replace function public.list_pas_unassigned_request_previews()
returns table(id uuid,request_number text,subject text,requester_name text,requester_role text,category text,submitted_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not private.is_directiva() then
    raise exception 'Solo Directiva puede consultar solicitudes sin responsable.' using errcode='42501';
  end if;
  return query
  select r.id,r.request_number,r.subject,r.requester_name,r.requester_role,r.category,r.submitted_at
  from public.institutional_requests r
  where r.claimed_by is null and r.request_status in ('pending','in_review','needs_info')
  order by r.submitted_at asc limit 30;
end; $$;

create or replace function public.list_pas_directiva_operators()
returns table(user_id uuid, display_name text, email text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_directiva() then
    raise exception 'Solo Directiva puede consultar a sus integrantes.' using errcode='42501';
  end if;
  return query
  select ur.user_id,
         coalesce(nullif(m.full_name,''), u.email, 'Directivo PAS')::text,
         coalesce(u.email,'')::text
  from public.user_roles ur
  join auth.users u on u.id = ur.user_id
  left join public.members m on m.auth_user_id = ur.user_id
  where ur.role = 'directiva'
  order by 2;
end; $$;

create or replace function public.claim_pas_request(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_role text;
  v_name text;
  v_req public.institutional_requests%rowtype;
begin
  if v_uid is null or not private.is_directiva() then
    raise exception 'Solo un integrante de Directiva puede tomar una solicitud.' using errcode='42501';
  end if;
  select coalesce(nullif(m.full_name,''), u.email, 'Directiva PAS')
    into v_name from auth.users u left join public.members m on m.auth_user_id=u.id where u.id=v_uid;
  select * into v_req from public.institutional_requests where id=p_request_id for update;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
  if v_req.claimed_by = v_uid then
    return jsonb_build_object('claimed',true,'already_mine',true,'claimed_by',v_uid,'claimed_by_name',v_req.claimed_by_name);
  end if;
  if v_req.claimed_by is not null then
    return jsonb_build_object('claimed',false,'claimed_by',v_req.claimed_by,'claimed_by_name',v_req.claimed_by_name);
  end if;
  if v_req.request_status in ('approved','rejected') then
    raise exception 'Esta solicitud ya está cerrada.' using errcode='22023';
  end if;
  update public.institutional_requests
    set claimed_by=v_uid, claimed_by_name=v_name, claimed_at=now(), last_activity_at=now(),
        request_status=case when request_status='pending' then 'in_review' else request_status end
    where id=p_request_id;
  insert into public.institutional_request_events(request_id,actor_user_id,actor_name,event_type,details)
    values(p_request_id,v_uid,v_name,'claimed',jsonb_build_object('claimed_by',v_uid));
  insert into public.institutional_request_messages(request_id,sender_user_id,sender_role,sender_name,body)
    values(p_request_id,v_uid,'directiva',v_name,'He tomado la responsabilidad de atender tu solicitud. Puedes responder en esta conversación para dar seguimiento.');
  return jsonb_build_object('claimed',true,'already_mine',false,'claimed_by',v_uid,'claimed_by_name',v_name);
end; $$;

create or replace function public.transfer_pas_request(p_request_id uuid,p_new_owner uuid default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_old public.institutional_requests%rowtype;
  v_new_name text;
  v_actor_name text;
begin
  if v_uid is null or not private.is_directiva() then
    raise exception 'Solo Directiva puede transferir una solicitud.' using errcode='42501';
  end if;
  select * into v_old from public.institutional_requests where id=p_request_id for update;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
  if v_old.claimed_by is distinct from v_uid then
    raise exception 'Solo el responsable actual puede transferir o liberar este caso.' using errcode='42501';
  end if;
  if v_old.request_status in ('approved','rejected') then
    raise exception 'El caso está cerrado y no puede transferirse.' using errcode='22023';
  end if;
  select coalesce(nullif(m.full_name,''),u.email,'Directiva PAS') into v_actor_name
  from auth.users u left join public.members m on m.auth_user_id=u.id where u.id=v_uid;
  if p_new_owner is not null then
    if not exists(select 1 from public.user_roles ur where ur.user_id=p_new_owner and ur.role='directiva') then
      raise exception 'La persona seleccionada no pertenece a Directiva.' using errcode='22023';
    end if;
    select coalesce(nullif(m.full_name,''),u.email,'Directiva PAS') into v_new_name
    from auth.users u left join public.members m on m.auth_user_id=u.id where u.id=p_new_owner;
    update public.institutional_requests set claimed_by=p_new_owner,claimed_by_name=v_new_name,
      claimed_at=now(),transferred_at=now(),last_activity_at=now() where id=p_request_id;
    insert into public.institutional_request_events(request_id,actor_user_id,actor_name,event_type,details)
      values(p_request_id,v_uid,v_actor_name,'transferred',jsonb_build_object('from',v_uid,'to',p_new_owner,'to_name',v_new_name));
    insert into public.institutional_request_messages(request_id,sender_user_id,sender_role,sender_name,body)
      values(p_request_id,v_uid,'directiva',v_actor_name,'La responsabilidad de esta solicitud fue transferida a '||v_new_name||'.');
  else
    update public.institutional_requests set claimed_by=null,claimed_by_name=null,claimed_at=null,
      transferred_at=now(),last_activity_at=now() where id=p_request_id;
    insert into public.institutional_request_events(request_id,actor_user_id,actor_name,event_type,details)
      values(p_request_id,v_uid,v_actor_name,'released',jsonb_build_object('released_to_queue',true));
    insert into public.institutional_request_messages(request_id,sender_user_id,sender_role,sender_name,body)
      values(p_request_id,v_uid,'directiva',v_actor_name,'La solicitud volvió a la bandeja general de Directiva para que otro integrante pueda continuar su atención.');
  end if;
end; $$;

create or replace function public.send_pas_request_message(p_request_id uuid,p_body text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_role text := public.current_pas_role();
  v_name text;
  v_req public.institutional_requests%rowtype;
  v_message_id uuid;
begin
  if v_uid is null then raise exception 'Inicia sesión para responder.' using errcode='42501'; end if;
  if length(trim(coalesce(p_body,''))) not between 1 and 5000 then
    raise exception 'El mensaje debe tener entre 1 y 5000 caracteres.' using errcode='22023';
  end if;
  if v_role not in ('directiva','afiliado','colaborador') then
    raise exception 'Tu cuenta no tiene un rol PAS autorizado.' using errcode='42501';
  end if;
  select * into v_req from public.institutional_requests where id=p_request_id for update;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
  if v_req.requester_user_id is distinct from v_uid and v_req.claimed_by is distinct from v_uid then
    raise exception 'Solo el solicitante y el directivo responsable pueden escribir en esta conversación.' using errcode='42501';
  end if;
  if v_req.request_status in ('approved','rejected') then
    raise exception 'La solicitud está cerrada. Para continuar, envía una nueva solicitud.' using errcode='22023';
  end if;
  select coalesce(nullif(m.full_name,''),u.email,'Integrante PAS') into v_name
    from auth.users u left join public.members m on m.auth_user_id=u.id where u.id=v_uid;
  insert into public.institutional_request_messages(request_id,sender_user_id,sender_role,sender_name,body)
    values(p_request_id,v_uid,v_role,v_name,trim(p_body)) returning id into v_message_id;
  update public.institutional_requests set last_activity_at=now() where id=p_request_id;
  return v_message_id;
end; $$;

create or replace function public.mark_pas_request_messages_read(p_request_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_count integer;
begin
  if v_uid is null then raise exception 'Se requiere iniciar sesión.' using errcode='42501'; end if;
  if not exists(select 1 from public.institutional_requests r where r.id=p_request_id
    and (r.requester_user_id=v_uid or r.claimed_by=v_uid)) then
    raise exception 'No tienes acceso a esta conversación.' using errcode='42501';
  end if;
  insert into public.institutional_request_message_reads(message_id,user_id)
    select msg.id,v_uid from public.institutional_request_messages msg
    where msg.request_id=p_request_id and msg.sender_user_id<>v_uid
      and not exists(select 1 from public.institutional_request_message_reads rd where rd.message_id=msg.id and rd.user_id=v_uid)
  on conflict(message_id,user_id) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end; $$;

create or replace function public.count_my_pas_request_unread_messages()
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer
  from public.institutional_request_messages msg
  join public.institutional_requests r on r.id=msg.request_id
  where msg.sender_user_id <> (select auth.uid())
    and (r.requester_user_id=(select auth.uid()) or r.claimed_by=(select auth.uid()))
    and not exists(select 1 from public.institutional_request_message_reads rd where rd.message_id=msg.id and rd.user_id=(select auth.uid()));
$$;

create or replace function public.list_my_pas_request_unread_previews()
returns table(request_id uuid,request_number text,subject text,sender_name text,body text,created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'Se requiere iniciar sesión.' using errcode='42501'; end if;
  return query
  select latest.request_id,latest.request_number,latest.subject,latest.sender_name,latest.body,latest.created_at
  from (
    select distinct on (msg.request_id) msg.request_id,r.request_number,r.subject,msg.sender_name,msg.body,msg.created_at
    from public.institutional_request_messages msg
    join public.institutional_requests r on r.id=msg.request_id
    where msg.sender_user_id <> (select auth.uid())
      and (r.requester_user_id=(select auth.uid()) or r.claimed_by=(select auth.uid()))
      and not exists(select 1 from public.institutional_request_message_reads rd where rd.message_id=msg.id and rd.user_id=(select auth.uid()))
    order by msg.request_id,msg.created_at desc
  ) latest
  order by latest.created_at desc;
end; $$;

create or replace function public.update_pas_request_status(p_request_id uuid,p_status text,p_response text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_req public.institutional_requests%rowtype;
  v_actor_name text;
begin
  if v_uid is null or not private.is_directiva() then
    raise exception 'Solo Directiva puede actualizar el estado.' using errcode='42501';
  end if;
  if p_status not in ('in_review','needs_info','approved','rejected') then
    raise exception 'Estado de solicitud no válido.' using errcode='22023';
  end if;
  select * into v_req from public.institutional_requests where id=p_request_id for update;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
  if v_req.claimed_by is distinct from v_uid then
    raise exception 'Primero debes tomar la solicitud para administrar este caso.' using errcode='42501';
  end if;
  if v_req.request_status in ('approved','rejected') then
    raise exception 'La solicitud ya está cerrada. Para continuar, crea una nueva solicitud.' using errcode='22023';
  end if;
  if p_response is not null and length(p_response)>3000 then
    raise exception 'La respuesta breve no puede superar 3000 caracteres.' using errcode='22023';
  end if;
  if v_req.source_type='profile_change' and p_status in ('approved','rejected') then
    perform public.review_pas_profile_change_request(v_req.source_request_id,p_status,p_response);
  end if;
  select coalesce(nullif(m.full_name,''),u.email,'Directiva PAS') into v_actor_name
    from auth.users u left join public.members m on m.auth_user_id=u.id where u.id=v_uid;
  update public.institutional_requests set request_status=p_status,
    admin_response=coalesce(nullif(trim(coalesce(p_response,'')),''),admin_response),
    reviewed_at=now(),reviewed_by=v_uid,last_activity_at=now(),
    closed_at=case when p_status in ('approved','rejected') then now() else null end
    where id=p_request_id;
  insert into public.institutional_request_messages(request_id,sender_user_id,sender_role,sender_name,body)
    values(p_request_id,v_uid,'directiva',v_actor_name,
      'El estado de tu solicitud cambió a: ' || case p_status when 'in_review' then 'En revisión' when 'needs_info' then 'Requiere información' when 'approved' then 'Resuelta / aprobada' when 'rejected' then 'Rechazada' end ||
      case when nullif(trim(coalesce(p_response,'')),'') is not null then E'\n\n' || trim(p_response) else '' end);
  insert into public.institutional_request_events(request_id,actor_user_id,actor_name,event_type,details)
    values(p_request_id,v_uid,v_actor_name,'status_changed',jsonb_build_object('from',v_req.request_status,'to',p_status,'response',nullif(trim(coalesce(p_response,'')),'')));
end; $$;

-- Mantiene compatibilidad con versiones anteriores, pero aplica la regla de responsable único.
create or replace function public.review_pas_request(p_request_id uuid,p_status text,p_response text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  if not private.is_directiva() then raise exception 'Solo la Directiva puede resolver solicitudes.' using errcode='42501'; end if;
  select claimed_by into v_owner from public.institutional_requests where id=p_request_id;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
  if v_owner is null then
    perform public.claim_pas_request(p_request_id);
  elsif v_owner <> auth.uid() then
    raise exception 'La solicitud ya tiene un directivo responsable.' using errcode='42501';
  end if;
  perform public.update_pas_request_status(p_request_id,p_status,p_response);
end; $$;

revoke all on function public.submit_my_pas_profile_change_request(jsonb) from public,anon;
revoke all on function public.submit_my_pas_photo_change_request(text) from public,anon;
revoke all on function public.review_pas_profile_change_request(uuid,text,text) from public,anon,authenticated;
grant execute on function public.submit_my_pas_profile_change_request(jsonb) to authenticated;
grant execute on function public.submit_my_pas_photo_change_request(text) to authenticated;

revoke all on function public.count_pas_unassigned_requests() from public,anon;
revoke all on function public.list_pas_unassigned_request_previews() from public,anon;
revoke all on function public.list_pas_directiva_operators() from public,anon;
revoke all on function public.claim_pas_request(uuid) from public,anon;
revoke all on function public.transfer_pas_request(uuid,uuid) from public,anon;
revoke all on function public.send_pas_request_message(uuid,text) from public,anon;
revoke all on function public.mark_pas_request_messages_read(uuid) from public,anon;
revoke all on function public.count_my_pas_request_unread_messages() from public,anon;
revoke all on function public.list_my_pas_request_unread_previews() from public,anon;
revoke all on function public.update_pas_request_status(uuid,text,text) from public,anon;
revoke all on function public.review_pas_request(uuid,text,text) from public,anon;
grant execute on function public.count_pas_unassigned_requests() to authenticated;
grant execute on function public.list_pas_unassigned_request_previews() to authenticated;
grant execute on function public.list_pas_directiva_operators() to authenticated;
grant execute on function public.claim_pas_request(uuid) to authenticated;
grant execute on function public.transfer_pas_request(uuid,uuid) to authenticated;
grant execute on function public.send_pas_request_message(uuid,text) to authenticated;
grant execute on function public.mark_pas_request_messages_read(uuid) to authenticated;
grant execute on function public.count_my_pas_request_unread_messages() to authenticated;
grant execute on function public.list_my_pas_request_unread_previews() to authenticated;
grant execute on function public.update_pas_request_status(uuid,text,text) to authenticated;
grant execute on function public.review_pas_request(uuid,text,text) to authenticated;

commit;
