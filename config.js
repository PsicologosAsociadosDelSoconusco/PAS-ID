/*
 * Configuración pública del cliente PAS ID.
 * Coloca aquí la URL y la clave PUBLISHABLE (o anon heredada) del proyecto Supabase.
 * NUNCA pegues aquí service_role, secret keys, contraseñas ni credenciales de base de datos.
 */
window.PAS_ID_CONFIG = {
  supabaseUrl: 'https://ihvofsudjojebmlclpzh.supabase.co',
  supabasePublishableKey: 'sb_publishable_VWculwsUCvivFM5vzk3QBg_EGlZzl48',
  // Se usa como referencia al preparar QR/NFC; el dominio definitivo puede cambiarse después.
  publicBaseUrl: window.location.origin + window.location.pathname
};
