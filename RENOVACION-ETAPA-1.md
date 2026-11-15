# PAS ID · Renovación etapa 1

## Entrega
- Nuevo dashboard de afiliados y colaboradores.
- Portal con navegación lateral por vistas (Inicio, Mi credencial, Mi expediente, Mi perfil, Directorio profesional, Mis solicitudes, Eventos y asistencia, Mis constancias, Notificaciones y Academia PAS); menú contraíble en escritorio y desplegable en móvil.
- Credencial digital de integrante con diseño de anverso y reverso, fotografía aprobada, folio, expedición, vigencia y QR de consulta pública.
- Vista de expediente independiente y dashboard de bienvenida con accesos rápidos y tarjeta de credencial de tamaño mediano.
- Acceso directo al directorio profesional desde el menú del portal y desde la pantalla inicial de acceso.
- Academia PAS visible como módulo futuro.
- Acceso directo al directorio desde el inicio de sesión, sin pasar antes por la consulta de credenciales.
- El punto de notificaciones permanece oculto hasta que existen avisos sin leer; se actualiza al entrar al portal y al consultar/leer avisos.
- El panel de Directiva obtiene también un menú lateral contraíble en escritorio.

## Conservación
- Se conservaron los identificadores y formularios existentes de perfil, eventos, constancias y solicitudes.
- `config.js` se mantuvo intacto.
- No se añadieron migraciones SQL ni se modificó ninguna migración existente.
- No se requiere ejecutar SQL ni desplegar Edge Functions para esta entrega visual.
- Los folios históricos 0000001, 0000002 y 0000003 no se alteran.

## Publicación
1. Haz una copia de seguridad del repositorio actual.
2. Sustituye `index.html`, `styles.css` y `app.js` por los de este paquete.
3. Conserva tu `config.js` actual si ya contiene la URL y clave publicable correctas del proyecto.
4. Publica GitHub Pages.
5. Prueba con cuentas reales de prueba de afiliado, colaborador y Directiva; verifica QR, foto aprobada, mapa del perfil, directorio, notificaciones y formularios.

## Pendiente para las siguientes etapas
- Rediseño visual completo del panel de Directiva (esta etapa solo incorpora el colapso de su menú).
- Centro integral de solicitudes con categorías ampliadas, asignación automática al primer directivo que tome el caso, mensajería privada por folio e historial.
- Notificaciones en tiempo real y lógica avanzada de seguimiento.
- Pruebas integrales con cuentas de afiliado, colaborador y Directiva.

La interfaz de credencial mantiene la verificación QR existente; no se modificó la lógica NFC. La entrega fue revisada estáticamente: `app.js` pasa `node --check`, el HTML no tiene IDs duplicados y no se detectaron errores de análisis CSS. No se pudo abrir una previsualización de navegador en este entorno y no se ha probado contra la instancia activa de Supabase ni contra GitHub Pages.
