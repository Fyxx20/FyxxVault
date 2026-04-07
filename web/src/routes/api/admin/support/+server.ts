import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS_FALLBACK = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

async function getAdminEmails(supabaseAdmin: ReturnType<typeof createClient>): Promise<string[]> {
	try {
		const { data } = await supabaseAdmin
			.from('platform_settings')
			.select('value')
			.eq('key', 'admin_emails')
			.single();
		if (data?.value) {
			const parsed = JSON.parse(data.value);
			if (Array.isArray(parsed)) {
				return parsed.map((email: string) => String(email).toLowerCase());
			}
		}
	} catch {}
	return ADMIN_EMAILS_FALLBACK;
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<{ valid: boolean; email?: string }> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return { valid: false };

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user?.email) return { valid: false };

	const admins = await getAdminEmails(supabaseAdmin);
	if (!admins.includes(user.email.toLowerCase())) return { valid: false };

	return { valid: true, email: user.email };
}

export const GET: RequestHandler = async ({ request, url }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();
	if (!(await verifyAdmin(request, supabaseAdmin)).valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const status = url.searchParams.get('status') || '';
		const page = parseInt(url.searchParams.get('page') || '1');
		const limit = parseInt(url.searchParams.get('limit') || '20');

		// Get status counts
		const { data: allTickets } = await supabaseAdmin
			.from('support_tickets')
			.select('status');

		const counts = { open: 0, waiting: 0, resolved: 0, closed: 0 };
		(allTickets || []).forEach((t: any) => {
			if (t.status in counts) {
				counts[t.status as keyof typeof counts]++;
			}
		});
		const total = allTickets?.length || 0;

		// Build filtered query
		let query = supabaseAdmin
			.from('support_tickets')
			.select('*', { count: 'exact' })
			.order('updated_at', { ascending: false })
			.range((page - 1) * limit, page * limit - 1);

		if (status && ['open', 'waiting', 'resolved', 'closed'].includes(status)) {
			query = query.eq('status', status);
		}

		const { data: tickets, error, count } = await query;

		if (error) return json({ error: error.message }, { status: 500 });

		return json({
			tickets: tickets || [],
			total: status ? (count || 0) : total,
			counts
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
