'use strict';

const STORAGE_KEY = 'pas_id_prototype_members_v1';
const foundingMembers = [
  { id: '0000001', name: 'Manuel Alejandro Perdomo López', type: 'Miembro fundador', issued: '04/11/2026', expires: '04/11/2027', status: 'Activo', historical: true },
  { id: '0000002', name: 'Josefina Sánchez Félix', type: 'Miembro fundador', issued: '04/11/2026', expires: '04/11/2027', status: 'Activo', historical: true },
  { id: '0000003', name: 'Verónica Meza Santizo', type: 'Miembro fundador', issued: '04/11/2026', expires: '04/11/2027', status: 'Activo', historical: true }
];
let members = loadMembers();
const pasBackend = window.PASIDBackend;
const connectedMode = Boolean(pasBackend && pasBackend.isConfigured());
const backendConfigured = Boolean(pasBackend && pasBackend.hasConfiguration());
const backendUnavailable = backendConfigured && !connectedMode;
let signedInEmail = '';
let signedInRole = '';
let currentMemberProfile = null;
let selectedMemberId = null;
let selectedCredentialMemberId = null;
let pendingRandomId = null;
let toastTimer;

let qrFallbackPromise = null;
async function ensureQrLibrary() {
  if (window.QRCode) return window.QRCode;
  if (!qrFallbackPromise) {
    qrFallbackPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = 'https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js';
      script.onload = () => window.QRCode ? resolve(window.QRCode) : reject(new Error('La biblioteca QR no quedó disponible.'));
      script.onerror = () => reject(new Error('No se pudo cargar la biblioteca para generar códigos QR.'));
      document.head.appendChild(script);
    });
  }
  return qrFallbackPromise;
}
async function drawVerificationQr(canvas, value, size) {
  const ctx = canvas?.getContext?.('2d');
  if (!ctx || !value) return false;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  try {
    const library = await ensureQrLibrary();
    if (typeof library.toCanvas === 'function') {
      await library.toCanvas(canvas, value, { width: size, margin: 1, color: { dark: '#173655', light: '#ffffff' } });
      return true;
    }
    // Compatibilidad con QRCode.js cuando la biblioteca principal no carga.
    const host = document.createElement('div');
    host.style.cssText = 'position:fixed;left:-10000px;top:-10000px;width:1px;height:1px;overflow:hidden';
    document.body.appendChild(host);
    try {
      new library(host, { text: value, width: size, height: size, colorDark: '#173655', colorLight: '#ffffff', correctLevel: library.CorrectLevel?.M || 0 });
      const generated = host.querySelector('canvas');
      if (!generated) throw new Error('La biblioteca QR no generó una imagen.');
      ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(generated, 0, 0, canvas.width, canvas.height);
      return true;
    } finally { host.remove(); }
  } catch (error) {
    console.warn('No se pudo generar el QR de verificación.', error);
    ctx.fillStyle = '#f1f4f7'; ctx.fillRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#52677e'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('QR no disponible', canvas.width / 2, canvas.height / 2);
    return false;
  }
}

// Ajusta las etiquetas que en el HTML base describen el modo de demostración.
// En modo conectado, los formularios de altas y cambios utilizan las funciones RPC de Supabase.
if (connectedMode) {
  const memberSubmit = document.querySelector('#memberForm button[type="submit"]');
  const memberHelp = document.querySelector('#memberModal .field-help');
  const memberNote = document.querySelector('#view-members .bottom-note p');
  const verifyNote = document.querySelector('#view-verification .verify-disclaimer');
  const footerStatus = document.querySelector('.app-footer span:last-child');
  const dashboardNote = document.querySelector('#view-overview .bottom-note p');
  const dashboardTag = document.querySelector('#view-overview .bottom-note .note-tag');
  const activeStatNote = document.querySelector('#view-overview #statActive')?.parentElement?.querySelector('small');
  const verificationHeading = document.querySelector('#view-verification .page-heading p');
  const settingsNotice = document.querySelector('#view-settings .bottom-note p');
  if (memberSubmit) memberSubmit.innerHTML = 'Registrar miembro <span>→</span>';
  if (memberHelp) memberHelp.textContent = 'El registro se guardará en la base institucional y recibirá un identificador aleatorio generado por el servidor.';
  if (memberNote) memberNote.textContent = 'Los folios históricos de los fundadores se conservan. Las nuevas altas se registran en la base institucional con identificadores aleatorios revocables.';
  if (verifyNote) verifyNote.textContent = 'La consulta se realiza en línea desde la base de datos institucional de PAS ID y muestra únicamente información autorizada para verificación pública.';
  if (footerStatus) footerStatus.innerHTML = '<i></i> PAS ID · Entorno conectado · Fase de pruebas';
  if (dashboardNote) dashboardNote.innerHTML = '<strong>Base institucional conectada.</strong> Los registros, estados y verificaciones se consultan en Supabase. La plataforma continúa en fase de pruebas; valida los procedimientos antes de su operación institucional definitiva.';
  if (dashboardTag) dashboardTag.textContent = 'PRUEBAS';
  if (activeStatNote) activeStatNote.innerHTML = '<span class="stat-positive">Estado vigente</span> en la base institucional';
  if (verificationHeading) verificationHeading.textContent = 'Comprueba en línea el estado vigente de una credencial PAS.';
  if (settingsNotice) settingsNotice.innerHTML = '<strong>Entorno conectado en fase de pruebas.</strong> La autenticación, el directorio y la verificación pública ya consultan Supabase. Antes de operar oficialmente, completa las pruebas de permisos, respaldos, privacidad y emisión de credenciales.';
  const integrationHeading = document.querySelector('#view-settings .settings-card:nth-child(2) h3');
  const integrationEyebrow = document.querySelector('#view-settings .settings-card:nth-child(2) .eyebrow');
  const integrationStatuses = document.querySelectorAll('#view-settings .integration-list li em');
  if (integrationHeading) integrationHeading.textContent = 'Estado de la infraestructura';
  if (integrationEyebrow) integrationEyebrow.textContent = 'ESTADO DE INTEGRACIÓN';
  ['Conectada', 'Conectada', 'Publicado', 'Pendiente'].forEach((value, index) => {
    if (integrationStatuses[index]) integrationStatuses[index].textContent = value;
  });
}

function loadMembers() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved ? JSON.parse(saved) : structuredClone(foundingMembers);
  } catch (error) {
    console.warn('No se pudieron leer los datos locales de demostración.', error);
    return structuredClone(foundingMembers);
  }
}
function saveMembers() {
  try { localStorage.setItem(STORAGE_KEY, JSON.stringify(members)); }
  catch (error) { showToast('No fue posible guardar el cambio en este navegador.'); }
}
function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
}
function initials(name) {
  return String(name).trim().split(/\s+/).slice(0, 2).map(part => part[0] || '').join('').toUpperCase();
}
function normalize(text) {
  return String(text).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
}
function parseDate(dateText) {
  const parts = String(dateText || '').split('/');
  if (parts.length !== 3) return null;
  const day = Number(parts[0]), month = Number(parts[1]), year = Number(parts[2]);
  const fullYear = year < 100 ? year + 2000 : year;
  const date = new Date(fullYear, month - 1, day, 23, 59, 59);
  return Number.isNaN(date.getTime()) ? null : date;
}
function effectiveStatus(member) {
  if (member.status === 'Activo') {
    const expiry = parseDate(member.expires);
    if (expiry && expiry < new Date()) return 'Vencido';
  }
  return member.status;
}
function formatDate(dateText) {
  const date = parseDate(dateText);
  if (!date) return dateText || '—';
  return date.toLocaleDateString('es-MX', { day:'2-digit', month:'short', year:'numeric' });
}
function statusClass(status) {
  return ({'Activo':'status-active','Suspendido':'status-suspended','Revocado':'status-revoked','Vencido':'status-expired','Inactivo':'status-expired','Sustituido':'status-expired'})[status] || 'status-suspended';
}
function statusBadge(status) {
  return `<span class="status-pill ${statusClass(status)}">${escapeHtml(status)}</span>`;
}
function showToast(message) {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('show'), 2800);
}
function updateStats() {
  const counts = members.reduce((acc, member) => {
    const status = effectiveStatus(member);
    acc.total++;
    if (status === 'Activo') acc.active++;
    else acc.inactive++;
    return acc;
  }, { total:0, active:0, inactive:0 });
  document.getElementById('statTotal').textContent = counts.total;
  document.getElementById('statActive').textContent = counts.active;
  document.getElementById('statInactive').textContent = counts.inactive;
  document.getElementById('navMemberCount').textContent = counts.total;
  document.getElementById('directoryCount').textContent = `${counts.total} ${counts.total === 1 ? 'registro' : 'registros'}`;
  document.getElementById('credentialCount').textContent = `${counts.total} registros`;
  document.getElementById('activeLine').style.width = counts.total ? `${counts.active / counts.total * 100}%` : '0%';
  document.getElementById('inactiveLine').style.width = counts.total ? `${counts.inactive / counts.total * 100}%` : '0%';
}
function renderRecent() {
  const recent = [...members].slice(-4).reverse();
  document.getElementById('recentMembers').innerHTML = recent.length ? recent.map(member => `
    <div class="recent-row"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div class="member-info"><b>${escapeHtml(member.name)}</b><small>${escapeHtml(member.id)} · ${escapeHtml(member.type)}</small></div>${statusBadge(effectiveStatus(member))}</div>`).join('') : '<p class="muted">No hay registros todavía.</p>';
}
function renderMembers() {
  const query = normalize(document.getElementById('memberSearch').value.trim());
  const filter = document.getElementById('statusFilter').value;
  const filtered = members.filter(member => {
    const found = !query || normalize(member.name).includes(query) || normalize(member.id).includes(query) || normalize(member.type).includes(query);
    return found && (filter === 'all' || effectiveStatus(member) === filter);
  });
  document.getElementById('membersTable').innerHTML = filtered.map(member => `
    <tr><td><div class="table-member"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div><b>${escapeHtml(member.name)}</b><small>${member.historical ? 'Registro histórico fundador' : (connectedMode ? 'Registro institucional' : 'Registro de demostración')}</small></div></div></td>
    <td><span class="folio">${escapeHtml(member.id)}</span></td><td><span class="type-label">${escapeHtml(member.type)}</span></td><td>${escapeHtml(formatDate(member.expires))}</td><td>${statusBadge(effectiveStatus(member))}</td><td><span class="account-status ${member.authUserId ? 'linked' : 'unlinked'}">${member.authUserId ? 'Vinculada' : 'Sin cuenta'}</span></td><td><button class="action-button" data-manage="${escapeHtml(member.id)}" aria-label="Gestionar ${escapeHtml(member.name)}" title="Gestionar miembro">⋯</button></td></tr>`).join('');
  document.getElementById('emptyMembers').classList.toggle('hidden', filtered.length > 0);
}
function renderCredentials() {
  const list = document.getElementById('credentialList');
  list.innerHTML = members.map(member => `
    <div class="credential-row"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div><b>${escapeHtml(member.name)}</b><small>${escapeHtml(member.id)} · ${escapeHtml(effectiveStatus(member))}</small></div><button type="button" class="text-button" data-preview-credential="${escapeHtml(member.id)}">Ver tarjeta</button></div>`).join('');
  const preview = members.find(member => member.id === selectedCredentialMemberId) || null;
  const badge = document.getElementById('credentialPreviewBadge');
  const name = document.getElementById('credentialPreviewName');
  const type = document.getElementById('credentialPreviewType');
  const identifier = document.getElementById('credentialPreviewId');
  const monogram = document.getElementById('credentialPreviewMonogram');
  const issued = document.getElementById('credentialPreviewIssued');
  const expires = document.getElementById('credentialPreviewExpires');
  const status = document.getElementById('credentialPreviewStatus');
  const canvas = document.getElementById('credentialPreviewQr');
  const qrHeading = document.getElementById('credentialQrHeading');
  const qrHelp = document.getElementById('credentialQrHelp');
  const copyButton = document.getElementById('copyCredentialPreviewUrl');
  if (!preview) {
    name.textContent = members.length ? 'Selecciona un miembro' : 'Sin miembros registrados'; type.textContent = 'VISTA DE DIRECTIVA'; identifier.textContent = '—'; monogram.textContent = 'PAS';
    issued.textContent = '—'; expires.textContent = '—'; status.innerHTML = '<i></i> SIN SELECCIÓN';
    badge.textContent = 'VISTA GENERAL'; qrHeading.textContent = 'Sin credencial seleccionada'; qrHelp.textContent = 'Elige «Ver tarjeta» en un miembro del directorio para consultar su credencial.';
    copyButton.disabled = true; copyButton.dataset.url = '';
    const ctx = canvas.getContext('2d'); ctx.clearRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#f1f4f7'; ctx.fillRect(0,0,canvas.width,canvas.height); ctx.fillStyle='#52677e'; ctx.font='10px sans-serif'; ctx.textAlign='center'; ctx.fillText('SELECCIONA',canvas.width/2,canvas.height/2-4); ctx.fillText('UN MIEMBRO',canvas.width/2,canvas.height/2+10);
    return;
  }
  const publicId = preview.publicIdentifier || preview.id;
  const verifyUrl = buildVerificationUrl(publicId);
  badge.textContent = connectedMode ? 'CREDENCIAL REAL' : 'VISTA LOCAL';
  name.textContent = preview.name;
  type.textContent = String(preview.type || 'MIEMBRO PAS').toUpperCase();
  identifier.textContent = publicId;
  monogram.textContent = initials(preview.name);
  issued.textContent = formatDate(preview.issued).toUpperCase();
  expires.textContent = formatDate(preview.expires).toUpperCase();
  status.innerHTML = `<i></i> ${escapeHtml(effectiveStatus(preview).toUpperCase())}`;
  qrHeading.textContent = `QR · ${preview.name}`;
  qrHelp.textContent = 'El mismo enlace puede grabarse en una etiqueta NFC compatible.';
  copyButton.disabled = false; copyButton.dataset.url = verifyUrl;
  drawVerificationQr(canvas, verifyUrl, 112);
}
function renderAll() {
  updateStats(); renderRecent(); renderMembers(); renderCredentials();
}
function profileChangeLabel(key) {
  return ({contact_email:'Correo de contacto',phone:'Teléfono',professional_license:'Cédula profesional',specialty:'Área / especialidad',city:'Municipio',state:'Estado',about:'Presentación profesional'})[key] || key;
}
async function loadProfileRequests() {
  const target = document.getElementById('profileRequestsList');
  if (!target || !connectedMode || signedInRole !== 'directiva') return;
  target.innerHTML = '<p class="muted">Consultando solicitudes…</p>';
  try {
    const requests = await pasBackend.listProfileChangeRequests();
    const pending = requests.filter(item => item.request_status === 'pending').length;
    document.getElementById('profileRequestCount').textContent = `${pending} pendientes`;
    if (!requests.length) {
      target.innerHTML = '<p class="muted">Todavía no hay solicitudes de actualización.</p>';
      return;
    }
    target.innerHTML = requests.map(request => {
      const member = Array.isArray(request.members) ? request.members[0] : request.members;
      const changes = Object.entries(request.requested_changes || {}).map(([key,value]) => `<div class="request-change"><span>${escapeHtml(profileChangeLabel(key))}</span><b>${escapeHtml(value || '—')}</b></div>`).join('');
      const status = request.request_status === 'approved' ? 'Aprobada' : request.request_status === 'rejected' ? 'Rechazada' : 'Pendiente';
      return `<article class="profile-request-item"><div class="profile-request-head"><div><b>${escapeHtml(member?.full_name || 'Miembro PAS')}</b><small>${escapeHtml(member?.legacy_folio || member?.member_type || '')} · ${new Date(request.submitted_at).toLocaleDateString('es-MX')}</small></div><span class="request-status ${request.request_status}">${status}</span></div><div class="request-changes-grid">${changes}</div>${request.request_status === 'pending' ? `<div class="request-actions"><button type="button" class="btn btn-outline" data-review-request="${request.id}" data-decision="rejected">Rechazar</button><button type="button" class="btn btn-primary" data-review-request="${request.id}" data-decision="approved">Aprobar cambios</button></div>` : `<small class="request-response">${escapeHtml(request.admin_response || 'Solicitud atendida.')}</small>`}</article>`;
    }).join('');
  } catch (error) {
    console.error(error);
    target.innerHTML = `<p class="muted">No fue posible cargar las solicitudes: ${escapeHtml(error.message)}</p>`;
  }
}
function showView(viewName) {
  const target = document.getElementById(`view-${viewName}`);
  if (!target) return;
  document.querySelectorAll('.view').forEach(view => view.classList.remove('active'));
  target.classList.add('active');
  document.querySelectorAll('.nav-item[data-view]').forEach(button => button.classList.toggle('active', button.dataset.view === viewName));
  const labels = {overview:'Resumen',members:'Directorio de miembros',credentials:'Credenciales',events:'Eventos y asistencia',certificates:'Constancias',verification:'Verificar credencial',settings:'Configuración'};
  document.getElementById('breadcrumbCurrent').textContent = labels[viewName] || 'Plataforma';
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebarScrim').classList.remove('show');
  if (viewName === 'members') loadProfileRequests();
  if (viewName === 'events') loadEventsModule();
  window.scrollTo({top:0, behavior:'smooth'});
}
function openMemberModal() {
  pendingRandomId = connectedMode ? null : makeRandomId();
  document.getElementById('memberForm').reset();
  document.getElementById('generatedId').textContent = connectedMode ? 'Se generará de forma segura al registrar' : pendingRandomId;
  document.getElementById('memberModal').classList.remove('hidden');
  setTimeout(() => document.getElementById('newName').focus(), 50);
}
function makeRandomId() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const bytes = new Uint8Array(12);
  if (window.crypto?.getRandomValues) window.crypto.getRandomValues(bytes);
  else for (let i=0;i<bytes.length;i++) bytes[i] = Math.floor(Math.random()*256);
  let token = '';
  for (const byte of bytes) token += alphabet[byte % alphabet.length];
  return `PAS-${token}`;
}
function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
function showIssuedCredential(identifier) {
  document.getElementById('issuedIdentifier').textContent = identifier;
  const verifyUrl = new URL(window.location.href);
  verifyUrl.searchParams.set('verificar', identifier);
  document.getElementById('issuedVerificationUrl').textContent = verifyUrl.toString();
  document.getElementById('issuedModal').classList.remove('hidden');
}
function spanishDateToISO(dateText) {
  const parts = String(dateText || '').split('/');
  if (parts.length !== 3) return '';
  const [day, month, year] = parts;
  return `${year.length === 2 ? `20${year}` : year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
}
function defaultRenewalDate() {
  const date = new Date();
  date.setFullYear(date.getFullYear() + 1);
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
}
function openMemberDetail(id) {
  const member = members.find(item => item.id === id);
  if (!member) return;
  selectedMemberId = id;
  const profile = member.profile || {};
  document.getElementById('detailModalTitle').textContent = 'Gestionar miembro';
  document.getElementById('detailContent').innerHTML = `
    <div class="detail-top"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div><b>${escapeHtml(member.name)}</b><small>${escapeHtml(member.id)} · ${escapeHtml(member.type)}</small></div></div>
    <div class="detail-fields"><div class="detail-field"><span>FOLIO / IDENTIFICADOR</span><b>${escapeHtml(member.id)}</b></div><div class="detail-field"><span>TIPO DE REGISTRO</span><b>${escapeHtml(member.type)}</b></div><div class="detail-field"><span>EXPEDICIÓN</span><b>${escapeHtml(formatDate(member.issued))}</b></div><div class="detail-field"><span>VIGENCIA</span><b>${escapeHtml(formatDate(member.expires))}</b></div><div class="detail-field"><span>ESPECIALIDAD</span><b>${escapeHtml(profile.specialty || 'Sin capturar')}</b></div><div class="detail-field"><span>CÉDULA PROFESIONAL</span><b>${escapeHtml(profile.professional_license || 'Sin capturar')}</b></div></div>
    ${connectedMode ? `<div class="admin-profile-editor"><div><span class="eyebrow">EXPEDIENTE DIGITAL</span><b>Datos del miembro</b><small>Estos datos son privados y solo los consulta el afiliado y la Directiva.</small></div><div class="admin-profile-grid"><div><label for="adminProfileEmail">CORREO DE CONTACTO</label><input id="adminProfileEmail" type="email" maxlength="254" value="${escapeHtml(profile.contact_email || '')}"></div><div><label for="adminProfilePhone">TELÉFONO</label><input id="adminProfilePhone" maxlength="40" value="${escapeHtml(profile.phone || '')}"></div><div><label for="adminProfileLicense">CÉDULA PROFESIONAL</label><input id="adminProfileLicense" maxlength="80" value="${escapeHtml(profile.professional_license || '')}"></div><div><label for="adminProfileSpecialty">ÁREA / ESPECIALIDAD</label><input id="adminProfileSpecialty" maxlength="160" value="${escapeHtml(profile.specialty || '')}"></div><div><label for="adminProfileCity">MUNICIPIO</label><input id="adminProfileCity" maxlength="100" value="${escapeHtml(profile.city || '')}"></div><div><label for="adminProfileState">ESTADO</label><input id="adminProfileState" maxlength="100" value="${escapeHtml(profile.state || '')}"></div><div class="wide"><label for="adminProfileAbout">PRESENTACIÓN PROFESIONAL</label><textarea id="adminProfileAbout" rows="2" maxlength="300">${escapeHtml(profile.about || '')}</textarea></div></div><button type="button" class="btn btn-outline" id="saveAdminMemberProfile">Guardar datos del expediente</button><small class="field-help">El correo de contacto no cambia automáticamente el correo de inicio de sesión.</small></div>` : ''}
    <div class="access-panel"><div class="access-panel-head"><div><span class="eyebrow">CUENTA PERSONAL PAS ID</span><b>${member.authUserId ? 'Cuenta vinculada' : 'Sin cuenta individual'}</b></div><span class="account-status ${member.authUserId ? 'linked' : 'unlinked'}">${member.authUserId ? 'Vinculada' : 'Pendiente'}</span></div>
    ${member.authUserId ? `<p class="access-help">Este expediente ya está vinculado a una cuenta de acceso. El rol se determina según el tipo de miembro.</p>` : `<label for="memberAccessEmail">CORREO PARA EL ACCESO</label><input id="memberAccessEmail" type="email" maxlength="254" value="${escapeHtml(profile.contact_email || '')}" placeholder="correo@ejemplo.com"><div class="access-actions"><button type="button" class="btn btn-outline" id="linkExistingMemberAccount">Vincular cuenta existente</button><button type="button" class="btn btn-primary" id="inviteMemberAccount">Enviar invitación y vincular →</button></div><small class="field-help">La invitación llega por correo y permite crear una contraseña propia. Para cuentas ya existentes, utiliza la opción de vincular.</small>`}</div>
    <div class="status-edit"><label for="detailStatus">ESTADO DE MEMBRESÍA / CREDENCIAL</label><select id="detailStatus"><option ${member.status==='Activo'?'selected':''}>Activo</option><option ${member.status==='Suspendido'?'selected':''}>Suspendido</option><option ${member.status==='Revocado'?'selected':''}>Revocado</option><option ${member.status==='Vencido'?'selected':''} disabled>Vencido (requiere renovación)</option><option ${member.status==='Sustituido'?'selected':''} disabled>Sustituido</option><option ${member.status==='Inactivo'?'selected':''}>Inactivo</option></select></div>
    ${connectedMode ? `<div class="renewal-box"><label for="renewalExpiry">NUEVA VIGENCIA PARA REEMISIÓN</label><input id="renewalExpiry" type="date" min="${new Date().toISOString().slice(0,10)}" value="${defaultRenewalDate()}"><small>La reemisión sustituye la credencial activa anterior. El folio histórico se conserva, pero la credencial anterior dejará de validarse.</small><button class="btn btn-outline" type="button" id="issueReplacement">Emitir credencial renovada →</button></div>` : ''}
    <div class="detail-actions"><button class="btn btn-ghost" data-close-detail>Cancelar</button><button class="btn btn-primary" id="saveMemberStatus">Guardar cambio →</button></div>
    <p class="field-help">${member.historical ? 'Este es un folio histórico de fundador; el folio no se modifica.' : 'Identificador aleatorio asignado a esta credencial.'} ${connectedMode ? 'Los cambios se guardarán en la base de datos central y quedarán registrados.' : 'Los cambios son locales a este navegador.'}</p>`;
  document.getElementById('detailModal').classList.remove('hidden');
}

function findById(value) {
  const query = String(value || '').trim().toUpperCase();
  if (!query) return null;
  return members.find(member => member.id.toUpperCase() === query || member.id.replace(/^0+/, '') === query.replace(/^0+/, '')) || null;
}
function verificationMarkup(member) {
  const status = effectiveStatus(member);
  const label = status === 'Activo' ? 'Credencial vigente en el directorio' : `Credencial ${status.toLowerCase()}`;
  return `<div class="verification-card-result"><div class="verification-result-head"><span class="eyebrow">RESULTADO DE CONSULTA</span>${statusBadge(status)}</div><h3>${escapeHtml(member.name)}</h3><p>${escapeHtml(member.type)} · PAS</p><div class="verification-data"><div><span>FOLIO / IDENTIFICADOR</span><b>${escapeHtml(member.id)}</b></div><div><span>VIGENCIA</span><b>${escapeHtml(formatDate(member.expires))}</b></div></div><strong class="verification-label ${statusClass(status)}">${escapeHtml(label)}</strong><small class="verification-footnote">Consulta institucional de PAS ID.</small></div>`;
}
async function renderVerification(value, targetId) {
  const target = document.getElementById(targetId);
  const query = String(value || '').trim();
  if (!query) {
    target.innerHTML = `<div class="verification-not-found"><b>Escribe un folio o identificador.</b><span>Después podrás consultar su estado institucional.</span></div>`;
    return;
  }
  if (backendUnavailable) {
    target.innerHTML = `<div class="verification-not-found"><b>Servicio de verificación no disponible.</b><span>No se puede consultar la base de datos ahora. Vuelve a intentarlo.</span></div>`;
    return;
  }
  if (connectedMode) {
    target.innerHTML = '<div class="verification-not-found"><b>Consultando PAS ID…</b><span>Verificando el estado más reciente.</span></div>';
    try {
      const normalizedQuery = query.toUpperCase();
      let result = await pasBackend.verify(normalizedQuery);
      if ((!result || !result.found) && /^[A-Z0-9]{16,}$/.test(normalizedQuery)) {
        result = await pasBackend.verify(`PAS-${normalizedQuery}`);
      }
      if (!result || !result.found) {
        target.innerHTML = `<div class="verification-not-found"><b>No se encontró el registro.</b><span>Revisa el folio o identificador e inténtalo nuevamente.</span></div>`;
        return;
      }
      const statusMap = {active:'Activo', suspended:'Suspendido', inactive:'Inactivo', expired:'Vencido', revoked:'Revocado', replaced:'Sustituido'};
      const status = statusMap[result.verification_status] || 'No disponible';
      const folio = result.legacy_folio || query.toUpperCase();
      const label = status === 'Activo' ? 'Credencial vigente en el directorio institucional' : `Credencial ${status.toLowerCase()}`;
      target.innerHTML = `<div class="verification-card-result"><div class="verification-result-head"><span class="eyebrow">RESULTADO DE CONSULTA</span>${statusBadge(status)}</div><h3>${escapeHtml(result.full_name)}</h3><p>${escapeHtml(result.member_type)} · PAS</p><div class="verification-data"><div><span>FOLIO / IDENTIFICADOR</span><b>${escapeHtml(folio)}</b></div><div><span>VIGENCIA</span><b>${escapeHtml(formatDate(result.expires_on ? isoDateToSpanish(result.expires_on) : ''))}</b></div></div><strong class="verification-label ${statusClass(status)}">${escapeHtml(label)}</strong><small class="verification-footnote">Consulta en línea del registro institucional PAS ID.</small></div>`;
    } catch (error) {
      console.error(error);
      target.innerHTML = `<div class="verification-not-found"><b>No fue posible completar la consulta.</b><span>Inténtalo nuevamente más tarde.</span></div>`;
    }
    return;
  }
  const member = findById(query);
  if (!member) {
    target.innerHTML = `<div class="verification-not-found"><b>No se encontró el registro.</b><span>Revisa el folio o identificador e inténtalo nuevamente.</span></div>`;
    return;
  }
  target.innerHTML = verificationMarkup(member);
}
function isoDateToSpanish(value) {
  const parts = String(value || '').slice(0, 10).split('-');
  return parts.length === 3 ? `${parts[2]}/${parts[1]}/${parts[0]}` : value;
}
function spanishDateFromIso(value) {
  if (!value) return '—';
  const date = new Date(`${String(value).slice(0,10)}T12:00:00`);
  return Number.isNaN(date.getTime()) ? '—' : date.toLocaleDateString('es-MX', {day:'2-digit', month:'short', year:'numeric'});
}
function profileStatus(profile) {
  const member = profile.member || {};
  const credential = profile.credential || {};
  if (credential.credential_status === 'revoked') return 'Revocado';
  if (credential.credential_status === 'replaced') return 'Sustituido';
  if (member.membership_status === 'suspended') return 'Suspendido';
  if (member.membership_status === 'inactive') return 'Inactivo';
  const expiry = credential.expires_on || member.expires_on;
  if (expiry && new Date(`${expiry}T23:59:59`) < new Date()) return 'Vencido';
  return 'Activo';
}
function buildVerificationUrl(identifier) {
  const url = new URL(window.location.href);
  url.hash = '';
  url.search = '';
  url.searchParams.set('verificar', identifier);
  return url.toString();
}
function renderMemberRequests(requests = []) {
  const target = document.getElementById('memberRequestsList');
  if (!target) return;
  if (!requests.length) {
    target.innerHTML = '<p class="muted">No hay solicitudes registradas.</p>';
    return;
  }
  target.innerHTML = requests.map(request => {
    const status = request.request_status === 'approved' ? 'Aprobada' : request.request_status === 'rejected' ? 'Rechazada' : 'Pendiente';
    const changes = Object.entries(request.requested_changes || {}).map(([key,value]) => `${profileChangeLabel(key)}: ${value || '—'}`).join(' · ');
    return `<article class="member-request-row"><div><b>${status}</b><small>${new Date(request.submitted_at).toLocaleDateString('es-MX')} · ${escapeHtml(changes)}</small>${request.admin_response ? `<small>Respuesta de Directiva: ${escapeHtml(request.admin_response)}</small>` : ''}</div><span class="request-status ${request.request_status}">${status}</span></article>`;
  }).join('');
}
function portalEventDate(value) {
  if (!value) return 'Fecha por confirmar';
  return new Date(value).toLocaleString('es-MX', { dateStyle:'long', timeStyle:'short' });
}
async function loadMemberEvents() {
  const eventsTarget = document.getElementById('memberPublishedEvents');
  const attendanceTarget = document.getElementById('memberAttendanceHistory');
  if (!eventsTarget || !attendanceTarget) return;
  eventsTarget.innerHTML = '<p class="muted">Consultando agenda institucional…</p>';
  attendanceTarget.innerHTML = '<p class="muted">Consultando tu historial…</p>';
  try {
    const [events, attendance] = await Promise.all([pasBackend.listPublishedEvents(), pasBackend.listMyAttendance()]);
    eventsTarget.innerHTML = events.length ? events.map(item => `
      <article class="member-event-row"><div class="member-event-date">${escapeHtml(portalEventDate(item.starts_at))}</div><div class="member-event-copy"><b>${escapeHtml(item.title)}</b><span>${escapeHtml(item.location || 'Lugar por confirmar')}</span>${item.description ? `<p>${escapeHtml(item.description)}</p>` : ''}</div></article>`).join('') : '<p class="events-empty">Por el momento no hay próximos eventos publicados.</p>';
    attendanceTarget.innerHTML = attendance.length ? attendance.map(row => {
      const event = row.events || {};
      return `<article class="member-event-row member-attendance-row"><div class="member-event-date">Asistencia · ${escapeHtml(portalEventDate(row.checked_in_at))}</div><div class="member-event-copy"><b>${escapeHtml(event.title || 'Actividad PAS')}</b><span>${escapeHtml(event.location || 'Lugar no especificado')}</span></div><span class="member-attendance-pill">Registrada</span></article>`;
    }).join('') : '<p class="events-empty">Todavía no tienes asistencias registradas.</p>';
  } catch (error) {
    console.error('No se pudo cargar la agenda del afiliado.', error);
    eventsTarget.innerHTML = `<p class="events-empty">No se pudieron cargar los eventos. ${escapeHtml(error.message || '')}</p>`;
    attendanceTarget.innerHTML = `<p class="events-empty">No se pudo cargar tu historial. ${escapeHtml(error.message || '')}</p>`;
  }
}

function showMemberPortal(profile) {
  currentMemberProfile = profile;
  const member = profile.member || {};
  const detail = profile.profile || {};
  const credential = profile.credential || {};
  const identifier = credential.public_identifier || member.legacy_folio || 'Sin credencial';
  const status = profileStatus(profile);
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('passwordSetupScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('appShell').classList.add('hidden');
  document.getElementById('memberPortalScreen').classList.remove('hidden');
  document.getElementById('memberPortalName').textContent = member.full_name || 'Afiliado PAS';
  document.getElementById('memberPortalTitle').innerHTML = 'Mi expediente <em>institucional.</em>';
  document.getElementById('memberPortalAccountEmail').textContent = signedInEmail || '';
  document.getElementById('memberPortalType').textContent = member.member_type || (signedInRole === 'colaborador' ? 'Colaborador' : 'Afiliado');
  document.getElementById('memberPortalFolio').textContent = `Folio / identificador: ${member.legacy_folio || identifier}`;
  const badge = document.getElementById('memberPortalStatus');
  badge.textContent = status;
  badge.className = `status-pill ${statusClass(status)}`;
  document.getElementById('memberPortalIssued').textContent = spanishDateFromIso(member.issued_on);
  document.getElementById('memberPortalExpires').textContent = spanishDateFromIso(credential.expires_on || member.expires_on);
  document.getElementById('memberPortalSpecialty').textContent = detail.specialty || 'Por completar';
  document.getElementById('memberPortalLicense').textContent = detail.professional_license || 'Por completar';
  document.getElementById('memberPortalCredential').textContent = identifier;
  const verifyUrl = identifier !== 'Sin credencial' ? buildVerificationUrl(identifier) : '';
  const link = document.getElementById('memberPortalVerifyLink');
  link.href = verifyUrl || '#';
  link.classList.toggle('disabled-link', !verifyUrl);
  const canvas = document.getElementById('memberPortalQrCanvas');
  drawVerificationQr(canvas, verifyUrl, 168);
  const fields = {
    profileEmail: detail.contact_email || signedInEmail || '',
    profilePhone: detail.phone || '',
    profileLicense: detail.professional_license || '',
    profileSpecialty: detail.specialty || '',
    profileCity: detail.city || '',
    profileState: detail.state || '',
    profileAbout: detail.about || ''
  };
  Object.entries(fields).forEach(([id,value]) => { document.getElementById(id).value = value; });
  renderMemberRequests(profile.requests || []);
  loadMemberEvents();
}
async function activateAuthenticatedRole(role, session) {
  signedInRole = role || '';
  signedInEmail = session?.user?.email || signedInEmail || '';
  if (role === 'directiva') {
    members = await pasBackend.listMembers();
    document.getElementById('activeUserName').textContent = signedInEmail || 'Directiva PAS';
    document.getElementById('activeUserRole').textContent = 'Directiva · Conectado';
    document.getElementById('signOutButton').classList.remove('hidden');
    showApp();
    return;
  }
  if (role === 'afiliado' || role === 'colaborador') {
    const profile = await pasBackend.getMyProfile();
    showMemberPortal(profile);
    return;
  }
  await pasBackend.signOut();
  signedInRole = '';
  showLoginWithNotice('Tu cuenta todavía no tiene un rol institucional válido. Solicita apoyo a la Directiva PAS.');
}

function openPublicScreen() {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('memberPortalScreen').classList.add('hidden');
  document.getElementById('appShell').classList.add('hidden');
  document.getElementById('publicScreen').classList.remove('hidden');
}
function showApp() {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('memberPortalScreen').classList.add('hidden');
  document.getElementById('appShell').classList.remove('hidden');
  renderAll();
  showView('overview');
}
function showPasswordSetupScreen(message = '') {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('memberPortalScreen').classList.add('hidden');
  document.getElementById('appShell').classList.add('hidden');
  const screen = document.getElementById('passwordSetupScreen');
  screen.classList.remove('hidden');
  const messageBox = document.getElementById('passwordSetupMessage');
  messageBox.textContent = message;
  messageBox.classList.toggle('show', Boolean(message));
  messageBox.classList.remove('success');
}
function showLoginWithNotice(message) {
  document.getElementById('passwordSetupScreen').classList.add('hidden');
  document.getElementById('appShell').classList.add('hidden');
  document.getElementById('memberPortalScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
  const hint = document.querySelector('.login-hint');
  if (hint) hint.innerHTML = `<span class="info-dot">i</span> ${escapeHtml(message)}`;
}

// Con Supabase configurado, el acceso se enruta según el rol: Directiva, afiliado o colaborador.
// Sin configuración, se conserva la experiencia local limitada para revisión visual.
document.getElementById('passwordSetupForm').addEventListener('submit', async event => {
  event.preventDefault();
  if (!connectedMode) {
    showLoginWithNotice('No se pudo conectar con PAS ID. Solicita una nueva invitación a la Directiva.');
    return;
  }
  const password = document.getElementById('setupPassword').value;
  const confirmation = document.getElementById('setupPasswordConfirm').value;
  const message = document.getElementById('passwordSetupMessage');
  const submit = document.getElementById('saveSetupPassword');
  message.classList.add('show');
  message.classList.remove('success');
  if (password.length < 12) {
    message.textContent = 'La contraseña debe contener al menos 12 caracteres.';
    return;
  }
  if (password !== confirmation) {
    message.textContent = 'Las contraseñas no coinciden. Revísalas e inténtalo nuevamente.';
    return;
  }
  submit.disabled = true;
  submit.textContent = 'Guardando contraseña…';
  try {
    await pasBackend.updatePassword(password);
    document.getElementById('setupPassword').value = '';
    document.getElementById('setupPasswordConfirm').value = '';
    const role = await pasBackend.currentRole();
    const session = await pasBackend.getSession();
    window.history.replaceState({}, document.title, window.location.pathname + window.location.search.replace(/([?&])type=(invite|recovery)(&|$)/, '$1').replace(/[?&]$/, ''));
    await activateAuthenticatedRole(role, session);
    showToast('Cuenta activada. Bienvenido a PAS ID.');
  } catch (error) {
    message.textContent = error.message || 'No fue posible guardar la contraseña. Solicita una nueva invitación si el enlace venció.';
    message.classList.add('show');
    submit.disabled = false;
    submit.innerHTML = 'Guardar contraseña <span>→</span>';
    return;
  }
  submit.disabled = false;
  submit.innerHTML = 'Guardar contraseña <span>→</span>';
});

document.getElementById('enterDemo').addEventListener('click', async () => {
  if (backendUnavailable) { showToast('La configuración está presente, pero no se pudo cargar la biblioteca de conexión.'); return; }
  if (!connectedMode) { showApp(); return; }
  const button = document.getElementById('enterDemo');
  const email = document.getElementById('demoEmail').value.trim();
  const password = document.getElementById('demoPassword').value;
  button.disabled = true;
  button.innerHTML = 'Validando acceso…';
  try {
    const sessionData = await pasBackend.signIn(email, password);
    signedInEmail = sessionData.user?.email || email;
    const role = await pasBackend.currentRole();
    if (!urlParams.has('verificar')) await activateAuthenticatedRole(role, sessionData);
  } catch (error) {
    showToast(error.message || 'No se pudo iniciar sesión.');
  } finally {
    button.disabled = false;
    button.innerHTML = connectedMode ? 'Iniciar sesión <span>→</span>' : 'Explorar demostración <span>→</span>';
  }
});
document.getElementById('togglePassword').addEventListener('click', () => {
  const input = document.getElementById('demoPassword');
  input.type = input.type === 'password' ? 'text' : 'password';
});
document.getElementById('publicAccess').addEventListener('click', openPublicScreen);
document.getElementById('backToLogin').addEventListener('click', () => {
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
});
document.getElementById('profileChangeForm').addEventListener('submit', async event => {
  event.preventDefault();
  if (!currentMemberProfile) return;
  const existing = currentMemberProfile.profile || {};
  const values = {
    contact_email: document.getElementById('profileEmail').value.trim(),
    phone: document.getElementById('profilePhone').value.trim(),
    professional_license: document.getElementById('profileLicense').value.trim(),
    specialty: document.getElementById('profileSpecialty').value.trim(),
    city: document.getElementById('profileCity').value.trim(),
    state: document.getElementById('profileState').value.trim(),
    about: document.getElementById('profileAbout').value.trim()
  };
  const changes = Object.fromEntries(Object.entries(values).filter(([key,value]) => String(value) !== String(existing[key] || '')));
  if (!Object.keys(changes).length) { showToast('No hay cambios nuevos para enviar.'); return; }
  const button = document.getElementById('submitProfileChanges');
  button.disabled = true; button.textContent = 'Enviando solicitud…';
  try {
    await pasBackend.submitProfileChangeRequest(changes);
    currentMemberProfile = await pasBackend.getMyProfile();
    showMemberPortal(currentMemberProfile);
    showToast('Solicitud enviada. La Directiva revisará los cambios.');
  } catch (error) {
    showToast(error.message || 'No se pudo enviar la solicitud.');
  } finally {
    button.disabled = false; button.textContent = 'Enviar actualización a Directiva →';
  }
});
document.getElementById('memberSignOutButton').addEventListener('click', async () => {
  try { if (connectedMode) await pasBackend.signOut(); } catch (error) { console.warn(error); }
  signedInRole = ''; signedInEmail = ''; currentMemberProfile = null;
  document.getElementById('memberPortalScreen').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
  document.getElementById('demoPassword').value = '';
  showToast('Sesión cerrada.');
});
document.getElementById('copyMemberCredential').addEventListener('click', async () => {
  const value = document.getElementById('memberPortalCredential').textContent.trim();
  try { await navigator.clipboard.writeText(value); showToast('Identificador copiado.'); }
  catch (_) { showToast('No se pudo copiar. Selecciona el identificador manualmente.'); }
});

document.getElementById('publicVerifyForm').addEventListener('submit', event => {
  event.preventDefault();
  const value = document.getElementById('publicVerifyInput').value;
  renderVerification(value, 'publicVerifyResult');
});
document.getElementById('internalVerifyForm').addEventListener('submit', event => {
  event.preventDefault();
  renderVerification(document.getElementById('internalVerifyInput').value, 'internalVerifyResult');
});
document.querySelectorAll('.nav-item[data-view]').forEach(button => button.addEventListener('click', () => showView(button.dataset.view)));
document.addEventListener('click', event => {
  const go = event.target.closest('[data-go]');
  if (go) showView(go.dataset.go);
  const action = event.target.closest('[data-action]');
  if (action?.dataset.action === 'new-member') openMemberModal();
  const manage = event.target.closest('[data-manage]');
  if (manage) openMemberDetail(manage.dataset.manage);
  if (event.target.closest('[data-close-modal]')) closeModal('memberModal');
  if (event.target.closest('[data-close-detail]')) closeModal('detailModal');
});
document.getElementById('credentialList').addEventListener('click', event => {
  const button = event.target.closest('[data-preview-credential]');
  if (!button) return;
  selectedCredentialMemberId = button.dataset.previewCredential;
  renderCredentials();
});
document.getElementById('copyCredentialPreviewUrl').addEventListener('click', async event => {
  const url = event.currentTarget.dataset.url || '';
  if (!url) return;
  try { await navigator.clipboard.writeText(url); showToast('Enlace de verificación copiado para QR/NFC.'); }
  catch (_) { showToast('No se pudo copiar el enlace.'); }
});
document.getElementById('memberSearch').addEventListener('input', renderMembers);
document.getElementById('statusFilter').addEventListener('change', renderMembers);
document.getElementById('memberForm').addEventListener('submit', async event => {
  event.preventDefault();
  const name = document.getElementById('newName').value.trim();
  if (!name) return;
  const expiry = document.getElementById('newExpiry').value;
  const expiryDate = expiry ? new Date(`${expiry}T12:00:00`) : new Date(new Date().setFullYear(new Date().getFullYear()+1));
  if (connectedMode) {
    const submit = event.currentTarget.querySelector('button[type="submit"]');
    submit.disabled = true;
    try {
      const result = await pasBackend.registerMember({
        name,
        type: document.getElementById('newType').value,
        expiresOn: expiry || expiryDate.toISOString().slice(0, 10)
      });
      members = await pasBackend.listMembers();
      renderAll(); closeModal('memberModal');
      showIssuedCredential(result.public_identifier);
      document.getElementById('memberSearch').value = '';
      document.getElementById('statusFilter').value = 'all';
      showView('members');
      showToast(`Miembro registrado. Identificador: ${result.public_identifier}`);
    } catch (error) {
      showToast(error.message || 'No se pudo registrar el miembro.');
    } finally { submit.disabled = false; }
    return;
  }
  const newMember = {
    id: pendingRandomId || makeRandomId(), name,
    type: document.getElementById('newType').value,
    issued: new Date().toLocaleDateString('es-MX'),
    expires: expiryDate.toLocaleDateString('es-MX'),
    status: 'Activo', historical: false
  };
  if (members.some(member => member.id === newMember.id)) newMember.id = makeRandomId();
  members.push(newMember);
  saveMembers(); renderAll(); closeModal('memberModal');
  document.getElementById('memberSearch').value = '';
  document.getElementById('statusFilter').value = 'all';
  showView('members');
  showToast(`Miembro agregado a la demostración: ${newMember.id}`);
});
document.getElementById('detailContent').addEventListener('click', async event => {
  if (event.target.id === 'saveAdminMemberProfile') {
    const member = members.find(item => item.id === selectedMemberId);
    if (!member) return;
    const changes = {
      contact_email: document.getElementById('adminProfileEmail').value.trim(),
      phone: document.getElementById('adminProfilePhone').value.trim(),
      professional_license: document.getElementById('adminProfileLicense').value.trim(),
      specialty: document.getElementById('adminProfileSpecialty').value.trim(),
      city: document.getElementById('adminProfileCity').value.trim(),
      state: document.getElementById('adminProfileState').value.trim(),
      about: document.getElementById('adminProfileAbout').value.trim()
    };
    event.target.disabled = true;
    try {
      await pasBackend.updateMemberProfile(member.backendId, changes);
      members = await pasBackend.listMembers();
      openMemberDetail(selectedMemberId);
      showToast('Expediente actualizado.');
    } catch (error) {
      showToast(error.message || 'No se pudo actualizar el expediente.');
      event.target.disabled = false;
    }
    return;
  }
  const accessButton = event.target.closest('#inviteMemberAccount, #linkExistingMemberAccount');
  if (accessButton) {
    const member = members.find(item => item.id === selectedMemberId);
    const email = document.getElementById('memberAccessEmail')?.value.trim();
    if (!member || !email) { showToast('Escribe el correo de la cuenta.'); return; }
    const action = accessButton.id === 'inviteMemberAccount' ? 'invite' : 'link_existing';
    accessButton.disabled = true;
    try {
      const result = await pasBackend.manageMemberAccess(action, member.backendId, email);
      members = await pasBackend.listMembers();
      openMemberDetail(selectedMemberId);
      showToast(result.warning || result.message || 'Cuenta vinculada correctamente.');
    } catch (error) {
      showToast(error.message || 'No se pudo vincular la cuenta.');
      accessButton.disabled = false;
    }
    return;
  }
  const member = members.find(item => item.id === selectedMemberId);
  if (!member) return;
  if (event.target.id === 'issueReplacement') {
    const expiry = document.getElementById('renewalExpiry').value;
    if (!expiry) { showToast('Selecciona la nueva fecha de vigencia.'); return; }
    event.target.disabled = true;
    try {
      const result = await pasBackend.issueCredential(member.backendId, expiry);
      members = await pasBackend.listMembers();
      renderAll(); closeModal('detailModal');
      showIssuedCredential(result.public_identifier);
      showToast('Nueva credencial emitida; la anterior quedó sustituida.');
    } catch (error) {
      showToast(error.message || 'No se pudo emitir la credencial.');
      event.target.disabled = false;
    }
    return;
  }
  if (event.target.id !== 'saveMemberStatus') return;
  const nextStatus = document.getElementById('detailStatus').value;
  if (connectedMode) {
    const saveButton = event.target;
    saveButton.disabled = true;
    try {
      if (nextStatus === 'Revocado') {
        await pasBackend.revokeCredential(member.credentialId);
      } else {
        await pasBackend.setMemberStatus(member.backendId, nextStatus);
      }
      members = await pasBackend.listMembers();
      renderAll(); closeModal('detailModal');
      showToast(nextStatus === 'Revocado' ? 'Credencial revocada en PAS ID.' : `Estado de membresía actualizado: ${nextStatus}`);
    } catch (error) {
      showToast(error.message || 'No se pudo guardar el cambio.');
      saveButton.disabled = false;
    }
    return;
  }
  member.status = nextStatus;
  saveMembers(); renderAll(); closeModal('detailModal');
  showToast(`Estado actualizado en esta demostración: ${nextStatus}`);
});
document.getElementById('profileRequestsList').addEventListener('click', async event => {
  const button = event.target.closest('[data-review-request]');
  if (!button) return;
  const requestId = button.dataset.reviewRequest;
  const decision = button.dataset.decision;
  button.disabled = true;
  try {
    await pasBackend.reviewProfileChangeRequest(requestId, decision);
    await loadProfileRequests();
    if (decision === 'approved') members = await pasBackend.listMembers();
    showToast(decision === 'approved' ? 'Cambios aprobados y aplicados al expediente.' : 'Solicitud rechazada.');
  } catch (error) {
    showToast(error.message || 'No se pudo resolver la solicitud.');
    button.disabled = false;
  }
});

document.getElementById('openSidebar').addEventListener('click', () => {
  document.getElementById('sidebar').classList.add('open');
  document.getElementById('sidebarScrim').classList.add('show');
});
document.getElementById('closeSidebar').addEventListener('click', () => {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebarScrim').classList.remove('show');
});
document.getElementById('sidebarScrim').addEventListener('click', () => {
  document.getElementById('sidebar').classList.remove('open');
  document.getElementById('sidebarScrim').classList.remove('show');
});
document.querySelectorAll('.modal-backdrop').forEach(backdrop => backdrop.addEventListener('click', event => {
  if (event.target === backdrop) backdrop.classList.add('hidden');
}));

document.getElementById('todayLabel').textContent = new Date().toLocaleDateString('es-MX', {weekday:'short', day:'numeric', month:'short', year:'numeric'});

const demoRibbon = document.querySelector('.demo-ribbon');
const loginHint = document.querySelector('.login-hint');
const loginButton = document.getElementById('enterDemo');
if (backendUnavailable) {
  demoRibbon.textContent = 'CONFIGURACIÓN DETECTADA · CONECTOR NO DISPONIBLE';
  loginButton.disabled = true;
  loginHint.innerHTML = '<span class="info-dot">!</span> Se detectaron datos de conexión, pero no cargó el SDK de Supabase. Verifica la conexión a internet y vuelve a cargar.';
} else if (connectedMode) {
  demoRibbon.textContent = 'CONEXIÓN SUPABASE CONFIGURADA · PAS ID';
  const publicIntro = document.querySelector('.verify-main > .muted');
  if (publicIntro) publicIntro.textContent = 'Introduce el folio histórico o el identificador aleatorio para consultar el estado vigente en la base de datos institucional.';
  const internalIntro = document.querySelector('#view-verification .page-heading p');
  if (internalIntro) internalIntro.textContent = 'Comprueba en línea el estado vigente de una credencial PAS.';
  demoRibbon.classList.add('connected-ribbon');
  loginButton.innerHTML = 'Iniciar sesión <span>→</span>';
  loginHint.innerHTML = '<span class="info-dot">i</span> Acceso protegido. Directiva y afiliados ingresan con sus cuentas personales autorizadas.';
} else {
  renderAll();
}

document.querySelectorAll('[data-close-issued]').forEach(button => button.addEventListener('click', () => closeModal('issuedModal')));
document.getElementById('copyIssuedIdentifier').addEventListener('click', async () => {
  const value = document.getElementById('issuedIdentifier').textContent.trim();
  try {
    await navigator.clipboard.writeText(value);
    showToast('Identificador copiado.');
  } catch (_) {
    showToast('Selecciona y copia el identificador manualmente.');
  }
});
document.getElementById('copyIssuedUrl').addEventListener('click', async () => {
  const value = document.getElementById('issuedVerificationUrl').textContent.trim();
  try {
    await navigator.clipboard.writeText(value);
    showToast('Enlace de verificación copiado.');
  } catch (_) {
    showToast('Selecciona y copia el enlace manualmente.');
  }
});

document.getElementById('signOutButton').addEventListener('click', async () => {
  try { if (connectedMode) await pasBackend.signOut(); }
  catch (error) { console.warn('No se pudo cerrar la sesión de Supabase.', error); }
  members = loadMembers();
  signedInRole = ''; signedInEmail = ''; currentMemberProfile = null;
  document.getElementById('appShell').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
  document.getElementById('signOutButton').classList.add('hidden');
  document.getElementById('demoPassword').value = '';
  showToast('Sesión cerrada.');
});

// En una instancia conectada se recupera la sesión persistida y se comprueba el rol.
const urlParams = new URLSearchParams(window.location.search);
const authHashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
const authFlowType = authHashParams.get('type') || urlParams.get('type');
const authFlowError = authHashParams.get('error_description') || urlParams.get('error_description');
(async function initialiseConnectedSession() {
  if (!connectedMode) return;
  try {
    const session = await pasBackend.getSession();
    if (authFlowError) {
      showLoginWithNotice('El enlace de acceso no pudo validarse o ha caducado. Solicita una nueva invitación.');
      return;
    }
    if (authFlowType === 'invite' || authFlowType === 'recovery') {
      if (session) showPasswordSetupScreen();
      else showLoginWithNotice('No se pudo validar el enlace. Solicita una nueva invitación o recuperación de contraseña.');
      return;
    }
    if (!session) return;
    const role = await pasBackend.currentRole();
    if (urlParams.has('verificar')) return;
    await activateAuthenticatedRole(role, session);
  } catch (error) {
    console.error('No se pudo recuperar la sesión de PAS ID.', error);
    showToast('No se pudo recuperar la sesión. Inicia sesión nuevamente.');
  }
})();

// ?verificar= acepta folios históricos o identificadores aleatorios del QR/NFC.
if (urlParams.has('verificar')) {
  openPublicScreen();
  document.getElementById('publicVerifyInput').value = urlParams.get('verificar');
  renderVerification(urlParams.get('verificar'), 'publicVerifyResult');
}

// Módulo operativo de eventos y control de asistencia (Directiva).
let pasEvents = [];
let selectedEventId = null;
function eventDateLabel(value) {
  if (!value) return 'Fecha pendiente';
  return new Date(value).toLocaleString('es-MX', { dateStyle:'medium', timeStyle:'short' });
}
function renderEventsList() {
  const target = document.getElementById('eventsList');
  if (!target) return;
  if (!pasEvents.length) { target.innerHTML = '<p class="events-empty">Todavía no hay eventos registrados. Crea el primero para comenzar.</p>'; return; }
  target.innerHTML = pasEvents.map(item => `<article class="event-item ${item.id === selectedEventId ? 'selected' : ''}"><button class="event-select" type="button" data-select-event="${escapeHtml(item.id)}"><span class="event-date">${escapeHtml(eventDateLabel(item.starts_at))}</span><b>${escapeHtml(item.title)}</b><small>${escapeHtml(item.location || 'Lugar por definir')} · ${item.published ? 'Publicado' : 'Borrador'}</small></button><div class="event-actions"><button type="button" class="text-button" data-edit-event="${escapeHtml(item.id)}">${item.published ? 'Despublicar' : 'Publicar'}</button><button type="button" class="text-button danger-text" data-delete-event="${escapeHtml(item.id)}">Cancelar</button></div></article>`).join('');
}
async function loadEventsModule() {
  const list = document.getElementById('eventsList');
  if (!list) return;
  if (!connectedMode || signedInRole !== 'directiva') {
    list.innerHTML = '<p class="events-empty">Este módulo requiere una sesión de Directiva conectada a Supabase.</p>';
    return;
  }
  list.innerHTML = '<p class="muted">Consultando la agenda institucional…</p>';
  try {
    pasEvents = await pasBackend.listEvents();
    if (!pasEvents.some(item => item.id === selectedEventId)) selectedEventId = null;
    renderEventsList();
    if (selectedEventId) await loadAttendance(selectedEventId);
    else showAttendanceEmpty();
  } catch (error) {
    list.innerHTML = `<p class="events-empty">No se pudieron cargar los eventos: ${escapeHtml(error.message)}</p>`;
  }
}
function showAttendanceEmpty() {
  document.getElementById('attendanceEmpty')?.classList.remove('hidden');
  document.getElementById('attendanceContent')?.classList.add('hidden');
}
async function loadAttendance(eventId) {
  selectedEventId = eventId;
  renderEventsList();
  const event = pasEvents.find(item => item.id === eventId);
  if (!event) return showAttendanceEmpty();
  document.getElementById('attendanceEmpty').classList.add('hidden');
  document.getElementById('attendanceContent').classList.remove('hidden');
  document.getElementById('selectedEventTitle').textContent = event.title;
  const memberSelect = document.getElementById('attendanceMember');
  const activeMembers = members.filter(member => member.backendId && member.status === 'Activo' && member.membershipStatus === 'active');
  memberSelect.innerHTML = '<option value="">Selecciona un miembro…</option>' + activeMembers.map(member => `<option value="${escapeHtml(member.backendId)}">${escapeHtml(member.name)} · ${escapeHtml(member.id)}</option>`).join('');
  const list = document.getElementById('attendanceList');
  list.innerHTML = '<p class="muted">Cargando participantes…</p>';
  try {
    const rows = await pasBackend.listAttendance(eventId);
    document.getElementById('attendanceCount').textContent = `${rows.length} ${rows.length === 1 ? 'asistente' : 'asistentes'}`;
    list.innerHTML = rows.length ? rows.map(row => `<div class="attendance-row"><div><b>${escapeHtml(row.members?.full_name || 'Miembro PAS')}</b><small>${escapeHtml(row.members?.legacy_folio || '')} · ${escapeHtml(eventDateLabel(row.checked_in_at))}</small></div><button type="button" class="text-button danger-text" data-remove-attendance="${escapeHtml(row.id)}">Quitar</button></div>`).join('') : '<p class="events-empty">Aún no hay asistentes registrados para este evento.</p>';
  } catch (error) { list.innerHTML = `<p class="events-empty">No se pudo consultar la asistencia: ${escapeHtml(error.message)}</p>`; }
}
document.getElementById('openCreateEvent')?.addEventListener('click', () => {
  document.getElementById('createEventPanel').classList.remove('hidden');
  document.getElementById('eventStart').value = new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0,16);
  document.getElementById('eventTitle').focus();
});
document.getElementById('closeCreateEvent')?.addEventListener('click', () => document.getElementById('createEventPanel').classList.add('hidden'));
document.getElementById('refreshEvents')?.addEventListener('click', loadEventsModule);
document.getElementById('createEventForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  const form = event.currentTarget;
  const submit = form.querySelector('button[type="submit"]');
  const start = document.getElementById('eventStart').value;
  const end = document.getElementById('eventEnd').value;
  if (end && new Date(end) < new Date(start)) return showToast('La fecha de término no puede ser anterior al inicio.');
  submit.disabled = true;
  try {
    await pasBackend.createEvent({ title:document.getElementById('eventTitle').value.trim(), location:document.getElementById('eventLocation').value.trim() || null, description:document.getElementById('eventDescription').value.trim() || null, starts_at:new Date(start).toISOString(), ends_at:end ? new Date(end).toISOString() : null, published:document.getElementById('eventPublished').checked });
    form.reset();
    document.getElementById('createEventPanel').classList.add('hidden');
    showToast('Evento guardado en PAS ID.');
    await loadEventsModule();
  } catch (error) { showToast(error.message || 'No se pudo guardar el evento.'); }
  finally { submit.disabled = false; }
});
document.getElementById('eventsList')?.addEventListener('click', async event => {
  const select = event.target.closest('[data-select-event]');
  const publish = event.target.closest('[data-edit-event]');
  const remove = event.target.closest('[data-delete-event]');
  if (select) return loadAttendance(select.dataset.selectEvent);
  if (publish) {
    const item = pasEvents.find(row => row.id === publish.dataset.editEvent);
    if (!item) return;
    try { await pasBackend.updateEvent(item.id, { published:!item.published }); showToast(item.published ? 'Evento retirado de la agenda pública.' : 'Evento publicado.'); await loadEventsModule(); }
    catch (error) { showToast(error.message || 'No se pudo actualizar el evento.'); }
  }
  if (remove) {
    const item = pasEvents.find(row => row.id === remove.dataset.deleteEvent);
    if (!item || !confirm(`¿Cancelar «${item.title}»? Se eliminarán también sus registros de asistencia.`)) return;
    try { await pasBackend.deleteEvent(item.id); if (selectedEventId === item.id) { selectedEventId = null; showAttendanceEmpty(); } showToast('Evento cancelado.'); await loadEventsModule(); }
    catch (error) { showToast(error.message || 'No se pudo cancelar el evento.'); }
  }
});
document.getElementById('attendanceForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  const memberId = document.getElementById('attendanceMember').value;
  if (!memberId || !selectedEventId) return;
  const submit = event.currentTarget.querySelector('button[type="submit"]'); submit.disabled = true;
  try { await pasBackend.addAttendance(selectedEventId, memberId); showToast('Asistencia registrada.'); await loadAttendance(selectedEventId); }
  catch (error) { showToast(/duplicate|unique/i.test(error.message) ? 'Este miembro ya tiene asistencia registrada en el evento.' : (error.message || 'No se pudo registrar la asistencia.')); }
  finally { submit.disabled = false; }
});
document.getElementById('attendanceList')?.addEventListener('click', async event => {
  const button = event.target.closest('[data-remove-attendance]'); if (!button) return;
  if (!confirm('¿Quitar este registro de asistencia?')) return;
  try { await pasBackend.removeAttendance(button.dataset.removeAttendance); showToast('Registro de asistencia eliminado.'); await loadAttendance(selectedEventId); }
  catch (error) { showToast(error.message || 'No se pudo quitar la asistencia.'); }
});


// Registro de asistencia mediante el QR público de la credencial PAS.
let attendanceCameraStream = null;
let attendanceScanActive = false;
let attendanceDetector = null;
let attendanceScanBusy = false;
function stopAttendanceScanner() {
  attendanceScanActive = false;
  if (attendanceCameraStream) attendanceCameraStream.getTracks().forEach(track => track.stop());
  attendanceCameraStream = null;
  const video = document.getElementById('attendanceScannerVideo');
  if (video) video.srcObject = null;
  document.getElementById('attendanceScannerPanel')?.classList.add('hidden');
}
function identifierFromQr(rawValue) {
  const raw = String(rawValue || '').trim();
  try {
    const url = new URL(raw);
    const value = url.searchParams.get('verificar') || url.searchParams.get('folio') || url.searchParams.get('id');
    if (value) return value.trim();
  } catch (_) {}
  return raw;
}
async function registerAttendanceByIdentifier(rawValue) {
  if (!selectedEventId) throw new Error('Primero selecciona un evento.');
  const identifier = identifierFromQr(rawValue);
  if (!identifier) throw new Error('El QR no contiene un identificador válido.');
  const members = await pasBackend.listMembers();
  const normalized = identifier.toUpperCase().replace(/^PAS-/, 'PAS-');
  const member = members.find(item =>
    String(item.publicIdentifier || '').toUpperCase() === normalized ||
    String(item.id || '').toUpperCase() === identifier.toUpperCase()
  );
  if (!member) throw new Error('No encontramos una credencial asociada a ese QR o folio.');
  if (effectiveStatus(member) !== 'Activo' || member.membershipStatus !== 'active') {
    throw new Error(`No se puede registrar: la membresía o credencial de ${member.name} no está vigente (${effectiveStatus(member)}).`);
  }
  await pasBackend.addAttendance(selectedEventId, member.backendId);
  await loadAttendance(selectedEventId);
  showToast(`Asistencia registrada: ${member.name}.`);
  return member;
}
async function startAttendanceScanner() {
  const panel = document.getElementById('attendanceScannerPanel');
  const status = document.getElementById('attendanceScannerStatus');
  if (!selectedEventId) return showToast('Selecciona primero el evento.');
  if (!navigator.mediaDevices?.getUserMedia) {
    panel.classList.remove('hidden'); status.textContent = 'Este navegador no permite acceder a la cámara. Usa la captura manual de folio o identificador.'; return;
  }
  if (!('BarcodeDetector' in window)) {
    panel.classList.remove('hidden'); status.textContent = 'El lector QR automático no está disponible en este navegador. Usa la captura manual de folio o identificador.'; return;
  }
  try {
    attendanceDetector = new BarcodeDetector({ formats: ['qr_code'] });
    attendanceCameraStream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' } }, audio: false });
    const video = document.getElementById('attendanceScannerVideo');
    video.srcObject = attendanceCameraStream;
    await video.play();
    panel.classList.remove('hidden');
    status.textContent = 'Apunta la cámara al QR de la credencial.';
    attendanceScanActive = true;
    scanAttendanceFrame();
  } catch (error) {
    stopAttendanceScanner();
    panel.classList.remove('hidden');
    status.textContent = error.name === 'NotAllowedError' ? 'Permite el acceso a la cámara en tu navegador y vuelve a intentarlo.' : `No se pudo iniciar la cámara: ${error.message || 'error desconocido'}. También puedes capturar el folio manualmente.`;
  }
}
async function scanAttendanceFrame() {
  if (!attendanceScanActive) return;
  const video = document.getElementById('attendanceScannerVideo');
  try {
    if (!attendanceScanBusy && video?.readyState >= 2) {
      const codes = await attendanceDetector.detect(video);
      if (codes.length && codes[0].rawValue) {
        attendanceScanBusy = true;
        document.getElementById('attendanceScannerStatus').textContent = 'QR detectado. Validando credencial…';
        try { await registerAttendanceByIdentifier(codes[0].rawValue); stopAttendanceScanner(); }
        catch (error) { document.getElementById('attendanceScannerStatus').textContent = error.message; attendanceScanBusy = false; }
      }
    }
  } catch (error) { document.getElementById('attendanceScannerStatus').textContent = `No se pudo leer el QR: ${error.message || ''}`; }
  if (attendanceScanActive) requestAnimationFrame(scanAttendanceFrame);
}
document.getElementById('startAttendanceScanner')?.addEventListener('click', startAttendanceScanner);
document.getElementById('stopAttendanceScanner')?.addEventListener('click', stopAttendanceScanner);
document.getElementById('attendanceQrManualForm')?.addEventListener('submit', async event => {
  event.preventDefault();
  const input = document.getElementById('attendanceQrManual');
  const submit = event.currentTarget.querySelector('button[type="submit"]');
  submit.disabled = true;
  try { await registerAttendanceByIdentifier(input.value); input.value = ''; }
  catch (error) { showToast(/duplicate|unique/i.test(error.message) ? 'Este miembro ya tiene asistencia registrada en el evento.' : error.message); }
  finally { submit.disabled = false; }
});
window.addEventListener('beforeunload', stopAttendanceScanner);
