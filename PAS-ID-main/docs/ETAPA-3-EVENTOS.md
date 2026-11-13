# PAS ID · Etapa 3: Eventos y asistencia

## Incluido en esta entrega

- La vista previa de credenciales ya no elige automáticamente al primer miembro activo. Directiva verá una vista neutral hasta pulsar **Ver tarjeta** en un registro.
- Directiva puede crear eventos con título, lugar, fecha/hora de inicio y término, descripción y estado de publicación.
- Los eventos se consultan desde `public.events`.
- Directiva puede publicar/despublicar o cancelar un evento.
- En cada evento puede registrar manualmente la asistencia de miembros activos y consultar/eliminar registros.
- La restricción única `(event_id, member_id)` impide duplicar asistencia de una misma persona al mismo evento.

## Requisitos de base de datos

Esta entrega utiliza las tablas `public.events` y `public.event_attendance` y las políticas RLS de Directiva definidas en `supabase/001_initial_schema.sql`. No agrega tablas ni requiere una migración SQL si esas tablas y políticas ya existen en el proyecto Supabase configurado.

## Publicación

1. Descomprime el ZIP.
2. Sustituye los archivos del repositorio por los de esta versión, conservando `config.js` con la configuración pública actual de Supabase.
3. Publica el contenido en la rama `main` de GitHub Pages.
4. Inicia sesión como Directiva y abre **Eventos y asistencia**.
5. Crea un evento de prueba sin datos sensibles y verifica el registro de asistencia con un miembro de prueba.

## Alcance y limitaciones

- El registro de asistencia es manual en esta versión. El escaneo de QR con cámara, tokens de asistencia de un solo uso y control de duplicados por escaneo requieren una integración posterior específica.
- La lista de eventos y el control de asistencia están implementados para Directiva. No se ha añadido todavía una agenda de eventos en el portal de afiliados.
- Cancelar un evento elimina sus registros de asistencia porque la relación actual usa `ON DELETE CASCADE`. Para eventos ya realizados, es preferible despublicarlos en vez de eliminarlos.
- No se han modificado las tablas ni los registros históricos de miembros o credenciales.


## Corrección posterior: agenda del afiliado
El portal del afiliado ahora consulta únicamente eventos publicados y muestra su propio historial de asistencias. Las consultas usan las políticas RLS existentes: eventos publicados para usuarios autenticados y asistencias propias para cada afiliado. No se amplían permisos ni se exponen listas de participantes. También se corrige el reset del formulario de creación y el selector de asistencia excluye membresías que no estén activas o cuya credencial no esté vigente.
