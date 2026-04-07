-- ============================================================
-- FyxxVault Email System
-- Tables for disposable email aliases and inbox
-- ============================================================

-- Email aliases (e.g. abc123@fyxxvault.com)
CREATE TABLE IF NOT EXISTS email_aliases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    address TEXT NOT NULL UNIQUE,
    label TEXT DEFAULT '',
    is_active BOOLEAN DEFAULT true,
    emails_received INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Emails received
CREATE TABLE IF NOT EXISTS emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alias_id UUID NOT NULL REFERENCES email_aliases(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    from_address TEXT NOT NULL,
    from_name TEXT DEFAULT '',
    to_address TEXT NOT NULL,
    subject TEXT DEFAULT '(sans objet)',
    body_text TEXT DEFAULT '',
    body_html TEXT DEFAULT '',
    folder TEXT DEFAULT 'inbox' CHECK (folder IN ('inbox', 'trash', 'spam', 'archive')),
    is_read BOOLEAN DEFAULT false,
    is_starred BOOLEAN DEFAULT false,
    received_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_email_aliases_user ON email_aliases(user_id);
CREATE INDEX IF NOT EXISTS idx_email_aliases_address ON email_aliases(address);
CREATE INDEX IF NOT EXISTS idx_emails_user ON emails(user_id);
CREATE INDEX IF NOT EXISTS idx_emails_alias ON emails(alias_id);
CREATE INDEX IF NOT EXISTS idx_emails_folder ON emails(user_id, folder);
CREATE INDEX IF NOT EXISTS idx_emails_received ON emails(user_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_emails_unread ON emails(user_id, is_read) WHERE is_read = false;

-- RLS Policies
ALTER TABLE email_aliases ENABLE ROW LEVEL SECURITY;
ALTER TABLE emails ENABLE ROW LEVEL SECURITY;

-- Aliases: users can only see/manage their own
CREATE POLICY "Users can view own aliases"
    ON email_aliases FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create own aliases"
    ON email_aliases FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own aliases"
    ON email_aliases FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own aliases"
    ON email_aliases FOR DELETE
    USING (auth.uid() = user_id);

-- Emails: users can only see/manage their own
CREATE POLICY "Users can view own emails"
    ON emails FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update own emails"
    ON emails FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own emails"
    ON emails FOR DELETE
    USING (auth.uid() = user_id);

-- Service role can insert emails (from inbound webhook)
CREATE POLICY "Service can insert emails"
    ON emails FOR INSERT
    WITH CHECK (true);

-- Service role can insert/update aliases counter
CREATE POLICY "Service can update alias counters"
    ON email_aliases FOR UPDATE
    USING (true);

-- Trigger to auto-set user_id on alias insert
CREATE OR REPLACE FUNCTION set_alias_user_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.user_id IS NULL THEN
        NEW.user_id := auth.uid();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_set_alias_user_id
    BEFORE INSERT ON email_aliases
    FOR EACH ROW
    EXECUTE FUNCTION set_alias_user_id();

-- Function to increment email counter on alias
CREATE OR REPLACE FUNCTION increment_alias_email_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE email_aliases
    SET emails_received = emails_received + 1,
        updated_at = now()
    WHERE id = NEW.alias_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_increment_alias_count
    AFTER INSERT ON emails
    FOR EACH ROW
    EXECUTE FUNCTION increment_alias_email_count();
