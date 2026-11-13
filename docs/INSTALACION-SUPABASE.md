# Puesta en marcha de PAS ID 0.2 con Supabase

Esta guía conecta el prototipo con un proyecto de Supabase propio de PAS. La dirección de correo institucional definitiva sigue pendiente; no se ha inventado ni configurado ninguna cuenta.

## 1. Crear el proyecto

1. Crear un proyecto nuevo en Supabase a nombre de Psicólogos Asociados del Soconusco.
2. Guardar de forma privada los datos de acceso al proyecto.
3. En el panel del proyecto, abrir **SQL Editor**.
4. Copiar y ejecutar el archivo `supabase/001_initial_schema.sql` completo.
5. Confirmar que aparezcan las tablas `members`, `credentials`, `user_roles`, `events`, `event_attendance`, `certificates` y `audit_logs`.

El script inserta los tres registros fundadores con sus folios históricos y fechas de la credencial compartida. Si algún dato institucional cambió desde la emisión, verificarlo antes de utilizar el proyecto como directorio oficial.

## 2. Crear el primer usuario de Directiva

1. En **Authentication → Users**, agregar manualmente al primer usuario autorizado. Utilizar el correo institucional cuando PAS lo tenga definido; mientras tanto, no usar una dirección inventada en el sitio.
2. Establecer una contraseña fuerte y entregarla únicamente a la persona autorizada.
3. Copiar el UUID del usuario creado.
4. En SQL Editor, asignarle el rol de directiva. Sustituir el marcador por el correo real:

```sql
insert into public.user_roles (user_id, role)
select id, 'directiva'
from auth.users
where lower(email) = lower('CORREO-INSTITUCIONAL-REAL')
on conflict (user_id, role) do nothing;
```

5. Verificar que solo las cuentas autorizadas reciban el rol `directiva`.
6. Desactivar el registro público de usuarios en Authentication, para que visitantes no puedan crear cuentas por su cuenta.

La aplicación de esta versión no asigna roles desde el navegador. Las altas de miembros no crean automáticamente una cuenta de inicio de sesión; la vinculación de cuentas de afiliados se añadirá en la siguiente fase.

## 3. Configurar el cliente web

Abrir `config.js` y completar los dos valores del proyecto:

```js
window.PAS_ID_CONFIG = {
  supabaseUrl: 'https://TU-PROYECTO.supabase.co',
  supabasePublishableKey: 'TU_CLAVE_PUBLICABLE',
  publicBaseUrl: window.location.origin + window.location.pathname
};
```

La clave publicable está diseñada para estar en el cliente y **no sustituye a las políticas RLS**. No se debe usar una `service_role` key ni una secret key en este archivo. La aplicación requiere HTTPS para el despliegue web.

## 4. Publicar PAS ID por separado

1. Crear un repositorio independiente de GitHub para PAS ID.
2. Subir el contenido de esta carpeta conservando las rutas `assets/`, `supabase/` y `docs/`.
3. Activar GitHub Pages para el repositorio.
4. Probar el acceso conectado y la consulta pública desde la URL de GitHub Pages.
5. Cuando PAS defina un dominio propio, vincularlo a este repositorio y actualizar `publicBaseUrl`.

El sitio institucional actual no necesita modificarse en este paso. Después se agregará un enlace hacia PAS ID.

## 5. Verificaciones de seguridad y operación

Realiza las verificaciones con cuentas y registros controlados, sin alterar credenciales institucionales activas:

1. Sin iniciar sesión, intentar consultar tablas directamente: debe denegarse el acceso.
2. Sin iniciar sesión, consultar `0000001` con la interfaz pública: debe devolver únicamente nombre, tipo, folio, fechas y estado.
3. Iniciar sesión con el usuario autorizado de Directiva: debe abrirse el panel.
4. Iniciar sesión con un usuario autenticado sin rol `directiva`: no debe abrirse el panel administrativo.
5. Registrar un expediente controlado: el servidor debe generar el identificador aleatorio y este debe aparecer una sola vez en el cuadro de emisión.
6. Consultar el identificador desde una ventana privada: debe mostrar el estado vigente.
7. Revocar la credencial controlada: la consulta pública debe reflejar inmediatamente `Revocado`.
8. Suspender la membresía controlada: la consulta debe reflejar `Suspendido`.
9. Emitir una credencial renovada controlada: el identificador anterior debe quedar como `Sustituido` y el nuevo debe consultar como `Activo`.
10. Confirmar que correo, teléfono y notas internas no se muestran en la consulta pública ni en el directorio.
11. Confirmar en `audit_logs` que las acciones administrativas relevantes generen historial.

Para una auditoría formal, añadir pruebas automatizadas RLS con `supabase test db` antes de la puesta en producción.

## 6. Decisiones todavía pendientes

- Dirección y dominio del correo institucional.
- Dominio propio para PAS ID.
- Personas que tendrán rol de Directiva.
- Política institucional de altas, renovaciones, suspensiones y bajas.
- Qué datos de los afiliados se mostrarán públicamente.
- Flujo de invitación y vinculación de cuentas de afiliados y colaboradores.
- Formato final del QR/NFC y reemisión de credenciales.

## Nota de seguridad

El esquema mantiene deshabilitado el acceso anónimo directo a las tablas. La verificación pública se realiza únicamente mediante una función que devuelve datos mínimos. Las funciones con privilegios elevados fijan `search_path` vacío y califican explícitamente los objetos usados. La clave de servicio nunca se utiliza en el navegador.
