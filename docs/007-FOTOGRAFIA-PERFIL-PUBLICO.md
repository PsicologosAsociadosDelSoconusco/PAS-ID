# PAS ID · Fotografía profesional en el perfil público

## Qué incorpora
- Carga de fotografía JPG, PNG o WEBP de hasta 3 MB desde «Mi información».
- Casilla de autorización explícita para publicación.
- La fotografía se guarda en Supabase Storage y se envía como solicitud pendiente; no aparece en la verificación hasta que Directiva la aprueba.
- Directiva ve una vista previa de la fotografía propuesta al revisar la solicitud.
- La aprobación actualiza el perfil público asociado al mismo QR/folio.
- Cada miembro solo puede cargar, consultar, sustituir o borrar archivos dentro de su propia carpeta.

## Instalación
1. Publicar los archivos del proyecto en GitHub.
2. Si aún no se ha ejecutado `supabase/006_public_professional_profile.sql`, ejecutarlo primero.
3. Ejecutar `supabase/007_profile_photos.sql` una sola vez en Supabase SQL Editor. Esta migración amplía la función pública para incluir la fotografía.
4. No requiere desplegar Edge Functions ni modificar Secrets.

La fotografía es opcional. La publicación requiere autorización expresa y aprobación de Directiva. Correo y teléfono permanecen privados.
