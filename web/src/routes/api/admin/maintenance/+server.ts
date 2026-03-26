import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import type { RequestHandler } from './$types';

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
	return ['fyxxfn@gmail.com'];
}

async function verifyAdmin(request: Request, supabaseAdmin: ReturnType<typeof createClient>): Promise<boolean> {
	const authHeader = request.headers.get('Authorization');
	if (!authHeader?.startsWith('Bearer ')) return false;

	const token = authHeader.slice(7);
	const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
	if (error || !user?.email) return false;

	const admins = await getAdminEmails(supabaseAdmin);
	return admins.includes(user.email);
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
		return json({ maintenance: false, admins: ['fyxxfn@gmail.com'] });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const supabaseAdmin = getSupabaseAdmin();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

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

		return json({ success: true, maintenance: enabled });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
