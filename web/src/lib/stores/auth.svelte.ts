import { deriveKEK, unwrapVEK, wrapVEK, generateVEK, generateSalt, bytesToHex, hexToBytes } from '$lib/crypto';

// ─── Private state (VEK never persisted) ───
let _vek: Uint8Array | null = null;

// ─── Reactive Svelte 5 state ───
let _userId: string | null = $state(null);
let _email: string | null = $state(null);
let _isAuthenticated = $state(false);
let _isUnlocked = $state(false);
let _loading = $state(true);
let _isPro = $state(true); // Always true in self-hosted
let _masterPassword: string | null = null;

// ─── Auto-lock (default 5 minutes) ───
let _autoLockTimeout = 5 * 60 * 1000;
let _inactivityTimer: ReturnType<typeof setTimeout> | null = null;

function resetInactivityTimer() {
	if (_inactivityTimer) clearTimeout(_inactivityTimer);
	if (_autoLockTimeout > 0 && _isUnlocked) {
		_inactivityTimer = setTimeout(() => lockVault(), _autoLockTimeout);
	}
}

if (typeof window !== 'undefined') {
	['mousemove', 'keydown', 'scroll', 'click', 'touchstart'].forEach(evt => {
		window.addEventListener(evt, resetInactivityTimer, { passive: true });
	});
}

// ─── Public accessors ───
export function getAuthState() {
	return {
		get user() { return _userId ? { id: _userId, email: _email } : null; },
		get userId() { return _userId; },
		get email() { return _email; },
		get isAuthenticated() { return _isAuthenticated; },
		get isUnlocked() { return _isUnlocked; },
		get loading() { return _loading; },
		get isPro() { return _isPro; },
		get autoLockTimeout() { return _autoLockTimeout; },
		set autoLockTimeout(ms: number) {
			_autoLockTimeout = ms;
			resetInactivityTimer();
		}
	};
}

export function getVEK(): Uint8Array | null {
	return _vek;
}

// ─── Initialize: check if profile exists ───
let _initialized = false;
export async function initAuth() {
	if (_initialized) return;
	_initialized = true;

	try {
		const res = await fetch('/api/profile');
		if (res.ok) {
			// Profile exists and we have a session cookie
			const profile = await res.json();
			_isAuthenticated = true;
			// User needs to unlock vault with master password
		} else if (res.status === 401) {
			const data = await res.json();
			if (data.exists) {
				// User exists but no session — needs login
				_isAuthenticated = false;
			} else {
				// No user — first launch, needs registration
				_isAuthenticated = false;
			}
		} else {
			// No profile — first launch
			_isAuthenticated = false;
		}
	} catch {
		_isAuthenticated = false;
	}

	_loading = false;
}

// ─── Login with email + master password ───
export async function login(email: string, masterPassword: string): Promise<{ success: boolean; error?: string }> {
	try {
		// Authenticate and get session
		const loginRes = await fetch('/api/auth/login', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ email, password: masterPassword })
		});

		if (!loginRes.ok) {
			const err = await loginRes.json();
			return { success: false, error: err.error || 'Identifiants incorrects.' };
		}

		const loginData = await loginRes.json();
		_userId = loginData.userId;
		_email = email;
		_isAuthenticated = true;

		// Now unlock the vault
		return await unlockVault(masterPassword);
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur de connexion.' };
	}
}

// ─── Unlock vault with master password ───
export async function unlockVault(masterPassword: string): Promise<{ success: boolean; error?: string }> {
	try {
		const res = await fetch('/api/profile');
		if (!res.ok) {
			if (res.status === 404) {
				// No profile yet — first login, create one
				return await bootstrapProfile(masterPassword);
			}
			return { success: false, error: 'Erreur lors du chargement du profil.' };
		}

		const profile = await res.json();

		// Decode stored bytes
		const wrappedVek = hexToBytes(profile.wrapped_vek);
		const salt = hexToBytes(profile.vek_salt);
		const rounds = profile.vek_rounds || 210_000;

		// Derive KEK and unwrap VEK
		const kek = await deriveKEK(masterPassword, salt, rounds);
		const vek = await unwrapVEK(wrappedVek, kek);

		_vek = vek;
		_isUnlocked = true;
		_isPro = true; // Always true in self-hosted
		resetInactivityTimer();
		return { success: true };
	} catch (e: any) {
		console.error('Unlock failed:', e);
		if (e?.name === 'OperationError' || e?.message?.includes('decrypt')) {
			return { success: false, error: 'Mot de passe maitre incorrect.' };
		}
		return { success: false, error: e.message || 'Erreur inconnue.' };
	}
}

// ─── Bootstrap profile for first-time setup ───
async function bootstrapProfile(masterPassword: string): Promise<{ success: boolean; error?: string }> {
	try {
		const salt = generateSalt();
		const rounds = 210_000;
		const vek = generateVEK();

		const kek = await deriveKEK(masterPassword, salt, rounds);
		const wrappedVek = await wrapVEK(vek, kek);

		const res = await fetch('/api/profile', {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				wrapped_vek: bytesToHex(wrappedVek),
				vek_salt: bytesToHex(salt),
				vek_rounds: rounds
			})
		});

		if (!res.ok) {
			return { success: false, error: 'Erreur lors de la creation du profil.' };
		}

		_vek = vek;
		_isUnlocked = true;
		resetInactivityTimer();
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la creation du profil.' };
	}
}

// ─── Lock vault (keep session, clear VEK) ───
export function lockVault() {
	_vek = null;
	_isUnlocked = false;
	_masterPassword = null;
	if (_inactivityTimer) clearTimeout(_inactivityTimer);
}

// ─── Logout ───
export async function logout() {
	_vek = null;
	_isUnlocked = false;
	_masterPassword = null;
	_userId = null;
	_email = null;
	_isAuthenticated = false;
	if (_inactivityTimer) clearTimeout(_inactivityTimer);
	// Clear session cookie
	document.cookie = 'session_user=; Max-Age=0; path=/';
}

// ─── Change master password ───
export async function changeMasterPassword(
	currentPassword: string,
	newPassword: string
): Promise<{ success: boolean; error?: string }> {
	if (!_vek) return { success: false, error: 'Coffre non deverrouille.' };

	try {
		// Verify current password by fetching profile and trying unwrap
		const res = await fetch('/api/profile');
		if (!res.ok) return { success: false, error: 'Profil introuvable.' };

		const profile = await res.json();

		const salt = hexToBytes(profile.vek_salt);
		const rounds = profile.vek_rounds || 210_000;

		// Verify current password
		const currentKek = await deriveKEK(currentPassword, salt, rounds);
		const wrappedVek = hexToBytes(profile.wrapped_vek);
		await unwrapVEK(wrappedVek, currentKek); // throws if wrong password

		// Re-wrap VEK with new password
		const newSalt = generateSalt();
		const newKek = await deriveKEK(newPassword, newSalt, rounds);
		const newWrappedVek = await wrapVEK(_vek, newKek);

		// Update profile
		const updateRes = await fetch('/api/profile', {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				wrapped_vek: bytesToHex(newWrappedVek),
				vek_salt: bytesToHex(newSalt)
			})
		});

		if (!updateRes.ok) return { success: false, error: 'Erreur lors de la mise a jour du profil.' };

		return { success: true };
	} catch (e: any) {
		if (e?.name === 'OperationError') {
			return { success: false, error: 'Mot de passe actuel incorrect.' };
		}
		return { success: false, error: e.message || 'Erreur inconnue.' };
	}
}
