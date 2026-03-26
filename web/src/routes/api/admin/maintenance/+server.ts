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

export const GET: RequestHandler = async () => {
	const supabaseAdmin = getSupabaseAdmin();

	// Allow anyone to check maintenance status (needed by vault layout)
	try {
		const { data, error } = await supabaseAdmin
			.from('platform_settings')
			.select('value')
			.eq('key', 'maintenance_mode')
			.single();

		if (error) {
			// Table may not exist yet — default to off
			return json({ maintenance: false });
		}

		return json({ maintenance: data.value === 'true' });
	} catch {
		return json({ maintenance: false });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const supabaseAdmin = getSupabaseAdmin();

	if (!await verifyAdmin(request, supabaseAdmin)) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const body = await request.json();
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
