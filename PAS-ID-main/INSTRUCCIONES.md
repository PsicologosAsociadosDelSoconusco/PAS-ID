# PAS ID · Etapa 2

Esta versión añade las cuentas individuales de afiliados/colaboradores y su expediente digital privado.

## Orden de instalación

1. Realiza un respaldo de Supabase.
2. Ejecuta una sola vez `supabase/002_member_portal.sql` en Supabase SQL Editor. No vuelvas a ejecutar el esquema `001`.
3. Despliega la función `supabase/functions/manage-member-access` y configura su secreto `PAS_ID_SITE_URL` siguiendo `docs/ETAPA-2-INSTALACION.md`.
4. Sube el contenido del ZIP a la raíz de tu repositorio PAS-ID, conservando `config.js` y `assets/pas-logo.png`.
5. Inicia sesión como Directiva, registra un miembro de prueba e invítalo desde la ficha de gestión.

## Seguridad

No añadas nunca la clave `service_role` a `config.js`, HTML, JavaScript del navegador o GitHub. Esa clave se guarda únicamente en Secrets de Supabase.

La cuenta de prueba debe tener rol `afiliado` o `colaborador`, y su perfil debe abrir en el portal individual. La Directiva mantiene el panel administrativo.
