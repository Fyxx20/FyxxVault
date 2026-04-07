import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { generateAIResponse } from '$lib/supportAI';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

async function verifyUser(request: Request, supabaseAdmin: ReturnType<typeof createClient>) {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return null;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user) return null;

	return user;
}

const INACTIVITY_MS = 10 * 60 * 1000; // 10 minutes
const CLOSE_INACTIVITY_FR = '⏱️ Ce ticket a ete cloture automatiquement pour inactivite.\n\nSi tu as encore besoin d\'aide, n\'hesite pas a ouvrir une nouvelle conversation !';
const CLOSE_INACTIVITY_EN = '⏱️ This ticket has been automatically closed due to inactivity.\n\nIf you still need help, feel free to start a new conversation!';

async function autoCloseStaleTickets(supabaseAdmin: ReturnType<typeof createClient>) {
	try {
		const cutoff = new Date(Date.now() - INACTIVITY_MS).toISOString();

		// Find "waiting" tickets not updated in 10min
		const { data: staleTickets } = await supabaseAdmin
			.from('support_tickets')
			.select('id, updated_at')
			.eq('status', 'waiting')
			.lt('updated_at', cutoff);

		if (!staleTickets?.length) return;

		for (const ticket of staleTickets) {
			// Check last message is from admin (not user)
			const { data: lastMsg } = await supabaseAdmin
				.from('support_messages')
				.select('sender_type')
				.eq('ticket_id', ticket.id)
				.order('created_at', { ascending: false })
				.limit(1)
				.single();

			if (lastMsg?.sender_type === 'admin') {
				// Add bot close message
				await supabaseAdmin
					.from('support_messages')
					.insert({
						ticket_id: ticket.id,
						sender_type: 'ai',
						sender_name: 'FyxxBot',
						content: CLOSE_INACTIVITY_FR
					});

				// Close ticket
				await supabaseAdmin
					.from('support_tickets')
					.update({ status: 'closed', updated_at: new Date().toISOString() })
					.eq('id', ticket.id);
			}
		}
	} catch {
		// Silent - don't break the main request
	}
}

export const GET: RequestHandler = async ({ request }) => {
	const supabaseAdmin = getSupabaseAdmin();
	const user = await verifyUser(request, supabaseAdmin);
	if (!user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	try {
		// Auto-close stale "waiting" tickets (admin replied, user inactive for 10min)
		await autoCloseStaleTickets(supabaseAdmin);

		const { data: tickets, error } = await supabaseAdmin
			.from('support_tickets')
			.select('*')
			.eq('user_id', user.id)
			.order('updated_at', { ascending: false });

		if (error) return json({ error: error.message }, { status: 500 });

		return json({ tickets: tickets || [] });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const supabaseAdmin = getSupabaseAdmin();
	const user = await verifyUser(request, supabaseAdmin);
	if (!user) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	try {
		const body = await request.json();
		const message = String(body?.message || '').trim();
		const lang = body?.lang || 'en';

		if (!message) {
			return json({ error: 'Message is required' }, { status: 400 });
		}

		// Create ticket
		const { data: ticket, error: ticketError } = await supabaseAdmin
			.from('support_tickets')
			.insert({
				user_id: user.id,
				user_email: user.email,
				status: 'open',
				subject: message.slice(0, 100)
			})
			.select()
			.single();

		if (ticketError || !ticket) {
			return json({ error: ticketError?.message || 'Failed to create ticket' }, { status: 500 });
		}

		// Create user message
		const { data: userMessage, error: msgError } = await supabaseAdmin
			.from('support_messages')
			.insert({
				ticket_id: ticket.id,
				sender_type: 'user',
				sender_name: user.email,
				content: message
			})
			.select()
			.single();

		if (msgError) {
			return json({ error: msgError.message }, { status: 500 });
		}

		// Generate AI response with language
		const aiContent = await generateAIResponse(message, lang);

		const { data: aiMessage, error: aiError } = await supabaseAdmin
			.from('support_messages')
			.insert({
				ticket_id: ticket.id,
				sender_type: 'ai',
				sender_name: 'FyxxBot',
				content: aiContent
			})
			.select()
			.single();

		if (aiError) {
			return json({ error: aiError.message }, { status: 500 });
		}

		// Update ticket updated_at
		await supabaseAdmin
			.from('support_tickets')
			.update({ updated_at: new Date().toISOString() })
			.eq('id', ticket.id);

		return json({ ticket, messages: [userMessage, aiMessage] }, { status: 201 });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
