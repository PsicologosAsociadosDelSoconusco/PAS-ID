-- PAS ID · Avisos automáticos del expediente documental.
-- Requiere que 010_member_document_repository.sql ya esté aplicada.
-- Notifica al integrante cuando recibe un requerimiento y a Directiva cuando
-- recibe una entrega; también avisa al integrante de aprobaciones/correcciones.
begin;

create table if not exists public.pas_member_document_notifications (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.member_document_requests(id) on delete cascade,
  recipient_user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in ('requested','submitted','approved','changes_requested')),
  title text not null check (char_length(trim(title)) between 1 and 140),
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index if not exists pas_member_document_notifications_recipient_idx
  on public.pas_member_document_notifications(recipient_user_id, created_at desc);
create index if not exists pas_member_document_notifications_request_idx
  on public.pas_member_document_notifications(request_id, created_at desc);

alter table public.pas_member_document_notifications enable row level security;
revoke all on public.pas_member_document_notifications from public, anon, authenticated;
grant select on public.pas_member_document_notifications to authenticated;
drop policy if exists pas_member_document_notifications_read_own on public.pas_member_document_notifications;
create policy pas_member_document_notifications_read_own
  on public.pas_member_document_notifications
  for select to authenticated
  using (recipient_user_id = (select auth.uid()));

create or replace function public.notify_pas_member_document_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_member_name text;
  v_member_user_id uuid;
begin
  if tg_op = 'INSERT' then
    select m.full_name, m.auth_user_id
      into v_member_name, v_member_user_id
      from public.members m
      where m.id = new.member_id;

    if v_member_user_id is not null then
      insert into public.pas_member_document_notifications
        (request_id, recipient_user_id, event_type, title, body)
      values
        (new.id, v_member_user_id, 'requested', 'Nuevo documento solicitado',
         'La asociación te solicitó: «' || new.title || '». Entra a Mi expediente para consultar las instrucciones y entregarlo.');
    end if;
    return new;
  end if;

  if old.status is distinct from new.status then
    if new.status = 'submitted' then
      select m.full_name into v_member_name
        from public.members m where m.id = new.member_id;

      insert into public.pas_member_document_notifications
        (request_id, recipient_user_id, event_type, title, body)
      select new.id, ur.user_id, 'submitted', 'Nuevo documento recibido',
             coalesce(v_member_name, 'Un integrante PAS') || ' entregó «' || new.title || '». Ya puedes revisar el archivo en Gestión de documentación.'
      from public.user_roles ur
      where ur.role = 'directiva';

    elsif new.status in ('approved', 'changes_requested') then
      select m.auth_user_id into v_member_user_id
        from public.members m where m.id = new.member_id;

      if v_member_user_id is not null then
        insert into public.pas_member_document_notifications
          (request_id, recipient_user_id, event_type, title, body)
        values (
          new.id,
          v_member_user_id,
          new.status,
          case when new.status = 'approved' then 'Documento aprobado' else 'Se requieren correcciones' end,
          case when new.status = 'approved'
            then 'Directiva aprobó el documento «' || new.title || '».'
            else 'Directiva solicitó correcciones para «' || new.title || '». Consulta las observaciones en Mi expediente y reemplaza el archivo.'
          end
        );
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.notify_pas_member_document_event() from public, anon, authenticated;
drop trigger if exists pas_member_document_event_notification on public.member_document_requests;
create trigger pas_member_document_event_notification
after insert or update on public.member_document_requests
for each row execute function public.notify_pas_member_document_event();

-- Retroaviso para los requerimientos que ya existían antes de instalar esta migración.
-- La tabla es nueva, por lo que este bloque no duplica avisos previos.
insert into public.pas_member_document_notifications
  (request_id, recipient_user_id, event_type, title, body)
select r.id, m.auth_user_id, 'requested', 'Nuevo documento solicitado',
       'La asociación te solicitó: «' || r.title || '». Entra a Mi expediente para consultar las instrucciones y entregarlo.'
from public.member_document_requests r
join public.members m on m.id = r.member_id
where m.auth_user_id is not null
  and r.status = 'pending'
  and not exists (
    select 1 from public.pas_member_document_notifications n
    where n.request_id = r.id and n.recipient_user_id = m.auth_user_id and n.event_type = 'requested'
  );

insert into public.pas_member_document_notifications
  (request_id, recipient_user_id, event_type, title, body)
select r.id, ur.user_id, 'submitted', 'Nuevo documento recibido',
       coalesce(m.full_name, 'Un integrante PAS') || ' entregó «' || r.title || '». Ya puedes revisar el archivo en Gestión de documentación.'
from public.member_document_requests r
join public.members m on m.id = r.member_id
cross join public.user_roles ur
where r.status = 'submitted'
  and ur.role = 'directiva'
  and not exists (
    select 1 from public.pas_member_document_notifications n
    where n.request_id = r.id and n.recipient_user_id = ur.user_id and n.event_type = 'submitted'
  );

insert into public.pas_member_document_notifications
  (request_id, recipient_user_id, event_type, title, body)
select r.id, m.auth_user_id, r.status,
       case when r.status = 'approved' then 'Documento aprobado' else 'Se requieren correcciones' end,
       case when r.status = 'approved'
         then 'Directiva aprobó el documento «' || r.title || '».'
         else 'Directiva solicitó correcciones para «' || r.title || '». Consulta las observaciones en Mi expediente y reemplaza el archivo.'
       end
from public.member_document_requests r
join public.members m on m.id = r.member_id
where m.auth_user_id is not null
  and r.status in ('approved', 'changes_requested')
  and not exists (
    select 1 from public.pas_member_document_notifications n
    where n.request_id = r.id and n.recipient_user_id = m.auth_user_id and n.event_type = r.status
  );

create or replace function public.list_my_pas_member_document_notifications()
returns table(
  id uuid,
  request_id uuid,
  event_type text,
  title text,
  body text,
  created_at timestamptz,
  read_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesión.' using errcode = '42501';
  end if;

  return query
  select n.id, n.request_id, n.event_type, n.title, n.body, n.created_at, n.read_at
  from public.pas_member_document_notifications n
  where n.recipient_user_id = (select auth.uid())
  order by n.created_at desc
  limit 100;
end;
$$;

create or replace function public.mark_pas_member_document_notification_read(p_notification_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesión.' using errcode = '42501';
  end if;

  update public.pas_member_document_notifications
  set read_at = coalesce(read_at, now())
  where id = p_notification_id
    and recipient_user_id = (select auth.uid());
  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'Notificación no disponible.' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.list_my_pas_member_document_notifications() from public, anon;
revoke all on function public.mark_pas_member_document_notification_read(uuid) from public, anon;
grant execute on function public.list_my_pas_member_document_notifications() to authenticated;
grant execute on function public.mark_pas_member_document_notification_read(uuid) to authenticated;

commit;
