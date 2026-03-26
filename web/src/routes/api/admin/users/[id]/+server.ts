import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

const ADMIN_EMAIL = 'fyxxfn@gmail.com';

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

function getStripe() {
	return new Stripe(env.STRIPE_SECRET_KEY!);
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
		const { count: vaultItemsCount } = await supabaseAdmin
			.from('vault_items')
			.select('*', { count: 'exact', head: true })
			.eq('user_id', userId);

		// Get vault items for category stats
		const { data: vaultItems } = await supabaseAdmin
			.from('vault_items')
			.select('category')
			.eq('user_id', userId);

		const categories = new Set<string>();
		vaultItems?.forEach(item => {
			if (item.category) categories.add(item.category);
		});

		// Get sync metadata
		const { data: syncMeta } = await supabaseAdmin
			.from('sync_metadata')
			.select('*')
			.eq('user_id', userId)
			.order('last_sync', { ascending: false })
			.limit(1)
			.single();

		// Get Stripe subscription details if available
		let stripeSubscription: any = null;
		if (profile?.stripe_subscription_id) {
			try {
				const stripe = getStripe();
				const sub = await stripe.subscriptions.retrieve(profile.stripe_subscription_id);
				const item = sub.items.data[0];
				stripeSubscription = {
					id: sub.id,
					status: sub.status,
					current_period_start: sub.current_period_start ? new Date(sub.current_period_start * 1000).toISOString() : null,
					current_period_end: sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null,
					cancel_at_period_end: sub.cancel_at_period_end,
					trial_end: sub.trial_end ? new Date(sub.trial_end * 1000).toISOString() : null,
					amount: item?.price?.unit_amount ?? 0,
					currency: item?.price?.currency ?? 'eur',
					interval: item?.price?.recurring?.interval ?? null,
					created: new Date(sub.created * 1000).toISOString()
				};
			} catch {
				// Stripe not configured or subscription not found
			}
		}

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
			vault_items_count: vaultItemsCount ?? 0,
			categories_count: categories.size,
			categories_list: Array.from(categories),
			sync_metadata: syncMeta ? {
				last_sync: syncMeta.last_sync,
				device_name: syncMeta.device_name || null,
				device_id: syncMeta.device_id || null
			} : null,
			stripe_subscription: stripeSubscription
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

		// Handle password reset
		if (body.action === 'send_password_reset') {
			// Get user email first
			const { data: { user }, error: userError } = await supabaseAdmin.auth.admin.getUserById(userId);
			if (userError || !user?.email) {
				return json({ error: 'Utilisateur introuvable' }, { status: 404 });
			}

			const { data, error: resetError } = await supabaseAdmin.auth.admin.generateLink({
				type: 'recovery',
				email: user.email
			});

			if (resetError) {
				return json({ error: resetError.message }, { status: 500 });
			}

			return json({ success: true, message: 'Lien de recuperation genere', link: data });
		}

		// Handle profile updates
		const updates: Record<string, any> = { updated_at: new Date().toISOString() };

		if (typeof body.is_pro === 'boolean') {
			updates.is_pro = body.is_pro;
			// Auto-set plan when toggling pro
			if (!body.plan) {
				updates.plan = body.is_pro ? 'monthly' : 'free';
			}
		}
		if (body.plan) {
			updates.plan = body.plan;
			// Auto-set is_pro based on plan
			if (typeof body.is_pro === 'undefined') {
				updates.is_pro = body.plan !== 'free';
			}
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
