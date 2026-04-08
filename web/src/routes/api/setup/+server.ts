import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

/**
 * POST /api/setup
 * First-time setup: create the local user with just a master password.
 * No email needed — this is a local-only, single-user vault.
 */
export const POST: RequestHandler = async ({ request, cookies }) => {
	// Prevent setup if user already exists
	const stats = db.getStats();
	if (stats.users > 0) {
		return json({ error: 'Vault already configured' }, { status: 409 });
	}

	const { wrapped_vek, vek_salt, vek_iv, password } = await request.json();

	if (!wrapped_vek || !vek_salt || !password) {
		return json({ error: 'Missing required fields' }, { status: 400 });
	}

	// Hash the master password for session verification
	const salt = crypto.getRandomValues(new Uint8Array(16));
	const encoder = new TextEncoder();
	const keyMaterial = await globalThis.crypto.subtle.importKey(
		'raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']
	);
	const hash = await globalThis.crypto.subtle.deriveBits(
		{ name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
		keyMaterial, 256
	);
	const saltHex = Array.from(salt, b => b.toString(16).padStart(2, '0')).join('');
	const hashHex = Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, '0')).join('');
	const passwordHash = `${saltHex}:${hashHex}`;

	const userId = crypto.randomUUID();

	// Create user with a local placeholder email
	db.createUser(userId, 'local@fyxxvault', passwordHash);
	db.createProfile({
		user_id: userId,
		encrypted_vek: wrapped_vek,
		vek_salt: vek_salt,
		vek_iv: vek_iv || '',
		master_hint: '',
		is_pro: 1,
		created_at: new Date().toISOString()
	});

	// Auto-login: set session cookie
	cookies.set('session_user', userId, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		maxAge: 60 * 60 * 24 * 365 // 1 year for local
	});

	return json({ success: true, userId }, { status: 201 });
};
