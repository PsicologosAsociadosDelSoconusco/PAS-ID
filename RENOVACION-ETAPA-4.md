# PAS ID · Renovación, etapa 4: avisos documentales y estado de entregas

## Qué corrige
- Cuando Directiva crea un requerimiento documental, el integrante destinatario recibe una notificación dentro de PAS ID.
- Si el requerimiento ya existía antes de instalar esta etapa, se genera un aviso inicial para que el integrante no tenga que esperar una nueva solicitud.
- Cuando afiliado o colaborador entrega un archivo, todas las cuentas de Directiva reciben una notificación para revisar el documento.
- Cuando Directiva aprueba el archivo o solicita correcciones, el integrante recibe una notificación.
- Los avisos tienen lectura individual y se incluyen en el punto amarillo del centro de notificaciones.
- El indicador se actualiza al iniciar sesión, al volver a la pestaña y cada 45 segundos mientras la plataforma está visible.
- «Mi expediente» muestra claramente el estado, la fecha de entrega, el nombre del archivo, el tamaño, las observaciones de Directiva y el acceso para abrir el archivo entregado.
- Al seleccionar un archivo antes de enviarlo, el portal muestra su nombre. Después de una entrega correcta, el estado cambia a «Entregado · en revisión» y aparece la confirmación «Documento recibido por PAS».
- El portal de Directiva muestra la fecha y archivo recibidos en la bandeja de Gestión de documentación.

## Instalación
1. Realiza respaldo del repositorio y de Supabase.
2. Sustituye los archivos incluidos en este ZIP, conservando tu `config.js` actual.
3. Confirma en el historial de Supabase que `010_member_document_repository.sql` ya está aplicada. Esta etapa depende de las tablas y funciones de la migración 010.
4. Ejecuta `supabase/011_member_document_notifications.sql` una sola vez.
5. No repitas las migraciones 001–010 que ya estén aplicadas.
6. Publica GitHub Pages.

## Pruebas recomendadas
1. Con una cuenta de Directiva, crea un requerimiento documental para una cuenta de prueba de afiliado o colaborador.
2. En el portal del integrante, comprueba el punto amarillo y abre Notificaciones. Debe aparecer «Nuevo documento solicitado» y el botón «Ver en Mi expediente».
3. Abre Mi expediente. Debe aparecer el requerimiento y sus instrucciones.
4. Selecciona un PDF/JPG/PNG/WEBP menor de 10 MB. Antes de enviarlo, debe verse el nombre seleccionado.
5. Envía el documento. Mi expediente debe indicar «Entregado · en revisión», mostrar fecha y nombre del archivo, y permitir abrirlo.
6. En una cuenta de Directiva, comprueba el aviso «Nuevo documento recibido», abre Gestión de documentación y revisa el archivo.
7. Aprueba el documento o solicita correcciones. El integrante debe recibir una notificación con la decisión y, en caso de corrección, las observaciones.
8. Comprueba que una segunda cuenta de afiliado no vea los archivos ni las notificaciones de la primera.

## Seguridad y conservación
- La migración 011 crea únicamente notificaciones de destinatario y sus funciones/políticas de lectura.
- No vuelve a crear el bucket ni cambia permisos del almacenamiento documental de la migración 010.
- El destinatario solo puede listar y marcar como leídas sus propias notificaciones mediante funciones protegidas.
- Los archivos siguen en el bucket privado creado por 010 y conservan sus permisos existentes.
- No se modifica `config.js`, las claves, los miembros, credenciales, ni los folios históricos.
- La entrega debe verificarse en Supabase con cuentas de prueba; no se ejecutó esta migración en el proyecto real del usuario.
