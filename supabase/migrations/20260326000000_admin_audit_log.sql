-- Admin audit log table for tracking all admin actions
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_email TEXT NOT NULL,
    action TEXT NOT NULL,
    target_user_id UUID,
    details JSONB,
    ip_address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_created ON admin_audit_log(created_at DESC);
CREATE INDEX idx_audit_log_admin ON admin_audit_log(admin_email);

ALTER TABLE admin_audit_log ENABLE ROW LEVEL SECURITY;

-- Only service role can insert/read audit logs (no user access)
CREATE POLICY "Service role only" ON admin_audit_log
    FOR ALL
    USING (false)
    WITH CHECK (false);
