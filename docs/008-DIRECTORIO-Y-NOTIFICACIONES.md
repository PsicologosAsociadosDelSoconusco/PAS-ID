# PAS ID · Etapa 008: directorio público, consultorio y notificaciones

Esta migración agrega los campos de ubicación/modalidad del consultorio, consentimiento para aparecer en el directorio público y el centro de notificaciones.

## Instalación
1. Publicar los archivos del proyecto en GitHub.
2. Ejecutar **una sola vez** `supabase/008_public_directory_notifications.sql` en Supabase SQL Editor.
3. No volver a ejecutar las migraciones 001–007.
4. No requiere Edge Function ni secretos nuevos.

## Privacidad
- Los perfiles solo aparecen en el directorio si el integrante solicita aparecer y Directiva aprueba la solicitud.
- Solo se muestran perfiles de miembros con estado institucional activo.
- El directorio público no expone correo ni teléfono.
- Las notificaciones se consultan con sesión y cada usuario solo ve avisos generales o dirigidos a su rol.
- Directiva es la única que puede publicar notificaciones.

## Ubicación
La ficha permite capturar dirección, municipio/estado, modalidad y coordenadas de ubicación. La dirección y coordenadas solo se publican cuando el perfil ha sido autorizado para el directorio.
