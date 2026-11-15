# Corrección del error al generar QR

Si la migración 015 ya se ejecutó, abre Supabase → SQL Editor y ejecuta únicamente `supabase/016_fix_review_qr_crypto_schema.sql`.

La causa es que las funciones de `pgcrypto` se instalaron en el esquema `extensions`, pero las funciones RPC de QR las llamaban sin calificar el esquema y además usan `search_path = ''`. La corrección usa `extensions.gen_random_bytes` y `extensions.digest`.

No ejecutes de nuevo 015 ni ninguna migración anterior. Después, vuelve a cargar el portal, inicia sesión con un profesional activo cuyo perfil esté aprobado y visible en el directorio, y prueba generar un QR.
