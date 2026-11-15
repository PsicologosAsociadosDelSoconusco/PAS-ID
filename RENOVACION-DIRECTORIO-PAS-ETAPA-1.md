# PAS ID · Renovación del directorio profesional — Etapa 1

## Objetivo
Reorganizar el directorio para que una persona que busca atención pueda explorar profesionales afiliados y colaboradores activos de Psicólogos Asociados del Soconusco, comparar perfiles y ubicar consultorios que tengan coordenadas autorizadas.

## Cambios incluidos
- Nuevo encabezado institucional: **Psicólogos Asociados del Soconusco**.
- Vista de resultados y mapa lado a lado en escritorio; distribución apilada en móvil.
- Búsqueda por nombre, especialidad, presentación, población atendida y enfoques declarados.
- Filtros por municipio, modalidad, población, honorarios publicados y contacto publicado.
- Tarjetas de profesionales y ficha individual dinámica.
- Enlaces a Google Maps cuando hay coordenadas.
- El directorio público solo devuelve integrantes activos con `member_type` Afiliado o Colaborador que hayan autorizado su publicación.
- Los honorarios solo se devuelven públicamente con `public_fee = true`.
- Correo y teléfono solo se devuelven públicamente con `public_contact_enabled = true`; permanecen privados por defecto.
- El perfil del integrante permite solicitar cambios de población atendida, enfoques, honorarios y permisos de publicación. Directiva debe aprobar los cambios mediante el flujo ya existente.
- Se mantiene la publicación voluntaria y la aprobación de Directiva.

## Valoraciones
La interfaz muestra que todavía no hay valoraciones verificadas. No se habilitan reseñas ni se inventan estrellas. El sistema de valoración 1–5 debe incorporarse cuando exista un mecanismo auditable para confirmar que la atención ocurrió (por ejemplo, un comprobante de atención de un solo uso, sin recopilar información clínica del paciente). Solo entonces se mostrarán promedios y reseñas verificadas.

## Instalación
1. Realiza una copia del repositorio y de la base de datos.
2. Confirma que las migraciones 001–012 están aplicadas.
3. Ejecuta **una sola vez** `supabase/013_patient_friendly_professional_directory.sql` en Supabase SQL Editor.
4. Reemplaza los archivos del sitio con los de este paquete.
5. Conserva el `config.js` de tu proyecto actual; no uses claves secretas en el frontend.
6. Publica en GitHub Pages.

No vuelvas a ejecutar las migraciones 001–012.

## Pruebas requeridas
- Un afiliado activo solicita aparecer en el directorio y Directiva aprueba la solicitud.
- Un colaborador activo hace lo mismo.
- Un usuario Directiva no aparece en el directorio público.
- Un integrante sin consentimiento no aparece.
- El mapa muestra únicamente los perfiles con latitud y longitud configuradas.
- Un perfil sin ubicación sigue apareciendo en la lista y no crea un marcador.
- Los filtros de municipio, modalidad, población y honorarios funcionan al combinarse.
- Los honorarios no aparecen si el integrante no habilitó `public_fee`.
- El teléfono y correo no aparecen sin `public_contact_enabled`.
- Al habilitar contacto público, aparecen únicamente los datos que el integrante haya configurado.
- Un cambio en población, enfoques, honorarios o privacidad pasa por aprobación de Directiva antes de reflejarse públicamente.
- Probar mapa y ficha en Android y escritorio.

## Alcance que queda pendiente
- Flujo seguro de confirmación de atención y sistema de valoraciones verificadas 1–5.
- Cualquier sistema de agenda o reserva de citas (no se incorpora en esta etapa).
