import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import { copyFileSync, existsSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const dbPath = db.getPath();
	const dataDir = dirname(dbPath);
	const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
	const filename = `fyxxvault-backup-${timestamp}.db`;
	const dest = join(dataDir, filename);

	try {
		copyFileSync(dbPath, dest);
		return json({ success: true, filename });
	} catch (e: any) {
		return json({ error: e.message }, { status: 500 });
	}
};
