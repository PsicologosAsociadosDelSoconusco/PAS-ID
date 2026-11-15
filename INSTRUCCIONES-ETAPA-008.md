# Actualización PAS ID · Etapa 008

## Qué incorpora
- Solicitud de publicación voluntaria en directorio público con aprobación de Directiva.
- Datos de consultorio: dirección, coordenadas y modalidad de atención.
- Directorio público con búsqueda por nombre/especialidad y municipio.
- Campanita funcional en Directiva y portal de integrantes.
- Avisos generales o segmentados por categoría; lectura individual.
- La Academia PAS y el panel inteligente de afiliación quedan para la siguiente entrega.

## Instalación
1. Haz una copia local del repositorio actual.
2. Copia el contenido de esta carpeta al repositorio PAS-ID, reemplazando archivos existentes.
3. Ejecuta una sola vez `supabase/008_public_directory_notifications.sql` en Supabase SQL Editor.
4. Publica los cambios de GitHub Pages.
5. No vuelvas a ejecutar las migraciones 001–007 y no despliegues Edge Functions nuevas.

## Notas importantes
- La participación en el directorio se solicita desde Mi información; no se publica hasta que Directiva apruebe la solicitud.
- Solo aparecen perfiles activos y autorizados. El correo y teléfono no se exponen.
- La ubicación se captura con dirección y coordenadas; el enlace público abre el punto en Google Maps.
- Directiva publica avisos desde la campanita. El resto de usuarios puede leer y marcar como leídos los avisos que le correspondan.
- Antes de anunciar el directorio públicamente, Directiva debe revisar la autorización de cada perfil.
