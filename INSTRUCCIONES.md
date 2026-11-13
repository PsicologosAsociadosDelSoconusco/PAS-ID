# PAS ID — Verificación QR de constancias

Esta actualización agrega un QR de verificación pública a la constancia horizontal y una consulta segura por folio.

## Instalación
1. Descomprime el ZIP.
2. Reemplaza los archivos del repositorio con el contenido de `PAS-ID-main`.
3. Conserva el `config.js` actual.
4. En Supabase → SQL Editor, ejecuta `supabase/003_certificate_public_verification.sql`.
5. Publica los cambios en GitHub Pages y actualiza con Ctrl + F5.

## Prueba
- Imprime nuevamente una constancia de prueba (las copias PDF anteriores no tendrán el QR nuevo).
- Escanea el QR con un celular.
- Comprueba el estado vigente.
- Revoca el documento de prueba desde Directiva y vuelve a escanear para comprobar que se muestre como revocado.

La función pública devuelve solo el folio, concepto, fecha, nombre del titular, actividad asociada y estado de revocación. No devuelve datos privados ni permite listar constancias.
