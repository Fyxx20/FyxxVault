import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import * as pubEnv from '$env/dynamic/public';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.env.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

/**
 * GET /api/email/messages/[id]
 * Get full email content (including body)
 */
export const GET: RequestHandler = async ({ request, params }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const { data: email, error } = await supabase
		.from('emails')
		.select('*')
		.eq('id', params.id)
		.eq('user_id', user.id)
		.single();

	if (error || !email) return json({ error: 'Email not found' }, { status: 404 });

	// Auto-mark as read
	if (!email.is_read) {
		await supabase
			.from('emails')
			.update({ is_read: true })
			.eq('id', params.id)
			.eq('user_id', user.id);
	}

	return json({ email: { ...email, is_read: true } });
};
