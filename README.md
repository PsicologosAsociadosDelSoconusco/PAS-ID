# PAS ID · Plataforma institucional

PAS ID es la plataforma de identidad, membresías y gestión institucional de Psicólogos Asociados del Soconusco.

## Componentes

- `index.html`, `styles.css`, `app.js`: interfaz web.
- `pas-id-backend.js`: acceso a Supabase mediante la clave pública del proyecto.
- `config.js`: URL del proyecto y clave publicable; nunca debe contener secretos administrativos.
- `supabase/001_initial_schema.sql`: esquema inicial.
- `supabase/002_member_portal.sql`: portal y expedientes privados.
- `supabase/003_certificate_public_verification.sql`: verificación pública de constancias.
- `supabase/004_institutional_requests.sql`: base original de solicitudes institucionales.
- `supabase/009_integral_requests_messaging.sql`: responsable por primera atención, transferencias, historial y mensajería privada por folio.
- `supabase/functions/manage-member-access/`: función segura para invitación y vinculación de cuentas.

## Roles

- `directiva`: administración institucional, directorio y revisión de solicitudes.
- `afiliado`: portal y expediente propio, credencial, constancias y solicitudes.
- `colaborador`: portal individual y solicitudes institucionales.

## Seguridad

La autenticación se gestiona mediante Supabase Auth. Las contraseñas no se almacenan en el repositorio. Las consultas de datos privados están protegidas mediante Row Level Security (RLS) y funciones SQL con permisos restringidos. La clave `service_role` solo debe existir en los secretos de Supabase Edge Functions; nunca debe publicarse en HTML, JavaScript, `config.js` ni GitHub.

## Despliegue

1. Mantén `config.js` con la URL y la clave publicable del proyecto correcto.
2. Publica los archivos de la raíz en GitHub Pages.
3. Las migraciones `001` a `008` forman parte del historial previo de la plataforma y no deben repetirse si ya fueron aplicadas. Para la renovación de solicitudes de la etapa 2, ejecuta una sola vez `supabase/009_integral_requests_messaging.sql`.
4. Despliega `manage-member-access` y conserva `SUPABASE_SERVICE_ROLE_KEY` exclusivamente como secreto del entorno Edge.
5. Verifica las políticas RLS y los flujos de acceso antes de incorporar nuevos usuarios.

## Datos institucionales

La interfaz no mantiene un directorio alternativo en el navegador. Los datos operativos se consultan y modifican en Supabase. Los folios históricos de fundadores deben conservarse; las altas nuevas utilizan identificadores generados por el servidor.

## Eliminar una cuenta de acceso
Desde el Directorio de miembros, Directiva puede abrir la ficha de un afiliado o colaborador con cuenta vinculada y elegir **Eliminar cuenta de acceso**. La operación solicita confirmación y se ejecuta en la Edge Function `manage-member-access`, que valida la sesión y el rol `directiva` en el servidor. No elimina el expediente, las credenciales, asistencias ni constancias. Las cuentas de Directiva, la cuenta del usuario que ejecuta la acción y los registros históricos de fundadores están protegidos.

Después de actualizar `supabase/functions/manage-member-access/index.ts`, vuelve a desplegar la función `manage-member-access` desde Supabase (o mediante Supabase CLI). No se requiere una migración SQL adicional para esta opción.
La presentación profesional admite hasta **1,200 caracteres** tanto en el portal del miembro como en la edición administrativa.


## Renovación · Etapa 1

Consulta `RENOVACION-ETAPA-1.md` para los cambios del portal de integrantes, la credencial digital y la navegación. Esta etapa no agrega migraciones SQL.

## Renovación · Etapa 2

Consulta `RENOVACION-ETAPA-2.md` para el centro integral de solicitudes, la asignación al primer directivo que atienda y la mensajería privada por folio. Esta etapa incorpora la migración SQL nueva `009`; no vuelvas a ejecutar las migraciones anteriores.


## Renovación PAS ID · Etapa 3
Consulta `RENOVACION-ETAPA-3.md`. Incluye el repositorio documental privado de integrantes, módulo de gestión de documentación para Directiva y corrección de renderizado del QR en el portal individual.

## Renovación PAS ID · Etapa 4
Consulta `RENOVACION-ETAPA-4.md`. Añade notificaciones dirigidas cuando Directiva solicita un documento, cuando el integrante entrega el archivo y cuando Directiva aprueba o pide correcciones. También hace más explícito el estado de cada entrega en «Mi expediente». Requiere ejecutar una sola vez `supabase/011_member_document_notifications.sql` después de que la migración 010 esté aplicada.

## Renovación etapas 5 a 8

Consulta `RENOVACION-ETAPAS-5-A-8.md` para los cambios y `docs/PRUEBAS-SEGURIDAD-ETAPAS-5-A-8.md` para la lista de aceptación. Esta entrega no agrega migraciones SQL.

## Renovación · Etapa 9: documentos múltiples

Consulta `RENOVACION-ETAPA-9-DOCUMENTOS-MULTIPLES.md`. Permite hasta 10 archivos por requerimiento documental, con revisión individual por Directiva. Requiere ejecutar una sola vez `supabase/012_multiple_member_document_files.sql` después de confirmar que 010 y 011 ya están aplicadas.
