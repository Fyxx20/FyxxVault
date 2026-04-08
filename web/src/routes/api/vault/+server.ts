import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const items = db.getVaultItems(userId);
	// Map DB fields to what the client store expects
	return json(items.map(item => ({
		id: item.id,
		encrypted_blob: item.encrypted_data
	})));
};

export const POST: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json();
	const blob = body.encrypted_blob || body.encrypted_data;
	if (!blob) return json({ error: 'Missing encrypted data' }, { status: 400 });

	const id = body.id || crypto.randomUUID();
	const now = new Date().toISOString();
	db.createVaultItem({
		id,
		user_id: userId,
		encrypted_data: blob,
		data_iv: '',
		category: body.category ?? 'login',
		favorite: body.favorite ?? 0,
		created_at: now,
		updated_at: now
	});
	return json({ success: true, id }, { status: 201 });
};

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json();
	if (!body.id) return json({ error: 'Missing id' }, { status: 400 });

	const blob = body.encrypted_blob || body.encrypted_data;
	db.updateVaultItem(body.id, userId, {
		encrypted_data: blob,
		updated_at: new Date().toISOString()
	});
	return json({ success: true });
};

export const DELETE: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { id } = await request.json();
	if (!id) return json({ error: 'Missing id' }, { status: 400 });

	db.deleteVaultItem(id, userId);
	return json({ success: true });
};
