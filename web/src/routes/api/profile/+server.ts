import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

async function hashPassword(password: string): Promise<string> {
	const salt = crypto.getRandomValues(new Uint8Array(16));
	const encoder = new TextEncoder();
	const keyMaterial = await globalThis.crypto.subtle.importKey('raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']);
	const hash = await globalThis.crypto.subtle.deriveBits({ name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' }, keyMaterial, 256);
	const saltHex = Array.from(salt, b => b.toString(16).padStart(2, '0')).join('');
	const hashHex = Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, '0')).join('');
	return `${saltHex}:${hashHex}`;
}

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const profile = db.getProfile(userId);
	const user = db.getUserById(userId);
	if (!profile) return json({ error: 'Profile not found' }, { status: 404 });

	// Normalize field names for client compatibility
	return json({
		wrapped_vek: profile.encrypted_vek,
		vek_salt: profile.vek_salt,
		vek_iv: profile.vek_iv,
		vek_rounds: 210_000,
		email: user?.email
	});
};

export const POST: RequestHandler = async ({ request, cookies }) => {
	const { email, password, encrypted_vek, vek_salt, vek_iv, master_hint } = await request.json();

	if (!email || !password || !encrypted_vek || !vek_salt) {
		return json({ error: 'Missing required fields' }, { status: 400 });
	}

	const existing = db.getUser(email);
	if (existing) return json({ error: 'User already exists' }, { status: 409 });

	const userId = crypto.randomUUID();
	const passwordHash = await hashPassword(password);

	db.createUser(userId, email, passwordHash);
	db.createProfile({
		user_id: userId,
		encrypted_vek: encrypted_vek,
		vek_salt,
		vek_iv: vek_iv || '',
		master_hint: master_hint || '',
		is_pro: 1,
		created_at: new Date().toISOString()
	});

	cookies.set('session_user', userId, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		maxAge: 60 * 60 * 24 * 30
	});

	return json({ success: true, userId }, { status: 201 });
};

export const PUT: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { encrypted_vek, vek_salt, vek_iv, master_hint } = await request.json();

	const updates: Record<string, string> = {};
	if (encrypted_vek) updates.encrypted_vek = encrypted_vek;
	if (vek_salt) updates.vek_salt = vek_salt;

	if (Object.keys(updates).length === 0) {
		return json({ error: 'No fields to update' }, { status: 400 });
	}

	db.updateProfile(userId, updates as Partial<{ encrypted_vek: string; vek_salt: string }>);
	return json({ success: true });
};
