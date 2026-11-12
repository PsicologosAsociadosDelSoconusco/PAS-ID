# PAS ID · Base conectable 0.2

Plataforma independiente para Psicólogos Asociados del Soconusco. Esta versión conserva el prototipo visual 0.1 y agrega una primera capa de integración con Supabase para autenticación de la Directiva, directorio compartido, altas de miembros, cambios de estado y verificación pública.

## Qué contiene

- `index.html`, `styles.css`, `app.js`: interfaz institucional/tecnológica PAS.
- `assets/pas-logo.png`: logotipo PAS.
- `config.js`: configuración pública local; URL y clave publicable Supabase se dejan vacías.
- `pas-id-backend.js`: adaptador de autenticación y operaciones conectadas.
- `supabase/001_initial_schema.sql`: tablas, datos históricos, funciones seguras, auditoría y políticas RLS.
- `docs/INSTALACION-SUPABASE.md`: pasos de configuración.

## Dos modos de funcionamiento

### Demostración local

Si `config.js` permanece sin URL o clave, la página conserva el modo de demostración local del prototipo 0.1. Sus cambios se guardan únicamente en el navegador.

### Conexión Supabase

Cuando se configure una URL real del proyecto y una clave publicable, el acceso exige iniciar sesión. El panel de esta versión solo permite cuentas con rol `directiva`. La aplicación consulta el directorio central y ejecuta altas, suspensiones y revocaciones a través de funciones autorizadas en Postgres.

## Primeros pasos

Sigue `docs/INSTALACION-SUPABASE.md`. No conectes el sistema a miembros reales hasta completar las comprobaciones de seguridad y pruebas indicadas.

## Credenciales históricas y nuevas

- Los fundadores conservan exactamente sus folios `0000001`, `0000002` y `0000003`.
- Sus credenciales históricas se consultan por folio.
- Los nuevos registros reciben un identificador aleatorio emitido por Postgres (`PAS-` más 20 caracteres hexadecimales aleatorios, 80 bits).
- La directiva puede revocar el registro de una credencial; una consulta posterior devuelve el nuevo estado.
- Los datos de contacto y notas internas se separan de la tabla de miembros y no aparecen en la consulta pública.

## Estado de esta versión

La integración está preparada en el código, pero **todavía no está conectada a un proyecto real de Supabase**. No se ha creado el proyecto, no se ha ejecutado el SQL en una cuenta PAS y no hay cuentas directivas reales configuradas. Por ello, el modo conectado no funcionará hasta completar esos pasos.

Tampoco se han emitido QR oficiales, configurado NFC físico, publicado un dominio propio, desarrollado el portal completo de afiliados ni conectado todavía el directorio del sitio institucional. Los módulos de eventos, asistencia y constancias tienen su estructura inicial en la base de datos, pero aún no sus pantallas operativas.

## Seguridad importante

- En el navegador solo se coloca la clave publicable (`publishable` o la `anon` heredada), protegida por RLS.
- Nunca colocar `service_role`, secret keys, contraseñas de base de datos ni credenciales SMTP en `config.js` o en GitHub Pages.
- La primera asignación del rol de Directiva se hace desde el SQL Editor de Supabase, no desde el navegador.
- La función pública de verificación devuelve únicamente datos institucionales mínimos.
- Antes de uso oficial, probar los permisos con una cuenta anónima, una cuenta afiliada y una cuenta directiva.
