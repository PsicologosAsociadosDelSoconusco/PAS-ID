# PAS ID · Etapa 2: expedientes y cuentas individuales

Esta actualización añade el portal del afiliado, solicitudes de actualización de expediente y la vinculación segura de cuentas. No reemplaza el esquema inicial ni altera los folios históricos de los fundadores.

## Qué incluye

- Inicio de sesión por rol: `directiva`, `afiliado` y `colaborador`.
- Directiva conserva el panel de administración actual.
- Afiliados y colaboradores acceden a un portal privado separado.
- Cada usuario solo consulta el expediente ligado a su propio `auth.uid()`.
- El QR del portal abre la verificación pública usando el folio/identificador, sin exponer el expediente privado.
- Los cambios solicitados por un afiliado quedan pendientes hasta que Directiva los aprueba o rechaza.
- Directiva puede invitar un correo nuevo o vincular una cuenta de Supabase ya existente a un expediente.
- La clave `service_role` permanece en Secrets de Supabase; nunca se guarda en `config.js` ni en GitHub.

## 1. Respaldo y migración SQL

1. Antes de cambiar la base, en Supabase abre **Database → Backups** y confirma que existe un respaldo reciente. Si tu plan no incluye respaldos administrados, exporta las tablas `members`, `credentials` y `user_roles`.
2. Abre **SQL Editor → New query**.
3. Copia el contenido completo de `supabase/002_member_portal.sql` y ejecútalo una sola vez.
4. Comprueba que termina con `COMMIT` sin errores.

No vuelvas a ejecutar `001_initial_schema.sql`: esa es la instalación original y ya está aplicada. La migración 002 es incremental e idempotente para sus tablas, índices y políticas.

## 2. Desplegar la función de invitaciones

La invitación de Auth requiere una operación administrativa que no debe ejecutarse en el navegador. Por eso se incorpora la Edge Function `manage-member-access`.

Desde una terminal en la carpeta raíz de este repositorio (requiere Node.js 20 o posterior):

```bash
npx supabase login
npx supabase link --project-ref ihvofsudjojebmlclpzh
npx supabase functions deploy manage-member-access
```

En **Supabase → Edge Functions → Secrets**, agrega únicamente la variable propia de esta aplicación:

- `PAS_ID_SITE_URL` = `https://psicologosasociadosdelsoconusco.github.io/PAS-ID/`

Supabase inyecta automáticamente `SUPABASE_URL` y los mapas de claves `SUPABASE_PUBLISHABLE_KEYS` y `SUPABASE_SECRET_KEYS`; la función usa la clave `default` de cada mapa. También mantiene compatibilidad con las variables heredadas `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE_KEY`. No intentes crear secretos personalizados que comiencen con `SUPABASE_`: ese prefijo está reservado por Supabase.

**Seguridad:** la clave secreta/administrativa solo se utiliza dentro de la Edge Function y nunca se incluye en `config.js`, HTML, JavaScript del navegador, este ZIP o GitHub. No la pegues en el chat.

## 3. Subir los archivos del sitio

1. Conserva el `config.js` que ya contiene la URL y la clave pública actual del proyecto.
2. Sube los archivos del ZIP de esta etapa a la raíz del repositorio `PAS-ID`, incluyendo la carpeta `supabase/functions` y `supabase/002_member_portal.sql`.
3. No elimines `assets/pas-logo.png` ni cambies los tres folios históricos.
4. Espera a que GitHub Pages publique la versión.

## 4. Dar acceso a un afiliado

1. En PAS ID, entra como Directiva y abre el directorio.
2. Registra al afiliado como lo haces actualmente.
3. Abre los tres puntos de su registro.
4. En **Cuenta personal PAS ID**, escribe el correo del afiliado.
5. Pulsa **Enviar invitación y vincular**.
6. El correo recibe la invitación de Supabase. Al abrirla, la persona configura su contraseña y entra al portal de afiliado.

Si el correo ya tenía una cuenta de Auth, usa **Vincular cuenta existente**. La cuenta no puede estar asociada a otro expediente.

El rol se asigna conforme al tipo de registro: `Afiliado` → `afiliado`; `Colaborador` → `colaborador`; `Directiva` → `directiva`. Asigna el tipo Directiva únicamente cuando la persona deba tener permisos administrativos.

## 5. Pruebas obligatorias antes de usar datos reales

- [ ] La cuenta actual de Directiva sigue entrando al panel administrativo.
- [ ] Crear un miembro de prueba, invitar un correo de prueba y completar la invitación.
- [ ] La cuenta de prueba entra al portal de afiliado, no al panel de Directiva.
- [ ] El afiliado puede ver únicamente su expediente y su credencial.
- [ ] La cuenta de prueba no puede leer expedientes de otros miembros por URL ni API.
- [ ] Enviar una solicitud de cambio de perfil y comprobar que queda pendiente.
- [ ] Aprobarla desde Directiva y verificar que el expediente se actualiza.
- [ ] Comprobar que la Directiva conserva el acceso a los tres folios históricos.
- [ ] Comprobar QR y enlace público de verificación.

## Notas importantes

- El correo de contacto del expediente es independiente del correo usado para iniciar sesión.
- Los cambios del afiliado no se aplican directamente: son solicitudes revisables por Directiva.
- La consulta pública devuelve datos mínimos de validación; nunca devuelve correo, teléfono, especialidad, cédula, notas internas ni solicitudes.
- Esta etapa no convierte todavía las pantallas de eventos y constancias en módulos terminados. Quedan para las siguientes entregas después de validar el portal y los permisos.
