const state = {
  members: [],
  history: [],
  selectedMemberId: null,
};

const els = {
  status: document.querySelector('#syncStatus'),
  stats: document.querySelector('#stats'),
  memberFilters: document.querySelector('#memberFilters'),
  historyFilters: document.querySelector('#historyFilters'),
  membersRows: document.querySelector('#membersRows'),
  historyRows: document.querySelector('#historyRows'),
  activeRows: document.querySelector('#activeRows'),
  qualityRows: document.querySelector('#qualityRows'),
  memberDetail: document.querySelector('#memberDetail'),
  exportMembers: document.querySelector('#exportMembers'),
  exportHistory: document.querySelector('#exportHistory'),
  authPanel: document.querySelector('#authPanel'),
  appShell: document.querySelector('#appShell'),
  loginForm: document.querySelector('#loginForm'),
  codeForm: document.querySelector('#codeForm'),
  loginMessage: document.querySelector('#loginMessage'),
};

function setStatus(text, isError = false) {
  els.status.textContent = text;
  els.status.classList.toggle('error', isError);
}

function escapeHtml(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function formatValue(value) {
  return value === null || value === undefined || value === '' ? '-' : escapeHtml(value);
}

function paramsFromForm(form) {
  const params = new URLSearchParams();
  new FormData(form).forEach((value, key) => {
    const cleaned = String(value).trim();
    if (cleaned !== '') {
      params.set(key, cleaned);
    }
  });
  return params;
}

async function api(path, params = new URLSearchParams()) {
  const suffix = params.toString() ? `?${params}` : '';
  const response = await fetch(`api/${path}.php${suffix}`, {
    headers: { Accept: 'application/json' },
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    throw new Error(payload.error || 'Onbekende fout');
  }
  return payload.data;
}

async function postApi(path, values) {
  const response = await fetch(`api/${path}.php`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams(values),
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    const error = new Error(payload.error || 'Onbekende fout');
    error.payload = payload;
    throw error;
  }
  return payload.data;
}

function showLogin(message = '') {
  els.authPanel.hidden = false;
  els.appShell.hidden = true;
  els.loginMessage.textContent = message;
  setStatus('Inloggen vereist');
}

function showApp() {
  els.authPanel.hidden = true;
  els.appShell.hidden = false;
}

async function verifyMagicLinkFromUrl() {
  const params = new URLSearchParams(window.location.search);
  const selector = params.get('selector');
  const token = params.get('token');
  if (!selector || !token) {
    return false;
  }
  try {
    await postApi('auth/verify', { selector, token });
    window.history.replaceState({}, document.title, window.location.pathname);
    return true;
  } catch (error) {
    window.history.replaceState({}, document.title, window.location.pathname);
    if (error.payload?.needs_code) {
      els.codeForm.hidden = false;
      els.codeForm.email.value = error.payload.email || '';
    }
    showLogin(error.message);
    return false;
  }
}

function renderStats(rows) {
  els.stats.innerHTML = rows.map((row) => `
    <article class="stat">
      <strong>${formatValue(row.waarde)}</strong>
      <span>${formatValue(row.label)}</span>
    </article>
  `).join('');
}

function qualityClass(value) {
  return value === 'compleet' ? 'quality-compleet' : 'quality-issue';
}

function renderMembers(rows) {
  els.membersRows.innerHTML = rows.map((row) => `
    <tr data-id="${escapeHtml(row.id)}" class="${String(row.id) === String(state.selectedMemberId) ? 'is-selected' : ''}">
      <td>${formatValue(row.tellercode)}</td>
      <td>${formatValue(row.naam)}</td>
      <td>${formatValue(row.soort_lid)}</td>
      <td>${formatValue(row.woonplaats)}</td>
      <td>${formatValue(row.aantal_jaren_geteld)}</td>
      <td>${formatValue(row.aantal_plots)}</td>
      <td class="${qualityClass(row.datakwaliteit)}">${formatValue(row.datakwaliteit)}</td>
    </tr>
  `).join('');
}

function renderHistory(rows) {
  els.historyRows.innerHTML = rows.map((row) => `
    <tr>
      <td>${formatValue(row.tellercode)}</td>
      <td>${formatValue(row.naam)}</td>
      <td>${formatValue(row.jaar)}</td>
      <td>${formatValue(row.aantal_plots)}</td>
      <td>${formatValue(row.kavels)}</td>
    </tr>
  `).join('');
}

function renderActive(rows) {
  els.activeRows.innerHTML = rows.map((row) => `
    <tr>
      <td>${formatValue(row.jaar)}</td>
      <td>${formatValue(row.actieve_tellers)}</td>
      <td>${formatValue(row.getelde_plots)}</td>
      <td>${formatValue(row.plotjaren)}</td>
    </tr>
  `).join('');
}

function renderQuality(rows) {
  els.qualityRows.innerHTML = rows.map((row) => `
    <tr>
      <td>${formatValue(row.tellercode)}</td>
      <td>${formatValue(row.naam)}</td>
      <td>${formatValue(row.soort_lid)}</td>
      <td>${formatValue(row.aandachtspunt)}</td>
    </tr>
  `).join('');
}

function renderDetail(row) {
  if (!row) {
    els.memberDetail.innerHTML = '<h2>Selecteer een lid</h2><p>De detailkaart verschijnt hier.</p>';
    return;
  }

  els.memberDetail.innerHTML = `
    <h2>${formatValue(row.naam)}</h2>
    <p>${formatValue(row.tellercode)} · ${formatValue(row.soort_lid)}</p>
    <dl>
      <dt>Adres</dt><dd>${formatValue([row.straat, row.huisnummer].filter(Boolean).join(' '))}</dd>
      <dt>Postcode</dt><dd>${formatValue(row.postcode)}</dd>
      <dt>Woonplaats</dt><dd>${formatValue(row.woonplaats)}</dd>
      <dt>Email</dt><dd>${formatValue(row.email)}</dd>
      <dt>Mobiel</dt><dd>${formatValue(row.telefoon_mobiel)}</dd>
      <dt>Vast</dt><dd>${formatValue(row.telefoon_vast)}</dd>
      <dt>Bandnummer</dt><dd>${formatValue(row.bandnummer)}</dd>
      <dt>Eerste jaar</dt><dd>${formatValue(row.eerste_jaar)}</dd>
      <dt>Laatste jaar</dt><dd>${formatValue(row.laatste_jaar)}</dd>
      <dt>Jaren geteld</dt><dd>${formatValue(row.aantal_jaren_geteld)}</dd>
      <dt>Plotjaren</dt><dd>${formatValue(row.aantal_plotjaren)}</dd>
      <dt>Kavels</dt><dd>${formatValue(row.kavels)}</dd>
    </dl>
  `;
}

async function loadMembers() {
  setStatus('Leden laden...');
  state.members = await api('members', paramsFromForm(els.memberFilters));
  if (!state.selectedMemberId && state.members[0]) {
    state.selectedMemberId = state.members[0].id;
  }
  renderMembers(state.members);
  await loadMemberDetail(state.selectedMemberId);
  setStatus(`${state.members.length} leden`);
}

async function loadMemberDetail(id) {
  if (!id) {
    renderDetail(null);
    return;
  }
  state.selectedMemberId = id;
  renderMembers(state.members);
  renderDetail(await api('member', new URLSearchParams({ id })));
}

async function loadHistory() {
  setStatus('Telhistorie laden...');
  state.history = await api('history', paramsFromForm(els.historyFilters));
  renderHistory(state.history);
  setStatus(`${state.history.length} regels`);
}

async function loadStaticTables() {
  const [stats, active, quality] = await Promise.all([
    api('stats'),
    api('active-years'),
    api('data-quality'),
  ]);
  renderStats(stats);
  renderActive(active);
  renderQuality(quality);
}

function csvCell(value) {
  return `"${String(value ?? '').replaceAll('"', '""')}"`;
}

function exportCsv(filename, rows, columns) {
  const csv = [
    columns.map(([label]) => csvCell(label)).join(';'),
    ...rows.map((row) => columns.map(([, key]) => csvCell(row[key])).join(';')),
  ].join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

function bindTabs() {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((item) => item.classList.remove('is-active'));
      document.querySelectorAll('.panel').forEach((panel) => panel.classList.remove('is-active'));
      tab.classList.add('is-active');
      document.querySelector(`#${tab.dataset.tab}Panel`).classList.add('is-active');
    });
  });
}

function bindEvents() {
  els.loginForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      const data = await postApi('auth/request', Object.fromEntries(new FormData(els.loginForm)));
      els.loginMessage.textContent = data.message;
      els.codeForm.hidden = false;
      els.codeForm.email.value = els.loginForm.email.value;
    } catch (error) {
      els.loginMessage.textContent = error.message;
    }
  });

  els.codeForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await postApi('auth/code', Object.fromEntries(new FormData(els.codeForm)));
      showApp();
      await loadInitialData();
    } catch (error) {
      els.loginMessage.textContent = error.message;
    }
  });

  els.memberFilters.addEventListener('submit', async (event) => {
    event.preventDefault();
    state.selectedMemberId = null;
    try {
      await loadMembers();
    } catch (error) {
      setStatus(error.message, true);
    }
  });

  els.historyFilters.addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await loadHistory();
    } catch (error) {
      setStatus(error.message, true);
    }
  });

  els.membersRows.addEventListener('click', async (event) => {
    const row = event.target.closest('tr[data-id]');
    if (!row) {
      return;
    }
    try {
      await loadMemberDetail(row.dataset.id);
    } catch (error) {
      setStatus(error.message, true);
    }
  });

  els.exportMembers.addEventListener('click', () => {
    exportCsv('leden_informatie.csv', state.members, [
      ['Code', 'tellercode'],
      ['Naam', 'naam'],
      ['Lidtype', 'soort_lid'],
      ['Woonplaats', 'woonplaats'],
      ['Email', 'email'],
      ['Mobiel', 'telefoon_mobiel'],
      ['Eerste jaar', 'eerste_jaar'],
      ['Laatste jaar', 'laatste_jaar'],
      ['Jaren', 'aantal_jaren_geteld'],
      ['Plotjaren', 'aantal_plotjaren'],
      ['Unieke plots', 'aantal_plots'],
      ['Datakwaliteit', 'datakwaliteit'],
      ['id', 'id'],
    ]);
  });

  els.exportHistory.addEventListener('click', () => {
    const year = new FormData(els.historyFilters).get('year');
    exportCsv(year ? `telhistorie_${year}.csv` : 'telhistorie_alle_tellers.csv', state.history, [
      ['Code', 'tellercode'],
      ['Naam', 'naam'],
      ['Jaar', 'jaar'],
      ['Plots in jaar', 'aantal_plots'],
      ['Kavels', 'kavels'],
    ]);
  });
}

async function registerServiceWorker() {
  if ('serviceWorker' in navigator) {
    await navigator.serviceWorker.register('service-worker.js');
  }
}

async function init() {
  bindTabs();
  bindEvents();
  await verifyMagicLinkFromUrl();
  try {
    const status = await api('auth/status');
    if (!status.authenticated) {
      showLogin();
      return;
    }
    showApp();
    await loadInitialData();
  } catch (error) {
    showLogin(error.message);
  }
}

async function loadInitialData() {
    await registerServiceWorker();
    await loadStaticTables();
    await Promise.all([loadMembers(), loadHistory()]);
    setStatus('Bijgewerkt');
}

init();
