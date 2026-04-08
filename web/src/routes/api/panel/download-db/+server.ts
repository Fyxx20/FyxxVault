import { db } from '$lib/server/db';
import { readFileSync } from 'fs';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const dbPath = db.getPath();
	const file = readFileSync(dbPath);

	return new Response(file, {
		headers: {
			'Content-Type': 'application/x-sqlite3',
			'Content-Disposition': 'attachment; filename="fyxxvault.db"'
		}
	});
};
