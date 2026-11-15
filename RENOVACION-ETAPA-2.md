# PAS ID · Renovación · Etapa 2

## Alcance implementado

Esta entrega amplía el módulo de solicitudes institucionales para convertirlo en un centro integral con conversación privada vinculada a cada folio.

### Para afiliados y colaboradores
- Formulario de solicitudes con categorías más amplias: membresía, credenciales, expediente, perfil/directorio, constancias, formación, eventos, colaboración y apoyo institucional.
- Listado de solicitudes propias con folio, estado, responsable y última actividad.
- Las solicitudes existentes de actualización de perfil y fotografía, incluidas las pendientes antes de esta entrega, se integran al mismo buzón; su aprobación aplica los cambios especializados al expediente. Cuando se envían datos y fotografía en un mismo formulario, quedan agrupados bajo un solo folio y se presentan con etiquetas legibles en el centro.
- Conversación privada dentro de PAS ID para responder al directivo responsable.
- Historial visible de asignación, transferencias, liberaciones y cambios de estado.
- Los mensajes nuevos aparecen en el panel de notificaciones y activan el punto amarillo.
- Las solicitudes cerradas como aprobadas o rechazadas permanecen consultables, pero no aceptan nuevos mensajes; se puede crear una nueva solicitud para continuar.

### Para Directiva
- Bandeja integral con búsqueda y filtros por estado y responsable.
- La primera persona de Directiva que pulse **Atender solicitud** queda asignada de forma atómica como responsable.
- Si otro directivo ya la tomó, el resto ve quién la atiende y no puede abrir ni responder en esa conversación.
- El responsable puede conversar con el solicitante, actualizar el estado, transferir el caso a otro directivo o devolverlo a la bandeja general.
- Las asignaciones, transferencias, liberaciones y cambios de estado quedan registrados en el historial.
- Los mensajes del solicitante y las respuestas del directivo alimentan el indicador de mensajes nuevos.

## Seguridad y datos
- La conversación solo puede ser leída por quien envió la solicitud y el directivo actualmente responsable.
- El resto de Directiva puede ver la ficha de la solicitud y el responsable asignado, pero no el contenido privado de la conversación hasta que sea responsable.
- Las operaciones sensibles se ejecutan mediante funciones SQL `SECURITY DEFINER` con validación de sesión y rol.
- La lectura se registra por participante mediante una tabla de lecturas independiente; al transferir el caso, el nuevo responsable recibe como no leídos los mensajes que todavía no ha consultado.
- No se exponen claves secretas en el frontend.
- No se modifican las tablas de miembros, credenciales ni identificadores históricos.

## Instalación

1. Realiza una copia de seguridad del repositorio y confirma que tienes respaldo de la base de datos.
2. En el repositorio de GitHub Pages, reemplaza los archivos de la raíz incluidos en este paquete: `index.html`, `app.js`, `pas-id-backend.js`, `styles.css` y `README.md`.
3. Conserva tu `config.js` actual. Este archivo se incluye solo como parte de la estructura del ZIP; no es necesario reemplazarlo si ya tiene la URL y la clave publicable correctas.
4. En Supabase SQL Editor, ejecuta **una sola vez** `supabase/009_integral_requests_messaging.sql`.
5. No ejecutes nuevamente las migraciones `001` a `008`. La etapa 2 solo requiere la migración nueva `009`; no requiere desplegar Edge Functions.
6. Publica GitHub Pages.

## Pruebas recomendadas antes de usar con integrantes reales

1. Con una cuenta de afiliado de prueba, crea una solicitud y conserva su folio.
2. Con una cuenta colaboradora, crea otra solicitud y comprueba que solo aparezca en su propio portal.
3. Con la primera cuenta de Directiva, toma una solicitud, abre la conversación y responde.
4. Con una segunda cuenta de Directiva, verifica que pueda ver quién tiene el caso, pero no pueda apropiárselo ni abrir la conversación mientras siga asignado al primer directivo.
5. Comprueba que el solicitante recibe el mensaje en Notificaciones y que el punto amarillo aparece hasta leerlo.
6. Responde desde el solicitante y comprueba que el directivo responsable recibe el indicador de mensaje nuevo.
7. Prueba transferencia a otra cuenta de Directiva y devolución a la bandeja general.
8. Cambia el estado a «Requiere información» y posteriormente a «Resuelta / aprobada»; comprueba que el historial conserva ambos movimientos.
9. Verifica que el solicitante no pueda consultar solicitudes de otras personas ni mensajes de otros casos.

## Límites conocidos de esta entrega

- La conversación es de texto; no se incorporó carga de archivos adjuntos en esta etapa.
- La actualización del indicador de mensajes nuevos ocurre al abrir/actualizar el panel y cuando la persona vuelve a la pestaña. No se configuró una suscripción realtime de Supabase en esta entrega.
- La comprobación realizada en este entorno es estática. No se ha ejecutado esta migración en tu proyecto Supabase ni se ha probado el flujo contra tus cuentas activas.
