-- PAS ID · Expediente documental de integrantes.
-- Ejecutar UNA SOLA VEZ después de la migración 009.
-- No modifica miembros, credenciales, QR ni folios históricos.
begin;

create table if not exists public.member_document_requests (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 3 and 140),
  instructions text,
  due_date date,
  status text not null default 'pending' check (status in ('pending','submitted','approved','changes_requested')),
  requested_by uuid references auth.users(id) on delete set null,
  requested_at timestamptz not null default now(),
  submitted_at timestamptz,
  storage_path text,
  original_filename text,
  mime_type text,
  file_size bigint,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text,
  updated_at timestamptz not null default now(),
  constraint member_document_file_consistency check (
    (storage_path is null and original_filename is null and mime_type is null and file_size is null)
    or (storage_path is not null and original_filename is not null and mime_type is not null and file_size is not null)
  )
);

create index if not exists member_document_requests_member_date_idx
  on public.member_document_requests(member_id, requested_at desc);
create index if not exists member_document_requests_status_idx
  on public.member_document_requests(status, requested_at desc);

alter table public.member_document_requests enable row level security;
drop policy if exists pas_member_documents_read on public.member_document_requests;
create policy pas_member_documents_read on public.member_document_requests
for select to authenticated using (
  private.is_directiva() or exists (
    select 1 from public.members m where m.id=member_document_requests.member_id and m.auth_user_id=(select auth.uid())
  )
);
revoke all on public.member_document_requests from anon, authenticated, public;
grant select on public.member_document_requests to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('pas-member-documents','pas-member-documents',false,10485760,array['application/pdf','image/jpeg','image/png','image/webp'])
on conflict (id) do update set public=false,file_size_limit=10485760,allowed_mime_types=array['application/pdf','image/jpeg','image/png','image/webp'];

drop policy if exists pas_member_documents_storage_insert on storage.objects;
create policy pas_member_documents_storage_insert on storage.objects for insert to authenticated
with check (
  bucket_id='pas-member-documents' and exists (
    select 1 from public.member_document_requests r
    join public.members m on m.id=r.member_id
    where m.auth_user_id=(select auth.uid())
      and r.id::text=split_part(name,'/',2)
      and r.member_id::text=split_part(name,'/',1)
      and r.status in ('pending','changes_requested')
  )
);

drop policy if exists pas_member_documents_storage_read on storage.objects;
create policy pas_member_documents_storage_read on storage.objects for select to authenticated
using (
  bucket_id='pas-member-documents' and (
    private.is_directiva() or exists (
      select 1 from public.member_document_requests r
      join public.members m on m.id=r.member_id
      where m.auth_user_id=(select auth.uid())
        and r.id::text=split_part(name,'/',2)
        and r.member_id::text=split_part(name,'/',1)
    )
  )
);

drop policy if exists pas_member_documents_storage_update on storage.objects;
create policy pas_member_documents_storage_update on storage.objects for update to authenticated
using (
  bucket_id='pas-member-documents' and exists (
    select 1 from public.member_document_requests r
    join public.members m on m.id=r.member_id
    where m.auth_user_id=(select auth.uid())
      and r.id::text=split_part(name,'/',2)
      and r.member_id::text=split_part(name,'/',1)
      and r.status in ('pending','changes_requested')
  )
)
with check (
  bucket_id='pas-member-documents' and exists (
    select 1 from public.member_document_requests r
    join public.members m on m.id=r.member_id
    where m.auth_user_id=(select auth.uid())
      and r.id::text=split_part(name,'/',2)
      and r.member_id::text=split_part(name,'/',1)
      and r.status in ('pending','changes_requested')
  )
);

create or replace function public.create_pas_member_document_request(
  p_member_id uuid default null,
  p_title text default null,
  p_instructions text default null,
  p_due_date date default null
)
returns integer language plpgsql security definer set search_path='' as $$
declare v_count integer:=0;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_title is null or char_length(trim(p_title)) not between 3 and 140 then raise exception 'Escribe el nombre del documento solicitado (3 a 140 caracteres).' using errcode='22023'; end if;
  if char_length(coalesce(p_instructions,''))>1200 then raise exception 'Las instrucciones no pueden superar 1,200 caracteres.' using errcode='22023'; end if;
  if p_member_id is not null then
    insert into public.member_document_requests(member_id,title,instructions,due_date,requested_by)
    select m.id,trim(p_title),nullif(trim(coalesce(p_instructions,'')),''),p_due_date,auth.uid()
    from public.members m where m.id=p_member_id and m.membership_status='active' and m.auth_user_id is not null
      and m.member_type <> 'Directiva'
      and not exists(select 1 from public.user_roles ur where ur.user_id=m.auth_user_id and ur.role='directiva');
    get diagnostics v_count=row_count;
    if v_count=0 then raise exception 'El integrante no tiene una cuenta vinculada o no está activo.' using errcode='P0002'; end if;
  else
    insert into public.member_document_requests(member_id,title,instructions,due_date,requested_by)
    select m.id,trim(p_title),nullif(trim(coalesce(p_instructions,'')),''),p_due_date,auth.uid()
    from public.members m
    where m.membership_status='active' and m.auth_user_id is not null
      and m.member_type <> 'Directiva'
      and not exists(select 1 from public.user_roles ur where ur.user_id=m.auth_user_id and ur.role='directiva');
    get diagnostics v_count=row_count;
    if v_count=0 then raise exception 'No hay integrantes activos con cuenta vinculada para recibir el requerimiento.' using errcode='P0002'; end if;
  end if;
  return v_count;
end; $$;

create or replace function public.submit_my_pas_member_document(
  p_request_id uuid,p_storage_path text,p_original_filename text,p_mime_type text,p_file_size bigint
)
returns void language plpgsql security definer set search_path='' as $$
declare v_member_id uuid; v_request public.member_document_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=auth.uid() limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  select * into v_request from public.member_document_requests r where r.id=p_request_id and r.member_id=v_member_id for update;
  if not found then raise exception 'No encontramos esta solicitud de documentación.' using errcode='P0002'; end if;
  if v_request.status not in ('pending','changes_requested') then raise exception 'Esta solicitud ya no admite una nueva entrega.' using errcode='22023'; end if;
  if p_storage_path is null or split_part(p_storage_path,'/',1)<>v_member_id::text or split_part(p_storage_path,'/',2)<>p_request_id::text then raise exception 'La ruta del archivo no corresponde a tu solicitud.' using errcode='22023'; end if;
  if p_mime_type is null or p_mime_type not in ('application/pdf','image/jpeg','image/png','image/webp') or p_file_size is null or p_file_size not between 1 and 10485760 then raise exception 'El archivo debe ser PDF, JPG, PNG o WEBP y no superar 10 MB.' using errcode='22023'; end if;
  if p_original_filename is null or char_length(p_original_filename)>255 or position('/' in p_original_filename)>0 or position(chr(92) in p_original_filename)>0 then raise exception 'El nombre del archivo no es válido.' using errcode='22023'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='pas-member-documents' and o.name=p_storage_path) then raise exception 'No se encontró el archivo cargado.' using errcode='P0002'; end if;
  update public.member_document_requests set status='submitted',storage_path=p_storage_path,original_filename=p_original_filename,mime_type=p_mime_type,file_size=p_file_size,submitted_at=now(),reviewed_by=null,reviewed_at=null,review_notes=null,updated_at=now()
  where id=p_request_id;
end; $$;

create or replace function public.review_pas_member_document(p_request_id uuid,p_decision text,p_notes text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_request public.member_document_requests%rowtype;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_decision not in ('approved','changes_requested') then raise exception 'La decisión debe ser aprobar o solicitar corrección.' using errcode='22023'; end if;
  if p_decision='changes_requested' and nullif(trim(coalesce(p_notes,'')),'') is null then raise exception 'Indica qué debe corregir el integrante.' using errcode='22023'; end if;
  select * into v_request from public.member_document_requests where id=p_request_id for update;
  if not found then raise exception 'Solicitud de documento no encontrada.' using errcode='P0002'; end if;
  if v_request.status<>'submitted' then raise exception 'Solo pueden revisarse documentos entregados.' using errcode='22023'; end if;
  update public.member_document_requests set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_notes=nullif(trim(coalesce(p_notes,'')),''),updated_at=now() where id=p_request_id;
end; $$;

revoke all on function public.create_pas_member_document_request(uuid,text,text,date) from public,anon;
revoke all on function public.submit_my_pas_member_document(uuid,text,text,text,bigint) from public,anon;
revoke all on function public.review_pas_member_document(uuid,text,text) from public,anon;
grant execute on function public.create_pas_member_document_request(uuid,text,text,date) to authenticated;
grant execute on function public.submit_my_pas_member_document(uuid,text,text,text,bigint) to authenticated;
grant execute on function public.review_pas_member_document(uuid,text,text) to authenticated;

commit;
