// PAS ID · Gestión segura de invitaciones y vinculación de cuentas.
// Desplegar como Edge Function `manage-member-access`.
// Supabase inyecta SUPABASE_URL, SUPABASE_PUBLISHABLE_KEYS y
// SUPABASE_SECRET_KEYS. Solo PAS_ID_SITE_URL es secreto propio de esta app.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { error: 'Método no permitido.' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const publishableKeys = JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS') || '{}');
  const secretKeys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') || '{}');
  const anonKey = publishableKeys.default || Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_PUBLISHABLE_KEY');
  const serviceKey = secretKeys.default || Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const siteUrl = Deno.env.get('PAS_ID_SITE_URL') || 'https://psicologosasociadosdelsoconusco.github.io/PAS-ID/';
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return json(500, { error: 'La función no tiene configuradas todas sus variables de entorno.' });
  }

  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) return json(401, { error: 'Sesión requerida.' });

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  try {
    const { data: userData, error: userError } = await userClient.auth.getUser();
    if (userError || !userData.user) return json(401, { error: 'La sesión no es válida.' });
    const { data: role, error: roleError } = await userClient.rpc('current_pas_role');
    if (roleError || role !== 'directiva') return json(403, { error: 'Solo Directiva puede administrar accesos.' });

    const body = await req.json();
    const action = String(body.action || '');
    const memberId = String(body.member_id || '');
    const email = String(body.email || '').trim().toLowerCase();
    if (!memberId || !/^[0-9a-f-]{36}$/i.test(memberId)) return json(400, { error: 'Identificador de miembro no válido.' });
    if (!['invite', 'link_existing', 'delete_account'].includes(action)) return json(400, { error: 'Acción no válida.' });
    if (action !== 'delete_account' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json(400, { error: 'Escribe un correo electrónico válido.' });

    const { data: member, error: memberError } = await adminClient
      .from('members')
      .select('id, full_name, member_type, auth_user_id')
      .eq('id', memberId)
      .single();
    if (memberError || !member) return json(404, { error: 'No se encontró el expediente.' });

    if (action === 'delete_account') {
      if (member.member_type === 'Miembro fundador' || member.member_type === 'Directiva') {
        return json(403, { error: 'Por protección institucional, no se pueden eliminar cuentas de fundadores ni de Directiva desde el directorio.' });
      }
      if (!member.auth_user_id) return json(409, { error: 'Este expediente no tiene una cuenta vinculada.' });
      if (member.auth_user_id === userData.user.id) {
        return json(403, { error: 'No puedes eliminar desde aquí tu propia cuenta de Directiva.' });
      }

      const { data: targetRoles, error: targetRoleError } = await adminClient
        .from('user_roles').select('role').eq('user_id', member.auth_user_id);
      if (targetRoleError) return json(500, { error: `No se pudo validar el rol de la cuenta: ${targetRoleError.message}` });
      if ((targetRoles || []).some((item) => item.role === 'directiva')) {
        return json(403, { error: 'Esta cuenta tiene permisos de Directiva y no puede eliminarse desde el directorio.' });
      }

      const targetUserId = member.auth_user_id;
      const { error: unlinkError } = await adminClient
        .from('members').update({ auth_user_id: null }).eq('id', memberId).eq('auth_user_id', targetUserId);
      if (unlinkError) return json(500, { error: `No se pudo desvincular el expediente: ${unlinkError.message}` });

      const { error: deleteError } = await adminClient.auth.admin.deleteUser(targetUserId);
      if (deleteError) {
        await adminClient.from('members').update({ auth_user_id: targetUserId }).eq('id', memberId).is('auth_user_id', null);
        return json(500, { error: `No se pudo eliminar la cuenta de acceso. Se intentó restaurar la vinculación: ${deleteError.message}` });
      }

      return json(200, {
        ok: true,
        action: 'delete_account',
        message: 'Cuenta de acceso eliminada. El expediente, la credencial y el historial institucional se conservaron.'
      });
    }

    if (member.auth_user_id) return json(409, { error: 'Este expediente ya tiene una cuenta vinculada.' });

    let invitedUserId: string | null = null;
    let invited = false;
    if (action === 'invite') {
      const redirect = new URL(siteUrl);
      redirect.searchParams.set('type', 'invite');
      const { data, error } = await adminClient.auth.admin.inviteUserByEmail(email, {
        redirectTo: redirect.toString(),
        data: { pas_member_id: memberId, pas_member_name: member.full_name },
      });
      if (error || !data.user) {
        const message = error?.message || 'Supabase no devolvió el usuario invitado.';
        return json(400, {
          error: message.toLowerCase().includes('already') || message.toLowerCase().includes('registered')
            ? 'Ese correo ya tiene una cuenta. Usa «Vincular cuenta existente».'
            : `No se pudo enviar la invitación: ${message}`,
        });
      }
      invitedUserId = data.user.id;
      invited = true;
    } else {
      // Busca el usuario por correo mediante el endpoint administrativo, paginando para no asumir que está en la primera página.
      let page = 1;
      let foundUser: { id: string; email?: string } | null = null;
      while (page <= 20 && !foundUser) {
        const { data, error } = await adminClient.auth.admin.listUsers({ page, perPage: 500 });
        if (error) return json(500, { error: `No se pudo consultar Auth: ${error.message}` });
        foundUser = data.users.find((u) => (u.email || '').toLowerCase() === email) || null;
        if (data.users.length < 500) break;
        page += 1;
      }
      if (!foundUser) return json(404, { error: 'No existe una cuenta con ese correo. Usa «Enviar invitación y vincular».' });
      invitedUserId = foundUser.id;
    }

    const { data: alreadyLinked, error: linkCheckError } = await adminClient
      .from('members').select('id').eq('auth_user_id', invitedUserId).maybeSingle();
    if (linkCheckError) return json(500, { error: `No se pudo validar la vinculación: ${linkCheckError.message}` });
    if (alreadyLinked && alreadyLinked.id !== memberId) {
      return json(409, { error: 'Esa cuenta ya está vinculada a otro expediente PAS.' });
    }

    const roleForMember = member.member_type === 'Directiva'
      ? 'directiva'
      : member.member_type === 'Colaborador' ? 'colaborador' : 'afiliado';

    const { error: updateError } = await adminClient
      .from('members').update({ auth_user_id: invitedUserId }).eq('id', memberId);
    if (updateError) return json(500, { error: `La cuenta se creó, pero no se pudo vincular el expediente: ${updateError.message}` });

    const { error: roleInsertError } = await adminClient.from('user_roles').upsert({
      user_id: invitedUserId,
      role: roleForMember,
      created_by: userData.user.id,
    }, { onConflict: 'user_id,role' });
    if (roleInsertError) {
      await adminClient.from('members').update({ auth_user_id: null }).eq('id', memberId);
      return json(500, { error: `No se pudo asignar el rol. La vinculación fue revertida: ${roleInsertError.message}` });
    }

    const { error: profileError } = await adminClient.from('member_profiles').upsert({
      member_id: memberId,
      contact_email: email,
      updated_by: userData.user.id,
    }, { onConflict: 'member_id' });
    if (profileError) {
      // No se invalida el acceso ya asignado; se devuelve advertencia para corregir el perfil desde Directiva.
      return json(200, {
        ok: true, invited,
        warning: `La cuenta quedó vinculada, pero no se pudo guardar el correo en el expediente: ${profileError.message}`,
        role: roleForMember,
      });
    }

    return json(200, { ok: true, invited, role: roleForMember, message: invited ? 'Invitación enviada y expediente vinculado.' : 'Cuenta existente vinculada al expediente.' });
  } catch (error) {
    return json(500, { error: error instanceof Error ? error.message : 'Error inesperado al administrar la cuenta.' });
  }
});
