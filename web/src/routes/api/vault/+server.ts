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
	db.insertVaultItem(id, userId, JSON.stringify({ encrypted_data, data_iv, category, favorite }));
	return json({ success: true, id }, { status: 201 });
};

export const PATCH: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { id, encrypted_data, data_iv, category, favorite } = await request.json();
	if (!id) return json({ error: 'Missing id' }, { status: 400 });

	const fields = {
		encrypted_data,
		data_iv,
		category,
		favorite,
		updated_at: new Date().toISOString()
	};
	db.updateVaultItem(id, userId, JSON.stringify(fields));
	return json({ success: true });
};

export const DELETE: RequestHandler = async ({ request, cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const { id } = await request.json();
	if (!id) return json({ error: 'Missing id' }, { status: 400 });

	db.softDeleteVaultItem(id, userId);
	return json({ success: true });
};
