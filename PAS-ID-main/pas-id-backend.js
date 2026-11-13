'use strict';

(function () {
  const config = window.PAS_ID_CONFIG || {};
  const hasConfiguration = Boolean(
    /^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(config.supabaseUrl || '') &&
    typeof config.supabasePublishableKey === 'string' &&
    config.supabasePublishableKey.trim().length > 20
  );
  const sdkAvailable = Boolean(window.supabase && typeof window.supabase.createClient === 'function');
  const configured = hasConfiguration && sdkAvailable;

  const client = configured
    ? window.supabase.createClient(config.supabaseUrl, config.supabasePublishableKey, {
        auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
      })
    : null;

  async function unwrap(promise, context) {
    const result = await promise;
    if (result.error) {
      const error = new Error(result.error.message || `Error en ${context}`);
      error.code = result.error.code;
      throw error;
    }
    return result.data;
  }

  const api = {
    isConfigured: () => configured,
    hasConfiguration: () => hasConfiguration,
    isSdkAvailable: () => sdkAvailable,
    client,

    async getSession() {
      if (!configured) return null;
      const data = await unwrap(client.auth.getSession(), 'sesión');
      return data.session || null;
    },

    async signIn(email, password) {
      if (!configured) throw new Error('Falta configurar Supabase.');
      if (!email || !password) throw new Error('Escribe el correo institucional y la contraseña.');
      return unwrap(client.auth.signInWithPassword({ email, password }), 'inicio de sesión');
    },

    async signOut() {
      if (!configured) return;
      await unwrap(client.auth.signOut(), 'cierre de sesión');
    },

    async updatePassword(password) {
      if (!configured) throw new Error('Supabase no está configurado.');
      if (typeof password !== 'string' || password.length < 12) {
        throw new Error('La contraseña debe tener al menos 12 caracteres.');
      }
      return unwrap(client.auth.updateUser({ password }), 'actualización de contraseña');
    },

    async currentRole() {
      if (!configured) return null;
      return unwrap(client.rpc('current_pas_role'), 'consulta de rol');
    },

    async listMembers() {
      if (!configured) throw new Error('Supabase no está configurado.');
      const rows = await unwrap(
        client.from('members')
          .select('id,legacy_folio,full_name,member_type,membership_status,issued_on,expires_on,is_historical,auth_user_id,member_profiles(contact_email,phone,professional_license,specialty,city,state,about),credentials(id,public_identifier,credential_status,issued_at,expires_on,is_historical)')
          .order('full_name', { ascending: true }),
        'directorio de miembros'
      );
      return rows.map(mapMember);
    },

    async getMyProfile() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('get_my_pas_profile'), 'expediente del afiliado');
    },

    async submitProfileChangeRequest(changes) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('submit_my_pas_profile_change_request', { p_changes: changes }), 'solicitud de actualización');
    },

    async listProfileChangeRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('member_profile_change_requests')
        .select('id,member_id,requested_changes,request_status,submitted_at,members(full_name,legacy_folio,member_type)')
        .order('submitted_at', { ascending: false }), 'solicitudes de actualización');
    },

    async updateMemberProfile(memberId, changes) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('update_pas_member_profile', {
        p_member_id: memberId,
        p_changes: changes
      }), 'actualización del expediente');
    },

    async reviewProfileChangeRequest(requestId, decision, response = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('review_pas_profile_change_request', {
        p_request_id: requestId,
        p_decision: decision,
        p_admin_response: response || null
      }), 'resolución de solicitud');
    },

    async manageMemberAccess(action, memberId, email) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const result = await client.functions.invoke('manage-member-access', {
        body: { action, member_id: memberId, email }
      });
      if (result.error) {
        let message = result.error.message || 'No se pudo administrar el acceso.';
        try {
          const payload = await result.error.context?.json?.();
          if (payload?.error) message = payload.error;
        } catch (_) {}
        throw new Error(message);
      }
      if (result.data?.error) throw new Error(result.data.error);
      return result.data;
    },

    async registerMember({ name, type, expiresOn }) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const data = await unwrap(
        client.rpc('register_pas_member', {
          p_full_name: name,
          p_member_type: type,
          p_expires_on: expiresOn
        }),
        'registro de miembro'
      );
      const row = Array.isArray(data) ? data[0] : data;
      if (!row?.public_identifier) throw new Error('El miembro se registró, pero no se recibió el identificador.');
      return row;
    },

    async setMemberStatus(memberId, status) {
      const statusMap = { Activo: 'active', Suspendido: 'suspended', Inactivo: 'inactive' };
      const value = statusMap[status];
      if (!value) throw new Error('Estado de membresía no válido.');
      await unwrap(client.rpc('set_pas_member_status', { p_member_id: memberId, p_status: value }), 'cambio de estado');
    },

    async revokeCredential(credentialId) {
      if (!credentialId) throw new Error('No se encontró una credencial asociada para revocar.');
      await unwrap(client.rpc('revoke_pas_credential', { p_credential_id: credentialId }), 'revocación de credencial');
    },

    async issueCredential(memberId, expiresOn) {
      const data = await unwrap(
        client.rpc('issue_pas_credential', { p_member_id: memberId, p_expires_on: expiresOn }),
        'emisión de credencial'
      );
      const row = Array.isArray(data) ? data[0] : data;
      if (!row?.public_identifier) throw new Error('No se recibió el identificador de la nueva credencial.');
      return row;
    },

    async listEvents() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('events').select('id,title,description,starts_at,ends_at,location,published,created_at').order('starts_at', { ascending: false }), 'eventos');
    },

    async createEvent(eventData) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const { data: userData } = await client.auth.getUser();
      return unwrap(client.from('events').insert({ ...eventData, created_by: userData.user?.id || null }).select('id,title,description,starts_at,ends_at,location,published,created_at').single(), 'creación del evento');
    },

    async updateEvent(eventId, changes) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('events').update(changes).eq('id', eventId).select('id,title,description,starts_at,ends_at,location,published,created_at').single(), 'actualización del evento');
    },

    async deleteEvent(eventId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      await unwrap(client.from('events').delete().eq('id', eventId), 'cancelación del evento');
    },

    async listAttendance(eventId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('event_attendance').select('id,event_id,member_id,checked_in_at,members(id,full_name,legacy_folio,member_type)').eq('event_id', eventId).order('checked_in_at', { ascending: false }), 'asistencias');
    },

    async listPublishedEvents() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('events').select('id,title,description,starts_at,ends_at,location').eq('published', true).order('starts_at', { ascending: true }), 'eventos publicados');
    },

    async listMyAttendance() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('event_attendance').select('id,checked_in_at,events(id,title,starts_at,location)').order('checked_in_at', { ascending: false }), 'mi historial de asistencia');
    },

    async addAttendance(eventId, memberId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('event_attendance').insert({ event_id: eventId, member_id: memberId }).select('id,event_id,member_id,checked_in_at').single(), 'registro de asistencia');
    },

    async removeAttendance(attendanceId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      await unwrap(client.from('event_attendance').delete().eq('id', attendanceId), 'eliminación de asistencia');
    },

    async verify(identifier) {
      const data = await unwrap(
        client.rpc('verify_pas_credential', { p_identifier: String(identifier || '').trim() }),
        'verificación pública'
      );
      return Array.isArray(data) ? data[0] : data;
    }
  };

  function isoToSpanish(value) {
    if (!value) return '';
    const parts = String(value).slice(0, 10).split('-');
    return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : String(value);
  }

  function mapMember(row) {
    const credential = [...(row.credentials || [])].sort((a, b) =>
      new Date(b.issued_at).getTime() - new Date(a.issued_at).getTime()
    )[0] || null;
    let status = 'Activo';
    if (row.membership_status === 'suspended') status = 'Suspendido';
    else if (row.membership_status === 'inactive') status = 'Inactivo';
    else if (credential?.credential_status === 'revoked') status = 'Revocado';
    else if (credential?.credential_status === 'replaced') status = 'Sustituido';
    else if ((credential?.expires_on || row.expires_on) && new Date(`${credential?.expires_on || row.expires_on}T23:59:59`) < new Date()) status = 'Vencido';

    return {
      id: row.legacy_folio || credential?.public_identifier || row.id,
      backendId: row.id,
      credentialId: credential?.id || null,
      publicIdentifier: credential?.public_identifier || null,
      name: row.full_name,
      type: row.member_type,
      issued: isoToSpanish(credential?.issued_at ? credential.issued_at.slice(0, 10) : row.issued_on),
      expires: isoToSpanish(credential?.expires_on || row.expires_on),
      status,
      historical: Boolean(row.is_historical),
      membershipStatus: row.membership_status,
      authUserId: row.auth_user_id || null,
      profile: Array.isArray(row.member_profiles) ? (row.member_profiles[0] || {}) : (row.member_profiles || {})
    };
  }

  window.PASIDBackend = api;
})();
