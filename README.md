# PAS ID · Plataforma institucional

PAS ID es la plataforma de identidad, membresías y gestión institucional de Psicólogos Asociados del Soconusco.

## Componentes

- `index.html`, `styles.css`, `app.js`: interfaz web.
- `pas-id-backend.js`: acceso a Supabase mediante la clave pública del proyecto.
- `config.js`: URL del proyecto y clave publicable; nunca debe contener secretos administrativos.
- `supabase/001_initial_schema.sql`: esquema inicial.
- `supabase/002_member_portal.sql`: portal y expedientes privados.
- `supabase/003_certificate_public_verification.sql`: verificación pública de constancias.
- `supabase/004_institutional_requests.sql`: solicitudes institucionales para Directiva, afiliados y colaboradores.
- `supabase/005_security_hardening.sql`: endurece el `search_path` de la verificación pública de constancias.
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
3. Las migraciones se ejecutan una sola vez y en orden, únicamente si aún no están aplicadas en el proyecto: `001`, `002`, `003`, `004` y, cuando se autorice, `005`. No vuelvas a ejecutar el esquema inicial sobre una base con datos.
4. Despliega `manage-member-access` y conserva `SUPABASE_SERVICE_ROLE_KEY` exclusivamente como secreto del entorno Edge.
5. Verifica las políticas RLS y los flujos de acceso antes de incorporar nuevos usuarios.

## Datos institucionales

La interfaz no mantiene un directorio alternativo en el navegador. Los datos operativos se consultan y modifican en Supabase. Los folios históricos de fundadores deben conservarse; las altas nuevas utilizan identificadores generados por el servidor.
