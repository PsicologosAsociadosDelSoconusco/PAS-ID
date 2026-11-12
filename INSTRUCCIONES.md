# PAS ID 0.3 · Actualización de activación de invitaciones

Este paquete reemplaza cuatro archivos para habilitar la pantalla donde una persona invitada establece su contraseña.

## Archivos incluidos
- `index.html`
- `styles.css`
- `app.js`
- `pas-id-backend.js`

## Instrucciones de publicación
1. En el repositorio GitHub `PAS-ID`, reemplaza estos cuatro archivos en la raíz por los incluidos aquí.
2. **No reemplaces `config.js`**: conserva la URL y la clave publicable que ya configuraste en GitHub.
3. No subas contraseñas, claves SMTP ni claves `service_role`.
4. Espera a que GitHub Pages complete la publicación.
5. Solo después, abre el enlace de invitación de Supabase.

## Flujo
- El enlace de tipo `invite` abre una pantalla de configuración de contraseña.
- La contraseña se guarda mediante `supabase.auth.updateUser`.
- Si el usuario ya tiene rol `directiva`, el panel administrativo se abre.
- Si todavía no tiene rol, se cierra la sesión y se indica que falta autorización institucional.
- El enlace de recuperación también reutiliza esta pantalla.

La cuenta de prueba no recibe permisos de Directiva automáticamente. Asigna ese rol únicamente a la cuenta autorizada.
