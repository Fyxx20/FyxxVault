import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const dbSize = db.getDbSize();
	const userCount = (db.raw.prepare('SELECT COUNT(*) as count FROM users').get() as any)?.count || 0;
	const itemCount = (db.raw.prepare('SELECT COUNT(*) as count FROM vault_items WHERE deleted_at IS NULL').get() as any)?.count || 0;

	return json({
		uptime: process.uptime(),
		dbSize,
		users: userCount,
		items: itemCount,
		nodeVersion: process.version,
		platform: process.platform
	});
};
