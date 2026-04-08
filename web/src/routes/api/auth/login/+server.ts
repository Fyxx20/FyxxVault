import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

async function verifyPassword(password: string, stored: string): Promise<boolean> {
	const [saltHex, expectedHash] = stored.split(':');
	if (!saltHex || !expectedHash) return false;
	const salt = new Uint8Array(saltHex.match(/.{2}/g)!.map(h => parseInt(h, 16)));
	const encoder = new TextEncoder();
	const keyMaterial = await globalThis.crypto.subtle.importKey(
		'raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']
	);
	const hash = await globalThis.crypto.subtle.deriveBits(
		{ name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
		keyMaterial, 256
	);
	const hashHex = Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, '0')).join('');
	return hashHex === expectedHash;
}

export const POST: RequestHandler = async ({ request, cookies }) => {
	const { email, password } = await request.json();

	if (!email || !password) {
		return json({ error: 'Email et mot de passe requis' }, { status: 400 });
	}

	const user = db.getUser(email);
	if (!user) {
		return json({ error: 'Identifiants incorrects' }, { status: 401 });
	}

	const valid = await verifyPassword(password, user.password_hash);
	if (!valid) {
		return json({ error: 'Identifiants incorrects' }, { status: 401 });
	}

	// Set session cookie
	cookies.set('session_user', user.id, {
		path: '/',
		httpOnly: true,
		sameSite: 'lax',
		maxAge: 60 * 60 * 24 * 30 // 30 days
	});

	return json({ success: true, userId: user.id });
};
