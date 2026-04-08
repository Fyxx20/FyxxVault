import { json } from '@sveltejs/kit';
import { readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	const logPath = join(homedir(), '.fyxxvault', 'logs', 'fyxxvault.log');

	if (!existsSync(logPath)) {
		return json({ lines: [] });
	}

	const content = readFileSync(logPath, 'utf-8');
	const lines = content.split('\n').filter(Boolean).slice(-100);

	return json({ lines });
};
