-- PAS ID · Directorio profesional · Etapa 3: QR y valoraciones moderadas
-- Ejecutar UNA SOLA VEZ después de 014. No modifica folios ni expedientes históricos.
begin;

create table if not exists public.professional_review_invites (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.members(id) on delete cascade,
  token_hash text not null unique,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 days'),
  used_at timestamptz,
  revoked_at timestamptz
);
create index if not exists professional_review_invites_member_idx on public.professional_review_invites(member_id,created_at desc);

create table if not exists public.professional_reviews (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null unique references public.professional_review_invites(id),
  member_id uuid not null references public.members(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  comment text check (comment is null or length(comment) <= 600),
  moderation_status text not null default 'pending' check (moderation_status in ('pending','published','rejected','needs_revision')),
  moderation_note text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id)
);
create index if not exists professional_reviews_member_public_idx on public.professional_reviews(member_id,moderation_status,submitted_at desc);

alter table public.professional_review_invites enable row level security;
alter table public.professional_reviews enable row level security;
revoke all on public.professional_review_invites from public,anon,authenticated;
revoke all on public.professional_reviews from public,anon,authenticated;

-- Un QR activo por profesional. Devuelve el token una sola vez; solo se almacena su hash.
create or replace function public.create_my_professional_review_invite()
returns table(token text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare v_member uuid; v_token text;
begin
 select m.id into v_member from public.members m where m.auth_user_id=auth.uid() and m.membership_status='active' limit 1;
 if v_member is null then raise exception 'No se encontró un expediente PAS activo.' using errcode='42501'; end if;
 if not exists(select 1 from public.member_profiles p where p.member_id=v_member and p.public_directory_enabled=true) then
   raise exception 'Primero debes tener tu perfil profesional aprobado y visible en el directorio.' using errcode='22023';
 end if;
 update public.professional_review_invites set revoked_at=now() where member_id=v_member and used_at is null and revoked_at is null;
 v_token := pg_catalog.encode(extensions.gen_random_bytes(32),'hex');
 insert into public.professional_review_invites(member_id,token_hash,created_by)
 values(v_member,pg_catalog.encode(extensions.digest(v_token,'sha256'),'hex'),auth.uid());
 return query select v_token, now()+interval '30 days';
end; $$;
revoke all on function public.create_my_professional_review_invite() from public,anon;
grant execute on function public.create_my_professional_review_invite() to authenticated;

-- Envío público anónimo. Token de un solo uso; nunca recibe ni almacena identidad del paciente.
create or replace function public.submit_professional_review(p_token text,p_rating integer,p_comment text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_invite public.professional_review_invites%rowtype;
begin
 if p_token is null or length(p_token)<>64 or p_rating not between 1 and 5 then raise exception 'La invitación o la valoración no son válidas.' using errcode='22023'; end if;
 if p_comment is not null and length(p_comment)>600 then raise exception 'El comentario supera el máximo permitido.' using errcode='22023'; end if;
 select * into v_invite from public.professional_review_invites
 where token_hash=pg_catalog.encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or v_invite.used_at is not null or v_invite.revoked_at is not null or v_invite.expires_at<now() then
   raise exception 'Este QR ya fue utilizado, venció o fue desactivado. Solicita una nueva invitación al profesional.' using errcode='22023';
 end if;
 insert into public.professional_reviews(invite_id,member_id,rating,comment)
 values(v_invite.id,v_invite.member_id,p_rating,nullif(trim(p_comment),''));
 update public.professional_review_invites set used_at=now() where id=v_invite.id;
end; $$;
revoke all on function public.submit_professional_review(text,integer,text) from public;
grant execute on function public.submit_professional_review(text,integer,text) to anon,authenticated;

-- Bandeja de moderación solo para Directiva.
create or replace function public.list_professional_reviews_for_moderation()
returns table(review_id uuid,member_id uuid,professional_name text,rating smallint,comment text,moderation_status text,moderation_note text,submitted_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
 if not private.is_directiva() then raise exception 'Se requiere autorización de Directiva PAS.' using errcode='42501'; end if;
 return query select r.id,r.member_id,m.full_name,r.rating,r.comment,r.moderation_status,r.moderation_note,r.submitted_at
 from public.professional_reviews r join public.members m on m.id=r.member_id
 order by case when r.moderation_status='pending' then 0 else 1 end,r.submitted_at desc;
end; $$;
revoke all on function public.list_professional_reviews_for_moderation() from public,anon;
grant execute on function public.list_professional_reviews_for_moderation() to authenticated;

create or replace function public.moderate_professional_review(p_review_id uuid,p_decision text,p_note text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_review public.professional_reviews%rowtype;
begin
 if not private.is_directiva() then raise exception 'Se requiere autorización de Directiva PAS.' using errcode='42501'; end if;
 if p_decision not in ('published','rejected','needs_revision') then raise exception 'Decisión no válida.' using errcode='22023'; end if;
 if p_note is not null and length(p_note)>600 then raise exception 'La nota supera el máximo permitido.' using errcode='22023'; end if;
 select * into v_review from public.professional_reviews where id=p_review_id for update;
 if not found then raise exception 'Valoración no encontrada.' using errcode='P0002'; end if;
 if v_review.moderation_status<>'pending' and v_review.moderation_status<>'needs_revision' then raise exception 'Esta valoración ya fue resuelta.' using errcode='22023'; end if;
 update public.professional_reviews set moderation_status=p_decision,moderation_note=nullif(trim(p_note),''),reviewed_at=now(),reviewed_by=auth.uid() where id=p_review_id;
end; $$;
revoke all on function public.moderate_professional_review(uuid,text,text) from public,anon;
grant execute on function public.moderate_professional_review(uuid,text,text) to authenticated;

-- Resumen público: exclusivamente reseñas aprobadas. No expone comentarios ni datos del paciente.
create or replace function public.get_public_professional_rating(p_member_id uuid)
returns table(average_rating numeric,total_reviews bigint)
language sql stable security definer set search_path = '' as $$
 select round(avg(r.rating)::numeric,1),count(*)
 from public.professional_reviews r
 join public.members m on m.id=r.member_id and m.membership_status='active'
 join public.member_profiles p on p.member_id=m.id and p.public_directory_enabled=true
 where r.member_id=p_member_id and r.moderation_status='published';
$$;
revoke all on function public.get_public_professional_rating(uuid) from public;
grant execute on function public.get_public_professional_rating(uuid) to anon,authenticated;

commit;
