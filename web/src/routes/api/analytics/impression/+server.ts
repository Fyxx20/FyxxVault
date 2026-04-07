import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import type { RequestHandler } from './$types';

function getSupabaseAdmin() {
	return createClient(pubEnv.PUBLIC_SUPABASE_URL!, env.SUPABASE_SERVICE_ROLE_KEY!);
}

const BLOCKED_PATH_PREFIXES = ['/api', '/admin', '/vault'];

function shouldTrackPath(path: string): boolean {
	if (!path || !path.startsWith('/')) return false;
	return !BLOCKED_PATH_PREFIXES.some((prefix) => path.startsWith(prefix));
}

export const POST: RequestHandler = async ({ request }) => {
	try {
		const ip = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown';
		const ua = request.headers.get('user-agent') || '';

		if (/bot|crawler|spider|preview|headless/i.test(ua)) {
			return json({ ok: true, ignored: true });
		}

		const body = await request.json().catch(() => ({}));
		const rawVisitorId = typeof body?.visitorId === 'string' ? body.visitorId : '';
		const rawPath = typeof body?.path === 'string' ? body.path : '';
		const rawReferrer = typeof body?.referrer === 'string' ? body.referrer : '';

		const visitorId = rawVisitorId.slice(0, 120);
		const path = rawPath.slice(0, 240);
		const referrer = rawReferrer.slice(0, 500);

		if (!visitorId || !shouldTrackPath(path)) {
			return json({ ok: true, ignored: true });
		}

		if (!checkRateLimit(`impression:${ip}:${visitorId}:${path}`, 1, 10000)) {
			return json({ ok: true, throttled: true });
		}

		const supabaseAdmin = getSupabaseAdmin();
		await supabaseAdmin.from('site_impressions').insert({
			visitor_id: visitorId,
			path,
			referrer,
			user_agent: ua.slice(0, 500)
		});

		return json({ ok: true });
	} catch {
		// Best-effort analytics endpoint: never break UX.
		return json({ ok: true });
	}
};
