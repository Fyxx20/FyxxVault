import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { generateAIResponse } from '$lib/supportAI';
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

// Detect if user message indicates the issue is resolved
function isResolutionMessage(content: string): boolean {
	const lower = content.toLowerCase().trim();
	const resolvedPatterns = [
		/merci.*(?:reussi|march|fonctionne|resolu|r[eé]gl[eé]|ok|nickel|parfait|top|super|genial)/,
		/(?:c.*est|ca).*(?:bon|ok|fait|march|regl|resolu|nickel|parfait)/,
		/j.*ai.*(?:reussi|trouv|compris|resolu)/,
		/(?:problem|souci).*(?:regl|resolu|fix|corrig)/,
		/(?:thanks|thank you|thx).*(?:work|fixed|solved|resolved|got it|done)/,
		/(?:it|that).*(?:work|fixed|solved)/,
		/(?:all|everything).*(?:good|fine|work|ok)/,
		/^(?:merci|parfait|nickel|super|genial|top|excellent)[\s!.]*$/,
		/^(?:thanks|thank you|thx|perfect|great|awesome)[\s!.]*$/,
	];
	return resolvedPatterns.some(p => p.test(lower));
}

const CLOSE_MSG_FR = '🎉 Super, ton probleme semble resolu ! Je cloture ce ticket.\n\nSi tu as besoin d\'aide a nouveau, n\'hesite pas a ouvrir une nouvelle conversation. A bientot !';
const CLOSE_MSG_EN = '🎉 Great, your issue seems resolved! I\'m closing this ticket.\n\nIf you need help again, feel free to start a new conversation. See you!';

export const POST: RequestHandler = async ({ request }) => {
	const supabaseAdmin = getSupabaseAdmin();
	const auth = await verifyUserOrAdmin(request, supabaseAdmin);
	if (!auth) {
		return json({ error: 'Unauthorized' }, { status: 401 });
	}

	try {
		const body = await request.json();
		const ticketId = String(body?.ticket_id || '').trim();
		const content = String(body?.content || '').trim();
		const lang = body?.lang || 'en';
		const asAdmin = body?.as_admin === true && auth.isAdmin;

		if (!ticketId || !content) {
			return json({ error: 'ticket_id and content are required' }, { status: 400 });
		}

		const { data: ticket, error: ticketError } = await supabaseAdmin
			.from('support_tickets')
			.select('*')
			.eq('id', ticketId)
			.single();

		if (ticketError || !ticket) {
			return json({ error: 'Ticket not found' }, { status: 404 });
		}

		if (ticket.user_id !== auth.user.id && !auth.isAdmin) {
			return json({ error: 'Forbidden' }, { status: 403 });
		}

		const messages = [];

		if (asAdmin) {
			const { data: adminMsg, error: msgError } = await supabaseAdmin
				.from('support_messages')
				.insert({
					ticket_id: ticketId,
					sender_type: 'admin',
					sender_name: 'Support FyxxVault',
					content
				})
				.select()
				.single();

			if (msgError) return json({ error: msgError.message }, { status: 500 });
			messages.push(adminMsg);

			await supabaseAdmin
				.from('support_tickets')
				.update({ status: 'waiting', updated_at: new Date().toISOString() })
				.eq('id', ticketId);
		} else {
			const { data: userMsg, error: msgError } = await supabaseAdmin
				.from('support_messages')
				.insert({
					ticket_id: ticketId,
					sender_type: 'user',
					sender_name: auth.user.email,
					content
				})
				.select()
				.single();

			if (msgError) return json({ error: msgError.message }, { status: 500 });
			messages.push(userMsg);

			// Check if user is saying their issue is resolved
			if (isResolutionMessage(content)) {
				// Auto-close with bot message
				const closeMsg = lang === 'fr' ? CLOSE_MSG_FR : CLOSE_MSG_EN;
				const { data: botMsg, error: botError } = await supabaseAdmin
					.from('support_messages')
					.insert({
						ticket_id: ticketId,
						sender_type: 'ai',
						sender_name: 'FyxxBot',
						content: closeMsg
					})
					.select()
					.single();

				if (!botError && botMsg) messages.push(botMsg);

				await supabaseAdmin
					.from('support_tickets')
					.update({ status: 'resolved', updated_at: new Date().toISOString() })
					.eq('id', ticketId);
			} else {
				// Normal AI response
				const aiContent = await generateAIResponse(content, lang);

				const { data: aiMsg, error: aiError } = await supabaseAdmin
					.from('support_messages')
					.insert({
						ticket_id: ticketId,
						sender_type: 'ai',
						sender_name: 'FyxxBot',
						content: aiContent
					})
					.select()
					.single();

				if (aiError) return json({ error: aiError.message }, { status: 500 });
				messages.push(aiMsg);

				await supabaseAdmin
					.from('support_tickets')
					.update({ updated_at: new Date().toISOString() })
					.eq('id', ticketId);
			}
		}

		return json({ messages });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
