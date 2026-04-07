import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

const ANNOUNCEMENTS_KEY = 'announcements';

interface Announcement {
	id: string;
	type: 'update' | 'maintenance' | 'security' | 'feature' | 'info';
	title: string;
	content: string;
	date: string;
	pinned: boolean;
}

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

function normalizeAnnouncements(raw: unknown): Announcement[] {
	if (!Array.isArray(raw)) return [];
	return raw
		.map((item: any) => ({
			id: String(item?.id || ''),
			type: ['update', 'maintenance', 'security', 'feature', 'info'].includes(item?.type) ? item.type : 'info',
			title: String(item?.title || '').trim(),
			content: String(item?.content || '').trim(),
			date: String(item?.date || new Date().toISOString().slice(0, 10)),
			pinned: item?.pinned === true
		}))
		.filter(item => item.id && item.title && item.content)
		.sort((a, b) => {
			if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
			return new Date(b.date).getTime() - new Date(a.date).getTime();
		});
}

export const GET: RequestHandler = async ({ request }) => {
	try {
		const authHeader = request.headers.get('authorization');
		if (!authHeader?.startsWith('Bearer ')) {
			return json({ error: 'Unauthorized' }, { status: 401 });
		}

		const supabase = getSupabaseAdmin();
		const token = authHeader.slice(7);
		const { data: { user }, error: authError } = await supabase.auth.getUser(token);
		if (authError || !user) {
			return json({ error: 'Unauthorized' }, { status: 401 });
		}

		const { data } = await supabase
			.from('platform_settings')
			.select('value')
			.eq('key', ANNOUNCEMENTS_KEY)
			.single();

		if (!data?.value) {
			return json({ announcements: [] });
		}

		let parsed: unknown = [];
		try {
			parsed = JSON.parse(data.value);
		} catch {
			parsed = [];
		}

		return json({ announcements: normalizeAnnouncements(parsed) });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
