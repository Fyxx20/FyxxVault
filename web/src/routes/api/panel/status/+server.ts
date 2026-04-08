import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const stats = db.getStats();

	return json({
		uptime: process.uptime(),
		dbSize: stats.dbSize,
		users: stats.users,
		items: stats.items,
		nodeVersion: process.version,
		platform: process.platform,
		pid: process.pid,
		memoryUsage: process.memoryUsage().heapUsed,
		port: process.env.PORT || 3000
	});
};
