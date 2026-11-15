-- PAS ID · Corrección puntual Etapa 3: funciones criptográficas calificadas
-- Ejecutar si la migración 015 YA fue aplicada y el botón QR muestra:
-- function gen_random_bytes(integer) does not exist
-- No crea tablas ni modifica valoraciones, invitaciones o folios existentes.
begin;

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

commit;
