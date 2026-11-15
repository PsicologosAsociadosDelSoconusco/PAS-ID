-- PAS ID: entregas con varios archivos por requerimiento documental.
-- Ejecutar UNA SOLA VEZ después de confirmar que 010 y 011 están aplicadas.
-- Conserva las columnas antiguas para compatibilidad con expedientes existentes.
begin;

create table if not exists public.member_document_files (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.member_document_requests(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete cascade,
  storage_path text not null unique,
  original_filename text not null check (char_length(original_filename) between 1 and 255),
  mime_type text not null check (mime_type in ('application/pdf','image/jpeg','image/png','image/webp')),
  file_size bigint not null check (file_size between 1 and 10485760),
  status text not null default 'submitted' check (status in ('submitted','approved','changes_requested','superseded')),
  uploaded_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  review_notes text,
  constraint member_document_file_path_consistency check (
    split_part(storage_path,'/',1)=member_id::text and split_part(storage_path,'/',2)=request_id::text
  )
);
create index if not exists member_document_files_request_idx on public.member_document_files(request_id,uploaded_at);
alter table public.member_document_files enable row level security;
revoke all on public.member_document_files from public,anon,authenticated;
grant select on public.member_document_files to authenticated;
drop policy if exists pas_member_document_files_read on public.member_document_files;
create policy pas_member_document_files_read on public.member_document_files for select to authenticated using (
  private.is_directiva() or exists(select 1 from public.members m where m.id=member_document_files.member_id and m.auth_user_id=(select auth.uid()))
);

create or replace function public.submit_my_pas_member_documents(p_request_id uuid,p_files jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare v_member_id uuid; v_request public.member_document_requests%rowtype; v_item jsonb; v_count integer:=0; v_path text; v_name text; v_mime text; v_size bigint;
begin
  if auth.uid() is null then raise exception 'Se requiere una sesión.' using errcode='42501'; end if;
  select m.id into v_member_id from public.members m where m.auth_user_id=auth.uid() limit 1;
  if v_member_id is null then raise exception 'La cuenta no está vinculada a un expediente PAS.' using errcode='42501'; end if;
  select * into v_request from public.member_document_requests r where r.id=p_request_id and r.member_id=v_member_id for update;
  if not found then raise exception 'No encontramos esta solicitud de documentación.' using errcode='P0002'; end if;
  if v_request.status not in ('pending','changes_requested') then raise exception 'Esta solicitud ya no admite una nueva entrega.' using errcode='22023'; end if;
  if jsonb_typeof(p_files)<>'array' or jsonb_array_length(p_files)<1 or jsonb_array_length(p_files)>10 then raise exception 'Entrega entre 1 y 10 archivos.' using errcode='22023'; end if;
  update public.member_document_files set status='superseded' where request_id=p_request_id and status='changes_requested';
  for v_item in select value from jsonb_array_elements(p_files) loop
    v_path:=v_item->>'storage_path'; v_name:=v_item->>'original_filename'; v_mime:=v_item->>'mime_type'; v_size:=nullif(v_item->>'file_size','')::bigint;
    if v_path is null or split_part(v_path,'/',1)<>v_member_id::text or split_part(v_path,'/',2)<>p_request_id::text then raise exception 'La ruta de un archivo no corresponde a tu solicitud.' using errcode='22023'; end if;
    if v_name is null or char_length(v_name)>255 or position('/' in v_name)>0 or position(chr(92) in v_name)>0 then raise exception 'Nombre de archivo no válido.' using errcode='22023'; end if;
    if v_mime not in ('application/pdf','image/jpeg','image/png','image/webp') or v_size is null or v_size not between 1 and 10485760 then raise exception 'Cada archivo debe ser PDF, JPG, PNG o WEBP y no superar 10 MB.' using errcode='22023'; end if;
    if not exists(select 1 from storage.objects o where o.bucket_id='pas-member-documents' and o.name=v_path) then raise exception 'No se encontró uno de los archivos cargados.' using errcode='P0002'; end if;
    insert into public.member_document_files(request_id,member_id,storage_path,original_filename,mime_type,file_size)
    values(p_request_id,v_member_id,v_path,v_name,v_mime,v_size);
    v_count:=v_count+1;
  end loop;
  update public.member_document_requests set status='submitted',submitted_at=now(),reviewed_by=null,reviewed_at=null,review_notes=null,updated_at=now() where id=p_request_id;
  return v_count;
end; $$;

create or replace function public.review_pas_member_document_file(p_file_id uuid,p_decision text,p_notes text default null)
returns void language plpgsql security definer set search_path='' as $$
declare v_file public.member_document_files%rowtype; v_parent_id uuid; v_remaining integer; v_has_correction boolean;
begin
  if not private.is_directiva() then raise exception 'No autorizado: se requiere Directiva PAS.' using errcode='42501'; end if;
  if p_decision not in ('approved','changes_requested') then raise exception 'Decisión no válida.' using errcode='22023'; end if;
  if p_decision='changes_requested' and nullif(trim(coalesce(p_notes,'')),'') is null then raise exception 'Indica qué debe corregirse en este archivo.' using errcode='22023'; end if;
  select * into v_file from public.member_document_files where id=p_file_id for update;
  if not found then raise exception 'Archivo no encontrado.' using errcode='P0002'; end if;
  update public.member_document_files set status=p_decision,reviewed_by=auth.uid(),reviewed_at=now(),review_notes=nullif(trim(coalesce(p_notes,'')),'') where id=p_file_id;
  v_parent_id:=v_file.request_id;
  select count(*) filter(where status='submitted'), bool_or(status='changes_requested') into v_remaining,v_has_correction from public.member_document_files where request_id=v_parent_id;
  update public.member_document_requests set
    status=case when v_remaining>0 then 'submitted' when v_has_correction then 'changes_requested' else 'approved' end,
    reviewed_by=case when v_remaining=0 then auth.uid() else null end,
    reviewed_at=case when v_remaining=0 then now() else null end,
    review_notes=case when v_remaining=0 and v_has_correction then 'Uno o más archivos requieren corrección. Consulta las observaciones individuales.' else null end,
    updated_at=now()
  where id=v_parent_id;
end; $$;

revoke all on function public.submit_my_pas_member_documents(uuid,jsonb) from public,anon;
revoke all on function public.review_pas_member_document_file(uuid,text,text) from public,anon;
grant execute on function public.submit_my_pas_member_documents(uuid,jsonb) to authenticated;
grant execute on function public.review_pas_member_document_file(uuid,text,text) to authenticated;
commit;
