# PAS ID · Informe de auditoría estática

## Alcance
Revisión del código fuente y migraciones incluidos en este paquete. No implica acceso al proyecto Supabase remoto ni confirma el estado real de producción.

## Hallazgos
1. El ZIP recibido contenía una copia duplicada y desactualizada del proyecto en `PAS-ID-main/`. Esta distribución limpia conserva una sola raíz de proyecto.
2. Las migraciones 001–004 habilitan RLS en las tablas principales: `user_roles`, `members`, `member_private_data`, `credentials`, `events`, `event_attendance`, `certificates`, `audit_logs`, `member_profiles`, `member_profile_change_requests` e `institutional_requests`.
3. Las políticas de `members` observadas en el SQL limitan lectura a Directiva o al titular; INSERT/UPDATE/DELETE a Directiva. Esto coincide con las expresiones inspeccionadas en la consola por la persona administradora.
4. Las políticas de `credentials` permiten SELECT a Directiva o al titular vinculado y reservan INSERT/UPDATE/DELETE a Directiva.
5. Las solicitudes institucionales se leen por solicitante o Directiva y se actualizan por Directiva. El alta se realiza mediante `submit_pas_request(jsonb)`, una función `SECURITY DEFINER` que valida sesión, rol y longitudes.
6. La función pública `verify_pas_certificate(text)` de la migración 003 utilizaba `SECURITY DEFINER` con `search_path = public`. La migración 005 fija `search_path` vacío. La función ya referencia explícitamente las tablas `public`.
7. La Edge Function `manage-member-access` comprueba el usuario autenticado y exige que `current_pas_role()` devuelva `directiva` antes de invitar o vincular cuentas. Usa el secreto administrativo solo en el servidor.

## Límites y tareas pendientes
- No se inspeccionó el catálogo remoto de privilegios, triggers, políticas ni versiones efectivamente aplicadas en Supabase.
- No se ejecutaron pruebas negativas con tokens de afiliado/colaborador contra la API REST/RPC.
- No se puede confirmar desde el ZIP la configuración CORS, secretos, autenticación SMTP, backups ni protección del proyecto Supabase.
- La limpieza de cuentas y datos de prueba requiere operar sobre Auth y la base remota. No se elimina automáticamente en esta entrega para evitar borrar relaciones o evidencia de auditoría.
- Antes de producción, identificar por UUID las cuentas de prueba y revisar referencias; preservar los tres fundadores y los logs de auditoría.
