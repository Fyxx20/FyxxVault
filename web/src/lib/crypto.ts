import type { VaultEntry } from './types';

const PBKDF2_ROUNDS_DEFAULT = 210_000;
const AES_KEY_BITS = 256;
const IV_LENGTH = 12;

/**
 * Derive a Key-Encryption Key (KEK) from the master password using PBKDF2.
 * The KEK is used to wrap/unwrap the Vault Encryption Key (VEK).
 */
export async function deriveKEK(
	masterPassword: string,
	salt: Uint8Array,
	rounds: number = PBKDF2_ROUNDS_DEFAULT
): Promise<CryptoKey> {
	const enc = new TextEncoder();
	const keyMaterial = await crypto.subtle.importKey(
		'raw',
		enc.encode(masterPassword),
		'PBKDF2',
		false,
		['deriveKey']
	);

	return crypto.subtle.deriveKey(
		{
			name: 'PBKDF2',
			salt,
			iterations: rounds,
			hash: 'SHA-256'
		},
		keyMaterial,
		{ name: 'AES-GCM', length: AES_KEY_BITS },
		false,
		['encrypt', 'decrypt']
	);
}

/**
 * Generate a random 32-byte Vault Encryption Key (VEK).
 */
export function generateVEK(): Uint8Array {
	return crypto.getRandomValues(new Uint8Array(32));
}

/**
 * Generate a random salt for PBKDF2.
 */
export function generateSalt(): Uint8Array {
	return crypto.getRandomValues(new Uint8Array(32));
}

/**
 * Wrap (encrypt) the VEK with the KEK using AES-GCM.
 * Output format: [12-byte IV][ciphertext+tag]
 */
export async function wrapVEK(vek: Uint8Array, kek: CryptoKey): Promise<Uint8Array> {
	const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
	const ciphertext = await crypto.subtle.encrypt(
		{ name: 'AES-GCM', iv },
		kek,
		vek
	);

	const result = new Uint8Array(IV_LENGTH + ciphertext.byteLength);
	result.set(iv, 0);
	result.set(new Uint8Array(ciphertext), IV_LENGTH);
	return result;
}

/**
 * Unwrap (decrypt) the VEK with the KEK using AES-GCM.
 * Input format: [12-byte IV][ciphertext+tag]
 */
export async function unwrapVEK(wrapped: Uint8Array, kek: CryptoKey): Promise<Uint8Array> {
	const iv = wrapped.slice(0, IV_LENGTH);
	const ciphertext = wrapped.slice(IV_LENGTH);

	const plaintext = await crypto.subtle.decrypt(
		{ name: 'AES-GCM', iv },
		kek,
		ciphertext
	);

	return new Uint8Array(plaintext);
}

/**
 * Import raw VEK bytes as a CryptoKey for AES-GCM.
 */
async function importVEKKey(vek: Uint8Array): Promise<CryptoKey> {
	return crypto.subtle.importKey(
		'raw',
		vek,
		{ name: 'AES-GCM', length: AES_KEY_BITS },
		false,
		['encrypt', 'decrypt']
	);
}

/**
 * Encrypt a vault entry with the VEK using AES-GCM.
 * Output format: [12-byte IV][ciphertext+tag]
 */
export async function encryptEntry(entry: VaultEntry, vek: Uint8Array): Promise<Uint8Array> {
	const enc = new TextEncoder();
	const plaintext = enc.encode(JSON.stringify(entry));
	const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
	const key = await importVEKKey(vek);

	const ciphertext = await crypto.subtle.encrypt(
		{ name: 'AES-GCM', iv },
		key,
		plaintext
	);

	const result = new Uint8Array(IV_LENGTH + ciphertext.byteLength);
	result.set(iv, 0);
	result.set(new Uint8Array(ciphertext), IV_LENGTH);
	return result;
}

/**
 * Decrypt a vault entry blob with the VEK using AES-GCM.
 * Input format: [12-byte IV][ciphertext+tag]
 */
export async function decryptEntry(blob: Uint8Array, vek: Uint8Array): Promise<VaultEntry> {
	const iv = blob.slice(0, IV_LENGTH);
	const ciphertext = blob.slice(IV_LENGTH);
	const key = await importVEKKey(vek);

	const plaintext = await crypto.subtle.decrypt(
		{ name: 'AES-GCM', iv },
		key,
		ciphertext
	);

	const dec = new TextDecoder();
	return JSON.parse(dec.decode(plaintext)) as VaultEntry;
}

/**
 * Evaluate password strength on a 0–100 scale.
 */
export function passwordStrength(password: string): { score: number; label: string; color: string } {
	if (!password) return { score: 0, label: 'Aucun', color: 'var(--fv-ash)' };

	let score = 0;

	// Length scoring
	if (password.length >= 8) score += 15;
	if (password.length >= 12) score += 15;
	if (password.length >= 16) score += 10;
	if (password.length >= 20) score += 10;

	// Character variety
	if (/[a-z]/.test(password)) score += 10;
	if (/[A-Z]/.test(password)) score += 10;
	if (/[0-9]/.test(password)) score += 10;
	if (/[^a-zA-Z0-9]/.test(password)) score += 15;

	// Patterns (deductions)
	if (/(.)\1{2,}/.test(password)) score -= 10; // repeated chars
	if (/^[a-z]+$/i.test(password)) score -= 10; // only letters
	if (/^[0-9]+$/.test(password)) score -= 15; // only digits

	score = Math.max(0, Math.min(100, score));

	if (score < 30) return { score, label: 'Faible', color: 'var(--fv-danger)' };
	if (score < 60) return { score, label: 'Moyen', color: 'var(--fv-gold)' };
	if (score < 80) return { score, label: 'Fort', color: 'var(--fv-cyan)' };
	return { score, label: 'Excellent', color: 'var(--fv-success)' };
}

/**
 * Generate a random password.
 */
export function generatePassword(
	length: number = 20,
	options: {
		uppercase?: boolean;
		lowercase?: boolean;
		digits?: boolean;
		symbols?: boolean;
	} = {}
): string {
	const {
		uppercase = true,
		lowercase = true,
		digits = true,
		symbols = true
	} = options;

	let charset = '';
	if (lowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
	if (uppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	if (digits) charset += '0123456789';
	if (symbols) charset += '!@#$%^&*()-_=+[]{}|;:,.<>?';

	if (!charset) charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

	const array = crypto.getRandomValues(new Uint8Array(length));
	return Array.from(array, (byte) => charset[byte % charset.length]).join('');
}

/**
 * Convert Uint8Array to hex string (for debugging/display).
 */
export function bytesToHex(bytes: Uint8Array): string {
	return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Convert hex string to Uint8Array.
 */
export function hexToBytes(hex: string): Uint8Array {
	const bytes = new Uint8Array(hex.length / 2);
	for (let i = 0; i < hex.length; i += 2) {
		bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
	}
	return bytes;
}
