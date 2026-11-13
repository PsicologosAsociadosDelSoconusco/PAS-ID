# Etapa 4 — Verificación pública de constancias mediante QR

## Qué incorpora
- El PDF horizontal incorpora un QR asociado al folio único de la constancia.
- El QR abre PAS ID con el parámetro `verificar-constancia`.
- La página pública consulta Supabase y muestra titular, concepto, folio, fecha, actividad (si existe) y estado vigente/revocado.
- La consulta pública no expone correo, teléfono, datos privados ni identificadores internos.

## Instalación
1. Sustituye los archivos de `PAS-ID-main` en el repositorio, conservando `config.js`.
2. En Supabase → SQL Editor, ejecuta el contenido de `supabase/003_certificate_public_verification.sql`.
3. Publica el repositorio en GitHub Pages.
4. Abre una constancia emitida y vuelve a imprimirla para generar el QR en el documento.

No se modifican folios ni registros existentes. La función SQL solo permite consultar el documento por su folio exacto; no ofrece listados públicos.

## Prueba
1. Escanea el QR de una constancia vigente: debe mostrar `DOCUMENTO AUTÉNTICO · VIGENTE`.
2. Revoca una constancia de prueba desde Directiva.
3. Escanea nuevamente el mismo QR: debe mostrar `DOCUMENTO REVOCADO`.
4. Prueba un folio inventado: debe indicar que no se encontró.
