// FyxxVault Extension Popup

import type { VaultEntry, ExtStatus } from '../shared/types';

// ─── DOM references ───
const viewLoading = document.getElementById('view-loading')!;
const viewLogin = document.getElementById('view-login')!;
const viewLocked = document.getElementById('view-locked')!;
const viewUnlocked = document.getElementById('view-unlocked')!;
const btnLogin = document.getElementById('btn-login')!;
const loginEmail = document.getElementById('login-email') as HTMLInputElement;
const loginPassword = document.getElementById('login-password') as HTMLInputElement;
const loginError = document.getElementById('login-error')!;
const btnRegister = document.getElementById('btn-register')!;
const btnUnlock = document.getElementById('btn-unlock')!;
const btnLock = document.getElementById('btn-lock')!;
const masterPasswordInput = document.getElementById('master-password') as HTMLInputElement;
const unlockError = document.getElementById('unlock-error')!;
const searchInput = document.getElementById('search-input') as HTMLInputElement;
const entriesList = document.getElementById('entries-list')!;
const emptyState = document.getElementById('empty-state')!;
const entryCount = document.getElementById('entry-count')!;

let allLogins: VaultEntry[] = [];

// ─── Show a specific view ───
function showView(view: HTMLElement) {
  [viewLoading, viewLogin, viewLocked, viewUnlocked].forEach(v => v.classList.add('hidden'));
  view.classList.remove('hidden');
}

// ─── Get current tab domain ───
async function getCurrentDomain(): Promise<string> {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (tab?.url) {
      return new URL(tab.url).hostname.replace(/^www\./, '');
    }
  } catch {}
  return '';
}

// ─── Render entries ───
function renderEntries(entries: VaultEntry[]) {
  entriesList.innerHTML = '';

  if (entries.length === 0) {
    emptyState.classList.remove('hidden');
    return;
  }

  emptyState.classList.add('hidden');

  for (const entry of entries) {
    const item = document.createElement('div');
    item.className = 'entry-item';

    const domain = extractDomain(entry.website);
    const letter = (entry.title || domain || '?')[0].toUpperCase();

    item.innerHTML = `
      <div class="entry-favicon">
        <img src="https://www.google.com/s2/favicons?domain=${encodeURIComponent(domain)}&sz=40"
             onerror="this.style.display='none';this.nextElementSibling.style.display='flex'"
             alt="">
        <span class="fallback" style="display:none">${letter}</span>
      </div>
      <div class="entry-info">
        <div class="entry-title">${escapeHtml(entry.title || domain)}</div>
        <div class="entry-user">${escapeHtml(entry.username)}</div>
      </div>
      <button class="entry-copy" title="Copier le mot de passe">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>
      </button>
    `;

    // Click to fill on current page
    item.querySelector('.entry-info')?.addEventListener('click', async () => {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (tab?.id) {
        chrome.tabs.sendMessage(tab.id, {
          type: 'FILL_CREDENTIALS',
          username: entry.username,
          password: entry.password
        });
        window.close();
      }
    });

    // Copy password button
    item.querySelector('.entry-copy')?.addEventListener('click', (e) => {
      e.stopPropagation();
      navigator.clipboard.writeText(entry.password);
      const btn = e.currentTarget as HTMLElement;
      btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#22C55E" stroke-width="2" stroke-linecap="round"><path d="M20 6L9 17l-5-5"/></svg>`;
      setTimeout(() => {
        btn.innerHTML = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/></svg>`;
      }, 1500);
    });

    entriesList.appendChild(item);
  }
}

function extractDomain(url: string): string {
  try {
    return new URL(url.startsWith('http') ? url : `https://${url}`).hostname.replace(/^www\./, '');
  } catch {
    return url || '';
  }
}

function escapeHtml(str: string): string {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ─── Event handlers ───

// ─── Login with email + password ───
btnLogin.addEventListener('click', async () => {
  const email = loginEmail.value.trim();
  const password = loginPassword.value;
  if (!email || !password) return;

  btnLogin.textContent = '...';
  btnLogin.setAttribute('disabled', 'true');

  // Login + unlock in one step (password = master password)
  const response = await chrome.runtime.sendMessage({
    type: 'LOGIN_AND_UNLOCK',
    email,
    masterPassword: password
  });

  if (response?.success) {
    loginError.classList.add('hidden');
    await loadAndShow();
  } else {
    loginError.textContent = response?.error || 'Erreur de connexion';
    loginError.classList.remove('hidden');
    btnLogin.textContent = 'Se connecter';
    btnLogin.removeAttribute('disabled');
  }
});

loginPassword.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') btnLogin.click();
});
loginEmail.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') loginPassword.focus();
});

btnRegister.addEventListener('click', (e) => {
  e.preventDefault();
  chrome.tabs.create({ url: 'https://fyxxvault.com/register' });
});

// ─── Unlock (already logged in, just need master password) ───
btnUnlock.addEventListener('click', async () => {
  const password = masterPasswordInput.value;
  if (!password) return;

  btnUnlock.textContent = '...';
  btnUnlock.setAttribute('disabled', 'true');

  const response = await chrome.runtime.sendMessage({ type: 'UNLOCK', masterPassword: password });

  if (response?.success) {
    unlockError.classList.add('hidden');
    await loadAndShow();
  } else {
    unlockError.textContent = response?.error || 'Erreur';
    unlockError.classList.remove('hidden');
    btnUnlock.textContent = 'Deverrouiller';
    btnUnlock.removeAttribute('disabled');
  }
});

masterPasswordInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') btnUnlock.click();
});

btnLock.addEventListener('click', async () => {
  await chrome.runtime.sendMessage({ type: 'LOCK' });
  showView(viewLocked);
});

searchInput.addEventListener('input', () => {
  const q = searchInput.value.toLowerCase().trim();
  if (!q) {
    renderEntries(allLogins);
    return;
  }
  const filtered = allLogins.filter(e =>
    e.title.toLowerCase().includes(q) ||
    e.username.toLowerCase().includes(q) ||
    e.website.toLowerCase().includes(q)
  );
  renderEntries(filtered);
});

// ─── Load entries and show main view ───
async function loadAndShow() {
  const currentDomain = await getCurrentDomain();

  // Get all logins from service worker
  const response = await chrome.runtime.sendMessage({ type: 'GET_LOGINS', domain: '' });

  // Sort: current domain first, then alphabetical
  allLogins = (response?.logins || [])
    .filter((e: VaultEntry) => e.category === 'login')
    .sort((a: VaultEntry, b: VaultEntry) => {
      const aMatch = matchesDomain(a.website, currentDomain) ? 0 : 1;
      const bMatch = matchesDomain(b.website, currentDomain) ? 0 : 1;
      if (aMatch !== bMatch) return aMatch - bMatch;
      return (a.title || a.website).localeCompare(b.title || b.website);
    });

  entryCount.textContent = `${allLogins.length} identifiant${allLogins.length !== 1 ? 's' : ''}`;

  renderEntries(allLogins);
  showView(viewUnlocked);
  searchInput.focus();
}

function matchesDomain(website: string, domain: string): boolean {
  if (!website || !domain) return false;
  const entryDomain = extractDomain(website);
  return domain === entryDomain ||
    domain.endsWith('.' + entryDomain) ||
    entryDomain.endsWith('.' + domain);
}

// ─── Init ───
async function init() {
  const status: ExtStatus = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });

  if (!status.isAuthenticated) {
    showView(viewLogin);
  } else if (!status.isUnlocked) {
    showView(viewLocked);
    masterPasswordInput.focus();
  } else {
    await loadAndShow();
  }
}

init();
