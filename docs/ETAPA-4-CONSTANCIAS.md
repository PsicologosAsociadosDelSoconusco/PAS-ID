# PAS ID · Etapa 4: Constancias

## Funciones incluidas
- Directiva puede emitir constancias vinculadas a un miembro y opcionalmente a un evento.
- Cada constancia recibe un folio único `PAS-C-...` generado en el navegador con `crypto.getRandomValues`.
- Los registros se guardan en `public.certificates`.
- Directiva consulta todas las constancias y puede revocar una constancia vigente.
- La persona afiliada consulta únicamente sus constancias gracias a la política RLS existente `certificates_read_self_or_directiva`.
- Impresión / guardado como PDF mediante el diálogo de impresión del navegador.

## Instalación
1. Reemplazar los archivos del repositorio con los incluidos en este paquete.
2. Conservar el `config.js` actual.
3. No ejecutar SQL: se reutiliza la tabla `certificates` y las políticas RLS ya existentes en `001_initial_schema.sql`.
4. Publicar GitHub Pages y recargar con Ctrl+F5.

## Importante: alcance de esta entrega
La constancia se registra en Supabase y puede imprimirse como PDF, pero el PDF no se almacena en Supabase Storage. La verificación pública independiente mediante QR / folio documental requiere una función RPC pública específica y se implementará en una siguiente revisión; no se debe confundir con el QR de credencial.

Antes de emitir documentos oficiales, probar con registros de prueba y confirmar los datos y el formato institucional.
