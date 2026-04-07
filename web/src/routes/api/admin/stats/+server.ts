import { json } from '@sveltejs/kit';
import Stripe from 'stripe';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());

function getAdminClients() {
	const supabaseAdmin = createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
	const stripe = new Stripe(env.STRIPE_SECRET_KEY!);
	return { supabaseAdmin, stripe };
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<{ valid: boolean; email?: string }> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return { valid: false };

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user || !ADMIN_EMAILS.includes(user.email?.toLowerCase() || '')) return { valid: false };

	return { valid: true, email: user.email || undefined };
}

export const GET: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const { supabaseAdmin, stripe } = getAdminClients();

	if (!(await verifyAdmin(request, supabaseAdmin)).valid) {
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

		// Email metrics (for usage panel)
		const monthStartDate = new Date();
		monthStartDate.setUTCDate(1);
		monthStartDate.setUTCHours(0, 0, 0, 0);
		const monthStartEmails = monthStartDate.toISOString();

		const { count: emailsTotalStored } = await supabaseAdmin
			.from('emails')
			.select('id', { count: 'exact', head: true });

		const { count: emailsThisMonth } = await supabaseAdmin
			.from('emails')
			.select('id', { count: 'exact', head: true })
			.gte('received_at', monthStartEmails);

		const { count: aliasesActive } = await supabaseAdmin
			.from('email_aliases')
			.select('id', { count: 'exact', head: true })
			.eq('is_active', true);

		// Lifetime total received (more stable than emails table when rows are deleted/moved).
		let emailsTotalReceived = 0;
		try {
			const { data: aliasRows } = await supabaseAdmin
				.from('email_aliases')
				.select('emails_received');
			emailsTotalReceived = (aliasRows ?? []).reduce((sum, row: any) => sum + (Number(row?.emails_received) || 0), 0);
		} catch {
			emailsTotalReceived = emailsTotalStored ?? 0;
		}

		// Database size via dedicated admin RPC
		let dbSizeBytes = 0;
		try {
			const { data: sizeData } = await supabaseAdmin.rpc('admin_db_size_bytes');
			const parsed = Number(sizeData);
			if (!Number.isNaN(parsed) && parsed >= 0) dbSizeBytes = parsed;
		} catch {
			// Optional: RPC may not be configured yet
		}

		const dbQuotaMb = Math.max(1, Number(env.SUPABASE_DB_QUOTA_MB || '500'));
		const dbQuotaBytes = dbQuotaMb * 1024 * 1024;
		const dbUsagePercent = Math.min(100, Math.round((dbSizeBytes / dbQuotaBytes) * 100));

		const cloudflareEmailMonthlyQuota = Math.max(1, Number(env.CLOUDFLARE_EMAIL_MONTHLY_QUOTA || '100000'));
		const cloudflareUsagePercent = Math.min(100, Math.round(((emailsThisMonth || 0) / cloudflareEmailMonthlyQuota) * 100));

		// Saturation estimate: project from recent growth pace.
		let dbProjectedDaysToQuota: number | null = null;
		let dbGrowthBytesPerDay = 0;
		let cloudflareProjectedDaysToQuota: number | null = null;
		let cloudflareEmailsPerDay = 0;
		try {
			const sevenDaysAgoIso = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();

			const [
				profilesTotal, profiles7d,
				vaultTotal, vault7d,
				aliasesTotal, aliases7d,
				emailsTotalRows, emails7d,
				auditTotal, audit7d,
				impressionsTotal, impressions7d
			] = await Promise.all([
				supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgoIso),
				supabaseAdmin.from('vault_items').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('vault_items').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgoIso),
				supabaseAdmin.from('email_aliases').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('email_aliases').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgoIso),
				supabaseAdmin.from('emails').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('emails').select('id', { count: 'exact', head: true }).gte('received_at', sevenDaysAgoIso),
				supabaseAdmin.from('admin_audit_log').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('admin_audit_log').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgoIso),
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }),
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgoIso)
			]);

			const totalTrackedRows =
				(profilesTotal.count ?? 0) +
				(vaultTotal.count ?? 0) +
				(aliasesTotal.count ?? 0) +
				(emailsTotalRows.count ?? 0) +
				(auditTotal.count ?? 0) +
				(impressionsTotal.count ?? 0);

			const addedRows7d =
				(profiles7d.count ?? 0) +
				(vault7d.count ?? 0) +
				(aliases7d.count ?? 0) +
				(emails7d.count ?? 0) +
				(audit7d.count ?? 0) +
				(impressions7d.count ?? 0);

			const avgBytesPerRow = totalTrackedRows > 0 ? dbSizeBytes / totalTrackedRows : 0;
			dbGrowthBytesPerDay = avgBytesPerRow * (addedRows7d / 7);

			const dbRemaining = Math.max(0, dbQuotaBytes - dbSizeBytes);
			if (dbGrowthBytesPerDay > 0.0001 && dbRemaining > 0) {
				dbProjectedDaysToQuota = Math.ceil(dbRemaining / dbGrowthBytesPerDay);
			}

			const now = new Date();
			const dayOfMonth = Math.max(1, now.getUTCDate());
			cloudflareEmailsPerDay = (emailsThisMonth ?? 0) / dayOfMonth;
			const cloudRemaining = Math.max(0, cloudflareEmailMonthlyQuota - (emailsThisMonth ?? 0));
			if (cloudflareEmailsPerDay > 0.0001 && cloudRemaining > 0) {
				cloudflareProjectedDaysToQuota = Math.ceil(cloudRemaining / cloudflareEmailsPerDay);
			}
		} catch {
			// Best-effort projection.
		}

		// New users today / this week / this month
		const now = new Date();
		const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
		const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
		const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

		const newUsersToday = users.filter(u => u.created_at >= todayStart).length;
		const newUsersWeek = users.filter(u => u.created_at >= weekStart).length;
		const newUsersMonth = users.filter(u => u.created_at >= monthStart).length;

		// Public site impressions (rolling windows)
		const hourStart = new Date(now.getTime() - 60 * 60 * 1000).toISOString();
		const dayStart = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
		const weekStartTraffic = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
		const monthStartTraffic = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

		let impressionsHour = 0;
		let impressionsDay = 0;
		let impressionsWeek = 0;
		let impressionsMonth = 0;
		let visitorsHour = 0;
		let visitorsDay = 0;
		let visitorsWeek = 0;
		let visitorsMonth = 0;

		try {
			const [hourRes, dayRes, weekRes, monthRes, hourVisitorsRes, dayVisitorsRes, weekVisitorsRes, monthVisitorsRes] = await Promise.all([
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }).gte('created_at', hourStart),
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }).gte('created_at', dayStart),
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }).gte('created_at', weekStartTraffic),
				supabaseAdmin.from('site_impressions').select('id', { count: 'exact', head: true }).gte('created_at', monthStartTraffic),
				supabaseAdmin.from('site_impressions').select('visitor_id').gte('created_at', hourStart),
				supabaseAdmin.from('site_impressions').select('visitor_id').gte('created_at', dayStart),
				supabaseAdmin.from('site_impressions').select('visitor_id').gte('created_at', weekStartTraffic),
				supabaseAdmin.from('site_impressions').select('visitor_id').gte('created_at', monthStartTraffic)
			]);

			impressionsHour = hourRes.count ?? 0;
			impressionsDay = dayRes.count ?? 0;
			impressionsWeek = weekRes.count ?? 0;
			impressionsMonth = monthRes.count ?? 0;
			visitorsHour = new Set((hourVisitorsRes.data ?? []).map((r: any) => r.visitor_id).filter(Boolean)).size;
			visitorsDay = new Set((dayVisitorsRes.data ?? []).map((r: any) => r.visitor_id).filter(Boolean)).size;
			visitorsWeek = new Set((weekVisitorsRes.data ?? []).map((r: any) => r.visitor_id).filter(Boolean)).size;
			visitorsMonth = new Set((monthVisitorsRes.data ?? []).map((r: any) => r.visitor_id).filter(Boolean)).size;
		} catch {
			// Table may be missing before migration is applied.
		}

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
			activeSubscriptions,
			impressions: {
				hour: impressionsHour,
				day: impressionsDay,
				week: impressionsWeek,
				month: impressionsMonth
			},
			visitors: {
				hour: visitorsHour,
				day: visitorsDay,
				week: visitorsWeek,
				month: visitorsMonth
			},
			usage: {
				database: {
					usedBytes: dbSizeBytes,
					quotaBytes: dbQuotaBytes,
					percent: dbUsagePercent,
					projection: {
						daysToQuota: dbProjectedDaysToQuota,
						growthBytesPerDay: Math.round(dbGrowthBytesPerDay)
					}
				},
				cloudflare: {
					emailsThisMonth: emailsThisMonth ?? 0,
					emailsTotal: emailsTotalReceived,
					emailsStored: emailsTotalStored ?? 0,
					activeAliases: aliasesActive ?? 0,
					monthlyQuota: cloudflareEmailMonthlyQuota,
					percent: cloudflareUsagePercent,
					projection: {
						daysToQuota: cloudflareProjectedDaysToQuota,
						emailsPerDay: Math.round(cloudflareEmailsPerDay * 10) / 10
					}
				}
			}
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
