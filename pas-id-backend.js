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
          .select('id,legacy_folio,full_name,member_type,membership_status,issued_on,expires_on,is_historical,auth_user_id,member_profiles(contact_email,phone,professional_license,specialty,city,state,about,photo_path),credentials(id,public_identifier,credential_status,issued_at,expires_on,is_historical)')
          .order('full_name', { ascending: true }),
        'directorio de miembros'
      );
      return rows.map(mapMember);
    },

    async listPublicDirectory(filters = {}) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_pas_public_directory', {
        p_search: filters.search || null,
        p_city: filters.city || null,
        p_specialty: filters.specialty || null
      }), 'directorio profesional público');
    },

    async listNotifications() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_my_pas_notifications'), 'notificaciones');
    },

    async markNotificationRead(notificationId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('mark_pas_notification_read', { p_notification_id: notificationId }), 'notificación');
    },

    async listMemberDocumentNotifications() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_my_pas_member_document_notifications'), 'avisos de documentación');
    },

    async markMemberDocumentNotificationRead(notificationId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('mark_pas_member_document_notification_read', { p_notification_id: notificationId }), 'aviso documental');
    },

    async publishNotification(payload) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('publish_pas_notification', {
        p_title: payload.title, p_body: payload.body,
        p_audience: payload.audience, p_member_type: payload.memberType || null
      }), 'publicación de notificación');
    },

    async getMyProfile() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('get_my_pas_profile'), 'expediente del afiliado');
    },

    async submitProfileChangeRequest(changes) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('submit_my_pas_profile_change_request', { p_changes: changes }), 'solicitud de actualización');
    },

    async uploadProfilePhoto(file, memberId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      if (!file || !memberId) throw new Error('Selecciona una fotografía válida.');
      const allowed = ['image/jpeg','image/png','image/webp'];
      if (!allowed.includes(file.type)) throw new Error('La fotografía debe estar en formato JPG, PNG o WEBP.');
      if (file.size > 3 * 1024 * 1024) throw new Error('La fotografía no puede superar 3 MB.');
      const ext = file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg';
      const path = `${memberId}/${crypto.randomUUID()}.${ext}`;
      await unwrap(client.storage.from('pas-profile-photos').upload(path, file, { contentType:file.type, cacheControl:'3600', upsert:false }), 'carga de fotografía');
      return path;
    },

    async submitProfilePhotoChangeRequest(photoPath) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('submit_my_pas_photo_change_request', { p_photo_path: photoPath }), 'solicitud de fotografía');
    },

    publicProfilePhotoUrl(path) {
      if (!configured || !path) return '';
      return client.storage.from('pas-profile-photos').getPublicUrl(path).data.publicUrl;
    },

    async createInstitutionalRequest(payload) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('submit_pas_request', { p_request: payload }), 'envío de solicitud');
    },

    async listMyInstitutionalRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('institutional_requests')
        .select('id,request_number,category,subject,description,related_place,proposed_date,request_status,submitted_at,admin_response,claimed_by,claimed_by_name,claimed_at,last_activity_at,closed_at,source_type,source_request_id')
        .order('last_activity_at', { ascending: false }), 'mis solicitudes');
    },

    async listInstitutionalRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('institutional_requests')
        .select('id,request_number,requester_user_id,requester_email,requester_name,requester_role,category,subject,description,related_place,proposed_date,request_status,submitted_at,admin_response,claimed_by,claimed_by_name,claimed_at,last_activity_at,closed_at,source_type,source_request_id')
        .order('last_activity_at', { ascending: false }), 'solicitudes institucionales');
    },

    async claimInstitutionalRequest(requestId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('claim_pas_request', { p_request_id: requestId }), 'asignación de solicitud');
    },

    async listRequestMessages(requestId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('institutional_request_messages')
        .select('id,request_id,sender_user_id,sender_role,sender_name,body,created_at,read_at')
        .eq('request_id', requestId).order('created_at', { ascending: true }), 'conversación de solicitud');
    },

    async listRequestEvents(requestId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('institutional_request_events')
        .select('id,request_id,actor_user_id,actor_name,event_type,details,created_at')
        .eq('request_id', requestId).order('created_at', { ascending: true }), 'historial de solicitud');
    },

    async sendRequestMessage(requestId, body) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('send_pas_request_message', { p_request_id: requestId, p_body: body }), 'envío de mensaje');
    },

    async markRequestMessagesRead(requestId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('mark_pas_request_messages_read', { p_request_id: requestId }), 'lectura de mensajes');
    },

    async countUnreadRequestMessages() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('count_my_pas_request_unread_messages'), 'mensajes sin leer');
    },

    async listUnreadRequestPreviews() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_my_pas_request_unread_previews'), 'mensajes nuevos de solicitudes');
    },

    async updateInstitutionalRequestStatus(requestId, status, response = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('update_pas_request_status', { p_request_id: requestId, p_status: status, p_response: response || null }), 'actualización de solicitud');
    },

    async countUnassignedInstitutionalRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('count_pas_unassigned_requests'), 'solicitudes sin responsable');
    },

    async listUnassignedInstitutionalRequestPreviews() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_pas_unassigned_request_previews'), 'solicitudes pendientes de primera atención');
    },

    async listDirectivaOperators() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('list_pas_directiva_operators'), 'integrantes de Directiva');
    },

    async transferInstitutionalRequest(requestId, newOwnerId = null) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('transfer_pas_request', { p_request_id: requestId, p_new_owner: newOwnerId }), 'transferencia de solicitud');
    },

    async reviewInstitutionalRequest(requestId, status, response = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('review_pas_request', { p_request_id: requestId, p_status: status, p_response: response || null }), 'respuesta de solicitud');
    },

    async listProfileChangeRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('member_profile_change_requests')
        .select('id,member_id,requested_changes,request_status,submitted_at,members(full_name,legacy_folio,member_type)')
        .order('submitted_at', { ascending: false }), 'solicitudes de actualización');
    },

    async listMyMemberDocumentRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('member_document_requests')
        .select('id,title,instructions,due_date,status,requested_at,submitted_at,storage_path,original_filename,mime_type,file_size,reviewed_at,review_notes,member_document_files(id,storage_path,original_filename,mime_type,file_size,uploaded_at,status,review_notes)')
        .order('requested_at', { ascending: false }), 'mis documentos solicitados');
    },

    async listMemberDocumentRequests() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('member_document_requests')
        .select('id,member_id,title,instructions,due_date,status,requested_at,submitted_at,storage_path,original_filename,mime_type,file_size,reviewed_at,review_notes,members(full_name,legacy_folio,member_type),member_document_files(id,storage_path,original_filename,mime_type,file_size,uploaded_at,status,review_notes)')
        .order('requested_at', { ascending: false }), 'documentación de integrantes');
    },

    async createMemberDocumentRequest({ memberId = null, title, instructions = '', dueDate = null }) {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('create_pas_member_document_request', {
        p_member_id: memberId || null, p_title: title, p_instructions: instructions || null, p_due_date: dueDate || null
      }), 'solicitud de documentación');
    },

    async uploadMyMemberDocument(requestId, files) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const selected = Array.from(files || []);
      if (!selected.length) throw new Error('Selecciona al menos un archivo.');
      if (selected.length > 10) throw new Error('Puedes entregar hasta 10 archivos por requerimiento.');
      const allowed = ['application/pdf','image/jpeg','image/png','image/webp'];
      for (const file of selected) {
        if (!allowed.includes(file.type)) throw new Error(`El archivo ${file.name} debe ser PDF, JPG, PNG o WEBP.`);
        if (file.size < 1 || file.size > 10 * 1024 * 1024) throw new Error(`El archivo ${file.name} supera el límite de 10 MB o está vacío.`);
      }
      const request = await unwrap(client.from('member_document_requests').select('id,member_id,status').eq('id', requestId).single(), 'solicitud de documento');
      if (!['pending','changes_requested'].includes(request.status)) throw new Error('Esta solicitud ya no admite una nueva entrega.');
      const uploaded = [];
      try {
        for (const file of selected) {
          const ext = file.type === 'application/pdf' ? 'pdf' : file.type === 'image/png' ? 'png' : file.type === 'image/webp' ? 'webp' : 'jpg';
          const path = `${request.member_id}/${request.id}/${crypto.randomUUID()}.${ext}`;
          await unwrap(client.storage.from('pas-member-documents').upload(path, file, { contentType:file.type, cacheControl:'3600', upsert:false }), 'carga de documento');
          uploaded.push({ storage_path:path, original_filename:String(file.name || `documento.${ext}`).slice(0,255), mime_type:file.type, file_size:file.size });
        }
        return await unwrap(client.rpc('submit_my_pas_member_documents', { p_request_id:request.id, p_files:uploaded }), 'envío de documentos');
      } catch (error) {
        if (uploaded.length) await client.storage.from('pas-member-documents').remove(uploaded.map(item=>item.storage_path)).catch(()=>{});
        throw error;
      }
    },

    async reviewMemberDocumentFile(fileId, decision, notes = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('review_pas_member_document_file', { p_file_id:fileId, p_decision:decision, p_notes:notes || null }), 'revisión de archivo');
    },

    async reviewMemberDocumentRequest(requestId, decision, notes = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.rpc('review_pas_member_document', { p_request_id: requestId, p_decision: decision, p_notes: notes || null }), 'revisión de documento');
    },

    async getMemberDocumentSignedUrl(path) {
      if (!configured || !path) throw new Error('No hay un documento disponible.');
      const data = await unwrap(client.storage.from('pas-member-documents').createSignedUrl(path, 90), 'acceso temporal al documento');
      return data.signedUrl;
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

    async manageMemberAccess(action, memberId, email = '') {
      if (!configured) throw new Error('Supabase no está configurado.');
      const result = await client.functions.invoke('manage-member-access', {
        body: { action, member_id: memberId, ...(email ? { email } : {}) }
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

    async listCertificates() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('certificates').select('id,member_id,event_id,certificate_number,title,issued_at,revoked_at,members(id,full_name,legacy_folio,member_type),events(id,title,starts_at)').order('issued_at', { ascending: false }), 'constancias');
    },

    async listMyCertificates() {
      if (!configured) throw new Error('Supabase no está configurado.');
      return unwrap(client.from('certificates').select('id,certificate_number,title,issued_at,revoked_at,events(title,starts_at)').order('issued_at', { ascending: false }), 'mis constancias');
    },

    async issueCertificate({ memberId, eventId, title, certificateNumber }) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const { data: userData } = await client.auth.getUser();
      return unwrap(client.from('certificates').insert({ member_id: memberId, event_id: eventId || null, title, certificate_number: certificateNumber, created_by: userData.user?.id || null }).select('id,member_id,event_id,certificate_number,title,issued_at,revoked_at').single(), 'emisión de constancia');
    },

    async revokeCertificate(certificateId) {
      if (!configured) throw new Error('Supabase no está configurado.');
      const { data: userData } = await client.auth.getUser();
      return unwrap(client.from('certificates').update({ revoked_at: new Date().toISOString(), revoked_by: userData.user?.id || null }).eq('id', certificateId).is('revoked_at', null).select('id').single(), 'revocación de constancia');
    },

    async verify(identifier) {
      const data = await unwrap(
        client.rpc('verify_pas_credential_public', { p_identifier: String(identifier || '').trim() }),
        'verificación pública'
      );
      return Array.isArray(data) ? data[0] : data;
    },

    async verifyCertificate(certificateNumber) {
      if (!configured) throw new Error('El servicio de verificación no está disponible.');
      const data = await unwrap(
        client.rpc('verify_pas_certificate', {
          p_certificate_number: String(certificateNumber || '').trim()
        }),
        'verificación pública de constancia'
      );
      return Array.isArray(data) ? data[0] || null : data || null;
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
