import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { password } = await request.json();
	if (!password) return json({ error: 'Password required' }, { status: 400 });

	const user = db.getUserById(userId);
	if (!user) return json({ error: 'User not found' }, { status: 404 });

	const [saltHex, expectedHash] = user.password_hash.split(':');
	const salt = new Uint8Array(saltHex.match(/.{2}/g)!.map((h: string) => parseInt(h, 16)));
	const encoder = new TextEncoder();
	const keyMaterial = await globalThis.crypto.subtle.importKey(
		'raw', encoder.encode(password), 'PBKDF2', false, ['deriveBits']
	);
	const hash = await globalThis.crypto.subtle.deriveBits(
		{ name: 'PBKDF2', salt, iterations: 100000, hash: 'SHA-256' },
		keyMaterial, 256
	);
	const hashHex = Array.from(new Uint8Array(hash), b => b.toString(16).padStart(2, '0')).join('');

	return json({ valid: hashHex === expectedHash });
};
