# PAS ID · Renovación de las etapas 5 a 8

Esta entrega continúa sobre `PAS-ID-renovacion-etapa-4.zip`.

## Etapa 5 · Experiencia administrativa de Directiva

- Se conserva el panel administrativo por módulos y la navegación lateral contraíble ya existente.
- El dashboard incorpora accesos directos al Centro de solicitudes y a Gestión documental, además de los accesos previos.
- Se conservan los módulos administrativos de miembros, credenciales, eventos, solicitudes, documentación, constancias, verificación y configuración.
- La bandeja de solicitudes conserva la regla de primera atención: el primer directivo que toma el caso queda como responsable.

## Etapa 6 · Gestión institucional integrada

- El directorio de miembros continúa siendo el punto de consulta de los registros institucionales.
- Las solicitudes de actualización de perfil/fotografía y los casos institucionales mantienen su flujo de revisión en el Centro integral de solicitudes.
- La documentación conserva su módulo especializado, conectado con requerimientos, entregas y revisión de archivos.
- El dashboard proporciona accesos directos a solicitudes y documentos para reducir navegación innecesaria.
- No se duplican tablas ni se modifica el modelo de datos en esta entrega.

## Etapa 7 · Directorio profesional avanzado

- Se añade filtro por nombre o especialidad, municipio, especialidad y modalidad de atención.
- Las modalidades disponibles corresponden a los valores del perfil: Presencial, En línea y Presencial y en línea.
- Se muestra el número de profesionales que coincide con los filtros.
- Las búsquedas de texto esperan 260 ms después de la última pulsación para evitar llamadas repetidas por cada tecla.
- Se mantienen las reglas de publicación voluntaria y aprobación de Directiva; las ubicaciones se enlazan a Google Maps solo cuando existen coordenadas.
- El directorio sigue consultando el RPC público existente; no se agregan campos privados ni se exponen datos de contacto.

## Etapa 8 · Revisión estática y preparación de pruebas

- Se verificó sintaxis JavaScript con `node --check`.
- Se verificó que el HTML no contiene IDs duplicados.
- Se comprobó balance de llaves CSS.
- `config.js` y las migraciones SQL heredadas se conservaron desde la etapa 4; esta entrega no incorpora migraciones nuevas.
- No se ejecutaron pruebas autenticadas contra el proyecto Supabase real ni pruebas de navegador en producción. Por tanto, la revisión estática no equivale a una auditoría de seguridad ni a una certificación de RLS.

## Instalación

1. Respalda el repositorio y la base de datos antes de publicar.
2. Sustituye los archivos del proyecto por los de este ZIP.
3. Conserva el `config.js` actual del repositorio si contiene la configuración vigente del proyecto.
4. No ejecutes migraciones SQL por esta entrega: no se añadieron cambios de esquema.
5. Publica en GitHub Pages y realiza la lista de pruebas de `docs/PRUEBAS-SEGURIDAD-ETAPAS-5-A-8.md`.

## Alcance y límites

Esta entrega no implementa Academia PAS (etapa 9), no altera credenciales ni folios, no modifica autenticación, RLS, buckets o Edge Functions. Los cambios de directorio utilizan el parámetro `p_specialty` ya admitido por el RPC público existente y filtran modalidad en el cliente sobre perfiles que el RPC ya autorizó para publicación.
