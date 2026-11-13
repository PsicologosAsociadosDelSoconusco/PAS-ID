# Parche QR en impresión de constancias

Esta actualización integra en la plantilla horizontal de impresión el mismo generador QR resiliente usado en las credenciales. No modifica `config.js`, el backend de autenticación, tablas ni registros.

## Instalación
1. Sustituye únicamente `app.js` en la raíz del repositorio por el incluido en este ZIP.
2. Conserva todos los demás archivos.
3. Publica el cambio en GitHub Pages y recarga con Ctrl+F5.
4. Abre una constancia emitida y vuelve a imprimirla.

El QR codifica la URL actual de PAS ID con el parámetro `verificar-constancia` y el folio documental. La vista pública que consulta ese parámetro debe estar habilitada para que el escaneo muestre los datos del documento; este parche resuelve su inclusión en la impresión, no añade ni modifica la función SQL 003.
