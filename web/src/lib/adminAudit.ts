import type { SupabaseClient } from '@supabase/supabase-js';

export async function logAdminAction(
	supabaseAdmin: SupabaseClient,
	adminEmail: string,
	action: string,
	targetUserId?: string | null,
	details?: Record<string, unknown> | null,
	ip?: string | null
): Promise<void> {
	try {
		await supabaseAdmin.from('admin_audit_log').insert({
			admin_email: adminEmail,
			action,
			target_user_id: targetUserId || null,
			details: details || null,
			ip_address: ip || null
		});
	} catch {
		// Audit logging should never break the main flow
		console.error('Failed to log admin action:', action);
	}
}
