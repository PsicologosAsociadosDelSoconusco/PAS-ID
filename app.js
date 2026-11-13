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
let selectedMemberId = null;
let pendingRandomId = null;
let toastTimer;

// Ajusta las etiquetas que en el HTML base describen el modo de demostración.
// En modo conectado, los formularios de altas y cambios utilizan las funciones RPC de Supabase.
if (connectedMode) {
  const memberSubmit = document.querySelector('#memberForm button[type="submit"]');
  const memberHelp = document.querySelector('#memberModal .field-help');
  const memberNote = document.querySelector('#view-members .bottom-note p');
  const verifyNote = document.querySelector('#view-verification .verify-disclaimer');
  const footerStatus = document.querySelector('.app-footer span:last-child');
  if (memberSubmit) memberSubmit.innerHTML = 'Registrar miembro <span>→</span>';
  if (memberHelp) memberHelp.textContent = 'El registro se guardará en la base institucional y recibirá un identificador aleatorio generado por el servidor.';
  if (memberNote) memberNote.textContent = 'Los folios históricos de los fundadores se conservan. Las nuevas altas se registran en la base institucional con identificadores aleatorios revocables.';
  if (verifyNote) verifyNote.textContent = 'La consulta se realiza en línea desde la base de datos institucional de PAS ID y muestra únicamente información autorizada para verificación pública.';
  if (footerStatus) footerStatus.innerHTML = '<i></i> PAS ID · Entorno conectado · Fase de pruebas';
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
    <td><span class="folio">${escapeHtml(member.id)}</span></td><td><span class="type-label">${escapeHtml(member.type)}</span></td><td>${escapeHtml(formatDate(member.expires))}</td><td>${statusBadge(effectiveStatus(member))}</td><td><button class="action-button" data-manage="${escapeHtml(member.id)}" aria-label="Gestionar ${escapeHtml(member.name)}" title="Gestionar miembro">⋯</button></td></tr>`).join('');
  document.getElementById('emptyMembers').classList.toggle('hidden', filtered.length > 0);
}
function renderCredentials() {
  document.getElementById('credentialList').innerHTML = members.map(member => `
    <div class="credential-row"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div><b>${escapeHtml(member.name)}</b><small>${escapeHtml(member.id)} · ${escapeHtml(effectiveStatus(member))}</small></div></div>`).join('');
}
function renderAll() {
  updateStats(); renderRecent(); renderMembers(); renderCredentials();
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
  document.getElementById('detailModalTitle').textContent = 'Gestionar miembro';
  document.getElementById('detailContent').innerHTML = `
    <div class="detail-top"><div class="member-avatar">${escapeHtml(initials(member.name))}</div><div><b>${escapeHtml(member.name)}</b><small>${escapeHtml(member.id)} · ${escapeHtml(member.type)}</small></div></div>
    <div class="detail-fields"><div class="detail-field"><span>FOLIO / IDENTIFICADOR</span><b>${escapeHtml(member.id)}</b></div><div class="detail-field"><span>TIPO DE REGISTRO</span><b>${escapeHtml(member.type)}</b></div><div class="detail-field"><span>EXPEDICIÓN</span><b>${escapeHtml(formatDate(member.issued))}</b></div><div class="detail-field"><span>VIGENCIA</span><b>${escapeHtml(formatDate(member.expires))}</b></div></div>
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
  return `<div class="verification-card-result"><div class="verification-result-head"><span class="eyebrow">RESULTADO DE CONSULTA</span>${statusBadge(status)}</div><h3>${escapeHtml(member.name)}</h3><p>${escapeHtml(member.type)} · PAS</p><div class="verification-data"><div><span>FOLIO / IDENTIFICADOR</span><b>${escapeHtml(member.id)}</b></div><div><span>VIGENCIA</span><b>${escapeHtml(formatDate(member.expires))}</b></div></div><strong class="verification-label ${statusClass(status)}">${escapeHtml(label)}</strong><small class="verification-footnote">Resultado de demostración local. La consulta oficial requerirá conexión al servidor de PAS ID.</small></div>`;
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
      const result = await pasBackend.verify(query);
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
function openPublicScreen() {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('appShell').classList.add('hidden');
  document.getElementById('publicScreen').classList.remove('hidden');
}
function showApp() {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('appShell').classList.remove('hidden');
  renderAll();
  showView('overview');
}
function showPasswordSetupScreen(message = '') {
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('publicScreen').classList.add('hidden');
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
  document.getElementById('publicScreen').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
  const hint = document.querySelector('.login-hint');
  if (hint) hint.innerHTML = `<span class="info-dot">i</span> ${escapeHtml(message)}`;
}

// Con proyecto Supabase configurado se exige sesión y rol de Directiva.
// Sin configuración, el botón conserva la experiencia local de demostración.
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
    if (role === 'directiva') {
      const session = await pasBackend.getSession();
      signedInEmail = session?.user?.email || '';
      members = await pasBackend.listMembers();
      document.getElementById('activeUserName').textContent = signedInEmail || 'Directiva PAS';
      document.getElementById('activeUserRole').textContent = 'Directiva · Conectado';
      document.getElementById('signOutButton').classList.remove('hidden');
      window.history.replaceState({}, document.title, window.location.pathname + window.location.search.replace(/([?&])type=(invite|recovery)(&|$)/, '$1').replace(/[?&]$/, ''));
      showApp();
      showToast('Cuenta activada. Bienvenido a PAS ID.');
    } else {
      await pasBackend.signOut();
      showLoginWithNotice('Tu contraseña quedó configurada. Tu cuenta aún no tiene un rol institucional asignado; solicita a la Directiva que active tu acceso.');
    }
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
    if (role !== 'directiva') {
      await pasBackend.signOut();
      throw new Error('La cuenta no tiene permisos de Directiva PAS. El portal de afiliados se habilitará en una fase posterior.');
    }
    members = await pasBackend.listMembers();
    document.getElementById('activeUserName').textContent = signedInEmail;
    document.getElementById('activeUserRole').textContent = 'Directiva · Conectado';
    document.getElementById('signOutButton').classList.remove('hidden');
    if (!urlParams.has('verificar')) showApp();
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
  loginHint.innerHTML = '<span class="info-dot">i</span> Acceso protegido. Se requiere una cuenta institucional autorizada por la Directiva PAS.';
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
    if (role !== 'directiva') {
      await pasBackend.signOut();
      return;
    }
    signedInEmail = session.user?.email || '';
    members = await pasBackend.listMembers();
    document.getElementById('activeUserName').textContent = signedInEmail || 'Directiva PAS';
    document.getElementById('activeUserRole').textContent = 'Directiva · Conectado';
    document.getElementById('signOutButton').classList.remove('hidden');
    if (!urlParams.has('verificar')) showApp();
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
