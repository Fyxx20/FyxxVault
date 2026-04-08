import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => {
	const stats = db.getStats();
	return json({ hasUser: stats.users > 0 });
};
