// ─── Vault types (mirrored from web app) ───

export interface VaultEntry {
  id: string;
  title: string;
  username: string;
  password: string;
  website: string;
  notes: string;
  category: VaultCategory;
  folder: string;
  tags: string[];
  isFavorite: boolean;
  mfaEnabled: boolean;
  mfaSecret: string;
  createdAt: string;
  lastModifiedAt: string;
  cardholderName?: string;
  cardNumber?: string;
  cardExpiry?: string;
  cardCVV?: string;
  firstName?: string;
  lastName?: string;
  dateOfBirth?: string;
  address?: string;
  phone?: string;
  email?: string;
  networkName?: string;
  securityType?: string;
  softwareName?: string;
  licenseKey?: string;
  licenseEmail?: string;
  softwareVersion?: string;
  passportFullName?: string;
  passportNumber?: string;
  passportCountry?: string;
  passportExpiry?: string;
  passportDOB?: string;
  bankName?: string;
  iban?: string;
  bic?: string;
  accountNumber?: string;
  passwordHistory?: { password: string; changedAt: string }[];
}

export type VaultCategory =
  | 'login' | 'creditCard' | 'identity' | 'secureNote' | 'bankAccount'
  | 'wifi' | 'softwareLicense' | 'passport' | 'server' | 'other';

export function newVaultEntry(overrides: Partial<VaultEntry> = {}): VaultEntry {
  return {
    id: crypto.randomUUID(),
    title: '',
    username: '',
    password: '',
    website: '',
    notes: '',
    category: 'login',
    folder: '',
    tags: [],
    isFavorite: false,
    mfaEnabled: false,
    mfaSecret: '',
    createdAt: new Date().toISOString(),
    lastModifiedAt: new Date().toISOString(),
    passwordHistory: [],
    ...overrides
  };
}

// ─── Category metadata ───

export const CATEGORY_META: Record<VaultCategory, { label: string; icon: string; color: string }> = {
  login:           { label: 'Identifiant',  icon: '🔑', color: 'var(--fv-cyan)' },
  creditCard:      { label: 'Carte',        icon: '💳', color: '#F59E0B' },
  identity:        { label: 'Identite',     icon: '👤', color: '#8B5CF6' },
  secureNote:      { label: 'Note',         icon: '📝', color: '#22C55E' },
  bankAccount:     { label: 'Banque',       icon: '🏦', color: '#3B82F6' },
  wifi:            { label: 'Wi-Fi',        icon: '📶', color: '#06B6D4' },
  softwareLicense: { label: 'Licence',      icon: '💿', color: '#EC4899' },
  passport:        { label: 'Passeport',    icon: '🛂', color: '#F97316' },
  server:          { label: 'Serveur',      icon: '🖥️', color: '#6366F1' },
  other:           { label: 'Autre',        icon: '📦', color: '#94A3B8' },
};

// ─── Email types ───

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
  body_text: string;
  body_html?: string;
  is_read: boolean;
  is_starred: boolean;
  received_at: string;
}

// ─── Settings ───

export interface ExtSettings {
  autoLockMinutes: number;       // 0 = never
  clipboardClearSeconds: number;  // 0 = never
  disableChromePasswords: boolean;
}

export const DEFAULT_SETTINGS: ExtSettings = {
  autoLockMinutes: 15,
  clipboardClearSeconds: 30,
  disableChromePasswords: true,
};

// ─── Extension messaging types ───

export type ExtMessage =
  | { type: 'GET_STATUS' }
  | { type: 'GET_LOGINS'; domain: string }
  | { type: 'SAVE_LOGIN'; entry: VaultEntry }
  | { type: 'DELETE_ENTRY'; entryId: string }
  | { type: 'FILL_CREDENTIALS'; username: string; password: string }
  | { type: 'BRIDGE_SESSION'; session: any }
  | { type: 'BRIDGE_VEK'; vekHex: string }
  | { type: 'GET_TOTP'; domain: string }
  | { type: 'DISABLE_GOOGLE_PASSWORDS' }
  | { type: 'OPEN_CHROME_PASSWORDS' }
  | { type: 'IMPORT_CSV_ENTRIES'; entries: Array<{ name: string; url: string; username: string; password: string }> }
  | { type: 'LOGIN_AND_UNLOCK'; email: string; masterPassword: string }
  | { type: 'UNLOCK'; masterPassword: string }
  | { type: 'LOCK' }
  | { type: 'LOGOUT' }
  | { type: 'GET_ALIASES' }
  | { type: 'GET_EMAILS'; aliasId: string }
  | { type: 'TOGGLE_ALIAS'; aliasId: string; active: boolean }
  | { type: 'GET_SETTINGS' }
  | { type: 'UPDATE_SETTINGS'; settings: Partial<ExtSettings> }
  | { type: 'GENERATE_PASSWORD'; length: number; uppercase: boolean; lowercase: boolean; digits: boolean; symbols: boolean };

export type ExtStatus = {
  isAuthenticated: boolean;
  isUnlocked: boolean;
  entryCount: number;
  userEmail?: string;
};
