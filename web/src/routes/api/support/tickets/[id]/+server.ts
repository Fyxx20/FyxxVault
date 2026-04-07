import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
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

async function verifyUserOrAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>) {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return null;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user?.email) return null;

	const admins = await getAdminEmails(supabaseAdmin);
	const isAdmin = admins.includes(user.email.toLowerCase());

	return { user, isAdmin };
}

export const GET: RequestHandler = async ({ request, params }) => {
	const supabaseAdmin = getSupabaseAdmin();
	const auth = await verifyUserOrAdmin(request, supabaseAdmin);
	if (!auth) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	try {
		const { data: ticket, error: ticketError } = await supabaseAdmin
			.from('support_tickets')
			.select('*')
			.eq('id', params.id)
			.single();

		if (ticketError || !ticket) {
			return json({ error: 'Ticket not found' }, { status: 404 });
		}

		// Check ownership or admin
		if (ticket.user_id !== auth.user.id && !auth.isAdmin) {
			return json({ error: 'Forbidden' }, { status: 403 });
		}

		const { data: messages, error: msgError } = await supabaseAdmin
			.from('support_messages')
			.select('*')
			.eq('ticket_id', ticket.id)
			.order('created_at', { ascending: true });

		if (msgError) {
			return json({ error: msgError.message }, { status: 500 });
		}

		return json({ ticket, messages: messages || [] });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const PATCH: RequestHandler = async ({ request, params }) => {
	const supabaseAdmin = getSupabaseAdmin();
	const auth = await verifyUserOrAdmin(request, supabaseAdmin);
	if (!auth) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	try {
		const { data: ticket, error: ticketError } = await supabaseAdmin
			.from('support_tickets')
			.select('*')
			.eq('id', params.id)
			.single();

		if (ticketError || !ticket) {
			return json({ error: 'Ticket not found' }, { status: 404 });
		}

		const body = await request.json();

		// Status change: admin only
		if (body.status !== undefined) {
			if (!auth.isAdmin) {
				return json({ error: 'Forbidden' }, { status: 403 });
			}

			const validStatuses = ['open', 'waiting', 'resolved', 'closed'];
			if (!validStatuses.includes(body.status)) {
				return json({ error: 'Invalid status' }, { status: 400 });
			}

			const { data: updated, error: updateError } = await supabaseAdmin
				.from('support_tickets')
				.update({ status: body.status, updated_at: new Date().toISOString() })
				.eq('id', params.id)
				.select()
				.single();

			if (updateError) {
				return json({ error: updateError.message }, { status: 500 });
			}

			return json({ ticket: updated });
		}

		// User must own ticket for other updates
		if (ticket.user_id !== auth.user.id && !auth.isAdmin) {
			return json({ error: 'Forbidden' }, { status: 403 });
		}

		return json({ ticket });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
