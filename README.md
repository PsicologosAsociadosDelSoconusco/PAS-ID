# PAS ID · Plataforma institucional

PAS ID es la plataforma de identidad y membresías de Psicólogos Asociados del Soconusco.

## Estructura

- `index.html`, `styles.css`, `app.js`: interfaz web.
- `pas-id-backend.js`: conexión con Supabase.
- `config.js`: URL y clave pública del proyecto (nunca secretos administrativos).
- `supabase/001_initial_schema.sql`: esquema de instalación original.
- `supabase/002_member_portal.sql`: migración incremental de expedientes y portal de afiliados.
- `supabase/004_institutional_requests.sql`: solicitudes institucionales para todos los roles autenticados.
- `supabase/functions/manage-member-access`: Edge Function para invitar/vincular cuentas de manera segura.
- `docs/ETAPA-2-INSTALACION.md`: guía de despliegue y pruebas.

## Roles

- `directiva`: panel administrativo institucional.
- `afiliado`: portal privado del expediente propio.
- `colaborador`: portal individual con rol diferenciado.

## Seguridad de cuentas

Las contraseñas se administran en Supabase Auth. Las cuentas quedan vinculadas a `members.auth_user_id`. Las políticas RLS y las funciones SQL limitan la lectura al expediente propio o al rol Directiva. Las solicitudes de cambio de datos se revisan por Directiva.

La clave `service_role` se usa solo como secreto dentro de Supabase Edge Functions; nunca se incorpora a este repositorio.

## Instalación

Sigue `docs/ETAPA-2-INSTALACION.md`. No vuelvas a ejecutar el esquema inicial si ya está instalado; aplica únicamente la migración 002.

## Etapa 3
La versión incorpora gestión de eventos y asistencia manual para Directiva. Consulta `docs/ETAPA-3-EVENTOS.md` antes de publicar.
