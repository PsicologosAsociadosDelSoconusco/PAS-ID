# PAS ID · Directorio profesional — Etapa 2: miembros fundadores

## Objetivo
Permitir que los miembros fundadores activos aparezcan en el directorio profesional público bajo las mismas condiciones que afiliados y colaboradores.

## Qué corrige
La función `public.list_pas_public_directory` de la migración 013 filtraba `member_type` únicamente a `Afiliado` y `Colaborador`. Los tres registros históricos de fundadores usan `Miembro fundador`, por lo que no podían aparecer aunque hubieran solicitado y obtenido la aprobación de publicación.

La migración 014 sustituye esa función y admite:
- `Afiliado`
- `Colaborador`
- `Miembro fundador`
- `Fundador` (variante histórica normalizada)

## Reglas de publicación que se conservan
Un miembro fundador solamente aparecerá si:
1. Su membresía está activa.
2. Tiene un perfil profesional.
3. Solicitó voluntariamente aparecer en el directorio.
4. Directiva aprobó el cambio, de modo que `public_directory_enabled = true`.

Los datos de honorarios solo se exponen si `public_fee = true`. Teléfono y correo solo se exponen si `public_contact_enabled = true`. La ubicación solo genera marcador si tiene coordenadas.

## Qué NO hace esta migración
- No cambia los folios históricos `0000001`, `0000002` y `0000003`.
- No cambia el tipo de membresía ni el estado de ningún integrante.
- No activa automáticamente el consentimiento de publicación.
- No aprueba automáticamente perfiles.
- No incluye a Directiva como categoría general.
- No altera las migraciones 001–013 ni requiere cambios de frontend.

## Instalación
1. Realiza un respaldo de Supabase.
2. Confirma que la migración 013 ya fue ejecutada.
3. Abre Supabase SQL Editor.
4. Ejecuta una sola vez `supabase/014_include_founders_in_public_directory.sql`.
5. No vuelvas a ejecutar las migraciones 001–013.

No es necesario reemplazar los archivos del sitio en GitHub Pages para esta corrección, porque el cambio se realiza en la función RPC de Supabase. Se recomienda agregar el archivo SQL y esta guía al repositorio para mantener el historial de migraciones documentado.

## Pruebas posteriores
- Un fundador activo con consentimiento aprobado aparece en el directorio.
- Un fundador sin consentimiento o sin aprobación no aparece.
- Los perfiles de afiliados y colaboradores continúan apareciendo bajo las mismas reglas.
- Los tres folios históricos siguen intactos.
- Honorarios, contacto y ubicación respetan sus autorizaciones individuales.
