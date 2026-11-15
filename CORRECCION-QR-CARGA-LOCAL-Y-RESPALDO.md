# Corrección del generador QR

Esta actualización corrige la ruta del bundle del generador QR: las versiones 1.5.2–1.5.4 del paquete `qrcode` no publicaron el directorio `build` esperado por la aplicación. Se fija la versión 1.5.1, que sí incluye ese bundle.

Además, el flujo de invitaciones ahora reutiliza `renderPasQr`, que intenta primero la biblioteca y después los proveedores alternativos ya contemplados por la plataforma. Si ambos fallan, informa el problema sin marcar el QR como generado.

No requiere migración SQL. Conserva las migraciones 015 y 016 ya aplicadas. Conserva tu `config.js` actual al publicar.
