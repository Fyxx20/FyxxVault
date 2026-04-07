-- Public site impressions tracking
CREATE TABLE IF NOT EXISTS site_impressions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visitor_id TEXT NOT NULL,
    path TEXT NOT NULL,
    referrer TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_site_impressions_created_at ON site_impressions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_site_impressions_path_created_at ON site_impressions(path, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_site_impressions_visitor_created_at ON site_impressions(visitor_id, created_at DESC);

ALTER TABLE site_impressions ENABLE ROW LEVEL SECURITY;

-- No direct client access; only service-role backend reads/writes.
CREATE POLICY "Service role only" ON site_impressions
    FOR ALL
    USING (false)
    WITH CHECK (false);
