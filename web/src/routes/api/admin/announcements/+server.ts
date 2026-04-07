import { json } from '@sveltejs/kit';
import { createClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/private';
import { env as pubEnv } from '$env/dynamic/public';
import { checkRateLimit } from '$lib/rateLimit';
import { logAdminAction } from '$lib/adminAudit';
import type { RequestHandler } from './$types';

const ADMIN_EMAILS_FALLBACK = (env.ADMIN_EMAILS || 'fyxxfn@gmail.com').split(',').map(e => e.trim().toLowerCase());
const ANNOUNCEMENTS_KEY = 'announcements';

type AnnouncementType = 'update' | 'maintenance' | 'security' | 'feature' | 'info';

interface Announcement {
	id: string;
	type: AnnouncementType;
	title: string;
	content: string;
	date: string;
	pinned: boolean;
	created_at: string;
	updated_at: string;
}

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
		if (data?.value) {
			const parsed = JSON.parse(data.value);
			if (Array.isArray(parsed)) {
				return parsed.map((email: string) => String(email).toLowerCase());
			}
		}
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
	if (!admins.includes(user.email.toLowerCase())) return { valid: false };

	return { valid: true, email: user.email };
}

function normalizeAnnouncements(raw: unknown): Announcement[] {
	if (!Array.isArray(raw)) return [];
	return raw
		.map((item: any) => ({
			id: String(item?.id || crypto.randomUUID()),
			type: ['update', 'maintenance', 'security', 'feature', 'info'].includes(item?.type) ? item.type : 'info',
			title: String(item?.title || '').trim(),
			content: String(item?.content || '').trim(),
			date: String(item?.date || new Date().toISOString().slice(0, 10)),
			pinned: item?.pinned === true,
			created_at: String(item?.created_at || new Date().toISOString()),
			updated_at: String(item?.updated_at || new Date().toISOString())
		}))
		.filter((item: Announcement) => item.title.length > 0 && item.content.length > 0)
		.sort((a, b) => {
			if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
			return new Date(b.date).getTime() - new Date(a.date).getTime();
		});
}

async function getAnnouncements(supabaseAdmin: ReturnType<typeof createClient>): Promise<Announcement[]> {
	const { data } = await supabaseAdmin
		.from('platform_settings')
		.select('value')
		.eq('key', ANNOUNCEMENTS_KEY)
		.single();

	if (!data?.value) return [];

	try {
		return normalizeAnnouncements(JSON.parse(data.value));
	} catch {
		return [];
	}
}

async function saveAnnouncements(supabaseAdmin: ReturnType<typeof createClient>, announcements: Announcement[]) {
	return supabaseAdmin
		.from('platform_settings')
		.upsert(
			{ key: ANNOUNCEMENTS_KEY, value: JSON.stringify(announcements), updated_at: new Date().toISOString() },
			{ onConflict: 'key' }
		);
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
		const announcements = await getAnnouncements(supabaseAdmin);
		return json({ announcements });
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
	const adminAuth = await verifyAdmin(request, supabaseAdmin);
	if (!adminAuth.valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const body = await request.json();
		const title = String(body?.title || '').trim();
		const content = String(body?.content || '').trim();
		const type = String(body?.type || 'info') as AnnouncementType;
		const pinned = body?.pinned === true;

		if (!title || !content) {
			return json({ error: 'Titre et contenu requis' }, { status: 400 });
		}

		if (!['update', 'maintenance', 'security', 'feature', 'info'].includes(type)) {
			return json({ error: 'Type invalide' }, { status: 400 });
		}

		const announcements = await getAnnouncements(supabaseAdmin);
		const now = new Date().toISOString();
		const newAnnouncement: Announcement = {
			id: crypto.randomUUID(),
			type,
			title,
			content,
			date: new Date().toISOString().slice(0, 10),
			pinned,
			created_at: now,
			updated_at: now
		};

		const next = normalizeAnnouncements([newAnnouncement, ...announcements]);
		const { error } = await saveAnnouncements(supabaseAdmin, next);
		if (error) return json({ error: error.message }, { status: 500 });

		await logAdminAction(supabaseAdmin, adminAuth.email || 'unknown', 'create_announcement', null, { announcement_id: newAnnouncement.id, title }, clientIP);
		return json({ success: true, announcement: newAnnouncement, announcements: next });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const PATCH: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();
	const adminAuth = await verifyAdmin(request, supabaseAdmin);
	if (!adminAuth.valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const body = await request.json();
		const announcementId = String(body?.id || '');
		if (!announcementId) return json({ error: 'ID requis' }, { status: 400 });

		const announcements = await getAnnouncements(supabaseAdmin);
		const idx = announcements.findIndex(a => a.id === announcementId);
		if (idx === -1) return json({ error: 'Annonce introuvable' }, { status: 404 });

		const current = announcements[idx];
		const nextItem: Announcement = {
			...current,
			title: typeof body.title === 'string' ? body.title.trim() || current.title : current.title,
			content: typeof body.content === 'string' ? body.content.trim() || current.content : current.content,
			type: ['update', 'maintenance', 'security', 'feature', 'info'].includes(body.type) ? body.type : current.type,
			pinned: typeof body.pinned === 'boolean' ? body.pinned : current.pinned,
			updated_at: new Date().toISOString()
		};

		announcements[idx] = nextItem;
		const next = normalizeAnnouncements(announcements);
		const { error } = await saveAnnouncements(supabaseAdmin, next);
		if (error) return json({ error: error.message }, { status: 500 });

		await logAdminAction(supabaseAdmin, adminAuth.email || 'unknown', 'update_announcement', null, { announcement_id: announcementId }, clientIP);
		return json({ success: true, announcements: next });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};

export const DELETE: RequestHandler = async ({ request }) => {
	const clientIP = request.headers.get('x-forwarded-for') || 'unknown';
	if (!checkRateLimit(`admin:${clientIP}`, 100, 60000)) {
		return json({ error: 'Too many requests' }, { status: 429 });
	}

	const supabaseAdmin = getSupabaseAdmin();
	const adminAuth = await verifyAdmin(request, supabaseAdmin);
	if (!adminAuth.valid) {
		return json({ error: 'Non autorise' }, { status: 403 });
	}

	try {
		const body = await request.json().catch(() => ({}));
		const announcementId = String(body?.id || '');
		if (!announcementId) return json({ error: 'ID requis' }, { status: 400 });

		const announcements = await getAnnouncements(supabaseAdmin);
		const next = announcements.filter(a => a.id !== announcementId);

		const { error } = await saveAnnouncements(supabaseAdmin, next);
		if (error) return json({ error: error.message }, { status: 500 });

		await logAdminAction(supabaseAdmin, adminAuth.email || 'unknown', 'delete_announcement', null, { announcement_id: announcementId }, clientIP);
		return json({ success: true, announcements: next });
	} catch (err: any) {
		return json({ error: err.message }, { status: 500 });
	}
};
