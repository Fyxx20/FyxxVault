import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

const ADMIN_EMAIL = 'fyxxfn@gmail.com';

function getAdminClients() {
	const supabaseAdmin = createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
	const stripe = new Stripe(env.STRIPE_SECRET_KEY!);
	return { supabaseAdmin, stripe };
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<boolean> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return false;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user || user.email !== ADMIN_EMAIL) return false;

	return true;
}

export const GET: RequestHandler = async ({ request }) => {
	const { supabaseAdmin, stripe } = getAdminClients();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		// Get all users
		const { data: usersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
		const users = usersData?.users ?? [];
		const totalUsers = users.length;

		// Get profiles with is_pro
		const { data: profiles } = await supabaseAdmin.from('profiles').select('id, is_pro');
		const proUsers = profiles?.filter(p => p.is_pro === true).length ?? 0;
		const freeUsers = totalUsers - proUsers;

		// Get vault items count
		const { count: vaultItemsCount } = await supabaseAdmin
			.from('vault_items')
			.select('*', { count: 'exact', head: true });

		// New users today / this week / this month
		const now = new Date();
		const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
		const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
		const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

		const newUsersToday = users.filter(u => u.created_at >= todayStart).length;
		const newUsersWeek = users.filter(u => u.created_at >= weekStart).length;
		const newUsersMonth = users.filter(u => u.created_at >= monthStart).length;

		// Stripe revenue stats
		let mrr = 0;
		let activeSubscriptions = 0;
		try {
			const subs = await stripe.subscriptions.list({ status: 'active', limit: 100 });
			activeSubscriptions = subs.data.length;
			mrr = subs.data.reduce((sum, sub) => {
				const item = sub.items.data[0];
				if (!item?.price?.unit_amount) return sum;
				const amount = item.price.unit_amount;
				const interval = item.price.recurring?.interval;
				if (interval === 'year') return sum + Math.round(amount / 12);
				return sum + amount;
			}, 0);
		} catch (e) {
			// Stripe may not be configured
		}

		return json({
			totalUsers,
			proUsers,
			freeUsers,
			vaultItemsCount: vaultItemsCount ?? 0,
			newUsersToday,
			newUsersWeek,
			newUsersMonth,
			mrr,
			activeSubscriptions
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
