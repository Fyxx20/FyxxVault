import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import { logAdminAction } from '$lib/adminAudit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS_FALLBACK = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

async function getAdminEmails(supabaseAdmin: ReturnType<typeof createClient>): Promise<string[]> {
	try {
		const { data } = await supabaseAdmin
			.from('platform_settings')
			.select('value')
			.eq('key', 'admin_emails')
			.single();
		if (data?.value) return JSON.parse(data.value);
	} catch {}
	return ADMIN_EMAILS_FALLBACK;
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<{ valid: boolean; email?: string }> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return { valid: false };

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user?.email) return { valid: false };

	const admins = await getAdminEmails(supabaseAdmin);
	if (!admins.includes(user.email)) return { valid: false };

	return { valid: true, email: user.email };
}

export const GET: RequestHandler = async () => {
	const supabaseAdmin = getSupabaseAdmin();

	try {
		const { data: maintenanceData } = await supabaseAdmin
			.from('platform_settings')
			.select('value')
			.eq('key', 'maintenance_mode')
			.single();

		const admins = await getAdminEmails(supabaseAdmin);

		return json({
			maintenance: maintenanceData?.value === 'true',
			admins
		});
	} catch {
		return json({ maintenance: false, admins: ADMIN_EMAILS_FALLBACK });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();

	const adminAuth = await verifyAdmin(request, supabaseAdmin);
	if (!adminAuth.valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}
	const adminEmail = adminAuth.email || 'unknown';

	try {
		const body = await request.json();

		// Handle admin_emails update
		if (body.admin_emails && Array.isArray(body.admin_emails)) {
			// Ensure owner is always included
			const emails = body.admin_emails as string[];
			if (!emails.includes('fyxxfn@gmail.com')) emails.unshift('fyxxfn@gmail.com');

			await supabaseAdmin
				.from('platform_settings')
				.upsert(
					{ key: 'admin_emails', value: JSON.stringify(emails), updated_at: new Date().toISOString() },
					{ onConflict: 'key' }
				);

			await logAdminAction(supabaseAdmin, adminEmail, 'update_admin_emails', null, { emails }, clientIP);
			return json({ success: true, admins: emails });
		}

		// Handle maintenance toggle
		const enabled = body.enabled === true;
		const { error } = await supabaseAdmin
			.from('platform_settings')
			.upsert(
				{ key: 'maintenance_mode', value: enabled ? 'true' : 'false', updated_at: new Date().toISOString() },
				{ onConflict: 'key' }
			);

		if (error) {
			return json({ error: error.message }, { status: 500 });
		}

		await logAdminAction(supabaseAdmin, adminEmail, 'toggle_maintenance', null, { enabled }, clientIP);
		return json({ success: true, maintenance: enabled });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
