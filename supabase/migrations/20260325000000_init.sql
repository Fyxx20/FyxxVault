-- FyxxVault Supabase Database Schema
-- Run this in the Supabase SQL Editor to set up your database

-- Profiles table: stores wrapped VEK (encrypted vault encryption key)
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    wrapped_vek TEXT NOT NULL,
    vek_salt TEXT NOT NULL,
    vek_rounds INTEGER NOT NULL DEFAULT 210000,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vault items: individually encrypted entries
CREATE TABLE vault_items (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    encrypted_blob TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_vault_items_user ON vault_items(user_id);
CREATE INDEX idx_vault_items_updated ON vault_items(user_id, updated_at);

-- Sync metadata per device
CREATE TABLE sync_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    last_sync_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, device_id)
);

-- Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users own their profile" ON profiles
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "Users own their vault items" ON vault_items
    FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users own their sync metadata" ON sync_metadata
    FOR ALL USING (auth.uid() = user_id);

-- Auto-set user_id on insert for vault_items
CREATE OR REPLACE FUNCTION set_user_id()
RETURNS TRIGGER AS $$
BEGIN
    NEW.user_id = auth.uid();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER set_vault_items_user_id
    BEFORE INSERT ON vault_items
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id();

CREATE TRIGGER set_sync_metadata_user_id
    BEFORE INSERT ON sync_metadata
    FOR EACH ROW
    EXECUTE FUNCTION set_user_id();
