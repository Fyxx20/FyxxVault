import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const items = db.getVaultItems(userId);
	return json(items);
};

export const POST: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { encrypted_data, data_iv, category, favorite } = await request.json();
	if (!encrypted_data) return json({ error: 'Missing encrypted_data' }, { status: 400 });

	const id = crypto.randomUUID();
	const now = new Date().toISOString();
	db.createVaultItem({
		id,
		user_id: userId,
		encrypted_data,
		data_iv: data_iv ?? '',
		category: category ?? 'login',
		favorite: favorite ?? 0,
		created_at: now,
		updated_at: now
	});
	return json({ success: true, id }, { status: 201 });
};

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { id, encrypted_data, data_iv, category, favorite } = await request.json();
	if (!id) return json({ error: 'Missing id' }, { status: 400 });

	db.updateVaultItem(id, userId, {
		encrypted_data,
		data_iv,
		category,
		favorite,
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
