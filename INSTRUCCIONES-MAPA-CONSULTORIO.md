# PAS ID · Selector de ubicación del consultorio

Esta actualización reemplaza la captura manual de latitud/longitud por un mapa interactivo.

## Uso
- Clic en el mapa para colocar el marcador.
- Arrastra el marcador para ajustar la ubicación.
- Busca una dirección o establecimiento para centrar el mapa.
- «Usar mi ubicación» solicita permiso del navegador.
- «Quitar ubicación» elimina las coordenadas guardadas.
- Las coordenadas se guardan en los campos existentes y siguen sujetas a aprobación de Directiva.

## Tecnología
- Leaflet 1.9.4 y teselas de OpenStreetMap.
- Búsqueda de dirección mediante Nominatim (servicio público sujeto a límites de uso).
- No requiere cambios SQL adicionales: reutiliza `office_latitude` y `office_longitude` de la migración 008.
- No requiere Edge Function ni claves API.
