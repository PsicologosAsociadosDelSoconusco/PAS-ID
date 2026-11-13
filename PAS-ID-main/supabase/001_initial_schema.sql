-- PAS ID · Esquema inicial de producción
-- Ejecutar en Supabase SQL Editor después de crear el proyecto.
-- No contiene claves secretas. Todas las tablas expuestas aplican RLS.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;

-- -----------------------------------------------------------------------------
-- Roles institucionales
-- -----------------------------------------------------------------------------
create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('directiva', 'afiliado', 'colaborador')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  primary key (user_id, role)
);

create or replace function private.is_directiva()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = 'directiva'
  );
$$;

create or replace function public.current_pas_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select ur.role
  from public.user_roles ur
  where ur.user_id = (select auth.uid())
  order by case ur.role when 'directiva' then 1 when 'afiliado' then 2 else 3 end
  limit 1;
$$;

revoke all on function private.is_directiva() from public, anon;
revoke all on function public.current_pas_role() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_directiva() to authenticated;
grant execute on function public.current_pas_role() to authenticated;

-- -----------------------------------------------------------------------------
-- Miembros y credenciales
-- -----------------------------------------------------------------------------
create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  legacy_folio text unique,
  full_name text not null check (length(trim(full_name)) between 3 and 160),
  member_type text not null check (member_type in ('Miembro fundador', 'Afiliado', 'Colaborador', 'Directiva')),
  membership_status text not null default 'active' check (membership_status in ('active', 'suspended', 'inactive')),
  issued_on date not null default current_date,
  expires_on date,
  is_historical boolean not null default false,
  auth_user_id uuid unique references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint legacy_folio_format check (legacy_folio is null or legacy_folio ~ '^[0-9]{7}$')
);

-- Datos de contacto y notas internas se separan para que nunca aparezcan en el
-- directorio ni en la consulta pública, incluso al leer el perfil propio.
create table if not exists public.member_private_data (
  member_id uuid primary key references public.members(id) on delete cascade,
  contact_email text,
  phone text,
  admin_notes text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);

create table if not exists public.credentials (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete restrict,
  public_identifier text unique,
  credential_status text not null default 'active' check (credential_status in ('active', 'revoked', 'replaced')),
  issued_at timestamptz not null default now(),
  expires_on date,
  is_historical boolean not null default false,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  issued_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint credential_identifier_format check (public_identifier is null or public_identifier ~ '^PAS-[A-F0-9]{20}$'),
  constraint historical_identifier_rule check (not is_historical or public_identifier is null)
);

create index if not exists members_full_name_idx on public.members using btree (full_name);
create index if not exists credentials_member_id_idx on public.credentials (member_id);
create index if not exists credentials_status_idx on public.credentials (credential_status);

-- Los folios fundadores se conservan exactamente como aparecen en sus tarjetas.
-- Estos registros no reciben identificadores aleatorios nuevos.
insert into public.members
  (legacy_folio, full_name, member_type, membership_status, issued_on, expires_on, is_historical)
values
  ('0000001', 'Manuel Alejandro Perdomo López', 'Miembro fundador', 'active', date '2026-11-04', date '2027-11-04', true),
  ('0000002', 'Josefina Sánchez Félix', 'Miembro fundador', 'active', date '2026-11-04', date '2027-11-04', true),
  ('0000003', 'Verónica Meza Santizo', 'Miembro fundador', 'active', date '2026-11-04', date '2027-11-04', true)
on conflict (legacy_folio) do nothing;

insert into public.credentials (member_id, credential_status, issued_at, expires_on, is_historical)
select m.id, 'active', m.issued_on::timestamp at time zone 'UTC', m.expires_on, true
from public.members m
where m.legacy_folio in ('0000001', '0000002', '0000003')
  and not exists (
    select 1 from public.credentials c
    where c.member_id = m.id and c.is_historical = true
  );

-- -----------------------------------------------------------------------------
-- Módulos preparados para fases posteriores
-- -----------------------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  location text,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null
);

create table if not exists public.event_attendance (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  member_id uuid not null references public.members(id) on delete restrict,
  checked_in_at timestamptz not null default now(),
  checked_in_by uuid references auth.users(id) on delete set null,
  unique (event_id, member_id)
);

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete restrict,
  event_id uuid references public.events(id) on delete set null,
  certificate_number text not null unique,
  title text not null,
  issued_at timestamptz not null default now(),
  storage_path text,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id uuid,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  actor_id uuid references auth.users(id) on delete set null,
  occurred_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb
);

-- -----------------------------------------------------------------------------
-- Auditoría automática: guarda quién modificó un registro y sus valores.
-- No se almacenan identificadores secretos; solo el código público aleatorio.
-- -----------------------------------------------------------------------------
create or replace function private.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_id uuid;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_id := coalesce((v_new ->> 'id')::uuid, (v_new ->> 'user_id')::uuid, (v_new ->> 'member_id')::uuid);
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_id := coalesce((v_new ->> 'id')::uuid, (v_new ->> 'user_id')::uuid, (v_new ->> 'member_id')::uuid);
  else
    v_old := to_jsonb(old);
    v_id := coalesce((v_old ->> 'id')::uuid, (v_old ->> 'user_id')::uuid, (v_old ->> 'member_id')::uuid);
  end if;

  insert into public.audit_logs (table_name, record_id, action, actor_id, old_data, new_data)
  values (tg_table_name, v_id, tg_op, (select auth.uid()), v_old, v_new);

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.audit_row_change() from public, anon, authenticated;

drop trigger if exists audit_members_changes on public.members;
create trigger audit_members_changes after insert or update or delete on public.members
for each row execute function private.audit_row_change();
drop trigger if exists audit_credentials_changes on public.credentials;
create trigger audit_credentials_changes after insert or update or delete on public.credentials
for each row execute function private.audit_row_change();
drop trigger if exists audit_member_private_data_changes on public.member_private_data;
create trigger audit_member_private_data_changes after insert or update or delete on public.member_private_data
for each row execute function private.audit_row_change();
drop trigger if exists audit_user_roles_changes on public.user_roles;
create trigger audit_user_roles_changes after insert or update or delete on public.user_roles
for each row execute function private.audit_row_change();
drop trigger if exists audit_events_changes on public.events;
create trigger audit_events_changes after insert or update or delete on public.events
for each row execute function private.audit_row_change();
drop trigger if exists audit_attendance_changes on public.event_attendance;
create trigger audit_attendance_changes after insert or update or delete on public.event_attendance
for each row execute function private.audit_row_change();
drop trigger if exists audit_certificates_changes on public.certificates;
create trigger audit_certificates_changes after insert or update or delete on public.certificates
for each row execute function private.audit_row_change();

-- updated_at automático para miembros.
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
drop trigger if exists set_members_updated_at on public.members;
create trigger set_members_updated_at before update on public.members
for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Funciones transaccionales para acciones de directiva
-- -----------------------------------------------------------------------------
create or replace function public.register_pas_member(
  p_full_name text,
  p_member_type text,
  p_expires_on date
)
returns table (member_id uuid, public_identifier text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_id uuid;
  v_identifier text;
begin
  if not private.is_directiva() then
    raise exception 'No autorizado: se requiere un usuario de Directiva PAS.' using errcode = '42501';
  end if;
  if p_member_type not in ('Afiliado', 'Colaborador', 'Directiva') then
    raise exception 'Tipo de membresía no permitido.' using errcode = '22023';
  end if;
  if p_expires_on is null or p_expires_on < current_date then
    raise exception 'La vigencia debe ser una fecha actual o futura.' using errcode = '22023';
  end if;

  insert into public.members (full_name, member_type, membership_status, issued_on, expires_on, created_by)
  values (trim(p_full_name), p_member_type, 'active', current_date, p_expires_on, (select auth.uid()))
  returning id into v_member_id;

  -- 80 bits aleatorios. El identificador no es un permiso de acceso; solo permite
  -- consultar datos institucionales mínimos y se puede revocar desde la directiva.
  v_identifier := 'PAS-' || upper(pg_catalog.encode(extensions.gen_random_bytes(10), 'hex'));

  insert into public.credentials (member_id, public_identifier, credential_status, expires_on, issued_by)
  values (v_member_id, v_identifier, 'active', p_expires_on, (select auth.uid()));

  return query select v_member_id, v_identifier;
end;
$$;

create or replace function public.issue_pas_credential(
  p_member_id uuid,
  p_expires_on date
)
returns table (credential_id uuid, public_identifier text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_identifier text;
  v_credential_id uuid;
begin
  if not private.is_directiva() then
    raise exception 'No autorizado: se requiere un usuario de Directiva PAS.' using errcode = '42501';
  end if;
  if p_expires_on is null or p_expires_on < current_date then
    raise exception 'La vigencia debe ser una fecha actual o futura.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.members m where m.id = p_member_id) then
    raise exception 'Miembro no encontrado.' using errcode = 'P0002';
  end if;

  update public.credentials
  set credential_status = 'replaced'
  where member_id = p_member_id and credential_status = 'active';

  v_identifier := 'PAS-' || upper(pg_catalog.encode(extensions.gen_random_bytes(10), 'hex'));
  insert into public.credentials (member_id, public_identifier, credential_status, expires_on, issued_by)
  values (p_member_id, v_identifier, 'active', p_expires_on, (select auth.uid()))
  returning id into v_credential_id;

  -- Renueva la fecha, pero conserva el estado de afiliación (por ejemplo, suspendido).
  update public.members set expires_on = p_expires_on where id = p_member_id;

  return query select v_credential_id, v_identifier;
end;
$$;

create or replace function public.set_pas_member_status(
  p_member_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_directiva() then
    raise exception 'No autorizado.' using errcode = '42501';
  end if;
  if p_status not in ('active', 'suspended', 'inactive') then
    raise exception 'Estado no permitido.' using errcode = '22023';
  end if;
  update public.members set membership_status = p_status where id = p_member_id;
  if not found then raise exception 'Miembro no encontrado.' using errcode = 'P0002'; end if;
end;
$$;

create or replace function public.revoke_pas_credential(p_credential_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_directiva() then
    raise exception 'No autorizado.' using errcode = '42501';
  end if;
  update public.credentials
  set credential_status = 'revoked', revoked_at = now(), revoked_by = (select auth.uid())
  where id = p_credential_id and credential_status = 'active';
  if not found then raise exception 'No se encontró una credencial activa para revocar.' using errcode = 'P0002'; end if;
end;
$$;

-- Consulta pública: solo devuelve nombre, tipo, folio histórico y estado.
-- Nunca devuelve correo, teléfono, notas internas, usuario ni identificadores privados.
create or replace function public.verify_pas_credential(p_identifier text)
returns table (
  found boolean,
  full_name text,
  legacy_folio text,
  member_type text,
  verification_status text,
  issued_on date,
  expires_on date
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_member public.members%rowtype;
  v_credential public.credentials%rowtype;
  v_identifier text := upper(trim(coalesce(p_identifier, '')));
  v_status text;
begin
  if length(v_identifier) < 7 or length(v_identifier) > 64 then
    return query select false, null::text, null::text, null::text, 'not_found'::text, null::date, null::date;
    return;
  end if;

  select m.* into v_member
  from public.members m
  where m.legacy_folio = v_identifier
     or exists (
       select 1 from public.credentials c
       where c.member_id = m.id and c.public_identifier = v_identifier
     )
  limit 1;

  if not found then
    return query select false, null::text, null::text, null::text, 'not_found'::text, null::date, null::date;
    return;
  end if;

  select c.* into v_credential
  from public.credentials c
  where c.member_id = v_member.id
    and ((v_member.legacy_folio = v_identifier and c.is_historical = true)
      or c.public_identifier = v_identifier)
  order by c.issued_at desc
  limit 1;

  if v_credential.credential_status = 'revoked' then
    v_status := 'revoked';
  elsif v_credential.credential_status = 'replaced' then
    v_status := 'replaced';
  elsif v_member.membership_status = 'suspended' then
    v_status := 'suspended';
  elsif v_member.membership_status = 'inactive' then
    v_status := 'inactive';
  elsif coalesce(v_credential.expires_on, v_member.expires_on) < current_date then
    v_status := 'expired';
  else
    v_status := 'active';
  end if;

  return query select true, v_member.full_name, v_member.legacy_folio,
    v_member.member_type, v_status, coalesce(v_credential.issued_at::date, v_member.issued_on),
    coalesce(v_credential.expires_on, v_member.expires_on);
end;
$$;

revoke all on function public.register_pas_member(text, text, date) from public, anon;
revoke all on function public.set_pas_member_status(uuid, text) from public, anon;
revoke all on function public.issue_pas_credential(uuid, date) from public, anon;
revoke all on function public.revoke_pas_credential(uuid) from public, anon;
revoke all on function public.verify_pas_credential(text) from public;
grant execute on function public.register_pas_member(text, text, date) to authenticated;
grant execute on function public.set_pas_member_status(uuid, text) to authenticated;
grant execute on function public.issue_pas_credential(uuid, date) to authenticated;
grant execute on function public.revoke_pas_credential(uuid) to authenticated;
grant execute on function public.verify_pas_credential(text) to anon, authenticated;

-- -----------------------------------------------------------------------------
-- RLS y privilegios mínimos
-- -----------------------------------------------------------------------------
alter table public.user_roles enable row level security;
alter table public.members enable row level security;
alter table public.member_private_data enable row level security;
alter table public.credentials enable row level security;
alter table public.events enable row level security;
alter table public.event_attendance enable row level security;
alter table public.certificates enable row level security;
alter table public.audit_logs enable row level security;

revoke all on table public.user_roles, public.members, public.member_private_data, public.credentials,
  public.events, public.event_attendance, public.certificates, public.audit_logs
from anon, authenticated;

grant select on public.user_roles, public.members, public.credentials,
  public.events, public.event_attendance, public.certificates, public.audit_logs
 to authenticated;
grant select, insert, update, delete on public.member_private_data to authenticated;
grant insert, update, delete on public.events, public.event_attendance, public.certificates to authenticated;

-- Roles: un usuario puede consultar sus propios roles; la directiva administra los roles.
create policy "user_roles_read_self_or_directiva" on public.user_roles
for select to authenticated
using (user_id = (select auth.uid()) or (select private.is_directiva()));
create policy "user_roles_manage_directiva" on public.user_roles
for all to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));

-- Miembros: directiva ve y administra todo; cada afiliado ve únicamente su registro.
create policy "members_read_directiva_or_self" on public.members
for select to authenticated
using ((select private.is_directiva()) or auth_user_id = (select auth.uid()));
create policy "members_insert_directiva" on public.members
for insert to authenticated
with check ((select private.is_directiva()));
create policy "members_update_directiva" on public.members
for update to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));
create policy "members_delete_directiva" on public.members
for delete to authenticated
using ((select private.is_directiva()));

-- Credenciales: directiva consulta todas; el miembro ve las propias.
create policy "member_private_data_directiva_only" on public.member_private_data
for all to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));

create policy "credentials_read_directiva_or_self" on public.credentials
for select to authenticated
using (
  (select private.is_directiva())
  or exists (
    select 1 from public.members m
    where m.id = credentials.member_id and m.auth_user_id = (select auth.uid())
  )
);
create policy "credentials_insert_directiva" on public.credentials
for insert to authenticated
with check ((select private.is_directiva()));
create policy "credentials_update_directiva" on public.credentials
for update to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));
create policy "credentials_delete_directiva" on public.credentials
for delete to authenticated
using ((select private.is_directiva()));

-- Eventos: miembros autenticados ven eventos publicados; directiva gestiona todos.
create policy "events_read_published_or_directiva" on public.events
for select to authenticated
using (published = true or (select private.is_directiva()));
create policy "events_insert_directiva" on public.events
for insert to authenticated
with check ((select private.is_directiva()));
create policy "events_update_directiva" on public.events
for update to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));
create policy "events_delete_directiva" on public.events
for delete to authenticated
using ((select private.is_directiva()));

create policy "attendance_read_self_or_directiva" on public.event_attendance
for select to authenticated
using (
  (select private.is_directiva())
  or exists (select 1 from public.members m
    where m.id = event_attendance.member_id and m.auth_user_id = (select auth.uid()))
);
create policy "attendance_manage_directiva" on public.event_attendance
for all to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));

create policy "certificates_read_self_or_directiva" on public.certificates
for select to authenticated
using (
  (select private.is_directiva())
  or exists (select 1 from public.members m
    where m.id = certificates.member_id and m.auth_user_id = (select auth.uid()))
);
create policy "certificates_manage_directiva" on public.certificates
for all to authenticated
using ((select private.is_directiva()))
with check ((select private.is_directiva()));

create policy "audit_logs_read_directiva" on public.audit_logs
for select to authenticated
using ((select private.is_directiva()));

-- Nota: no se concede INSERT/UPDATE/DELETE directo de roles, miembros ni credenciales
-- al cliente; las operaciones sensibles se ejecutan mediante funciones autorizadas.
