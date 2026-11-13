# PAS ID — Etapa 3.1: registro de asistencia por QR

## Qué incorpora
- Lector de QR desde la cámara trasera del dispositivo mediante `getUserMedia` y `BarcodeDetector` del navegador.
- Reconoce el QR de verificación de la credencial PAS (`?verificar=...`) y extrae el identificador.
- Comprueba que el miembro exista y que tanto la membresía como la credencial estén vigentes antes de registrar asistencia.
- Registra la asistencia en el evento seleccionado usando el mismo método de Supabase que el registro manual.
- Evita duplicados mediante la restricción de unicidad existente en la base de datos.
- Incluye captura manual de folio/identificador como alternativa si el navegador no soporta `BarcodeDetector` o no concede acceso a la cámara.

## Requisitos
- Sitio servido mediante HTTPS (GitHub Pages cumple este requisito).
- Permiso de cámara concedido al navegador.
- Navegador con soporte para `BarcodeDetector` para lectura automática. En navegadores sin ese soporte se puede utilizar la captura manual.
- Sesión de Directiva y evento seleccionado.

## Instalación
1. Reemplaza los archivos del repositorio por los de esta carpeta.
2. Conserva el `config.js` actual con la configuración pública de Supabase.
3. No requiere migración SQL adicional.
4. Espera a que GitHub Pages publique los cambios y recarga con Ctrl+F5.

## Verificación operativa
1. Inicia sesión como Directiva y abre Eventos y asistencia.
2. Selecciona el evento que recibirá la asistencia.
3. Pulsa «Escanear credencial QR» y concede permiso de cámara.
4. Escanea el QR de una credencial vigente autorizada para la verificación.
5. Confirma que aparece en la lista de asistentes y que el afiliado ve su asistencia en «Mi historial».
6. Escanea el mismo QR otra vez: debe informar que ya existe una asistencia para ese evento.

El QR de credencial sigue siendo un QR de verificación pública. No contiene información privada; el registro se realiza en el servidor después de validar el identificador y el estado del miembro.
