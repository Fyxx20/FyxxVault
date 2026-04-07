// FyxxVault Autofill Content Script
// Dropdown appears directly when user clicks/focuses a login field — like Chrome's native autofill.

import type { VaultEntry } from '../shared/types';

const LOCK_SVG = `<svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="3" y="11" width="18" height="11" rx="2" fill="#00D4FF"/><path d="M7 11V7a5 5 0 0110 0v4" stroke="#00D4FF" stroke-width="2" fill="none"/></svg>`;

let currentDropdown: HTMLElement | null = null;
let cachedLogins: VaultEntry[] = [];
let cachedDomain = '';
let isUnlocked = false;
let processedFields = new WeakSet<HTMLInputElement>();

// ─── Field Detection ───
function findLoginFields(): { usernameField: HTMLInputElement | null; passwordField: HTMLInputElement | null } {
  const passwordFields = document.querySelectorAll<HTMLInputElement>('input[type="password"]');
  if (passwordFields.length === 0) return { usernameField: null, passwordField: null };

  const passwordField = passwordFields[0];
  let usernameField: HTMLInputElement | null = null;

  const form = passwordField.closest('form');
  const container = form || document.body;

  // Walk backwards to find the username/email field before the password field
  const inputs = Array.from(container.querySelectorAll<HTMLInputElement>(
    'input[type="text"], input[type="email"], input[type="tel"], input:not([type])'
  )).filter(el => {
    const t = el.getAttribute('type');
    return !t || t === 'text' || t === 'email' || t === 'tel';
  });

  for (const input of inputs) {
    if (input.compareDocumentPosition(passwordField) & Node.DOCUMENT_POSITION_FOLLOWING) {
      usernameField = input;
    }
  }

  // Fallback: common patterns
  if (!usernameField) {
    const selectors = [
      'input[autocomplete="username"]', 'input[autocomplete="email"]',
      'input[name*="user"]', 'input[name*="email"]', 'input[name*="login"]',
      'input[name*="identifier"]', 'input[id*="user"]', 'input[id*="email"]',
      'input[id*="login"]'
    ];
    for (const sel of selectors) {
      const match = container.querySelector<HTMLInputElement>(sel);
      if (match && match !== passwordField) {
        usernameField = match;
        break;
      }
    }
  }

  return { usernameField, passwordField };
}

// ─── Show dropdown on focus ───
function attachFocusDropdown(field: HTMLInputElement, logins: VaultEntry[], usernameField: HTMLInputElement | null, passwordField: HTMLInputElement) {
  if (processedFields.has(field)) return;
  processedFields.add(field);

  let justFilled = false;

  const showDropdown = () => {
    if (justFilled) return;
    if (logins.length === 0) return;
    if (currentDropdown) return;
    showLoginDropdown(field, logins, usernameField, passwordField, () => { justFilled = true; });
  };

  field.addEventListener('focus', showDropdown);
  field.addEventListener('click', showDropdown);
}

// ─── Dropdown UI ───
function showLoginDropdown(
  anchorField: HTMLInputElement,
  logins: VaultEntry[],
  usernameField: HTMLInputElement | null,
  passwordField: HTMLInputElement,
  onFill?: () => void
) {
  removeDropdown();

  const dropdown = document.createElement('div');
  dropdown.className = 'fyxx-dropdown';

  for (const login of logins.slice(0, 6)) {
    const item = document.createElement('div');
    item.className = 'fyxx-dropdown-item';

    const icon = document.createElement('div');
    icon.className = 'fyxx-dropdown-icon';
    icon.innerHTML = LOCK_SVG;

    const info = document.createElement('div');
    info.className = 'fyxx-dropdown-info';

    const user = document.createElement('div');
    user.className = 'fyxx-dropdown-user';
    user.textContent = login.username || login.email || login.title;

    const pass = document.createElement('div');
    pass.className = 'fyxx-dropdown-pass';
    pass.textContent = '\u2022'.repeat(12);

    info.appendChild(user);
    info.appendChild(pass);
    item.appendChild(icon);
    item.appendChild(info);

    item.addEventListener('mousedown', (e) => {
      e.preventDefault();
      e.stopPropagation();
      removeDropdown();
      if (onFill) onFill();
      fillCredentials(usernameField, passwordField, login.username, login.password);
    });

    dropdown.appendChild(item);
  }

  // Footer
  const footer = document.createElement('div');
  footer.className = 'fyxx-dropdown-footer';
  footer.innerHTML = `<span class="fyxx-dropdown-footer-icon">${LOCK_SVG}</span> FyxxVault`;
  dropdown.appendChild(footer);

  // Position ABOVE the anchor field so it doesn't overlap with Chrome's native dropdown
  const rect = anchorField.getBoundingClientRect();
  dropdown.style.position = 'fixed';
  dropdown.style.left = `${rect.left}px`;
  dropdown.style.width = `${Math.max(rect.width, 280)}px`;
  dropdown.style.zIndex = '2147483647';

  // Temporarily add to DOM to measure height
  dropdown.style.visibility = 'hidden';
  document.body.appendChild(dropdown);
  const dropdownHeight = dropdown.offsetHeight;
  dropdown.style.visibility = '';

  // Place above the field; if not enough space, fall below
  const spaceAbove = rect.top;
  if (spaceAbove >= dropdownHeight + 4) {
    dropdown.style.top = `${rect.top - dropdownHeight - 4}px`;
  } else {
    dropdown.style.top = `${rect.bottom + 4}px`;
  }

  currentDropdown = dropdown;

  // Close on outside click or blur
  const close = (ev: Event) => {
    const target = ev.target as Node;
    if (dropdown.contains(target)) return;
    removeDropdown();
    document.removeEventListener('mousedown', close, true);
    document.removeEventListener('focusin', close, true);
  };

  setTimeout(() => {
    document.addEventListener('mousedown', close, true);
    document.addEventListener('focusin', close, true);
  }, 50);

  // Close on scroll
  const scrollClose = () => {
    removeDropdown();
    window.removeEventListener('scroll', scrollClose, true);
  };
  window.addEventListener('scroll', scrollClose, true);

  // Close on Escape
  const escClose = (ev: KeyboardEvent) => {
    if (ev.key === 'Escape') {
      removeDropdown();
      document.removeEventListener('keydown', escClose, true);
    }
  };
  document.addEventListener('keydown', escClose, true);
}

function removeDropdown() {
  if (currentDropdown) {
    currentDropdown.remove();
    currentDropdown = null;
  }
}

// ─── Fill credentials ───
function fillCredentials(
  usernameField: HTMLInputElement | null,
  passwordField: HTMLInputElement,
  username: string,
  password: string
) {
  const fillField = (field: HTMLInputElement, value: string) => {
    field.focus();
    const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype, 'value'
    )?.set;
    if (nativeInputValueSetter) {
      nativeInputValueSetter.call(field, value);
    } else {
      field.value = value;
    }
    field.dispatchEvent(new Event('input', { bubbles: true }));
    field.dispatchEvent(new Event('change', { bubbles: true }));
    field.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
    field.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
  };

  if (usernameField) fillField(usernameField, username);
  fillField(passwordField, password);
}

// ─── Save Detection ───
function detectFormSubmission() {
  document.addEventListener('submit', handleFormSubmit, true);

  document.addEventListener('click', (e) => {
    const target = e.target as HTMLElement;
    const button = target.closest('button[type="submit"], input[type="submit"], button:not([type])');
    if (button) {
      const form = button.closest('form');
      if (form?.querySelector('input[type="password"]')) {
        setTimeout(() => handleFormSubmit(new Event('submit') as any, form), 100);
      }
    }
  }, true);
}

function handleFormSubmit(e: Event, formOverride?: HTMLFormElement) {
  const form = formOverride || (e.target as HTMLFormElement);
  if (!(form instanceof HTMLFormElement)) return;

  const passwordInput = form.querySelector<HTMLInputElement>('input[type="password"]');
  if (!passwordInput || !passwordInput.value) return;

  const usernameInput = form.querySelector<HTMLInputElement>(
    'input[type="email"], input[type="text"], input[autocomplete="username"]'
  );

  const username = usernameInput?.value || '';
  const password = passwordInput.value;
  const domain = location.hostname;

  if (!username && !password) return;

  chrome.runtime.sendMessage({ type: 'GET_LOGINS', domain }, (response) => {
    if (!response?.logins) return;

    const existing = response.logins.find(
      (l: VaultEntry) => l.username === username
    );

    if (!existing) {
      showSaveBanner(domain, username, password);
    } else if (existing.password !== password) {
      showUpdateBanner(existing, password);
    }
  });
}

// ─── Save Banner ───
function showSaveBanner(domain: string, username: string, password: string) {
  removeBanner();

  const banner = document.createElement('div');
  banner.className = 'fyxx-save-banner';
  banner.id = 'fyxx-save-banner';

  banner.innerHTML = `
    <div class="fyxx-save-banner-content">
      <div class="fyxx-save-banner-text">
        <strong>FyxxVault</strong> — Sauvegarder <span class="fyxx-save-user">${escapeHtml(username)}</span> pour ${escapeHtml(domain)} ?
      </div>
      <button class="fyxx-save-btn fyxx-save-btn-primary" id="fyxx-save-yes">Sauvegarder</button>
      <button class="fyxx-save-btn fyxx-save-btn-secondary" id="fyxx-save-no">Ignorer</button>
    </div>
  `;

  document.body.appendChild(banner);

  document.getElementById('fyxx-save-yes')?.addEventListener('click', () => {
    const entry = {
      id: crypto.randomUUID(),
      title: domain,
      username,
      password,
      website: `https://${domain}`,
      notes: '',
      category: 'login' as const,
      folder: '',
      tags: [],
      isFavorite: false,
      mfaEnabled: false,
      mfaSecret: '',
      createdAt: new Date().toISOString(),
      lastModifiedAt: new Date().toISOString(),
      passwordHistory: []
    };
    chrome.runtime.sendMessage({ type: 'SAVE_LOGIN', entry });
    removeBanner();
  });

  document.getElementById('fyxx-save-no')?.addEventListener('click', removeBanner);
  setTimeout(removeBanner, 15000);
}

function showUpdateBanner(existing: VaultEntry, newPassword: string) {
  removeBanner();

  const banner = document.createElement('div');
  banner.className = 'fyxx-save-banner';
  banner.id = 'fyxx-save-banner';

  banner.innerHTML = `
    <div class="fyxx-save-banner-content">
      <div class="fyxx-save-banner-text">
        <strong>FyxxVault</strong> — Mettre a jour le mot de passe pour <span class="fyxx-save-user">${escapeHtml(existing.username)}</span> ?
      </div>
      <button class="fyxx-save-btn fyxx-save-btn-primary" id="fyxx-save-yes">Mettre a jour</button>
      <button class="fyxx-save-btn fyxx-save-btn-secondary" id="fyxx-save-no">Ignorer</button>
    </div>
  `;

  document.body.appendChild(banner);

  document.getElementById('fyxx-save-yes')?.addEventListener('click', () => {
    const updated = {
      ...existing,
      password: newPassword,
      lastModifiedAt: new Date().toISOString(),
      passwordHistory: [
        ...(existing.passwordHistory || []),
        { password: existing.password, changedAt: new Date().toISOString() }
      ]
    };
    chrome.runtime.sendMessage({ type: 'SAVE_LOGIN', entry: updated });
    removeBanner();
  });

  document.getElementById('fyxx-save-no')?.addEventListener('click', removeBanner);
  setTimeout(removeBanner, 15000);
}

function removeBanner() {
  document.getElementById('fyxx-save-banner')?.remove();
}

function escapeHtml(str: string): string {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

// ─── Main ───
async function init() {
  try {
    const status = await chrome.runtime.sendMessage({ type: 'GET_STATUS' });
    if (!status?.isUnlocked) {
      isUnlocked = false;
      return;
    }
    isUnlocked = true;
  } catch {
    return;
  }

  const domain = location.hostname.replace(/^www\./, '');

  // Always try MFA detection (MFA pages don't have password fields)
  detectMfaField(domain);

  const { usernameField, passwordField } = findLoginFields();
  if (!passwordField) return;

  // Fetch logins for this domain
  if (domain !== cachedDomain) {
    const response = await chrome.runtime.sendMessage({ type: 'GET_LOGINS', domain });
    cachedLogins = response?.logins || [];
    cachedDomain = domain;
  }

  if (cachedLogins.length > 0) {
    if (usernameField) attachFocusDropdown(usernameField, cachedLogins, usernameField, passwordField);
    attachFocusDropdown(passwordField, cachedLogins, usernameField, passwordField);
  }

  detectFormSubmission();
}

// ─── MFA/TOTP auto-fill ───
async function detectMfaField(domain?: string) {
  if (!domain) domain = location.hostname.replace(/^www\./, '');
  // Common selectors for TOTP/2FA input fields
  const selectors = [
    'input[autocomplete="one-time-code"]',
    'input[name*="otp"]', 'input[name*="totp"]', 'input[name*="mfa"]',
    'input[name*="2fa"]', 'input[name*="verification"]', 'input[name*="code"]',
    'input[id*="otp"]', 'input[id*="totp"]', 'input[id*="mfa"]',
    'input[id*="2fa"]', 'input[id*="code"]',
    'input[aria-label*="code"]', 'input[aria-label*="verification"]',
    'input[placeholder*="code"]', 'input[placeholder*="XXXXXX"]',
    'input[placeholder*="000000"]', 'input[placeholder*="6-digit"]',
    'input[maxlength="6"][type="text"]', 'input[maxlength="6"][type="tel"]',
    'input[maxlength="6"][type="number"]',
    'input[maxlength="6"]:not([type])',
  ];

  let mfaField: HTMLInputElement | null = null;
  for (const sel of selectors) {
    const el = document.querySelector<HTMLInputElement>(sel);
    if (el && !el.value) {
      mfaField = el;
      break;
    }
  }

  // Also check if page text mentions 2FA/TOTP/verification
  if (!mfaField) {
    const pageText = document.body.innerText.toLowerCase();
    const is2faPage = pageText.includes('two-factor') || pageText.includes('2fa') ||
      pageText.includes('authentication code') || pageText.includes('verification code') ||
      pageText.includes('authenticator') || pageText.includes('code de verification');

    if (is2faPage) {
      // Find a short text/number input that looks like a code field
      const inputs = document.querySelectorAll<HTMLInputElement>(
        'input[type="text"], input[type="tel"], input[type="number"], input:not([type])'
      );
      for (const input of inputs) {
        const ml = input.getAttribute('maxlength');
        const isShort = ml && parseInt(ml) <= 8;
        const isPassword = input.type === 'password';
        if (!isPassword && (isShort || input.inputMode === 'numeric') && !input.value) {
          mfaField = input;
          break;
        }
      }
    }
  }

  if (!mfaField) return;

  const response = await chrome.runtime.sendMessage({ type: 'GET_TOTP', domain });

  if (response?.code) {
    // Auto-fill the TOTP code
    fillField(mfaField, response.code);
  }
}

function fillField(field: HTMLInputElement, value: string) {
  field.focus();
  const nativeInputValueSetter = Object.getOwnPropertyDescriptor(
    HTMLInputElement.prototype, 'value'
  )?.set;
  if (nativeInputValueSetter) {
    nativeInputValueSetter.call(field, value);
  } else {
    field.value = value;
  }
  field.dispatchEvent(new Event('input', { bubbles: true }));
  field.dispatchEvent(new Event('change', { bubbles: true }));
}

// ─── Handle FILL_CREDENTIALS from popup ───
chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg.type === 'FILL_CREDENTIALS') {
    const { usernameField, passwordField } = findLoginFields();
    if (passwordField) {
      fillCredentials(usernameField, passwordField, msg.username, msg.password);
      sendResponse({ success: true });
    } else {
      sendResponse({ success: false, error: 'No password field found' });
    }
  }
  return false;
});

// Run on page load
init();

// Re-run on DOM changes (SPA navigation)
const observer = new MutationObserver(() => {
  const passwordFields = document.querySelectorAll<HTMLInputElement>('input[type="password"]');
  for (const field of passwordFields) {
    if (!processedFields.has(field)) {
      init();
      break;
    }
  }
});

observer.observe(document.body, { childList: true, subtree: true });
