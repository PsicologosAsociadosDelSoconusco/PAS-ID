-- PAS ID · Endurecimiento de la verificación pública de constancias
-- Aplicar una sola vez después de las migraciones 001–004.
-- No modifica datos ni altera las políticas RLS existentes.

begin;

-- La función utiliza referencias totalmente calificadas a las tablas public.
-- Un search_path vacío evita resolución de objetos inyectados en SECURITY DEFINER.
alter function public.verify_pas_certificate(text) set search_path = '';

-- Reafirma el acceso explícito: solo el endpoint público de verificación
-- y usuarios autenticados pueden ejecutar esta función.
revoke all on function public.verify_pas_certificate(text) from public;
grant execute on function public.verify_pas_certificate(text) to anon, authenticated;

commit;
