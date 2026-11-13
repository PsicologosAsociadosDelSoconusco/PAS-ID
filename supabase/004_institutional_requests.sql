-- PAS ID · Solicitudes institucionales para afiliados, colaboradores y Directiva
-- Ejecutar una sola vez en Supabase SQL Editor, después de las migraciones anteriores.
begin;

create table if not exists public.institutional_requests (
  id uuid primary key default gen_random_uuid(),
  request_number text not null unique default ('PAS-SOL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10))),
  requester_user_id uuid not null references auth.users(id) on delete cascade,
  requester_member_id uuid references public.members(id) on delete set null,
  requester_email text,
  requester_name text,
  requester_role text not null check (requester_role in ('directiva','afiliado','colaborador')),
  category text not null check (length(trim(category)) between 3 and 120),
  subject text not null check (length(trim(subject)) between 3 and 160),
  description text not null check (length(trim(description)) between 10 and 5000),
  related_place text check (related_place is null or length(related_place) <= 180),
  proposed_date date,
  request_status text not null default 'pending' check (request_status in ('pending','in_review','approved','rejected','needs_info')),
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id) on delete set null,
  admin_response text check (admin_response is null or length(admin_response) <= 3000)
);
create index if not exists institutional_requests_user_idx on public.institutional_requests(requester_user_id, submitted_at desc);
create index if not exists institutional_requests_status_idx on public.institutional_requests(request_status, submitted_at desc);
alter table public.institutional_requests enable row level security;
revoke all on public.institutional_requests from anon, authenticated;
grant select on public.institutional_requests to authenticated;
drop policy if exists institutional_requests_read_own_or_directiva on public.institutional_requests;
create policy institutional_requests_read_own_or_directiva on public.institutional_requests for select to authenticated using (requester_user_id = (select auth.uid()) or (select private.is_directiva()));
drop policy if exists institutional_requests_update_directiva on public.institutional_requests;
create policy institutional_requests_update_directiva on public.institutional_requests for update to authenticated using ((select private.is_directiva())) with check ((select private.is_directiva()));

create or replace function public.submit_pas_request(p_request jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_role text; v_member_id uuid; v_name text; v_email text; v_row public.institutional_requests%rowtype;
begin
  if v_uid is null then raise exception 'Se requiere iniciar sesión.' using errcode = '42501'; end if;
  v_role := public.current_pas_role();
  if v_role not in ('directiva','afiliado','colaborador') then raise exception 'Tu cuenta no tiene un rol PAS autorizado.' using errcode = '42501'; end if;
  select id, full_name into v_member_id, v_name from public.members where auth_user_id = v_uid limit 1;
  select email into v_email from auth.users where id = v_uid;
  if length(trim(coalesce(p_request->>'category',''))) not between 3 and 120 then raise exception 'Selecciona un tipo de solicitud válido.'; end if;
  if length(trim(coalesce(p_request->>'subject',''))) not between 3 and 160 then raise exception 'El asunto debe tener entre 3 y 160 caracteres.'; end if;
  if length(trim(coalesce(p_request->>'description',''))) not between 10 and 5000 then raise exception 'La descripción debe tener entre 10 y 5000 caracteres.'; end if;
  insert into public.institutional_requests(requester_user_id, requester_member_id, requester_email, requester_name, requester_role, category, subject, description, related_place, proposed_date)
  values (v_uid, v_member_id, v_email, coalesce(v_name, v_email, 'Usuario PAS'), v_role, trim(p_request->>'category'), trim(p_request->>'subject'), trim(p_request->>'description'), nullif(trim(coalesce(p_request->>'related_place','')), ''), nullif(p_request->>'proposed_date','')::date) returning * into v_row;
  return jsonb_build_object('id',v_row.id,'request_number',v_row.request_number,'request_status',v_row.request_status,'submitted_at',v_row.submitted_at);
end; $$;
revoke all on function public.submit_pas_request(jsonb) from public, anon;
grant execute on function public.submit_pas_request(jsonb) to authenticated;

create or replace function public.review_pas_request(p_request_id uuid, p_status text, p_response text default null) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_directiva() then raise exception 'Solo la Directiva puede resolver solicitudes.' using errcode = '42501'; end if;
  if p_status not in ('in_review','approved','rejected','needs_info') then raise exception 'Estado de solicitud no válido.'; end if;
  if p_response is not null and length(p_response) > 3000 then raise exception 'La respuesta no puede superar 3000 caracteres.'; end if;
  update public.institutional_requests set request_status = p_status, admin_response = nullif(trim(coalesce(p_response,'')),''), reviewed_at = now(), reviewed_by = auth.uid() where id = p_request_id;
  if not found then raise exception 'No se encontró la solicitud.'; end if;
end; $$;
revoke all on function public.review_pas_request(uuid,text,text) from public, anon;
grant execute on function public.review_pas_request(uuid,text,text) to authenticated;
commit;
