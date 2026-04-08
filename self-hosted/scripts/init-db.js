#!/usr/bin/env node
import Database from 'better-sqlite3';
import path from 'path';
import os from 'os';
import fs from 'fs';

const DATA_DIR = process.env.FYXXVAULT_DATA_DIR || path.join(os.homedir(), '.fyxxvault', 'data');
fs.mkdirSync(DATA_DIR, { recursive: true });

const db = new Database(path.join(DATA_DIR, 'fyxxvault.db'));
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS profiles (
    user_id TEXT PRIMARY KEY REFERENCES users(id),
    encrypted_vek TEXT NOT NULL,
    vek_salt TEXT NOT NULL,
    vek_iv TEXT NOT NULL,
    master_hint TEXT DEFAULT '',
    is_pro INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS vault_items (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id),
    encrypted_data TEXT NOT NULL,
    data_iv TEXT NOT NULL,
    category TEXT DEFAULT 'login',
    favorite INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  );
  CREATE INDEX IF NOT EXISTS idx_vault_user ON vault_items(user_id);
  CREATE TABLE IF NOT EXISTS sync_metadata (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
  );
  CREATE TABLE IF NOT EXISTS platform_settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TEXT DEFAULT (datetime('now'))
  );
`);

// Set file permissions
fs.chmodSync(path.join(DATA_DIR, 'fyxxvault.db'), 0o600);

console.log('✅ Database initialized at', path.join(DATA_DIR, 'fyxxvault.db'));
db.close();
