import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import * as pubEnv from '$env/dynamic/public';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.env.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

function generateAlias(): string {
	const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
	let result = '';
	for (let i = 0; i < 10; i++) {
		result += chars.charAt(Math.floor(Math.random() * chars.length));
	}
	return result + '@fyxxmail.com';
}

/**
 * GET /api/email/aliases
 * List all aliases for the authenticated user
 */
export const GET: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const { data: aliases, error } = await supabase
		.from('email_aliases')
		.select('*')
		.eq('user_id', user.id)
		.order('created_at', { ascending: false });

	if (error) return json({ error: error.message }, { status: 500 });

	return json({ aliases });
};

/**
 * POST /api/email/aliases
 * Create a new alias
 * Body: { label?: string }
 */
export const POST: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json().catch(() => ({}));

	// Generate or use custom alias address
	let address: string;
	if (body.customName && typeof body.customName === 'string') {
		// Custom alias name: sanitize (lowercase, alphanumeric + dots/hyphens, 3-30 chars)
		const sanitized = body.customName.toLowerCase().replace(/[^a-z0-9.\-]/g, '').slice(0, 30);
		if (sanitized.length < 3) {
			return json({ error: 'Le nom doit contenir au moins 3 caracteres (lettres, chiffres, points, tirets).' }, { status: 400 });
		}
		address = sanitized + '@fyxxmail.com';

		// Check if already taken
		const { data: existing } = await supabase
			.from('email_aliases')
			.select('id')
			.eq('address', address)
			.single();

		if (existing) {
			return json({ error: `L'adresse ${address} est deja prise. Essaie un autre nom.` }, { status: 409 });
		}
	} else {
		// Random alias
		address = generateAlias();
		let attempts = 0;
		while (attempts < 10) {
			const { data: existing } = await supabase
				.from('email_aliases')
				.select('id')
				.eq('address', address)
				.single();

			if (!existing) break;
			address = generateAlias();
			attempts++;
		}
	}

	const { data: alias, error: insertError } = await supabase
		.from('email_aliases')
		.insert({
			user_id: user.id,
			address,
			label: body.label || ''
		})
		.select()
		.single();

	if (insertError) return json({ error: insertError.message }, { status: 500 });

	return json({ alias }, { status: 201 });
};

/**
 * DELETE /api/email/aliases
 * Delete an alias
 * Body: { id: string }
 */
export const DELETE: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json().catch(() => ({}));
	if (!body.id) return json({ error: 'Alias ID required' }, { status: 400 });

	// Delete alias (cascade deletes emails too)
	const { error } = await supabase
		.from('email_aliases')
		.delete()
		.eq('id', body.id)
		.eq('user_id', user.id);

	if (error) return json({ error: error.message }, { status: 500 });

	return json({ success: true });
};

/**
 * PATCH /api/email/aliases
 * Toggle alias active/inactive or update label
 * Body: { id: string, is_active?: boolean, label?: string }
 */
export const PATCH: RequestHandler = async ({ request }) => {
	const authHeader = request.headers.get('authorization');
	if (!authHeader) return json({ error: 'Unauthorized' }, { status: 401 });

	const supabase = getSupabaseAdmin();
	const token = authHeader.replace('Bearer ', '');

	const { data: { user }, error: authError } = await supabase.auth.getUser(token);
	if (authError || !user) return json({ error: 'Unauthorized' }, { status: 401 });

	const body = await request.json().catch(() => ({}));
	if (!body.id) return json({ error: 'Alias ID required' }, { status: 400 });

	const updates: Record<string, any> = { updated_at: new Date().toISOString() };
	if (typeof body.is_active === 'boolean') updates.is_active = body.is_active;
	if (typeof body.label === 'string') updates.label = body.label;

	const { data: alias, error } = await supabase
		.from('email_aliases')
		.update(updates)
		.eq('id', body.id)
		.eq('user_id', user.id)
		.select()
		.single();

	if (error) return json({ error: error.message }, { status: 500 });

	return json({ alias });
};
