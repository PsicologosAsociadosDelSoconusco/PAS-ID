# PAS ID · Perfil profesional en verificación pública

Esta mejora amplía la consulta pública de credenciales para mostrar, cuando estén capturados en el expediente:

- Área / especialidad.
- Cédula profesional (pública por defecto, según decisión de PAS).
- Municipio y estado.
- Presentación profesional.

El correo de contacto y el teléfono permanecen privados y no son devueltos por la función pública.

## Instalación

1. Actualizar los archivos del proyecto en GitHub con esta versión.
2. En Supabase → SQL Editor, ejecutar una sola vez `supabase/006_public_professional_profile.sql`.
3. No requiere cambiar Edge Functions ni secretos.
4. La verificación seguirá utilizando los QR y folios existentes.

Los datos se toman de `public.member_profiles`. Los perfiles sin información capturada simplemente no mostrarán esos apartados. Los fundadores conservan sus folios históricos.
La presentación profesional admite hasta **1,200 caracteres** tanto en el portal del miembro como en la edición administrativa.
