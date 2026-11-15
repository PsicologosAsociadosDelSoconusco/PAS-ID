# PAS ID · Etapa 3: valoraciones profesionales mediante QR

Esta entrega integra la interfaz frontend con la capa de base de datos de valoraciones QR, sobre la versión que incluye las migraciones 013 y 014.

## Funcionalidades incluidas

### Portal del integrante
- Botón para generar una invitación QR de valoración.
- El QR se muestra en pantalla y puede descargarse, imprimirse o compartirse mediante enlace.
- Cada invitación es de un solo uso y vence a los 30 días.
- Supabase almacena el hash del token, no el token original.
- La generación está limitada al integrante activo con perfil público habilitado.

### Formulario público
- El paciente abre el enlace del QR sin iniciar sesión.
- Puede elegir de 1 a 5 estrellas y agregar un comentario opcional de hasta 600 caracteres.
- No se solicitan nombre, correo ni teléfono.
- Al enviar, la invitación queda consumida y no puede reutilizarse.
- Se muestra una confirmación de recepción; la reseña todavía no es pública.

### Directiva
- Bandeja de valoraciones en el panel administrativo.
- Decisiones disponibles: validar y publicar, solicitar revisión o rechazar.
- Antes de publicar, Directiva debe confirmar que corresponde a una atención real y revisar que el texto no incluya datos identificables o información clínica.

### Directorio público
- Las tarjetas y fichas consultan el promedio y total de valoraciones aprobadas.
- Únicamente las reseñas con estado `published` participan en el promedio.
- No se exponen comentarios ni datos del paciente en el directorio.

## Instalación
1. Haz respaldo de la versión actualmente publicada.
2. En Supabase SQL Editor ejecuta únicamente `supabase/015_professional_reviews_qr.sql`, una sola vez y después de 014. No vuelvas a ejecutar 001–014.
3. Publica el contenido del ZIP en GitHub Pages conservando `config.js` con la URL y publishable key actuales del proyecto.
4. No agregues claves `service_role` ni secret keys al frontend.
5. Valida primero con cuentas de prueba, nunca con pacientes reales durante la primera prueba.

## Pruebas recomendadas
1. Con una cuenta de integrante activo y perfil público aprobado, genera un QR.
2. Escanéalo desde una ventana privada o un segundo dispositivo sin iniciar sesión.
3. Envía una valoración de prueba y confirma que el enlace no admite un segundo envío.
4. Entra con Directiva y comprueba que la reseña aparece pendiente.
5. Solicita revisión o rechaza una reseña de prueba y verifica que no cambie el promedio.
6. Publica otra reseña solo después de validar manualmente la atención de prueba; comprueba que el promedio y el conteo cambian en la ficha pública.
7. Comprueba que una invitación vencida, revocada o utilizada no se puede volver a enviar.
8. Comprueba permisos RLS/RPC con roles afiliado, colaborador, fundador, Directiva y sesión anónima.

## Límites y seguridad
- Un QR por sí solo no acredita que ocurrió una sesión. La validación de la atención es responsabilidad de Directiva.
- El profesional no puede editar estrellas ni aprobar sus propias reseñas.
- Las reseñas pendientes, rechazadas o con revisión solicitada no afectan el promedio.
- El comentario es opcional. Se recomienda no escribir nombres, diagnósticos, detalles clínicos ni datos que permitan identificar a alguien.
- La confirmación de publicación en la interfaz es una acción administrativa, no una verificación automática de la atención.
- Esta entrega no se ha probado contra el proyecto Supabase en producción; requiere ejecutar la migración y completar las pruebas anteriores antes de anunciar el módulo como operativo.
