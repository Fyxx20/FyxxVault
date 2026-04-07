import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { env } from '$env/dynamic/private';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`billing:${clientIP}`, 10, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const stripe = new Stripe(env.STRIPE_SECRET_KEY!);
	const { email } = await request.json();

	if (!email) {
		return json({ error: 'Email requis' }, { status: 400 });
	}

	try {
		// Find the Stripe customer by email
		const customers = await stripe.customers.list({ email, limit: 1 });

		if (customers.data.length === 0) {
			return json({ error: 'Aucun abonnement trouvé pour ce compte' }, { status: 404 });
		}

		const customer = customers.data[0];

		// Create a billing portal session
		const session = await stripe.billingPortal.sessions.create({
			customer: customer.id,
			return_url: `${request.headers.get('origin')}/vault/settings`
		});

		return json({ url: session.url });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
