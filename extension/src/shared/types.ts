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

// ─── Extension messaging types ───

export type ExtMessage =
  | { type: 'GET_STATUS' }
  | { type: 'GET_LOGINS'; domain: string }
  | { type: 'SAVE_LOGIN'; entry: VaultEntry }
  | { type: 'FILL_CREDENTIALS'; username: string; password: string }
  | { type: 'BRIDGE_SESSION'; session: any }
  | { type: 'BRIDGE_VEK'; vekHex: string }
  | { type: 'GET_TOTP'; domain: string }
  | { type: 'UNLOCK'; masterPassword: string }
  | { type: 'LOCK' };

export type ExtStatus = {
  isAuthenticated: boolean;
  isUnlocked: boolean;
  entryCount: number;
};
