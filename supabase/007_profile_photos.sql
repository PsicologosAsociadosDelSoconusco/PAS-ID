-- PAS ID · Fotografía profesional con autorización y revisión de Directiva.
-- Ejecutar DESPUÉS de 006_public_professional_profile.sql. Idempotente.
begin;


alter table public.member_profiles add column if not exists photo_path text;

-- Amplía la función pública sin cambiar los QR ni los identificadores.
drop function if exists public.verify_pas_credential_public(text);
create function public.verify_pas_credential_public(p_identifier text)
returns table (found boolean,full_name text,legacy_folio text,member_type text,verification_status text,issued_on date,expires_on date,professional_license text,specialty text,city text,state text,about text,photo_path text)
language plpgsql stable security definer set search_path='' as $$
declare v_base record; v_member_id uuid; v_profile public.member_profiles%rowtype;
begin
  select * into v_base from public.verify_pas_credential(p_identifier);
  if not coalesce(v_base.found,false) then
    return query select false,null::text,null::text,null::text,'not_found'::text,null::date,null::date,null::text,null::text,null::text,null::text,null::text,null::text;
    return;
  end if;
  select m.id into v_member_id from public.members m
  where m.legacy_folio=upper(trim(coalesce(p_identifier,''))) or exists (select 1 from public.credentials c where c.member_id=m.id and c.public_identifier=upper(trim(coalesce(p_identifier,'')))) limit 1;
  select p.* into v_profile from public.member_profiles p where p.member_id=v_member_id;
  return query select v_base.found,v_base.full_name,v_base.legacy_folio,v_base.member_type,v_base.verification_status,v_base.issued_on,v_base.expires_on,
    nullif(trim(v_profile.professional_license),''),nullif(trim(v_profile.specialty),''),nullif(trim(v_profile.city),''),nullif(trim(v_profile.state),''),nullif(trim(v_profile.about),''),nullif(trim(v_profile.photo_path),'');
end; $$;
revoke all on function public.verify_pas_credential_public(text) from public;
grant execute on function public.verify_pas_credential_public(text) to anon,authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pas-profile-photos','pas-profile-photos',true,3145728,array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=true, file_size_limit=3145728, allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists pas_profile_photos_public_read on storage.objects;
drop policy if exists pas_profile_photos_member_read on storage.objects;
create policy pas_profile_photos_member_read on storage.objects for select to authenticated
using (bucket_id='pas-profile-photos' and exists (select 1 from public.members m where m.id::text=split_part(name,'/',1) and m.auth_user_id=(select auth.uid())));

drop policy if exists pas_profile_photos_member_insert on storage.objects;
create policy pas_profile_photos_member_insert on storage.objects for insert to authenticated
with check (bucket_id='pas-profile-photos' and exists (select 1 from public.members m where m.id::text=split_part(name,'/',1) and m.auth_user_id=(select auth.uid())));

drop policy if exists pas_profile_photos_member_update on storage.objects;
create policy pas_profile_photos_member_update on storage.objects for update to authenticated
using (bucket_id='pas-profile-photos' and exists (select 1 from public.members m where m.id::text=split_part(name,'/',1) and m.auth_user_id=(select auth.uid())))
with check (bucket_id='pas-profile-photos' and exists (select 1 from public.members m where m.id::text=split_part(name,'/',1) and m.auth_user_id=(select auth.uid())));

drop policy if exists pas_profile_photos_member_delete on storage.objects;
create policy pas_profile_photos_member_delete on storage.objects for delete to authenticated
using (bucket_id='pas-profile-photos' and exists (select 1 from public.members m where m.id::text=split_part(name,'/',1) and m.auth_user_id=(select auth.uid())));

create or replace function public.submit_my_pas_photo_change_request(p_photo_path text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_member_id uuid; v_request_id uuid;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=(select auth.uid()) limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  if p_photo_path is null or split_part(p_photo_path,'/',1) <> v_member_id::text or p_photo_path !~ ('^'||v_member_id::text||'/[A-Za-z0-9-]+\.(jpg|png|webp)$') then
    raise exception 'La ruta de fotografía no es válida.' using errcode='22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id='pas-profile-photos' and o.name=p_photo_path) then
    raise exception 'No se encontró la fotografía cargada.' using errcode='P0002';
  end if;
  insert into public.member_profile_change_requests(member_id,requested_changes)
  values(v_member_id,jsonb_build_object('photo_path',p_photo_path)) returning id into v_request_id;
  return v_request_id;
end; $$;

create or replace function public.review_pas_profile_change_request(p_request_id uuid,p_decision text,p_admin_response text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_request public.member_profile_change_requests%rowtype; v_changes jsonb;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_decision not in ('approved','rejected') then raise exception 'Decisión no válida.' using errcode='22023'; end if;
  select * into v_request from public.member_profile_change_requests where id=p_request_id for update;
  if not found then raise exception 'Solicitud no encontrada.' using errcode='P0002'; end if;
  if v_request.request_status <> 'pending' then raise exception 'Esta solicitud ya fue atendida.' using errcode='22023'; end if;
  v_changes:=v_request.requested_changes;
  if p_decision='approved' then
    insert into public.member_profiles(member_id) values(v_request.member_id) on conflict(member_id) do nothing;
    if v_changes ? 'photo_path' then
      if v_changes->>'photo_path' is null or split_part(v_changes->>'photo_path','/',1) <> v_request.member_id::text then raise exception 'La fotografía no corresponde al expediente.' using errcode='22023'; end if;
      update public.member_profiles set photo_path=v_changes->>'photo_path',updated_at=now(),updated_by=(select auth.uid()) where member_id=v_request.member_id;
    else
      update public.member_profiles p set
        contact_email=case when v_changes?'contact_email' then nullif(trim(v_changes->>'contact_email'),'') else p.contact_email end,
        phone=case when v_changes?'phone' then nullif(trim(v_changes->>'phone'),'') else p.phone end,
        professional_license=case when v_changes?'professional_license' then nullif(trim(v_changes->>'professional_license'),'') else p.professional_license end,
        specialty=case when v_changes?'specialty' then nullif(trim(v_changes->>'specialty'),'') else p.specialty end,
        city=case when v_changes?'city' then nullif(trim(v_changes->>'city'),'') else p.city end,
        state=case when v_changes?'state' then nullif(trim(v_changes->>'state'),'') else p.state end,
        about=case when v_changes?'about' then nullif(trim(v_changes->>'about'),'') else p.about end,
        updated_at=now(),updated_by=(select auth.uid()) where p.member_id=v_request.member_id;
    end if;
  end if;
  update public.member_profile_change_requests set request_status=p_decision,reviewed_at=now(),reviewed_by=(select auth.uid()),admin_response=nullif(trim(coalesce(p_admin_response,'')),'') where id=p_request_id;
end; $$;

revoke all on function public.submit_my_pas_photo_change_request(text) from public,anon;
grant execute on function public.submit_my_pas_photo_change_request(text) to authenticated;
revoke all on function public.review_pas_profile_change_request(uuid,text,text) from public,anon;
grant execute on function public.review_pas_profile_change_request(uuid,text,text) to authenticated;
-- Devuelve la ruta de la fotografía aprobada al titular de la cuenta.
create or replace function public.get_my_pas_profile()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_member_id uuid; v_result jsonb;
begin
  if (select auth.uid()) is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=(select auth.uid()) limit 1;
  if v_member_id is null then raise exception 'Esta cuenta todavía no está vinculada a un expediente PAS.' using errcode='P0002'; end if;
  select jsonb_build_object(
    'member',jsonb_build_object('id',m.id,'full_name',m.full_name,'member_type',m.member_type,'membership_status',m.membership_status,'legacy_folio',m.legacy_folio,'issued_on',m.issued_on,'expires_on',m.expires_on,'is_historical',m.is_historical),
    'profile',coalesce((select jsonb_build_object('contact_email',p.contact_email,'phone',p.phone,'professional_license',p.professional_license,'specialty',p.specialty,'city',p.city,'state',p.state,'about',p.about,'photo_path',p.photo_path,'updated_at',p.updated_at) from public.member_profiles p where p.member_id=m.id),'{}'::jsonb),
    'credential',coalesce((select jsonb_build_object('id',c.id,'public_identifier',coalesce(c.public_identifier,m.legacy_folio),'credential_status',c.credential_status,'issued_at',c.issued_at,'expires_on',c.expires_on) from public.credentials c where c.member_id=m.id order by c.issued_at desc,c.created_at desc limit 1),'{}'::jsonb),
    'requests',coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'requested_changes',r.requested_changes,'request_status',r.request_status,'submitted_at',r.submitted_at,'reviewed_at',r.reviewed_at,'admin_response',r.admin_response) order by r.submitted_at desc) from public.member_profile_change_requests r where r.member_id=m.id),'[]'::jsonb)
  ) into v_result from public.members m where m.id=v_member_id;
  return v_result;
end; $$;
revoke all on function public.get_my_pas_profile() from public,anon;
grant execute on function public.get_my_pas_profile() to authenticated;

commit;
