# PAS ID · Impresión masiva de credenciales

## Acceso
El módulo está dentro de **Credenciales → Impresión masiva de credenciales** y se habilita en la aplicación administrativa de Directiva. El flujo también comprueba que el rol activo sea `directiva` antes de abrir la ventana de impresión.

## Selección
- Permite seleccionar uno o varios miembros del directorio.
- Incluye fundadores, afiliados y colaboradores siempre que su credencial esté activa.
- Los registros suspendidos, revocados, vencidos, sustituidos o inactivos no se ofrecen para impresión.
- Permite buscar por nombre o folio y seleccionar todos los resultados visibles.

## PDF
- Papel: carta, orientación vertical.
- Cada cara: CR80 vertical, 53.98 × 85.60 mm.
- Cada credencial aparece como una pareja horizontal: anverso a la izquierda y reverso a la derecha.
- Acomodo: hasta tres parejas por hoja, centradas y con separación para corte.
- El QR del reverso abre la misma URL pública de verificación asociada al folio.
- Si el expediente tiene fotografía de perfil guardada, se usa en el anverso; si no, aparece un monograma de iniciales.

## Cómo guardar el PDF
1. Selecciona los miembros y pulsa **Generar PDF de impresión**.
2. En el diálogo del navegador, selecciona **Guardar como PDF**.
3. Papel: Carta. Escala: 100 %. Desactiva encabezados y pies de página. Activa gráficos de fondo si el navegador lo solicita.
4. Imprime a doble cara solo si tu flujo de impresión lo requiere; en este diseño, las dos caras de cada credencial ya están juntas en la misma hoja, una al lado de la otra.

## Importante
El módulo no cambia folios, vigencias, estados ni registros de credenciales. Solo prepara un documento de impresión a partir de los miembros activos del directorio. La carga de fotografías depende de que la URL pública del almacenamiento de fotos esté accesible para el navegador.


## Ajustes visuales de impresión
- Se redujeron el logotipo y la fotografía para equilibrar el frente.
- Se reorganizó el frente para dejar espacio visible a expedición y vigencia.
- Se ajustó el reverso para evitar que los términos y condiciones queden tapados.
- El QR conserva la ruta de verificación existente (`buildVerificationUrl`) y la biblioteca QR ya utilizada por PAS ID; no se incorpora otro sistema.
- Las fechas se leen de los campos `issued` y `expires` del registro. La impresión no modifica fechas ni vigencias.
