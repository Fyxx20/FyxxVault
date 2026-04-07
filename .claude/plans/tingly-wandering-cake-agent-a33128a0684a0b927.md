# FyxxVault Extension Popup Major Upgrade — Implementation Plan

## Overview

Transform the extension popup from a single-page login list into a full-featured three-tab application (Vault / Emails / Settings) with add-entry form, password generator, category filtering, folder grouping, email inbox, and comprehensive settings — all in vanilla HTML/TS/CSS within the 360x520px popup constraint.

---

## Phase 1: Foundation — Types, Settings Infrastructure, and Service Worker Messages

### 1A. Update `extension/src/shared/types.ts`

Add the following new types and extend `ExtMessage`:

```ts
// ─── Email types (mirrors web app + iOS models) ───
export interface EmailAlias {
  id: string;
  address: string;
  label: string;
  is_active: boolean;
  emails_received: number;
  created_at: string;
}

export interface Email {
  id: string;
  alias_id: string;
  from_address: string;
  from_name: string;
  to_address: string;
  subject: string;
  body_text?: string;
  body_html?: string;
  folder: string;        // 'inbox' | 'spam' | 'trash' | 'archive'
  is_read: boolean;
  is_starred: boolean;
  received_at: string;
}

// ─── Settings types ───
export type AutoLockTimeout = 1 | 5 | 15 | 30 | 60 | 0; // 0 = never, values in minutes
export type ClipboardClearDelay = 10 | 30 | 60 | 0;      // 0 = never, values in seconds
export type AppLanguage = 'fr' | 'en';

export interface ExtSettings {
  autoLockMinutes: AutoLockTimeout;
  clipboardClearSeconds: ClipboardClearDelay;
  disableChromePasswords: boolean;
  language: AppLanguage;
}

export const DEFAULT_SETTINGS: ExtSettings = {
  autoLockMinutes: 15,
  clipboardClearSeconds: 30,
  disableChromePasswords: true,
  language: 'fr'
};

// ─── Category metadata ───
export const CATEGORY_META: Record<VaultCategory, { label: string; labelEn: string; icon: string }> = {
  login:           { label: 'Identifiants',  labelEn: 'Logins',           icon: 'key' },
  creditCard:      { label: 'Cartes',        labelEn: 'Cards',            icon: 'credit-card' },
  identity:        { label: 'Identité',      labelEn: 'Identity',         icon: 'user' },
  secureNote:      { label: 'Notes',         labelEn: 'Notes',            icon: 'file-text' },
  bankAccount:     { label: 'Banque',        labelEn: 'Bank',             icon: 'landmark' },
  wifi:            { label: 'Wi-Fi',         labelEn: 'Wi-Fi',            icon: 'wifi' },
  softwareLicense: { label: 'Licences',      labelEn: 'Licenses',         icon: 'package' },
  passport:        { label: 'Passeports',    labelEn: 'Passports',        icon: 'globe' },
  server:          { label: 'Serveurs',      labelEn: 'Servers',          icon: 'server' },
  other:           { label: 'Autres',        labelEn: 'Other',            icon: 'more-horizontal' },
};
```

Extend `ExtMessage` union with new message types:

```ts
export type ExtMessage =
  // ... existing messages ...
  | { type: 'GET_EMAILS'; folder: string; alias_id?: string; search?: string }
  | { type: 'GET_EMAIL'; id: string }
  | { type: 'GET_ALIASES' }
  | { type: 'CREATE_ALIAS'; label: string }
  | { type: 'TOGGLE_ALIAS'; id: string; is_active: boolean }
  | { type: 'MARK_EMAILS_READ'; ids: string[]; is_read: boolean }
  | { type: 'MOVE_EMAILS'; ids: string[]; folder: string }
  | { type: 'DELETE_ENTRY'; id: string }
  | { type: 'GET_SETTINGS' }
  | { type: 'UPDATE_SETTINGS'; settings: Partial<ExtSettings> }
  | { type: 'GENERATE_PASSWORD'; length: number; uppercase: boolean; lowercase: boolean; digits: boolean; symbols: boolean }
  | { type: 'LOGOUT' };
```

### 1B. Update `extension/src/background/service-worker.ts`

Add the following handlers inside the existing `switch (msg.type)` block:

**Settings management** — use `chrome.storage.local` with key `fv_settings`:
- `GET_SETTINGS`: Read from `chrome.storage.local`, merge with `DEFAULT_SETTINGS`
- `UPDATE_SETTINGS`: Merge partial update into stored settings, update auto-lock alarm, update clipboard behavior

**Auto-lock via chrome.alarms**:
- On `UPDATE_SETTINGS` when `autoLockMinutes` changes: clear existing alarm `fv-auto-lock`, create new one if value > 0
- Add `chrome.alarms.onAlarm` listener: when `fv-auto-lock` fires, call `lock()`
- Reset alarm on every `lastActivity` update (use `chrome.alarms.create` with `delayInMinutes`)

**Email handlers** — direct Supabase queries (the `supabase` client is already available):
- `GET_ALIASES`: Query `email_aliases` table where `user_id = session.user.id`, ordered by `created_at desc`
- `CREATE_ALIAS`: This requires calling the web app's API (via `fetch` to `https://fyxxvault.com/api/email/aliases`) with the user's auth token, since alias creation involves external service (addy.io). The extension cannot call addy.io directly — it must go through the web app's API.
- `TOGGLE_ALIAS`: Same — POST/PATCH to web app API
- `GET_EMAILS`: Query `emails` table with filters (folder, alias_id, search on subject/from_address), ordered by `received_at desc`, limited to 50
- `GET_EMAIL`: Query single email by id, also mark as read via update
- `MARK_EMAILS_READ` / `MOVE_EMAILS`: Update `emails` table rows

**Password generator**:
- `GENERATE_PASSWORD`: Pure logic — build charset from toggles, use `crypto.getRandomValues` to pick characters

**Entry management**:
- `DELETE_ENTRY`: Soft-delete by setting `deleted_at` on `vault_items` row, remove from `entries` array
- `LOGOUT`: Call `supabase.auth.signOut()`, then `lock()`

**Clipboard auto-clear**:
- Export a helper used by popup: after copying, set a timeout to clear clipboard
- Or: service worker receives `CLIPBOARD_COPIED` message, sets `chrome.alarms` to fire after `clipboardClearSeconds`, clears clipboard on alarm (note: service worker cannot directly access clipboard — this must happen in popup). **Decision: clipboard clear timer lives in popup.ts.**

### 1C. Manifest changes

The manifest already has `storage`, `alarms`, `privacy`, and `<all_urls>` permissions. No new permissions needed. The `email_aliases` and `emails` Supabase tables are accessed via the existing Supabase client with the user's auth session (RLS handles security).

---

## Phase 2: Popup HTML Restructure

### 2A. New HTML structure for `extension/src/popup/popup.html`

The HTML will have these top-level views (same show/hide pattern as current):

1. `#view-loading` — unchanged
2. `#view-login` — unchanged
3. `#view-locked` — unchanged
4. `#view-main` — NEW: replaces `#view-unlocked`, contains tab system

Inside `#view-main`:
```
#view-main
├── .header (logo, title, "+" button, lock button)
├── #tab-vault (the vault content area)
│   ├── .search-bar
│   ├── .category-chips (horizontal scrollable row of filter chips)
│   ├── #entries-list (scrollable list)
│   ├── #empty-state
│   └── .footer (entry count)
├── #tab-emails (hidden by default)
│   ├── .emails-header (folder tabs: inbox/spam/archive + refresh)
│   ├── .emails-list (scrollable)
│   ├── #email-detail (hidden, shows when email selected)
│   └── .emails-empty
├── #tab-settings (hidden by default)
│   ├── Settings sections (auto-lock, clipboard, language, etc.)
│   └── Lock/Logout buttons
├── #view-add-entry (overlay/screen for adding entry, hidden by default)
│   ├── Category selector (grid of icons)
│   ├── Dynamic form fields
│   ├── Password generator toggle
│   └── Save/Cancel buttons
├── #view-password-generator (overlay, hidden by default)
│   ├── Generated password display
│   ├── Length slider
│   ├── Character type toggles
│   ├── Strength indicator
│   └── Copy/Use buttons
└── .bottom-nav (3 tabs: Coffre-fort, Emails, Réglages)
```

### 2B. Bottom Navigation Bar HTML

```html
<nav class="bottom-nav">
  <button class="nav-tab active" data-tab="vault">
    <svg><!-- shield/vault icon --></svg>
    <span>Coffre-fort</span>
  </button>
  <button class="nav-tab" data-tab="emails">
    <svg><!-- mail icon --></svg>
    <span>Emails</span>
    <span class="nav-badge hidden" id="email-badge">0</span>
  </button>
  <button class="nav-tab" data-tab="settings">
    <svg><!-- gear icon --></svg>
    <span>Réglages</span>
  </button>
</nav>
```

### 2C. Category Filter Chips

Horizontal scrollable row below search bar:
```html
<div class="category-chips">
  <button class="chip active" data-category="all">Tous</button>
  <button class="chip" data-category="login">Identifiants</button>
  <button class="chip" data-category="creditCard">Cartes</button>
  <button class="chip" data-category="secureNote">Notes</button>
  <button class="chip" data-category="bankAccount">Banque</button>
  <!-- etc. only show chips for categories that have entries -->
</div>
```

### 2D. Add Entry Form

Full-screen overlay within the popup:
```html
<div id="view-add-entry" class="view-overlay hidden">
  <div class="overlay-header">
    <button class="btn-back">← Retour</button>
    <span>Nouvel élément</span>
    <button class="btn-save" id="btn-save-entry">Enregistrer</button>
  </div>
  <div class="overlay-body">
    <div class="category-grid" id="category-selector">
      <!-- 10 category buttons with icons -->
    </div>
    <div id="entry-form-fields">
      <!-- Dynamic fields rendered by JS based on selected category -->
    </div>
  </div>
</div>
```

### 2E. Password Generator

```html
<div id="view-password-gen" class="view-overlay hidden">
  <div class="overlay-header">
    <button class="btn-back">← Retour</button>
    <span>Générateur</span>
  </div>
  <div class="overlay-body">
    <div class="gen-preview" id="gen-preview">••••••••••••</div>
    <div class="gen-strength" id="gen-strength"></div>
    <div class="gen-control">
      <label>Longueur: <span id="gen-length-val">16</span></label>
      <input type="range" id="gen-length" min="8" max="64" value="16">
    </div>
    <div class="gen-toggles">
      <label><input type="checkbox" id="gen-upper" checked> ABC</label>
      <label><input type="checkbox" id="gen-lower" checked> abc</label>
      <label><input type="checkbox" id="gen-digits" checked> 123</label>
      <label><input type="checkbox" id="gen-symbols"> !@#</label>
    </div>
    <div class="gen-actions">
      <button class="btn-primary" id="btn-gen-regenerate">Régénérer</button>
      <button class="btn-secondary" id="btn-gen-copy">Copier</button>
    </div>
  </div>
</div>
```

---

## Phase 3: Popup TypeScript Refactoring

### 3A. File organization

The popup.ts file will grow significantly. Rather than splitting into multiple files (which would require build config changes), organize with clear section comments. The file structure:

```
popup.ts (~800-1000 lines estimated)
├── Imports and type declarations
├── ─── Constants & State ───
│   ├── DOM references (lazy-initialized after DOMContentLoaded)
│   ├── State variables (allEntries, currentTab, settings, emails, aliases, etc.)
│   └── Active category filter, active folder, selected email
├── ─── Utilities ───
│   ├── showView(), showTab(), showOverlay(), hideOverlay()
│   ├── escapeHtml(), extractDomain(), matchesDomain()
│   ├── timeAgo()
│   ├── getCategoryIcon() — returns SVG string for category
│   ├── getCategoryFields() — returns field definitions per category
│   ├── generatePasswordLocally() — client-side password generation
│   ├── calculatePasswordStrength() — returns 'weak'|'medium'|'strong'|'very-strong'
│   └── clipboardCopyWithAutoClear() — copies + sets clear timer
├── ─── Tab Navigation ───
│   ├── switchTab(tabName) — shows/hides tab content, updates bottom nav active state
│   └── Event listeners on .nav-tab buttons
├── ─── Vault Tab ───
│   ├── loadAndShow() — fetches ALL entries (not just login), sorts by domain match then alpha
│   ├── renderEntries() — enhanced with category icons, folder grouping
│   ├── Category chip filtering
│   ├── Search filtering (searches across all fields relevant to category)
│   └── Entry click handlers (fill for logins, copy relevant field for others)
├── ─── Add Entry ───
│   ├── showAddEntry() — shows overlay, renders category selector
│   ├── selectCategory() — renders dynamic form fields
│   ├── saveEntry() — validates, calls SAVE_LOGIN message
│   ├── Field definitions per category (which fields to show, labels, types)
│   └── Integration with password generator
├── ─── Password Generator ───
│   ├── showPasswordGenerator() — from add form or standalone
│   ├── generateAndDisplay() — generates password, updates preview + strength
│   ├── Slider and toggle event listeners
│   └── Copy/Use button handlers
├── ─── Emails Tab ───
│   ├── loadAliases(), loadEmails()
│   ├── renderEmailList() — shows emails grouped or flat
│   ├── openEmail() — shows email detail view
│   ├── createAlias() — calls CREATE_ALIAS
│   ├── Folder switching (inbox/spam/archive)
│   └── Email action handlers (mark read, move, star)
├── ─── Settings Tab ───
│   ├── loadSettings() — fetches from service worker
│   ├── renderSettings() — builds settings UI
│   ├── Setting change handlers (each calls UPDATE_SETTINGS)
│   └── Lock/Logout handlers
├── ─── Auth Views ───
│   ├── Login handler (existing)
│   ├── Unlock handler (existing)
│   └── Register link (existing)
└── ─── Init ───
    └── init() — checks status, routes to correct view
```

### 3B. Key behavioral changes

**Entry rendering** — currently only shows `login` category. Change to show ALL categories:
- Remove the `.filter((e: VaultEntry) => e.category === 'login')` from `loadAndShow()`
- Add category icon before the favicon/fallback
- For non-login entries, show relevant secondary info (e.g., cardholderName for creditCard, networkName for wifi)
- Copy button: copies `password` for login, `cardNumber` for creditCard, `licenseKey` for softwareLicense, `password` for wifi, `notes` for secureNote

**Folder grouping** — when entries have `folder` set:
- Group entries by folder, show folder headers
- Unfiled entries shown in "Sans dossier" section at bottom
- Folders collapsed by default, expandable

**Category filtering** — chips at top:
- "Tous" shows all
- Other chips filter by category
- Only show chips for categories that have at least one entry
- Active chip gets `--fv-cyan` border/bg accent

**Tab switching**:
- Bottom nav tabs switch content area
- State preserved when switching (scroll position, search query)
- Email badge shows unread count

### 3C. Dynamic form fields per category

Define a `CATEGORY_FIELDS` map that returns arrays of field definitions:

```ts
type FieldDef = {
  key: keyof VaultEntry;
  label: string;
  type: 'text' | 'password' | 'email' | 'url' | 'textarea' | 'date';
  required?: boolean;
  placeholder?: string;
};

const CATEGORY_FIELDS: Record<VaultCategory, FieldDef[]> = {
  login: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'username', label: 'Nom d\'utilisateur', type: 'text' },
    { key: 'password', label: 'Mot de passe', type: 'password' },  // + generator button
    { key: 'website', label: 'Site web', type: 'url' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  creditCard: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'cardholderName', label: 'Titulaire', type: 'text' },
    { key: 'cardNumber', label: 'Numéro', type: 'text' },
    { key: 'cardExpiry', label: 'Expiration', type: 'text', placeholder: 'MM/AA' },
    { key: 'cardCVV', label: 'CVV', type: 'password' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  identity: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'firstName', label: 'Prénom', type: 'text' },
    { key: 'lastName', label: 'Nom', type: 'text' },
    { key: 'email', label: 'Email', type: 'email' },
    { key: 'phone', label: 'Téléphone', type: 'text' },
    { key: 'address', label: 'Adresse', type: 'text' },
    { key: 'dateOfBirth', label: 'Date de naissance', type: 'date' },
  ],
  secureNote: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'notes', label: 'Contenu', type: 'textarea' },
  ],
  bankAccount: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'bankName', label: 'Banque', type: 'text' },
    { key: 'iban', label: 'IBAN', type: 'text' },
    { key: 'bic', label: 'BIC/SWIFT', type: 'text' },
    { key: 'accountNumber', label: 'Numéro de compte', type: 'text' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  wifi: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'networkName', label: 'Nom du réseau (SSID)', type: 'text' },
    { key: 'password', label: 'Mot de passe', type: 'password' },
    { key: 'securityType', label: 'Sécurité', type: 'text', placeholder: 'WPA2' },
  ],
  softwareLicense: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'softwareName', label: 'Logiciel', type: 'text' },
    { key: 'licenseKey', label: 'Clé de licence', type: 'text' },
    { key: 'licenseEmail', label: 'Email', type: 'email' },
    { key: 'softwareVersion', label: 'Version', type: 'text' },
  ],
  passport: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'passportFullName', label: 'Nom complet', type: 'text' },
    { key: 'passportNumber', label: 'Numéro', type: 'text' },
    { key: 'passportCountry', label: 'Pays', type: 'text' },
    { key: 'passportExpiry', label: 'Expiration', type: 'date' },
    { key: 'passportDOB', label: 'Date de naissance', type: 'date' },
  ],
  server: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'website', label: 'Hôte / IP', type: 'text' },
    { key: 'username', label: 'Utilisateur', type: 'text' },
    { key: 'password', label: 'Mot de passe', type: 'password' },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
  other: [
    { key: 'title', label: 'Titre', type: 'text', required: true },
    { key: 'notes', label: 'Notes', type: 'textarea' },
  ],
};
```

---

## Phase 4: CSS Additions

### 4A. New CSS sections in `extension/src/popup/popup.css`

The popup.css will approximately double in size (~650 lines). New sections:

**Bottom navigation**:
```css
.bottom-nav {
  display: flex;
  border-top: 1px solid var(--fv-border);
  background: var(--fv-surface);
  /* Fixed at bottom of #view-main */
}
.nav-tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2px;
  padding: 8px 0 6px;
  font-size: 10px;
  color: var(--fv-text-muted);
  background: none;
  border: none;
  cursor: pointer;
  position: relative;
}
.nav-tab.active {
  color: var(--fv-cyan);
}
.nav-tab svg { width: 20px; height: 20px; }
.nav-badge {
  position: absolute;
  top: 4px;
  right: calc(50% - 18px);
  background: var(--fv-danger);
  color: white;
  font-size: 9px;
  min-width: 16px;
  height: 16px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
}
```

**Category chips**:
```css
.category-chips {
  display: flex;
  gap: 6px;
  padding: 8px 16px;
  overflow-x: auto;
  scrollbar-width: none;
  border-bottom: 1px solid var(--fv-border);
}
.category-chips::-webkit-scrollbar { display: none; }
.chip {
  flex-shrink: 0;
  padding: 4px 12px;
  border-radius: 16px;
  font-size: 11px;
  border: 1px solid var(--fv-border);
  background: transparent;
  color: var(--fv-text-muted);
  cursor: pointer;
}
.chip.active {
  border-color: var(--fv-cyan);
  color: var(--fv-cyan);
  background: rgba(0, 212, 255, 0.08);
}
```

**Overlay screens** (add entry, password generator, email detail):
```css
.view-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--fv-bg);
  z-index: 10;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.overlay-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  border-bottom: 1px solid var(--fv-border);
}
.overlay-body {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}
```

**Category selector grid** (for add entry):
```css
.category-grid {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 8px;
  margin-bottom: 16px;
}
.category-grid button {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 10px 4px;
  border-radius: 10px;
  border: 1px solid var(--fv-border);
  background: transparent;
  color: var(--fv-text-muted);
  font-size: 9px;
  cursor: pointer;
}
.category-grid button.active {
  border-color: var(--fv-cyan);
  color: var(--fv-cyan);
  background: rgba(0, 212, 255, 0.06);
}
```

**Form fields**:
```css
.form-group {
  margin-bottom: 12px;
}
.form-group label {
  display: block;
  font-size: 11px;
  color: var(--fv-text-muted);
  margin-bottom: 4px;
}
.form-group input,
.form-group textarea {
  width: 100%;
  padding: 8px 12px;
  background: var(--fv-surface);
  border: 1px solid var(--fv-border);
  border-radius: 8px;
  color: var(--fv-text);
  font-size: 13px;
  outline: none;
}
.form-group textarea { resize: vertical; min-height: 60px; }
.password-field-wrap {
  display: flex;
  gap: 6px;
}
.password-field-wrap input { flex: 1; }
.btn-gen-inline {
  /* Small dice/wand icon button next to password field */
  width: 36px;
  flex-shrink: 0;
}
```

**Password generator**:
```css
.gen-preview {
  font-family: 'SF Mono', 'Fira Code', monospace;
  font-size: 16px;
  word-break: break-all;
  padding: 16px;
  background: var(--fv-surface);
  border-radius: 10px;
  border: 1px solid var(--fv-border);
  text-align: center;
  margin-bottom: 12px;
  color: var(--fv-cyan);
}
.gen-strength {
  height: 4px;
  border-radius: 2px;
  margin-bottom: 16px;
  transition: background 0.2s;
}
.gen-strength.weak { background: var(--fv-danger); width: 25%; }
.gen-strength.medium { background: #F59E0B; width: 50%; }
.gen-strength.strong { background: var(--fv-success); width: 75%; }
.gen-strength.very-strong { background: var(--fv-cyan); width: 100%; }
.gen-toggles {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin: 12px 0;
}
```

**Email list**:
```css
.email-item {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 10px 16px;
  border-bottom: 1px solid var(--fv-border);
  cursor: pointer;
}
.email-item.unread { background: rgba(0, 212, 255, 0.04); }
.email-item.unread .email-subject { font-weight: 600; }
.email-from { font-size: 12px; color: var(--fv-text); }
.email-subject { font-size: 12px; color: var(--fv-text-muted); }
.email-time { font-size: 10px; color: var(--fv-text-muted); flex-shrink: 0; }
.email-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: var(--fv-cyan);
  flex-shrink: 0;
  margin-top: 4px;
}
```

**Settings**:
```css
.settings-section {
  margin-bottom: 20px;
}
.settings-section-title {
  font-size: 10px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--fv-text-muted);
  margin-bottom: 8px;
  padding: 0 4px;
}
.setting-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  background: var(--fv-surface);
  border-radius: 10px;
  margin-bottom: 4px;
}
.setting-label { font-size: 13px; }
.setting-select {
  background: var(--fv-bg);
  border: 1px solid var(--fv-border);
  border-radius: 6px;
  color: var(--fv-text);
  padding: 4px 8px;
  font-size: 12px;
}
/* Toggle switch */
.toggle {
  width: 40px;
  height: 22px;
  border-radius: 11px;
  background: var(--fv-border);
  position: relative;
  cursor: pointer;
  border: none;
}
.toggle.active { background: var(--fv-cyan); }
.toggle::after {
  content: '';
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: white;
  position: absolute;
  top: 2px;
  left: 2px;
  transition: transform 0.15s;
}
.toggle.active::after { transform: translateX(18px); }
```

**Folder headers** (for grouped entries):
```css
.folder-header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  font-size: 11px;
  color: var(--fv-text-muted);
  background: rgba(255, 255, 255, 0.02);
  cursor: pointer;
}
.folder-header svg { width: 14px; height: 14px; }
.entry-category-icon {
  width: 16px;
  height: 16px;
  color: var(--fv-violet);
  flex-shrink: 0;
}
```

**Layout adjustments**:
- `#view-main` needs `display: flex; flex-direction: column; height: 520px;` (fills popup)
- Tab content areas need `flex: 1; overflow-y: auto;`
- `.entries-list` max-height changes from fixed 360px to `flex: 1` within the tab
- Reduce `.entries-list` max-height to account for bottom nav (~48px) and category chips (~40px)

---

## Phase 5: Email Tab — Service Worker Queries

### 5A. Email data access strategy

The web app accesses emails via `/api/email/messages` and `/api/email/aliases` — these are SvelteKit server routes that likely do not exist as standalone API endpoints. The extension has two options:

**Option A (Recommended): Direct Supabase queries from service worker**
Since the extension already has the Supabase client with the user's session, and RLS policies restrict to `user_id = auth.uid()`, the service worker can query the `email_aliases` and `emails` tables directly. This avoids needing the web app to be running.

```ts
// GET_ALIASES
const { data } = await supabase
  .from('email_aliases')
  .select('id, address, label, is_active, emails_received, created_at')
  .eq('user_id', session.user.id)
  .order('created_at', { ascending: false });

// GET_EMAILS
const query = supabase
  .from('emails')
  .select('id, alias_id, from_address, from_name, to_address, subject, body_text, folder, is_read, is_starred, received_at')
  .eq('folder', msg.folder)
  .order('received_at', { ascending: false })
  .limit(50);
// Filter by alias_id and search if provided
if (msg.alias_id) query.eq('alias_id', msg.alias_id);
if (msg.search) query.or(`subject.ilike.%${msg.search}%,from_address.ilike.%${msg.search}%`);
```

**Option B: For alias creation — call web app API**
Creating a new alias requires integration with addy.io (external service). The extension should call the web app's API endpoint:
```ts
// CREATE_ALIAS
const token = session.access_token;
const res = await fetch('https://fyxxvault.com/api/email/aliases', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${token}` },
  body: JSON.stringify({ label: msg.label })
});
```

However, since the `/api/email/aliases` endpoint may not exist as a standalone API, a fallback is needed. We need to verify whether these API routes exist. If they do not, the "Create alias" button in the extension should open the web app's emails page instead. For the initial implementation, alias creation will open the web app.

---

## Phase 6: Implementation Order

### Step 1: Types + Settings (low risk, foundation)
1. Add new types to `types.ts`
2. Add `GET_SETTINGS` and `UPDATE_SETTINGS` handlers to service worker
3. Add auto-lock alarm logic to service worker

### Step 2: HTML restructuring
1. Restructure `popup.html` with tab containers and bottom nav
2. Keep existing views (loading, login, locked) unchanged
3. Add empty shells for emails tab, settings tab, overlays

### Step 3: CSS additions
1. Add all new CSS sections to `popup.css`
2. Adjust existing layout styles for tab system

### Step 4: Popup.ts — Tab navigation + Enhanced vault
1. Refactor popup.ts with tab switching logic
2. Remove `login`-only filter, show all categories
3. Add category chips and filtering
4. Add category icons to entries
5. Add folder grouping
6. Add "+" button and add-entry overlay

### Step 5: Add Entry form + Password generator
1. Implement category selector grid
2. Implement dynamic form field rendering
3. Wire up SAVE_LOGIN
4. Implement password generator UI and logic
5. Connect generator to password fields in add-entry form

### Step 6: Settings tab
1. Implement settings UI rendering
2. Wire up all setting controls to UPDATE_SETTINGS
3. Implement clipboard auto-clear in popup
4. Test auto-lock alarm behavior

### Step 7: Email tab + service worker email handlers
1. Add email message handlers to service worker
2. Implement email list rendering in popup
3. Implement email detail view
4. Add unread badge to bottom nav
5. Alias creation: open web app (or API call if endpoint exists)

### Step 8: Polish
1. Smooth transitions between tabs (CSS)
2. Loading states for async operations
3. Error handling for all network calls
4. Keyboard navigation (Enter to submit, Escape to close overlays)
5. Scroll position preservation when switching tabs
6. Test at 360x520px constraint

---

## Key Design Decisions

1. **No framework** — stays vanilla TS. The popup is small enough that a framework adds unnecessary complexity and bundle size.

2. **Single popup.ts file** — Vite's current config builds one output per entry point. Splitting into modules would require build config changes. Instead, use clear section delimiters and a flat structure. At ~800-1000 lines this is manageable.

3. **Direct Supabase queries for emails** — avoids dependency on web app being accessible. The Supabase client + RLS provides secure access.

4. **Alias creation opens web app** — the addy.io integration is complex and lives server-side. Rather than duplicating it in the extension, open the web app's email page for alias management.

5. **Password generation in popup** — no need for service worker round-trip. `crypto.getRandomValues()` is available in the popup context. The `GENERATE_PASSWORD` message type is kept for potential use from other contexts but is not strictly needed.

6. **Settings in chrome.storage.local** — persists across browser sessions. Service worker reads on wake to set up auto-lock alarm.

7. **Clipboard auto-clear in popup.ts** — service workers cannot access `navigator.clipboard`. The popup sets a timeout after each copy operation; if the popup closes before timeout fires, the clipboard is not cleared (acceptable trade-off; a more robust solution would use a content script but adds complexity).

8. **Layout: fixed 520px height with flex layout** — bottom nav is pinned at bottom, tab content area takes remaining space with overflow scroll. This ensures the bottom nav is always visible.

---

## Risk Assessment

- **Popup size**: At 520px max height, with header (44px) + search (40px) + chips (36px) + bottom nav (48px) = 168px of chrome, leaving ~352px for scrollable content. This is tight but workable.

- **Service worker wake latency**: Email queries may be slow on first load if SW needs to wake + restore session. Show loading spinners.

- **Email table RLS**: Need to confirm that `emails` and `email_aliases` tables have RLS policies allowing the user's session to query them. The admin code uses `supabaseAdmin` (service role), so we need to verify standard user access. If RLS is missing, a migration will be needed.

- **Bundle size**: Adding email types and more HTML/CSS/TS is minimal. No new dependencies needed.

- **Supabase email API routes**: The web app uses `/api/email/*` routes that are SvelteKit server routes (not available to the extension). Direct Supabase queries solve this for reads. For writes (create alias, move emails), we need to verify table insert/update RLS policies.
