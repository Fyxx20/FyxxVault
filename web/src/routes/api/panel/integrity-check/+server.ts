import { db } from '$lib/server/db';
import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ cookies }) => {
	const userId = cookies.get('session_user');
	if (!userId) return json({ error: 'Unauthorized' }, { status: 401 });

	try {
		const result = db.raw.pragma('integrity_check');
		return json({ result });
	} catch (e: any) {
		return json({ error: e.message }, { status: 500 });
	}
};
