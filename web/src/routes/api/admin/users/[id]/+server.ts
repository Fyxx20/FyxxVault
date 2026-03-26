import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

const ADMIN_EMAIL = 'fyxxfn@gmail.com';

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<boolean> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return false;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user || user.email !== ADMIN_EMAIL) return false;

	return true;
}

export const GET: RequestHandler = async ({ request, params }) => {
	const supabaseAdmin = getSupabaseAdmin();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const userId = params.id;

		// Get user from auth
		const { data: { user }, error } = await supabaseAdmin.auth.admin.getUserById(userId);
		if (error || !user) {
			return json({ error: 'Utilisateur introuvable' }, { status: 404 });
		}

		// Get profile
		const { data: profile } = await supabaseAdmin
			.from('profiles')
			.select('*')
			.eq('id', userId)
			.single();

		// Get vault items count
		const { count } = await supabaseAdmin
			.from('vault_items')
			.select('*', { count: 'exact', head: true })
			.eq('user_id', userId);

		return json({
			id: user.id,
			email: user.email,
			created_at: user.created_at,
			last_sign_in_at: user.last_sign_in_at,
			email_confirmed_at: user.email_confirmed_at,
			is_pro: profile?.is_pro === true,
			plan: profile?.plan || 'free',
			stripe_customer_id: profile?.stripe_customer_id || null,
			stripe_subscription_id: profile?.stripe_subscription_id || null,
			vault_items_count: count ?? 0
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const PATCH: RequestHandler = async ({ request, params }) => {
	const supabaseAdmin = getSupabaseAdmin();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const userId = params.id;
		const body = await request.json();

		const updates: Record<string, any> = { updated_at: new Date().toISOString() };

		if (typeof body.is_pro === 'boolean') {
			updates.is_pro = body.is_pro;
		}
		if (body.plan) {
			updates.plan = body.plan;
		}

		const { error } = await supabaseAdmin
			.from('profiles')
			.upsert({ id: userId, ...updates }, { onConflict: 'id' });

		if (error) {
			return json({ error: error.message }, { status: 500 });
		}

		return json({ success: true });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const DELETE: RequestHandler = async ({ request, params }) => {
	const supabaseAdmin = getSupabaseAdmin();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const userId = params.id;

		// Delete vault items
		await supabaseAdmin.from('vault_items').delete().eq('user_id', userId);

		// Delete sync metadata
		await supabaseAdmin.from('sync_metadata').delete().eq('user_id', userId);

		// Delete profile
		await supabaseAdmin.from('profiles').delete().eq('id', userId);

		// Delete auth user
		const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
		if (error) {
			return json({ error: error.message }, { status: 500 });
		}

		return json({ success: true });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
