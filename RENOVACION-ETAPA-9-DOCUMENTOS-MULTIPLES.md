# PAS ID · Etapa 9: entregas documentales múltiples

Esta actualización permite que un mismo requerimiento documental reciba entre 1 y 10 archivos, con un máximo de 10 MB por archivo. Tipos admitidos: PDF, JPG, PNG y WEBP.

## Cambios
- Selector múltiple de archivos en «Mi expediente».
- Validación individual de tipo y tamaño antes de subir.
- Almacenamiento privado con rutas únicas por archivo.
- Registro de cada archivo en `member_document_files`, vinculado al requerimiento y al integrante.
- Directiva puede abrir y aprobar cada archivo por separado o solicitar corrección con observaciones específicas.
- El estado general del requerimiento permanece «Entregado · en revisión» mientras haya archivos por revisar; queda «Aprobado» cuando todos están aprobados o «Requiere corrección» cuando ya no quedan archivos en revisión y al menos uno necesita corrección.
- Al volver a entregar archivos después de una corrección, las versiones anteriores marcadas para corrección se conservan como `superseded` en el historial.
- Los requerimientos y archivos previos se conservan; las columnas antiguas siguen presentes para compatibilidad.

## Instalación
1. Haz respaldo del repositorio y de Supabase.
2. Confirma que las migraciones 010 y 011 ya estén aplicadas.
3. Ejecuta una sola vez `supabase/012_multiple_member_document_files.sql`.
4. Sustituye los archivos del proyecto por los del ZIP y conserva tu `config.js` vigente.
5. Publica en GitHub Pages.

No vuelvas a ejecutar las migraciones 001–011.

## Prueba de aceptación
1. Desde Directiva, crea un requerimiento para una cuenta de prueba.
2. Desde el afiliado, selecciona dos o más archivos y envíalos en una sola entrega.
3. Comprueba que aparece un solo requerimiento y que cada archivo se lista por separado.
4. Desde Directiva, abre cada archivo y aprueba uno; solicita corrección en otro con observación.
5. Comprueba que el integrante ve el resultado por archivo y el estado general «Requiere corrección».
6. El integrante vuelve a enviar el/los archivo(s) corregidos; Directiva revisa y aprueba.
7. Comprueba que el requerimiento termina aprobado y que las versiones anteriores permanecen en el historial.

La comprobación estática del paquete no sustituye la prueba real de RLS, Storage y RPC en el proyecto Supabase.
