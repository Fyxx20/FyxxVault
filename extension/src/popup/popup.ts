// FyxxVault Extension Popup — Full-featured with tabs, add entry, emails, settings, password generator

import { CATEGORY_META, newVaultEntry } from '../shared/types';
import type { VaultEntry, VaultCategory, ExtStatus, ExtSettings, EmailAlias, Email } from '../shared/types';

// ─── DOM references ───
const $ = (id: string) => document.getElementById(id)!;
const viewLoading = $('view-loading');
const viewLogin = $('view-login');
const viewLocked = $('view-locked');
const viewMain = $('view-main');

// Auth
const btnLogin = $('btn-login');
const loginEmail = $('login-email') as HTMLInputElement;
const loginPassword = $('login-password') as HTMLInputElement;
const loginError = $('login-error');
const btnRegister = $('btn-register');
const btnUnlock = $('btn-unlock');
const masterPasswordInput = $('master-password') as HTMLInputElement;
const unlockError = $('unlock-error');

// Vault tab
const searchInput = $('search-input') as HTMLInputElement;
const entriesList = $('entries-list');
const emptyState = $('empty-state');
const entryCount = $('entry-count');
const categoryChips = $('category-chips');
const btnAdd = $('btn-add');
const btnLock = $('btn-lock');

// Emails tab
const aliasesList = $('aliases-list');
const emailsList = $('emails-list');
const emailDetail = $('email-detail');
const emailsEmpty = $('emails-empty');
const btnNewAlias = $('btn-new-alias');

// Settings tab
const userEmailEl = $('user-email');
const userAvatar = $('user-avatar');
const settingAutolock = $('setting-autolock') as HTMLSelectElement;
const settingClipboard = $('setting-clipboard') as HTMLSelectElement;
const settingChromePw = $('setting-chrome-pw') as HTMLInputElement;

// Overlays
const overlayAdd = $('overlay-add');
const overlayGenerator = $('overlay-generator');

// ─── State ───
let allEntries: VaultEntry[] = [];
let activeCategory: string = 'all';
let currentDomain = '';
let userEmail = '';
let clipboardTimer: ReturnType<typeof setTimeout> | null = null;
let addCategory: VaultCategory = 'login';
let generatedPassword = '';
let generatorCallback: ((pw: string) => void) | null = null;

// ─── Views ───
function showView(view: HTMLElement) {
  [viewLoading, viewLogin, viewLocked, viewMain].forEach(v => v.classList.add('hidden'));
  view.classList.remove('hidden');
}

// ─── Tabs ───
function switchTab(tab: string) {
  document.querySelectorAll('.tab-content').forEach(t => t.classList.add('hidden'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  $(`tab-${tab}`)?.classList.remove('hidden');
  document.querySelector(`.nav-btn[data-tab="${tab}"]`)?.classList.add('active');

  if (tab === 'emails') loadAliases();
  if (tab === 'settings') loadSettings();
}

document.querySelectorAll('.nav-btn').forEach(btn => {
  btn.addEventListener('click', () => switchTab((btn as HTMLElement).dataset.tab!));
});

// ─── Utils ───
function escapeHtml(str: string): string {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function extractDomain(url: string): string {
  try {
    return new URL(url.startsWith('http') ? url : `https://${url}`).hostname.replace(/^www\./, '');
  } catch { return url || ''; }
}

function matchesDomain(website: string, domain: string): boolean {
  if (!website || !domain) return false;
  const entryDomain = extractDomain(website);
  return domain === entryDomain || domain.endsWith('.' + entryDomain) || entryDomain.endsWith('.' + domain);
}

function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "a l'instant";
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}j`;
}

async function getCurrentDomain(): Promise<string> {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab?.url) return new URL(tab.url).hostname.replace(/^www\./, '');
  } catch {}
  return '';
}

async function copyToClipboard(text: string) {
  await navigator.clipboard.writeText(text);
  // Auto-clear clipboard
  if (clipboardTimer) clearTimeout(clipboardTimer);
  const settings: ExtSettings = await chrome.runtime.sendMessage({ type: 'GET_SETTINGS' });
  if (settings.clipboardClearSeconds > 0) {
    clipboardTimer = setTimeout(() => {
      navigator.clipboard.writeText('').catch(() => {});
    }, settings.clipboardClearSeconds * 1000);
  }
}

// ═══════════════════════════════════════════════
// ─── VAULT TAB ───
// ═══════════════════════════════════════════════

function getFilteredEntries(): VaultEntry[] {
  let filtered = allEntries;
  if (activeCategory !== 'all') {
    filtered = filtered.filter(e => e.category === activeCategory);
  }
  const q = searchInput.value.toLowerCase().trim();
  if (q) {
    filtered = filtered.filter(e =>
      e.title.toLowerCase().includes(q) ||
      e.username.toLowerCase().includes(q) ||
      e.website.toLowerCase().includes(q) ||
      (e.notes || '').toLowerCase().includes(q)
    );
  }
  // Sort: favorites first, then domain match, then alphabetical
  return filtered.sort((a, b) => {
    if (a.isFavorite !== b.isFavorite) return a.isFavorite ? -1 : 1;
    const aMatch = matchesDomain(a.website, currentDomain) ? 0 : 1;
    const bMatch = matchesDomain(b.website, currentDomain) ? 0 : 1;
    if (aMatch !== bMatch) return aMatch - bMatch;
    return (a.title || a.website).localeCompare(b.title || b.website);
  });
}

function renderEntries() {
  const filtered = getFilteredEntries();
  entriesList.innerHTML = '';

  if (filtered.length === 0) {
    emptyState.classList.remove('hidden');
    entryCount.textContent = '';
    return;
  }
  emptyState.classList.add('hidden');

  for (const entry of filtered) {
    const item = document.createElement('div');
    item.className = 'entry-item';
    const domain = extractDomain(entry.website);
    const letter = (entry.title || domain || '?')[0].toUpperCase();
    const meta = CATEGORY_META[entry.category] || CATEGORY_META.other;
    const subtitle = entry.username || entry.cardholderName || entry.networkName || entry.bankName || entry.firstName || '';

    item.innerHTML = `
      <div class="entry-favicon">
        ${entry.category === 'login' && domain
          ? `<img src="https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=40" onerror="this.style.display='none';this.nextElementSibling.style.display='flex'" alt="">
             <span class="fallback">${letter}</span>`
          : `<span style="font-size:18px">${meta.icon}</span>`
        }
      </div>
      <div class="entry-info">
        <div class="entry-title">${entry.isFavorite ? '<span class="entry-fav">★</span>' : ''}${escapeHtml(entry.title || domain || meta.label)}</div>
        ${subtitle ? `<div class="entry-user">${escapeHtml(subtitle)}</div>` : ''}
      </div>
      <button class="entry-copy" title="Copier">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
      </button>
    `;

    // Click entry to fill (login only) or copy main field
    item.querySelector('.entry-info')?.addEventListener('click', async () => {
      if (entry.category === 'login') {
        const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
        if (tab?.id) {
          chrome.tabs.sendMessage(tab.id, { type: 'FILL_CREDENTIALS', username: entry.username, password: entry.password });
          window.close();
        }
      } else if (entry.category === 'creditCard' && entry.cardNumber) {
        await copyToClipboard(entry.cardNumber);
        showCopyFeedback(item);
      } else if (entry.category === 'wifi' && entry.password) {
        await copyToClipboard(entry.password);
        showCopyFeedback(item);
      }
    });

    // Copy button — copies the most relevant secret
    item.querySelector('.entry-copy')?.addEventListener('click', async (e) => {
      e.stopPropagation();
      const secret = entry.password || entry.cardNumber || entry.licenseKey || entry.iban || entry.notes || '';
      if (secret) {
        await copyToClipboard(secret);
        showCopyFeedback(item);
      }
    });

    entriesList.appendChild(item);
  }

  const total = activeCategory === 'all' ? allEntries.length : filtered.length;
  entryCount.textContent = `${total} element${total !== 1 ? 's' : ''}`;
}

function showCopyFeedback(item: Element) {
  const btn = item.querySelector('.entry-copy') as HTMLElement;
  if (!btn) return;
  btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22C55E" stroke-width="2" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>`;
  setTimeout(() => {
    btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>`;
  }, 1500);
}

// Category chips
categoryChips.addEventListener('click', (e) => {
  const chip = (e.target as HTMLElement).closest('.chip') as HTMLElement;
  if (!chip) return;
  categoryChips.querySelectorAll('.chip').forEach(c => c.classList.remove('active'));
  chip.classList.add('active');
  activeCategory = chip.dataset.cat || 'all';
  renderEntries();
});

searchInput.addEventListener('input', () => renderEntries());

async function loadVault() {
  currentDomain = await getCurrentDomain();
  const response = await chrome.runtime.sendMessage({ type: 'GET_LOGINS', domain: '' });
  allEntries = response?.logins || [];
  renderEntries();
}

// ═══════════════════════════════════════════════
// ─── ADD ENTRY ───
// ═══════════════════════════════════════════════

const FIELDS_BY_CAT: Record<string, { key: string; label: string; type?: string }[]> = {
  login: [
    { key: 'title', label: 'Titre' },
    { key: 'website', label: 'Site web' },
    { key: 'username', label: 'Identifiant' },
    { key: 'password', label: 'Mot de passe', type: 'password' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  creditCard: [
    { key: 'title', label: 'Titre' },
    { key: 'cardholderName', label: 'Titulaire' },
    { key: 'cardNumber', label: 'Numero de carte' },
    { key: 'cardExpiry', label: 'Expiration (MM/AA)' },
    { key: 'cardCVV', label: 'CVV', type: 'password' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  secureNote: [
    { key: 'title', label: 'Titre' },
    { key: 'notes', label: 'Note', type: 'textarea' },
  ],
  identity: [
    { key: 'title', label: 'Titre' },
    { key: 'firstName', label: 'Prenom' },
    { key: 'lastName', label: 'Nom' },
    { key: 'email', label: 'Email' },
    { key: 'phone', label: 'Telephone' },
    { key: 'address', label: 'Adresse' },
    { key: 'dateOfBirth', label: 'Date de naissance' },
  ],
  bankAccount: [
    { key: 'title', label: 'Titre' },
    { key: 'bankName', label: 'Banque' },
    { key: 'iban', label: 'IBAN' },
    { key: 'bic', label: 'BIC' },
    { key: 'accountNumber', label: 'Numero de compte' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  wifi: [
    { key: 'title', label: 'Titre' },
    { key: 'networkName', label: 'Nom du reseau' },
    { key: 'password', label: 'Mot de passe', type: 'password' },
    { key: 'securityType', label: 'Type de securite' },
  ],
};

function renderAddFields() {
  const fields = FIELDS_BY_CAT[addCategory] || FIELDS_BY_CAT.login;
  const container = $('add-fields');
  container.innerHTML = '';

  for (const field of fields) {
    const div = document.createElement('div');
    div.className = 'add-field';

    if (field.type === 'textarea') {
      div.innerHTML = `<label>${field.label}</label><textarea id="add-${field.key}" placeholder="${field.label}"></textarea>`;
    } else if (field.key === 'password') {
      div.innerHTML = `
        <label>${field.label}</label>
        <div class="field-row">
          <div class="add-field" style="margin:0"><input type="password" id="add-${field.key}" placeholder="${field.label}"></div>
          <button class="btn-icon" id="btn-add-gen" title="Generer">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 11-7.778 7.778 5.5 5.5 0 017.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
          </button>
        </div>
      `;
    } else {
      div.innerHTML = `<label>${field.label}</label><input type="${field.type || 'text'}" id="add-${field.key}" placeholder="${field.label}">`;
    }
    container.appendChild(div);
  }

  // Generator button for password field
  const genBtn = $('btn-add-gen');
  if (genBtn) {
    genBtn.addEventListener('click', () => {
      generatorCallback = (pw) => {
        const pwInput = $('add-password') as HTMLInputElement;
        if (pwInput) pwInput.value = pw;
      };
      $('btn-gen-use')?.classList.remove('hidden');
      overlayGenerator.classList.remove('hidden');
    });
  }
}

// Category selector in add overlay
$('category-selector').addEventListener('click', (e) => {
  const btn = (e.target as HTMLElement).closest('.cat-btn') as HTMLElement;
  if (!btn) return;
  document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  addCategory = (btn.dataset.cat || 'login') as VaultCategory;
  renderAddFields();
});

// Open add overlay
btnAdd.addEventListener('click', () => {
  addCategory = 'login';
  document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
  document.querySelector('.cat-btn[data-cat="login"]')?.classList.add('active');
  renderAddFields();
  overlayAdd.classList.remove('hidden');
  // Pre-fill website with current domain
  setTimeout(() => {
    const websiteInput = $('add-website') as HTMLInputElement;
    if (websiteInput && currentDomain) websiteInput.value = currentDomain;
  }, 50);
});

$('btn-add-back').addEventListener('click', () => overlayAdd.classList.add('hidden'));

// Save entry
$('btn-add-save').addEventListener('click', async () => {
  const saveBtn = $('btn-add-save') as HTMLButtonElement;
  saveBtn.disabled = true;
  saveBtn.textContent = '...';

  const fields = FIELDS_BY_CAT[addCategory] || FIELDS_BY_CAT.login;
  const overrides: Record<string, any> = { category: addCategory };

  for (const field of fields) {
    const el = $(`add-${field.key}`) as HTMLInputElement | HTMLTextAreaElement;
    if (el) overrides[field.key] = el.value;
  }

  if (!overrides.title) {
    overrides.title = overrides.website ? extractDomain(overrides.website) : CATEGORY_META[addCategory].label;
  }

  const entry = newVaultEntry(overrides);
  const response = await chrome.runtime.sendMessage({ type: 'SAVE_LOGIN', entry });

  if (response?.success) {
    overlayAdd.classList.add('hidden');
    await loadVault();
  } else {
    alert(response?.error || 'Erreur');
  }

  saveBtn.disabled = false;
  saveBtn.textContent = 'Enregistrer';
});

// ═══════════════════════════════════════════════
// ─── PASSWORD GENERATOR ───
// ═══════════════════════════════════════════════

const genPreview = $('gen-preview');
const genLengthSlider = $('gen-length') as HTMLInputElement;
const genLengthVal = $('gen-length-val');
const genStrengthBar = $('gen-strength-bar').querySelector('.gen-strength-fill') as HTMLElement;
const genStrengthLabel = $('gen-strength-label');

genLengthSlider.addEventListener('input', () => {
  genLengthVal.textContent = genLengthSlider.value;
});

async function doGenerate() {
  const length = parseInt(genLengthSlider.value);
  const response = await chrome.runtime.sendMessage({
    type: 'GENERATE_PASSWORD',
    length,
    uppercase: ($('gen-upper') as HTMLInputElement).checked,
    lowercase: ($('gen-lower') as HTMLInputElement).checked,
    digits: ($('gen-digits') as HTMLInputElement).checked,
    symbols: ($('gen-symbols') as HTMLInputElement).checked,
  });

  generatedPassword = response?.password || '';
  genPreview.textContent = generatedPassword;

  // Strength meter
  let score = 0;
  if (length >= 8) score += 15;
  if (length >= 12) score += 15;
  if (length >= 16) score += 15;
  if (length >= 20) score += 10;
  if (/[a-z]/.test(generatedPassword)) score += 10;
  if (/[A-Z]/.test(generatedPassword)) score += 10;
  if (/[0-9]/.test(generatedPassword)) score += 10;
  if (/[^a-zA-Z0-9]/.test(generatedPassword)) score += 15;
  score = Math.min(100, score);

  genStrengthBar.style.width = score + '%';
  if (score < 30) { genStrengthBar.style.background = 'var(--fv-danger)'; genStrengthLabel.textContent = 'Faible'; }
  else if (score < 60) { genStrengthBar.style.background = 'var(--fv-gold)'; genStrengthLabel.textContent = 'Moyen'; }
  else if (score < 80) { genStrengthBar.style.background = 'var(--fv-cyan)'; genStrengthLabel.textContent = 'Fort'; }
  else { genStrengthBar.style.background = 'var(--fv-success)'; genStrengthLabel.textContent = 'Excellent'; }
}

$('btn-gen-generate').addEventListener('click', doGenerate);
$('btn-gen-copy').addEventListener('click', async () => {
  if (generatedPassword) {
    await copyToClipboard(generatedPassword);
    $('btn-gen-copy').textContent = 'Copie !';
    setTimeout(() => { $('btn-gen-copy').textContent = 'Copier'; }, 1500);
  }
});

$('btn-gen-back').addEventListener('click', () => {
  overlayGenerator.classList.add('hidden');
  generatorCallback = null;
});

$('btn-gen-use')?.addEventListener('click', () => {
  if (generatorCallback && generatedPassword) {
    generatorCallback(generatedPassword);
  }
  overlayGenerator.classList.add('hidden');
  $('btn-gen-use')?.classList.add('hidden');
  generatorCallback = null;
});

// Standalone generator from settings
$('btn-gen-standalone').addEventListener('click', () => {
  generatorCallback = null;
  $('btn-gen-use')?.classList.add('hidden');
  overlayGenerator.classList.remove('hidden');
  doGenerate();
});

// ═══════════════════════════════════════════════
// ─── EMAILS TAB ───
// ═══════════════════════════════════════════════

let currentAliasId: string | null = null;

async function loadAliases() {
  const response = await chrome.runtime.sendMessage({ type: 'GET_ALIASES' });
  const aliases: EmailAlias[] = response?.aliases || [];

  if (aliases.length === 0) {
    aliasesList.classList.add('hidden');
    emailsList.classList.add('hidden');
    emailDetail.classList.add('hidden');
    emailsEmpty.classList.remove('hidden');
    return;
  }

  emailsEmpty.classList.add('hidden');
  emailDetail.classList.add('hidden');
  emailsList.classList.add('hidden');
  aliasesList.classList.remove('hidden');
  aliasesList.innerHTML = '';

  for (const alias of aliases) {
    const item = document.createElement('div');
    item.className = 'alias-item';
    item.innerHTML = `
      <div class="alias-icon">${alias.is_active ? '📧' : '🚫'}</div>
      <div class="alias-info">
        <div class="alias-address">${escapeHtml(alias.address)}</div>
        <div class="alias-label">${escapeHtml(alias.label || 'Sans label')}</div>
      </div>
      <span class="alias-count">${alias.emails_received}</span>
    `;
    item.addEventListener('click', () => loadEmailsForAlias(alias.id, alias.address));
    aliasesList.appendChild(item);
  }
}

async function loadEmailsForAlias(aliasId: string, aliasAddress: string) {
  currentAliasId = aliasId;
  const response = await chrome.runtime.sendMessage({ type: 'GET_EMAILS', aliasId });
  const emails: Email[] = response?.emails || [];

  aliasesList.classList.add('hidden');
  emailDetail.classList.add('hidden');
  emailsList.classList.remove('hidden');
  emailsList.innerHTML = '';

  // Back bar
  const backBar = document.createElement('div');
  backBar.className = 'email-back-bar';
  backBar.innerHTML = `
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
    <span>${escapeHtml(aliasAddress)}</span>
  `;
  backBar.addEventListener('click', () => loadAliases());
  emailsList.appendChild(backBar);

  if (emails.length === 0) {
    const empty = document.createElement('div');
    empty.className = 'empty-state';
    empty.innerHTML = '<p>Aucun email recu</p>';
    emailsList.appendChild(empty);
    return;
  }

  for (const email of emails) {
    const item = document.createElement('div');
    item.className = `email-item${email.is_read ? '' : ' unread'}`;
    item.innerHTML = `
      <div class="email-dot${email.is_read ? ' read' : ''}"></div>
      <div class="email-content">
        <div class="email-from">${escapeHtml(email.from_name || email.from_address)}</div>
        <div class="email-subject">${escapeHtml(email.subject || '(Sans sujet)')}</div>
      </div>
      <span class="email-date">${timeAgo(email.received_at)}</span>
    `;
    item.addEventListener('click', () => showEmailDetail(email));
    emailsList.appendChild(item);
  }
}

function showEmailDetail(email: Email) {
  emailsList.classList.add('hidden');
  emailDetail.classList.remove('hidden');
  emailDetail.innerHTML = `
    <div class="email-back-bar" id="email-detail-back">
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><polyline points="15 18 9 12 15 6"/></svg>
      <span>Retour</span>
    </div>
    <div style="padding: 14px;">
      <div class="email-detail-header">
        <div class="email-detail-subject">${escapeHtml(email.subject || '(Sans sujet)')}</div>
        <div class="email-detail-meta">
          De: ${escapeHtml(email.from_name || '')} &lt;${escapeHtml(email.from_address)}&gt;<br>
          A: ${escapeHtml(email.to_address)}<br>
          ${new Date(email.received_at).toLocaleString('fr-FR')}
        </div>
      </div>
      <div class="email-detail-body">${escapeHtml(email.body_text || 'Aucun contenu texte.')}</div>
    </div>
  `;
  $('email-detail-back')?.addEventListener('click', () => {
    if (currentAliasId) {
      emailDetail.classList.add('hidden');
      emailsList.classList.remove('hidden');
    }
  });
}

btnNewAlias.addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/vault/emails' });
});

// ═══════════════════════════════════════════════
// ─── SETTINGS TAB ───
// ═══════════════════════════════════════════════

async function loadSettings() {
  const settings: ExtSettings = await chrome.runtime.sendMessage({ type: 'GET_SETTINGS' });
  settingAutolock.value = String(settings.autoLockMinutes);
  settingClipboard.value = String(settings.clipboardClearSeconds);
  settingChromePw.checked = settings.disableChromePasswords;

  if (userEmail) {
    userEmailEl.textContent = userEmail;
    userAvatar.textContent = userEmail[0].toUpperCase();
  }
}

settingAutolock.addEventListener('change', () => {
  chrome.runtime.sendMessage({ type: 'UPDATE_SETTINGS', settings: { autoLockMinutes: parseInt(settingAutolock.value) } });
});
settingClipboard.addEventListener('change', () => {
  chrome.runtime.sendMessage({ type: 'UPDATE_SETTINGS', settings: { clipboardClearSeconds: parseInt(settingClipboard.value) } });
});
settingChromePw.addEventListener('change', () => {
  chrome.runtime.sendMessage({ type: 'UPDATE_SETTINGS', settings: { disableChromePasswords: settingChromePw.checked } });
  if (settingChromePw.checked) {
    chrome.runtime.sendMessage({ type: 'DISABLE_GOOGLE_PASSWORDS' });
  }
});

$('btn-open-vault').addEventListener('click', () => {
  chrome.tabs.create({ url: 'https://fyxxvault.com/vault' });
});

$('btn-lock-settings').addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'LOCK' });
  showView(viewLocked);
});

$('btn-logout').addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'LOGOUT' });
  showView(viewLogin);
});

// ═══════════════════════════════════════════════
// ─── AUTH HANDLERS ───
// ═══════════════════════════════════════════════

btnLogin.addEventListener('click', async () => {
  const email = loginEmail.value.trim();
  const password = loginPassword.value;
  if (!email || !password) return;

  btnLogin.textContent = '...';
  btnLogin.setAttribute('disabled', 'true');

  const response = await chrome.runtime.sendMessage({ type: 'LOGIN_AND_UNLOCK', email, masterPassword: password });

  if (response?.success) {
    loginError.classList.add('hidden');
    userEmail = email;
    await loadVault();
    showView(viewMain);
    switchTab('vault');
  } else {
    loginError.textContent = response?.error || 'Erreur de connexion';
    loginError.classList.remove('hidden');
    btnLogin.textContent = 'Se connecter';
    btnLogin.removeAttribute('disabled');
  }
});

loginPassword.addEventListener('keydown', (e) => { if (e.key === 'Enter') btnLogin.click(); });
loginEmail.addEventListener('keydown', (e) => { if (e.key === 'Enter') loginPassword.focus(); });
btnRegister.addEventListener('click', (e) => { e.preventDefault(); chrome.tabs.create({ url: 'https://fyxxvault.com/register' }); });

btnUnlock.addEventListener('click', async () => {
  const password = masterPasswordInput.value;
  if (!password) return;

  btnUnlock.textContent = '...';
  btnUnlock.setAttribute('disabled', 'true');

  const response = await chrome.runtime.sendMessage({ type: 'UNLOCK', masterPassword: password });

  if (response?.success) {
    unlockError.classList.add('hidden');
    await loadVault();
    showView(viewMain);
    switchTab('vault');
  } else {
    unlockError.textContent = response?.error || 'Erreur';
    unlockError.classList.remove('hidden');
    btnUnlock.textContent = 'Deverrouiller';
    btnUnlock.removeAttribute('disabled');
  }
});

masterPasswordInput.addEventListener('keydown', (e) => { if (e.key === 'Enter') btnUnlock.click(); });

btnLock.addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'LOCK' });
  showView(viewLocked);
});

// ═══════════════════════════════════════════════
// ─── INIT ───
// ═══════════════════════════════════════════════

async function init() {
  const status: ExtStatus = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });

  if (!status.isAuthenticated) {
    showView(viewLogin);
  } else if (!status.isUnlocked) {
    showView(viewLocked);
    masterPasswordInput.focus();
  } else {
    userEmail = status.userEmail || '';
    await loadVault();
    showView(viewMain);
    switchTab('vault');
    searchInput.focus();
  }
}

init();
