# PAS ID · Revisión final y eliminación de cuenta

## Comportamiento de «Eliminar cuenta de acceso»
- Solo aparece en la ficha de un miembro con cuenta vinculada y dentro del panel de Directiva.
- Requiere confirmación explícita.
- La Edge Function valida la sesión y consulta `current_pas_role()`; no confía en el rol enviado por el navegador.
- Protege la cuenta que ejecuta la acción, cualquier cuenta con rol `directiva`, los registros de tipo `Directiva` y los registros históricos de fundadores.
- Desvincula `members.auth_user_id` y elimina el usuario mediante Supabase Auth Admin.
- Si Auth no permite eliminar la cuenta, intenta restaurar la vinculación.
- Conserva el expediente, perfil, credenciales, asistencias, solicitudes y constancias. La actualización del expediente queda en `audit_logs` por el trigger existente.

## Despliegue
1. Publica los archivos web actualizados en la raíz del repositorio de GitHub Pages.
2. Despliega de nuevo `supabase/functions/manage-member-access/index.ts` como `manage-member-access`.
3. No copies secretos al repositorio ni al navegador. La Edge Function utiliza las variables administradas por Supabase.
4. Prueba primero con una cuenta de afiliado/colaborador de prueba; no uses una cuenta de Directiva ni los registros fundadores.

## Revisión estática realizada
- Las tablas principales y las tablas de expediente/solicitudes tienen RLS habilitado en las migraciones incluidas.
- Las funciones administrativas SQL revisadas usan `SECURITY DEFINER`, `search_path` vacío y comprobaciones de rol Directiva.
- El cliente web usa la clave publicable; no se encontró una clave secreta literal en los archivos de configuración. Las referencias a `SUPABASE_SERVICE_ROLE_KEY` están solo en código de Edge Function/documentación y se leen del entorno del servidor.
- La verificación pública de credenciales devuelve campos limitados y la verificación de constancias usa la función endurecida de la migración 005.

Esta es una revisión estática del paquete, no una prueba de penetración ni una verificación en vivo de la configuración del proyecto Supabase. Deben completarse las pruebas de despliegue descritas arriba antes de dar por verificada la nueva opción.
