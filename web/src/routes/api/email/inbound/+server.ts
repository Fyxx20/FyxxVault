import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import * as pubEnv from '$env/dynamic/public';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.env.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

/**
 * POST /api/email/inbound
 * Called by Cloudflare Email Worker when an email arrives at @fyxxmail.com
 *
 * Expected JSON body:
 * {
 *   secret: string,        // shared secret for auth
 *   to: string,            // recipient address (e.g. abc123@fyxxmail.com)
 *   from: string,          // sender email
 *   from_name: string,     // sender display name
 *   subject: string,
 *   text: string,          // plain text body
 *   html: string           // HTML body
 * }
 */
export const POST: RequestHandler = async ({ request }) => {
	try {
		const body = await request.json();

		// Verify shared secret
		const expectedSecret = env.EMAIL_INBOUND_SECRET;
		if (!expectedSecret) {
			return json({ error: 'Server misconfigured' }, { status: 500 });
		}
		if (body.secret !== expectedSecret) {
			return json({ error: 'Unauthorized' }, { status: 401 });
		}

		const toAddress = (body.to || '').toLowerCase().trim();
		if (!toAddress || !toAddress.endsWith('@fyxxmail.com')) {
			return json({ error: 'Invalid recipient' }, { status: 400 });
		}

		const supabase = getSupabaseAdmin();

		// Find the alias
		const { data: alias, error: aliasError } = await supabase
			.from('email_aliases')
			.select('id, user_id, is_active')
			.eq('address', toAddress)
			.single();

		if (aliasError || !alias) {
			// Unknown alias — silently drop (don't reveal if alias exists)
			return json({ status: 'dropped', reason: 'unknown_alias' });
		}

		if (!alias.is_active) {
			return json({ status: 'dropped', reason: 'alias_inactive' });
		}

		// Detect spam (basic heuristics)
		const subject = body.subject || '(sans objet)';
		const fromAddress = body.from || 'unknown@unknown.com';
		const isSpam = detectSpam(fromAddress, subject, body.text || '');

		// Insert email
		const { error: insertError } = await supabase.from('emails').insert({
			alias_id: alias.id,
			user_id: alias.user_id,
			from_address: fromAddress,
			from_name: body.from_name || '',
			to_address: toAddress,
			subject,
			body_text: body.text || '',
			body_html: body.html || '',
			folder: isSpam ? 'spam' : 'inbox',
			is_read: false,
			received_at: new Date().toISOString()
		});

		if (insertError) {
			console.error('Email insert error:', insertError);
			return json({ error: 'Failed to store email' }, { status: 500 });
		}

		return json({ status: 'delivered' });
	} catch (e: any) {
		console.error('Inbound email error:', e);
		return json({ error: e.message || 'Internal error' }, { status: 500 });
	}
};

function detectSpam(from: string, subject: string, body: string): boolean {
	const spamKeywords = [
		'viagra', 'casino', 'lottery', 'winner', 'prize',
		'nigerian prince', 'wire transfer', 'crypto airdrop',
		'click here now', 'act now', 'limited time'
	];
	const content = `${subject} ${body}`.toLowerCase();
	return spamKeywords.some(kw => content.includes(kw));
}
