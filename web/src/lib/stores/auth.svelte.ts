import { supabase } from '$lib/supabase';
import { deriveKEK, unwrapVEK, wrapVEK, generateVEK, generateSalt } from '$lib/crypto';
import type { User, Session } from '@supabase/supabase-js';

// ─── Private state (VEK never persisted) ───
let _vek: Uint8Array | null = null;

// ─── Reactive Svelte 5 state ───
let _user: User | null = $state(null);
let _session: Session | null = $state(null);
let _isAuthenticated = $state(false);
let _isUnlocked = $state(false);
let _loading = $state(true);
let _masterPassword: string | null = null; // kept briefly for profile bootstrap

// ─── Public accessors ───
export function getAuthState() {
	return {
		get user() { return _user; },
		get session() { return _session; },
		get isAuthenticated() { return _isAuthenticated; },
		get isUnlocked() { return _isUnlocked; },
		get loading() { return _loading; }
	};
}

export function getVEK(): Uint8Array | null {
	return _vek;
}

// ─── Initialize: listen for auth changes ───
let _initialized = false;
export function initAuth() {
	if (_initialized) return;
	_initialized = true;

	supabase.auth.getSession().then(({ data: { session } }) => {
		_session = session;
		_user = session?.user ?? null;
		_isAuthenticated = !!session;
		_loading = false;
	});

	supabase.auth.onAuthStateChange((_event, session) => {
		_session = session;
		_user = session?.user ?? null;
		_isAuthenticated = !!session;
		_loading = false;
	});
}

// ─── Unlock vault with master password ───
export async function unlockVault(masterPassword: string): Promise<{ success: boolean; error?: string }> {
	if (!_user) return { success: false, error: 'Non authentifié.' };

	try {
		// Fetch profile
		const { data: profile, error: profileError } = await supabase
			.from('profiles')
			.select('wrapped_vek, vek_salt, vek_rounds')
			.eq('id', _user.id)
			.single();

		if (profileError && profileError.code === 'PGRST116') {
			// No profile yet — first login from web, create one
			return await bootstrapProfile(masterPassword);
		}

		if (profileError) {
			return { success: false, error: 'Erreur lors du chargement du profil.' };
		}

		// Decode stored bytes
		const wrappedVek = decodeSupabaseBytes(profile.wrapped_vek);
		const salt = decodeSupabaseBytes(profile.vek_salt);
		const rounds = profile.vek_rounds || 210_000;

		// Derive KEK and unwrap VEK
		const kek = await deriveKEK(masterPassword, salt, rounds);
		const vek = await unwrapVEK(wrappedVek, kek);

		_vek = vek;
		_isUnlocked = true;
		return { success: true };
	} catch (e: any) {
		console.error('Unlock failed:', e);
		// Most likely a wrong password → AES-GCM decryption error
		if (e?.name === 'OperationError' || e?.message?.includes('decrypt')) {
			return { success: false, error: 'Mot de passe maître incorrect.' };
		}
		return { success: false, error: e.message || 'Erreur inconnue.' };
	}
}

// ─── Bootstrap profile for first-time web login ───
async function bootstrapProfile(masterPassword: string): Promise<{ success: boolean; error?: string }> {
	if (!_user) return { success: false, error: 'Non authentifié.' };

	try {
		const salt = generateSalt();
		const rounds = 210_000;
		const vek = generateVEK();

		const kek = await deriveKEK(masterPassword, salt, rounds);
		const wrappedVek = await wrapVEK(vek, kek);

		const { error: insertError } = await supabase.from('profiles').insert({
			id: _user.id,
			wrapped_vek: encodeToSupabaseBytes(wrappedVek),
			vek_salt: encodeToSupabaseBytes(salt),
			vek_rounds: rounds
		});

		if (insertError) {
			return { success: false, error: 'Erreur lors de la création du profil.' };
		}

		_vek = vek;
		_isUnlocked = true;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la création du profil.' };
	}
}

// ─── Logout ───
export async function logout() {
	_vek = null;
	_isUnlocked = false;
	_masterPassword = null;
	_user = null;
	_session = null;
	_isAuthenticated = false;
	await supabase.auth.signOut();
}

// ─── Change master password ───
export async function changeMasterPassword(
	currentPassword: string,
	newPassword: string
): Promise<{ success: boolean; error?: string }> {
	if (!_user || !_vek) return { success: false, error: 'Coffre non déverrouillé.' };

	try {
		// Verify current password by deriving KEK and trying unwrap
		const { data: profile } = await supabase
			.from('profiles')
			.select('wrapped_vek, vek_salt, vek_rounds')
			.eq('id', _user.id)
			.single();

		if (!profile) return { success: false, error: 'Profil introuvable.' };

		const salt = decodeSupabaseBytes(profile.vek_salt);
		const rounds = profile.vek_rounds || 210_000;

		// Verify current password
		const currentKek = await deriveKEK(currentPassword, salt, rounds);
		const wrappedVek = decodeSupabaseBytes(profile.wrapped_vek);
		await unwrapVEK(wrappedVek, currentKek); // throws if wrong password

		// Re-wrap VEK with new password
		const newSalt = generateSalt();
		const newKek = await deriveKEK(newPassword, newSalt, rounds);
		const newWrappedVek = await wrapVEK(_vek, newKek);

		// Update Supabase auth password
		const { error: authError } = await supabase.auth.updateUser({ password: newPassword });
		if (authError) return { success: false, error: authError.message };

		// Update profile
		const { error: profileError } = await supabase
			.from('profiles')
			.update({
				wrapped_vek: encodeToSupabaseBytes(newWrappedVek),
				vek_salt: encodeToSupabaseBytes(newSalt)
			})
			.eq('id', _user.id);

		if (profileError) return { success: false, error: 'Erreur lors de la mise à jour du profil.' };

		return { success: true };
	} catch (e: any) {
		if (e?.name === 'OperationError') {
			return { success: false, error: 'Mot de passe actuel incorrect.' };
		}
		return { success: false, error: e.message || 'Erreur inconnue.' };
	}
}

// ─── Supabase BYTEA helpers ───
// Supabase returns BYTEA as hex-encoded string with \\x prefix
function decodeSupabaseBytes(value: any): Uint8Array {
	if (value instanceof Uint8Array) return value;
	if (value instanceof ArrayBuffer) return new Uint8Array(value);

	// Supabase returns BYTEA as "\\x<hex>" string
	if (typeof value === 'string') {
		let hex = value;
		if (hex.startsWith('\\x')) hex = hex.slice(2);
		if (hex.startsWith('0x')) hex = hex.slice(2);

		const bytes = new Uint8Array(hex.length / 2);
		for (let i = 0; i < hex.length; i += 2) {
			bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
		}
		return bytes;
	}

	throw new Error('Unexpected BYTEA format');
}

function encodeToSupabaseBytes(bytes: Uint8Array): string {
	const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
	return '\\x' + hex;
}
