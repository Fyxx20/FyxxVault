import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());

async function verifyAdmin(request: Request): Promise<{ valid: boolean; email?: string }> {
	const supabaseAdmin = createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return { valid: false };

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user || !ADMIN_EMAILS.includes(user.email?.toLowerCase() || '')) return { valid: false };

	return { valid: true, email: user.email || undefined };
}

export const GET: RequestHandler = async ({ request, url }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	if (!(await verifyAdmin(request)).valid) {
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
