import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<{ valid: boolean; email?: string }> {
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

	const supabaseAdmin = getSupabaseAdmin();

	if (!(await verifyAdmin(request, supabaseAdmin)).valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const page = parseInt(url.searchParams.get('page') || '1');
		const perPage = parseInt(url.searchParams.get('perPage') || '20');
		const search = url.searchParams.get('search') || '';
		const filter = url.searchParams.get('filter') || 'all';
		const sortBy = url.searchParams.get('sortBy') || 'created_at';
		const sortDir = url.searchParams.get('sortDir') || 'desc';

		// Get all users from auth
		const { data: usersData } = await supabaseAdmin.auth.admin.listUsers({ perPage: 1000 });
		let users = usersData?.users ?? [];

		// Get all profiles
		const { data: profiles } = await supabaseAdmin.from('profiles').select('id, is_pro, plan, stripe_customer_id, stripe_subscription_id');

		// Get vault items count per user
		const { data: vaultCounts } = await supabaseAdmin
			.from('vault_items')
			.select('user_id');

		const countMap: Record<string, number> = {};
		vaultCounts?.forEach(item => {
			countMap[item.user_id] = (countMap[item.user_id] || 0) + 1;
		});

		const profileMap: Record<string, any> = {};
		profiles?.forEach(p => { profileMap[p.id] = p; });

		// Build enriched user list
		let enrichedUsers = users.map(u => ({
			id: u.id,
			email: u.email || '',
			created_at: u.created_at,
			last_sign_in_at: u.last_sign_in_at,
			is_pro: profileMap[u.id]?.is_pro === true,
			plan: profileMap[u.id]?.plan || 'free',
			vault_items_count: countMap[u.id] || 0,
			stripe_customer_id: profileMap[u.id]?.stripe_customer_id || null,
			stripe_subscription_id: profileMap[u.id]?.stripe_subscription_id || null
		}));

		// Search
		if (search) {
			const s = search.toLowerCase();
			enrichedUsers = enrichedUsers.filter(u => u.email.toLowerCase().includes(s));
		}

		// Filter
		if (filter === 'pro') {
			enrichedUsers = enrichedUsers.filter(u => u.is_pro);
		} else if (filter === 'free') {
			enrichedUsers = enrichedUsers.filter(u => !u.is_pro);
		}

		// Sort
		enrichedUsers.sort((a, b) => {
			let valA: any, valB: any;
			if (sortBy === 'email') {
				valA = a.email.toLowerCase();
				valB = b.email.toLowerCase();
			} else {
				valA = a.created_at || '';
				valB = b.created_at || '';
			}
			if (valA < valB) return sortDir === 'asc' ? -1 : 1;
			if (valA > valB) return sortDir === 'asc' ? 1 : -1;
			return 0;
		});

		const total = enrichedUsers.length;
		const start = (page - 1) * perPage;
		const paginated = enrichedUsers.slice(start, start + perPage);

		return json({
			users: paginated,
			total,
			page,
			perPage,
			totalPages: Math.ceil(total / perPage)
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
