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

export const GET: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();

	if (!(await verifyAdmin(request, supabaseAdmin)).valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const { count: profilesCount } = await supabaseAdmin
			.from('profiles')
			.select('*', { count: 'exact', head: true });

		const { count: vaultItemsCount } = await supabaseAdmin
			.from('vault_items')
			.select('*', { count: 'exact', head: true });

		const { count: syncMetadataCount } = await supabaseAdmin
			.from('sync_metadata')
			.select('*', { count: 'exact', head: true });

		return json({
			tables: {
				profiles: profilesCount ?? 0,
				vault_items: vaultItemsCount ?? 0,
				sync_metadata: syncMetadataCount ?? 0
			}
		});
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const POST: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();

	if (!(await verifyAdmin(request, supabaseAdmin)).valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const { query } = await request.json();

		if (!query || typeof query !== 'string') {
			return json({ error: 'Requete invalide' }, { status: 400 });
		}

		// Block dangerous operations
		const upper = query.toUpperCase().trim();
		const forbidden = ['DROP', 'TRUNCATE', 'ALTER', 'CREATE', 'GRANT', 'REVOKE'];
		for (const keyword of forbidden) {
			if (upper.startsWith(keyword)) {
				return json({ error: `Operation "${keyword}" interdite via l'interface admin` }, { status: 400 });
			}
		}

		const { data, error } = await supabaseAdmin.rpc('admin_run_sql', { sql_query: query });

		if (error) {
			// Fallback: try direct query on known tables
			return json({ error: error.message, hint: 'Verifiez que la fonction RPC admin_run_sql existe, ou utilisez des requetes Supabase standard.' }, { status: 400 });
		}

		return json({ data, rowCount: Array.isArray(data) ? data.length : 0 });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
