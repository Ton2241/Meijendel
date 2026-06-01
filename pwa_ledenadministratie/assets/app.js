const state = {
  members: [],
  history: [],
  plots: [],
  tellers: [],
  selectedMemberId: null,
  historySortKey: 'naam',
  historySortDirection: 'asc',
  currentMember: null,
  isAdmin: false,
  csrfToken: '',
};

const memberTypes = ['aspirant', 'gewoon', 'buitengewoon', 'ondersteunend', 'erelid', 'onbekend', 'oudteller'];

const els = {
  status: document.querySelector('#syncStatus'),
  stats: document.querySelector('#stats'),
  memberFilters: document.querySelector('#memberFilters'),
  historyFilters: document.querySelector('#historyFilters'),
  membersRows: document.querySelector('#membersRows'),
  historyRows: document.querySelector('#historyRows'),
  historyAddForm: document.querySelector('#historyAddForm'),
  historyEditMessage: document.querySelector('#historyEditMessage'),
  tellerOptions: document.querySelector('#tellerOptions'),
  plotOptions: document.querySelector('#plotOptions'),
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
  const body = new URLSearchParams(values);
  if (state.csrfToken && !body.has('csrf_token')) {
    body.set('csrf_token', state.csrfToken);
  }
  const response = await fetch(`api/${path}.php`, {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  const payload = await response.json();
  if (!response.ok || !payload.ok) {
    const error = new Error(payload.error || 'Onbekende fout');
    error.payload = payload;
    throw error;
  }
  return payload.data;
}

function formValue(row, key) {
  return escapeHtml(row?.[key] ?? '');
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
  els.historyAddForm.hidden = !state.isAdmin;
}

async function refreshSessionState() {
  const status = await api('auth/status');
  state.isAdmin = Boolean(status.is_admin);
  state.csrfToken = status.csrf_token || '';
  return status;
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
  const sorted = sortHistory(rows);
  els.historyRows.innerHTML = sorted.map((row) => `
    <tr data-history-id="${escapeHtml(row.id)}">
      <td>${formatValue(row.tellercode)}</td>
      <td>${formatValue(row.naam)}</td>
      <td>${state.isAdmin ? `<input class="inline-input" name="jaar" type="number" min="1900" max="2100" value="${formValue(row, 'jaar')}">` : formatValue(row.jaar)}</td>
      <td>${state.isAdmin ? `<input class="inline-input" name="plot_id" type="number" min="1" list="plotOptions" value="${formValue(row, 'plot_id')}">` : formatValue(row.plot_id)}</td>
      <td>${formatValue(row.kavels)}</td>
      <td>${state.isAdmin ? `
        <button type="button" class="compact" data-history-action="update">Opslaan</button>
        <button type="button" class="compact danger" data-history-action="delete">Verwijder</button>
      ` : ''}</td>
    </tr>
  `).join('');
  updateHistorySortButtons();
}

function sortHistory(rows) {
  const key = state.historySortKey;
  const direction = state.historySortDirection === 'asc' ? 1 : -1;
  const numeric = key === 'jaar' || key === 'plot_id';
  return [...rows].sort((left, right) => {
    const leftValue = left[key] ?? '';
    const rightValue = right[key] ?? '';
    if (numeric) {
      return ((Number(leftValue) || 0) - (Number(rightValue) || 0)) * direction;
    }
    return String(leftValue).localeCompare(String(rightValue), 'nl', { sensitivity: 'base' }) * direction;
  });
}

function updateHistorySortButtons() {
  document.querySelectorAll('[data-history-sort]').forEach((button) => {
    const active = button.dataset.historySort === state.historySortKey;
    const suffix = active ? (state.historySortDirection === 'asc' ? ' ▲' : ' ▼') : '';
    button.textContent = button.textContent.replace(/\s[▲▼]$/, '') + suffix;
    button.setAttribute('aria-sort', active ? (state.historySortDirection === 'asc' ? 'ascending' : 'descending') : 'none');
  });
}

function renderPlotOptions(rows) {
  els.plotOptions.innerHTML = rows.map((row) => `
    <option value="${escapeHtml(row.label)}">${formatValue(row.plot_naam)} · id ${formatValue(row.plot_id)}</option>
  `).join('');
}

function renderTellerOptions(rows) {
  els.tellerOptions.innerHTML = rows.map((row) => `
    <option value="${escapeHtml(row.tellercode)}">${formatValue(row.achternaam)}, ${formatValue(row.naam)} · id ${formatValue(row.id)}</option>
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
  state.currentMember = row;
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
      <dt>Beheerstatus</dt><dd>${formatValue(row.beheer_status)}</dd>
      <dt>Opmerking</dt><dd>${formatValue(row.beheer_opmerking)}</dd>
      <dt>Eerste jaar</dt><dd>${formatValue(row.eerste_jaar)}</dd>
      <dt>Laatste jaar</dt><dd>${formatValue(row.laatste_jaar)}</dd>
      <dt>Jaren geteld</dt><dd>${formatValue(row.aantal_jaren_geteld)}</dd>
      <dt>Plotjaren</dt><dd>${formatValue(row.aantal_plotjaren)}</dd>
      <dt>Kavels</dt><dd>${formatValue(row.kavels)}</dd>
    </dl>
    ${state.isAdmin ? renderMemberForm(row) : ''}
  `;
}

function renderMemberForm(row) {
  return `
    <form class="edit-form" id="memberEditForm">
      <h3>Beheer</h3>
      <input type="hidden" name="id" value="${formValue(row, 'id')}">
      <div class="edit-grid">
        <label>Voornaam<input name="voornaam" value="${formValue(row, 'voornaam')}" maxlength="80"></label>
        <label>Tussenvoegsel<input name="tussenvoegsel" value="${formValue(row, 'tussenvoegsel')}" maxlength="40"></label>
        <label>Achternaam<input name="achternaam" value="${formValue(row, 'achternaam')}" maxlength="120" required></label>
        <label>Straat<input name="straat" value="${formValue(row, 'straat')}" maxlength="120"></label>
        <label>Huisnummer<input name="huisnummer" value="${formValue(row, 'huisnummer')}" maxlength="30"></label>
        <label>Postcode<input name="postcode" value="${formValue(row, 'postcode')}" maxlength="20"></label>
        <label>Woonplaats<input name="woonplaats" value="${formValue(row, 'woonplaats')}" maxlength="120"></label>
        <label>Email<input name="email" type="email" value="${formValue(row, 'email')}" maxlength="255"></label>
        <label>Mobiel<input name="telefoon_mobiel" value="${formValue(row, 'telefoon_mobiel')}" maxlength="40"></label>
        <label>Vast<input name="telefoon_vast" value="${formValue(row, 'telefoon_vast')}" maxlength="40"></label>
        <label>Lidtype
          <select name="soort_lid">
            ${memberTypes.map((value) => `
              <option value="${value}" ${row.soort_lid === value ? 'selected' : ''}>${value}</option>
            `).join('')}
          </select>
        </label>
        <label>Bandnummer<input name="bandnummer" value="${formValue(row, 'bandnummer')}" maxlength="80"></label>
        <label>Beheerstatus
          <select name="beheer_status">
            ${[
              ['actief', 'actief'],
              ['inactief', 'inactief'],
              ['nader_controleren', 'nader controleren'],
            ].map(([value, label]) => `
              <option value="${value}" ${row.beheer_status === value ? 'selected' : ''}>${label}</option>
            `).join('')}
          </select>
        </label>
        <label class="wide">Opmerking<textarea name="beheer_opmerking" maxlength="4000">${formValue(row, 'beheer_opmerking')}</textarea></label>
      </div>
      <div class="edit-actions">
        <button class="primary" type="submit">Opslaan</button>
        <span id="memberEditMessage"></span>
      </div>
    </form>
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

async function loadPlots() {
  if (!state.isAdmin || state.plots.length > 0) {
    return;
  }
  state.plots = await api('plots');
  renderPlotOptions(state.plots);
}

async function loadTellers() {
  if (!state.isAdmin || state.tellers.length > 0) {
    return;
  }
  state.tellers = await api('tellers');
  renderTellerOptions(state.tellers);
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
      await refreshSessionState();
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

  els.historyAddForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (!window.confirm('Nieuwe telhistorie-regel opslaan in de live Meijendel database?')) {
      return;
    }
    try {
      els.historyEditMessage.textContent = 'Opslaan...';
      await postApi('admin/history-entry', {
        ...Object.fromEntries(new FormData(els.historyAddForm)),
        action: 'create',
      });
      els.historyAddForm.reset();
      await Promise.all([loadHistory(), loadMembers(), loadStaticTables()]);
      els.historyEditMessage.textContent = 'Opgeslagen';
      setStatus('Telhistorie bijgewerkt');
    } catch (error) {
      els.historyEditMessage.textContent = error.message;
      setStatus(error.message, true);
    }
  });

  els.historyRows.addEventListener('click', async (event) => {
    const button = event.target.closest('button[data-history-action]');
    if (!button) {
      return;
    }
    const row = button.closest('tr[data-history-id]');
    const action = button.dataset.historyAction;
    const body = { id: row.dataset.historyId, action };
    if (action === 'update') {
      body.jaar = row.querySelector('input[name="jaar"]').value;
      body.plot_id = row.querySelector('input[name="plot_id"]').value;
    }
    const prompt = action === 'delete'
      ? 'Deze telhistorie-regel verwijderen uit de live Meijendel database?'
      : 'Deze telhistorie-regel wijzigen in de live Meijendel database?';
    if (!window.confirm(prompt)) {
      return;
    }
    try {
      setStatus('Telhistorie opslaan...');
      await postApi('admin/history-entry', body);
      await Promise.all([loadHistory(), loadMembers(), loadStaticTables()]);
      setStatus('Telhistorie bijgewerkt');
    } catch (error) {
      setStatus(error.message, true);
    }
  });

  document.querySelectorAll('[data-history-sort]').forEach((button) => {
    button.addEventListener('click', () => {
      const key = button.dataset.historySort;
      if (state.historySortKey === key) {
        state.historySortDirection = state.historySortDirection === 'asc' ? 'desc' : 'asc';
      } else {
        state.historySortKey = key;
        state.historySortDirection = 'asc';
      }
      renderHistory(state.history);
    });
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

  els.memberDetail.addEventListener('submit', async (event) => {
    if (event.target.id !== 'memberEditForm') {
      return;
    }
    event.preventDefault();
    if (!window.confirm('Wijzigingen opslaan in de live Meijendel database?')) {
      return;
    }
    const message = event.target.querySelector('#memberEditMessage');
    try {
      message.textContent = 'Opslaan...';
      const updated = await postApi('admin/member-update', Object.fromEntries(new FormData(event.target)));
      renderDetail(updated);
      await loadMembers();
      await loadStaticTables();
      message.textContent = 'Opgeslagen';
      setStatus('Lid bijgewerkt');
    } catch (error) {
      message.textContent = error.message;
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
      ['Beheerstatus', 'beheer_status'],
      ['id', 'id'],
    ]);
  });

  els.exportHistory.addEventListener('click', () => {
    const year = new FormData(els.historyFilters).get('year');
    exportCsv(year ? `telhistorie_${year}.csv` : 'telhistorie_alle_tellers.csv', state.history, [
      ['Code', 'tellercode'],
      ['Naam', 'naam'],
      ['Jaar', 'jaar'],
      ['Plot-id', 'plot_id'],
      ['Kavel', 'kavels'],
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
    const status = await refreshSessionState();
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
    await Promise.all([loadPlots(), loadTellers()]);
    await Promise.all([loadMembers(), loadHistory()]);
    setStatus('Bijgewerkt');
}

init();
