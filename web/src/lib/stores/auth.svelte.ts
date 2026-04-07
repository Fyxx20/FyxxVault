import { supabase } from '$lib/supabase';
import { deriveKEK, unwrapVEK, wrapVEK, generateVEK, generateSalt, bytesToHex } from '$lib/crypto';
import type { User, Session } from '@supabase/supabase-js';

// ─── Private state (VEK never persisted) ───
let _vek: Uint8Array | null = null;

// ─── Reactive Svelte 5 state ───
let _user: User | null = $state(null);
let _session: Session | null = $state(null);
let _isAuthenticated = $state(false);
let _isUnlocked = $state(false);
let _loading = $state(true);
let _isPro = $state(true);
let _masterPassword: string | null = null; // kept briefly for profile bootstrap

// ─── Public accessors ───
export function getAuthState() {
	return {
		get user() { return _user; },
		get session() { return _session; },
		get isAuthenticated() { return _isAuthenticated; },
		get isUnlocked() { return _isUnlocked; },
		get loading() { return _loading; },
		get isPro() { return _isPro; }
	};
}

export function getVEK(): Uint8Array | null {
	return _vek;
}

export async function refreshProStatus(): Promise<boolean> {
	if (!_user) return false;
	try {
		const { data: profile, error } = await supabase
			.from('profiles')
			.select('is_pro')
			.eq('id', _user.id)
			.single();

		if (!error) {
			_isPro = profile?.is_pro === true;
		}
	} catch {
		// ignore network errors; keep previous local state
	}
	return _isPro;
}

// ─── Browser Extension Bridge ───
// Sends session and VEK to the FyxxVault extension automatically.
// Uses both postMessage (for content script in isolated world) and custom events.
function bridgeToExtension() {
	if (typeof window === 'undefined') return;

	if (_session) {
		window.dispatchEvent(new CustomEvent('fyxxvault-bridge-session', {
			detail: {
				access_token: _session.access_token,
				refresh_token: _session.refresh_token
			}
		}));
	}

	if (_vek) {
		const vekHex = bytesToHex(_vek);
		// Custom event (same-world listeners)
		window.dispatchEvent(new CustomEvent('fyxxvault-bridge-vek', { detail: vekHex }));
		// postMessage (cross-world — content script isolated world can read this)
		window.postMessage({ type: '__FYXX_VEK__', payload: vekHex }, window.location.origin);
	}
}

// Listen for extension requesting current state
if (typeof window !== 'undefined') {
	window.addEventListener('fyxxvault-extension-ready', () => bridgeToExtension());
}

// ─── Initialize: listen for auth changes ───
let _initialized = false;
export function initAuth() {
	if (_initialized) return;
	_initialized = true;

	// onAuthStateChange fires INITIAL_SESSION first (reads from localStorage),
	// then TOKEN_REFRESHED, SIGNED_IN, SIGNED_OUT etc.
	// This is the recommended way to restore sessions in Supabase v2.
	const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
		_session = session;
		_user = session?.user ?? null;
		_isAuthenticated = !!session;
		_loading = false;

		// If session expired, try to refresh it
		if (event === 'TOKEN_REFRESHED' && session) {
			_isAuthenticated = true;
		}

		if (session) bridgeToExtension();
	});

	// Fallback: if onAuthStateChange hasn't fired after 2s, stop loading
	setTimeout(() => {
		if (_loading) {
			_loading = false;
		}
	}, 2000);
}

// ─── Unlock vault with master password ───
export async function unlockVault(masterPassword: string): Promise<{ success: boolean; error?: string }> {
	if (!_user) return { success: false, error: 'Non authentifié.' };

	try {
		// Fetch profile
		const { data: profile, error: profileError } = await supabase
			.from('profiles')
			.select('wrapped_vek, vek_salt, vek_rounds, is_pro')
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
		_isPro = profile.is_pro === true;
		bridgeToExtension();
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
		bridgeToExtension();
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la création du profil.' };
	}
}

// ─── Lock vault (keep session, clear VEK) ───
export function lockVault() {
	_vek = null;
	_isUnlocked = false;
	_masterPassword = null;
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
