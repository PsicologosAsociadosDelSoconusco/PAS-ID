# PAS ID · Renovación, etapa 3: credencial QR y expediente documental

## Qué cambia
- Se corrige el QR del portal del integrante: antes se llamaba a una función de fallback que únicamente pintaba el texto «Usa la imagen QR». Ahora se reutiliza el renderizador QR real que ya se empleaba en la plataforma.
- «Mi expediente» deja de ser una ficha duplicada de datos personales. Se convierte en un repositorio de los documentos que PAS solicite al integrante.
- Directiva obtiene un módulo «Documentación» para crear requerimientos a todos los integrantes activos con cuenta o a una persona concreta, fijar una fecha límite, consultar entregas, abrir archivos y aprobarlos o solicitar correcciones.
- Los archivos aceptados son PDF, JPG, PNG y WEBP, con un límite de 10 MB. Se guardan en un bucket privado de Supabase Storage y se abren mediante enlaces firmados temporales.

## Instalación
1. Realiza respaldo del repositorio y de Supabase.
2. Publica los archivos del ZIP sustituyendo los correspondientes, pero conserva el `config.js` actual.
3. Comprueba primero el historial: si la migración 009 ya se aplicó, no la repitas. Si todavía no está aplicada, ejecuta 009 una sola vez. Después ejecuta `supabase/010_member_document_repository.sql` una sola vez.
4. No vuelvas a ejecutar 001–008 ni la migración 009 si ya se aplicó.
5. Publica GitHub Pages.

## Flujo de prueba recomendado
1. Como Directiva, abre «Documentación» y solicita un archivo de prueba a un integrante de prueba.
2. Inicia sesión con ese integrante, abre «Mi expediente», adjunta un PDF o imagen pequeño y envíalo.
3. Como Directiva, abre la entrega y apruébala. Repite otra prueba usando «Solicitar corrección» y comprueba que el integrante pueda reemplazar el archivo.
4. Comprueba que otra cuenta de afiliado no puede listar ni abrir el documento de la primera cuenta.
5. Abre «Mi credencial» y escanea el QR con un teléfono distinto; debe abrir la consulta pública del identificador.

## Seguridad y conservación
- La migración 010 crea solamente tablas, funciones, políticas y un bucket privado para documentos. No cambia miembros, cuentas, credenciales ni folios.
- No se modifica `config.js` ni se incorpora ninguna clave secreta al navegador.
- No se han ejecutado migraciones en el proyecto Supabase del usuario.
- La validación realizada aquí es estática; la carga, lectura y permisos deben confirmarse con cuentas reales de prueba después de aplicar la migración.
