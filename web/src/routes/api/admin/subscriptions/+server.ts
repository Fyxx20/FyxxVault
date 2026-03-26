import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

const ADMIN_EMAIL = 'fyxxfn@gmail.com';

async function verifyAdmin(request: Request): Promise<boolean> {
	const supabaseAdmin = createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return false;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user || user.email !== ADMIN_EMAIL) return false;

	return true;
}

export const GET: RequestHandler = async ({ request, url }) => {
	if (!await verifyAdmin(request)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const stripe = new Stripe(env.STRIPE_SECRET_KEY!);
		const status = url.searchParams.get('status') || undefined;
		const limit = parseInt(url.searchParams.get('limit') || '50');

		const params: Stripe.SubscriptionListParams = { limit, expand: ['data.customer'] };
		if (status && status !== 'all') {
			params.status = status as Stripe.SubscriptionListParams['status'];
		}

		const subscriptions = await stripe.subscriptions.list(params);

		const enriched = subscriptions.data.map(sub => {
			const customer = sub.customer as Stripe.Customer;
			const item = sub.items.data[0];
			return {
				id: sub.id,
				customer_email: customer?.email || 'N/A',
				customer_name: customer?.name || '',
				status: sub.status,
				plan: item?.price?.recurring?.interval === 'year' ? 'yearly' : 'monthly',
				amount: item?.price?.unit_amount ?? 0,
				currency: item?.price?.currency ?? 'eur',
				current_period_end: sub.current_period_end,
				trial_end: sub.trial_end,
				cancel_at_period_end: sub.cancel_at_period_end,
				created: sub.created
			};
		});

		// Count by status
		const allSubs = await stripe.subscriptions.list({ limit: 100, status: 'all' });
		const counts = {
			active: 0,
			trialing: 0,
			canceled: 0,
			past_due: 0,
			incomplete: 0
		};
		allSubs.data.forEach(s => {
			if (s.status in counts) {
				counts[s.status as keyof typeof counts]++;
			}
		});

		return json({ subscriptions: enriched, counts });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
