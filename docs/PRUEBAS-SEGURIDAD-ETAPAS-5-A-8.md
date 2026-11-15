# Pruebas de aceptación y seguridad · PAS ID etapas 5 a 8

## A. Directiva

- [ ] Iniciar sesión con una cuenta de Directiva.
- [ ] Contraer y expandir el menú lateral en escritorio.
- [ ] En móvil, abrir y cerrar el menú sin bloquear el contenido.
- [ ] Desde Inicio, abrir Centro integral de solicitudes y Gestión documental.
- [ ] Comprobar que el primer directivo que atiende una solicitud queda como responsable.
- [ ] Comprobar que un segundo directivo no puede apropiarse del caso ya tomado.
- [ ] Revisar un documento enviado y aprobarlo o solicitar corrección.

## B. Afiliado y colaborador

- [ ] Iniciar sesión con una cuenta de prueba de cada rol.
- [ ] Confirmar que solo ve su propio expediente documental.
- [ ] Confirmar que puede consultar sus propias solicitudes y conversaciones.
- [ ] Confirmar que recibe aviso al solicitarle un documento.
- [ ] Entregar un archivo de prueba y confirmar su estado «Entregado · en revisión».
- [ ] Confirmar que recibe aprobación o solicitud de corrección y sus observaciones.

## C. Directorio público

- [ ] Abrir el directorio sin iniciar sesión.
- [ ] Buscar por nombre.
- [ ] Buscar por especialidad.
- [ ] Filtrar por municipio.
- [ ] Filtrar por modalidad presencial, en línea y combinada.
- [ ] Confirmar que el contador coincide con los resultados visibles.
- [ ] Confirmar que solo aparecen perfiles con consentimiento y aprobación.
- [ ] Confirmar que el enlace a Google Maps solo aparece para perfiles con coordenadas aprobadas.
- [ ] Confirmar que no se muestran correo, teléfono ni documentos privados.

## D. Seguridad de documentos y datos

- [ ] Con una segunda cuenta de integrante, intentar consultar el registro documental de la primera cuenta mediante la interfaz.
- [ ] Verificar en Supabase que el bucket documental es privado.
- [ ] Verificar que las políticas RLS impiden leer filas documentales de otros integrantes.
- [ ] Verificar que una URL firmada expirada deja de permitir acceso.
- [ ] Verificar que solo Directiva autorizada puede consultar entregas de todos los integrantes.
- [ ] Confirmar que no hay claves `service_role` o secretas en archivos del frontend.

## E. Regresión

- [ ] Verificar folios históricos `0000001`, `0000002` y `0000003`.
- [ ] Verificar QR de credenciales y verificación pública.
- [ ] Verificar impresión individual y masiva.
- [ ] Verificar invitación y acceso por rol.
- [ ] Verificar eventos, asistencia y constancias.
- [ ] Verificar ubicación del consultorio y consentimiento del directorio.

**Importante:** las casillas requieren ejecución en el entorno real de Supabase/GitHub Pages. Las comprobaciones estáticas locales no sustituyen estas pruebas, ni constituyen una auditoría de seguridad.
