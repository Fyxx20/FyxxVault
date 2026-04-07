import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import * as pubEnv from '$env/dynamic/public';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.env.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

/**
 * GET /api/email/messages?folder=inbox&alias_id=xxx&page=1&limit=50
 * List emails for the authenticated user
 */
export const GET: RequestHandler = async ({ request, url }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const folder = url.searchParams.get('folder') || 'inbox';
	const aliasId = url.searchParams.get('alias_id');
	const search = url.searchParams.get('search');
	const page = parseInt(url.searchParams.get('page') || '1');
	const limit = Math.min(parseInt(url.searchParams.get('limit') || '50'), 100);
	const offset = (page - 1) * limit;

	let query = supabase
		.from('emails')
		.select('id, alias_id, from_address, from_name, to_address, subject, folder, is_read, is_starred, received_at', { count: 'exact' })
		.eq('user_id', user.id)
		.eq('folder', folder)
		.order('received_at', { ascending: false })
		.range(offset, offset + limit - 1);

	if (aliasId) {
		query = query.eq('alias_id', aliasId);
	}

	if (search) {
		query = query.or(`subject.ilike.%${search}%,from_address.ilike.%${search}%,from_name.ilike.%${search}%`);
	}

	const { data: emails, error, count } = await query;

	if (error) return json({ error: error.message }, { status: 500 });

	// Get unread counts per folder
	const folders = ['inbox', 'spam', 'trash', 'archive'];
	const unreadCounts: Record<string, number> = {};

	for (const f of folders) {
		const { count: c } = await supabase
			.from('emails')
			.select('id', { count: 'exact', head: true })
			.eq('user_id', user.id)
			.eq('folder', f)
			.eq('is_read', false);
		unreadCounts[f] = c || 0;
	}

	return json({
		emails: emails || [],
		total: count || 0,
		page,
		limit,
		unreadCounts
	});
};

/**
 * PATCH /api/email/messages
 * Bulk update emails (mark read, move to folder, star)
 * Body: { ids: string[], is_read?: boolean, folder?: string, is_starred?: boolean }
 */
export const PATCH: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json().catch(() => ({}));
	if (!body.ids || !Array.isArray(body.ids) || body.ids.length === 0) {
		return json({ error: 'Email IDs required' }, { status: 400 });
	}

	const updates: Record<string, any> = {};
	if (typeof body.is_read === 'boolean') updates.is_read = body.is_read;
	if (typeof body.is_starred === 'boolean') updates.is_starred = body.is_starred;
	if (body.folder && ['inbox', 'trash', 'spam', 'archive'].includes(body.folder)) {
		updates.folder = body.folder;
	}

	if (Object.keys(updates).length === 0) {
		return json({ error: 'No updates provided' }, { status: 400 });
	}

	const { error } = await supabase
		.from('emails')
		.update(updates)
		.in('id', body.ids)
		.eq('user_id', user.id);

	if (error) return json({ error: error.message }, { status: 500 });

	return json({ success: true });
};

/**
 * DELETE /api/email/messages
 * Permanently delete emails
 * Body: { ids: string[] }
 */
export const DELETE: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json().catch(() => ({}));
	if (!body.ids || !Array.isArray(body.ids)) {
		return json({ error: 'Email IDs required' }, { status: 400 });
	}

	const { error } = await supabase
		.from('emails')
		.delete()
		.in('id', body.ids)
		.eq('user_id', user.id);

	if (error) return json({ error: error.message }, { status: 500 });

	return json({ success: true });
};
