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
	// Credit Card fields
	cardholderName?: string;
	cardNumber?: string;
	cardExpiry?: string;
	cardCVV?: string;
	// Identity fields
	firstName?: string;
	lastName?: string;
	dateOfBirth?: string;
	address?: string;
	phone?: string;
	email?: string;
	// Wi-Fi fields
	networkName?: string;
	securityType?: string;
	// Software License fields
	softwareName?: string;
	licenseKey?: string;
	licenseEmail?: string;
	softwareVersion?: string;
	// Passport fields
	passportFullName?: string;
	passportNumber?: string;
	passportCountry?: string;
	passportExpiry?: string;
	passportDOB?: string;
	// Bank Account fields
	bankName?: string;
	iban?: string;
	bic?: string;
	accountNumber?: string;
	// Password history
	passwordHistory?: { password: string; changedAt: string }[];
}

export type VaultCategory =
	| 'login'
	| 'creditCard'
	| 'identity'
	| 'secureNote'
	| 'bankAccount'
	| 'wifi'
	| 'softwareLicense'
	| 'passport'
	| 'server'
	| 'other';

export interface Profile {
	id: string;
	wrapped_vek: Uint8Array;
	vek_salt: Uint8Array;
	vek_rounds: number;
}

export interface VaultItemRow {
	id: string;
	user_id: string;
	encrypted_blob: Uint8Array;
	updated_at: string;
	deleted_at: string | null;
}

export const CATEGORY_META: Record<VaultCategory, { label: string; icon: string; color: string }> = {
	login: { label: 'Login', icon: '🔑', color: 'var(--fv-cyan)' },
	creditCard: { label: 'Carte bancaire', icon: '💳', color: 'var(--fv-violet)' },
	identity: { label: 'Identité', icon: '🪪', color: 'var(--fv-gold)' },
	secureNote: { label: 'Note sécurisée', icon: '📝', color: 'var(--fv-success)' },
	bankAccount: { label: 'Compte bancaire', icon: '🏦', color: 'var(--fv-cyan)' },
	wifi: { label: 'Wi-Fi', icon: '📶', color: 'var(--fv-violet)' },
	softwareLicense: { label: 'Licence', icon: '🔧', color: 'var(--fv-gold)' },
	passport: { label: 'Passeport', icon: '🛂', color: 'var(--fv-danger)' },
	server: { label: 'Serveur', icon: '🖥️', color: 'var(--fv-danger)' },
	other: { label: 'Autre', icon: '📦', color: 'var(--fv-smoke)' }
};

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
