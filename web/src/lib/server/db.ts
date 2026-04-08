import Database from 'better-sqlite3';
import path from 'path';
import os from 'os';
import fs from 'fs';

// ─── Types ───

interface User {
	id: string;
	email: string;
	password_hash: string;
	created_at: string;
}

interface Profile {
	user_id: string;
	encrypted_vek: string;
	vek_salt: string;
	vek_iv: string;
	master_hint?: string;
	is_pro: number;
	created_at: string;
}

interface VaultItem {
	id: string;
	user_id: string;
	encrypted_data: string;
	data_iv: string;
	category: string;
	favorite: number;
	created_at: string;
	updated_at: string;
}

// ─── Init ───

const DATA_DIR = process.env.FYXXVAULT_DATA_DIR || path.join(os.homedir(), '.fyxxvault', 'data');
const DB_PATH = path.join(DATA_DIR, 'fyxxvault.db');

if (!fs.existsSync(DATA_DIR)) {
	fs.mkdirSync(DATA_DIR, { recursive: true });
}

const database = new Database(DB_PATH);
database.pragma('journal_mode = WAL');
database.pragma('foreign_keys = ON');

try {
	fs.chmodSync(DB_PATH, 0o600);
} catch {
	// ignore if chmod fails (e.g. Windows)
}

// ─── Schema ───

database.exec(`
	CREATE TABLE IF NOT EXISTS users (
		id TEXT PRIMARY KEY,
		email TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS profiles (
		user_id TEXT PRIMARY KEY REFERENCES users(id),
		encrypted_vek TEXT NOT NULL,
		vek_salt TEXT NOT NULL,
		vek_iv TEXT NOT NULL,
		master_hint TEXT DEFAULT '',
		is_pro INTEGER DEFAULT 1,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS vault_items (
		id TEXT PRIMARY KEY,
		user_id TEXT NOT NULL REFERENCES users(id),
		encrypted_data TEXT NOT NULL,
		data_iv TEXT NOT NULL,
		category TEXT DEFAULT 'login',
		favorite INTEGER DEFAULT 0,
		created_at TEXT DEFAULT CURRENT_TIMESTAMP,
		updated_at TEXT DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_vault_items_user_id ON vault_items(user_id);
`);

// ─── Prepared Statements ───

const stmts = {
	getUser: database.prepare('SELECT * FROM users WHERE email = ?'),
	getUserById: database.prepare('SELECT * FROM users WHERE id = ?'),
	createUser: database.prepare('INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)'),
	getProfile: database.prepare('SELECT * FROM profiles WHERE user_id = ?'),
	createProfile: database.prepare(
		'INSERT INTO profiles (user_id, encrypted_vek, vek_salt, vek_iv, master_hint, is_pro) VALUES (?, ?, ?, ?, ?, ?)'
	),
	getVaultItems: database.prepare(
		'SELECT * FROM vault_items WHERE user_id = ? ORDER BY updated_at DESC'
	),
	createVaultItem: database.prepare(
		'INSERT INTO vault_items (id, user_id, encrypted_data, data_iv, category, favorite, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
	),
	deleteVaultItem: database.prepare(
		'DELETE FROM vault_items WHERE id = ? AND user_id = ?'
	),
	countUsers: database.prepare('SELECT COUNT(*) AS count FROM users'),
	countItems: database.prepare('SELECT COUNT(*) AS count FROM vault_items'),
	dbSize: database.prepare(
		'SELECT page_count * page_size AS size FROM pragma_page_count(), pragma_page_size()'
	),
	integrityCheck: database.prepare('PRAGMA integrity_check'),
};

// ─── Helpers ───

function buildUpdate(table: string, fields: Record<string, unknown>, whereClause: string, whereParams: unknown[]): void {
	const keys = Object.keys(fields).filter((k) => fields[k] !== undefined);
	if (keys.length === 0) return;
	const sets = keys.map((k) => `${k} = ?`).join(', ');
	const values = keys.map((k) => fields[k]);
	database.prepare(`UPDATE ${table} SET ${sets} WHERE ${whereClause}`).run(...values, ...whereParams);
}

// ─── Exported DB Object ───

export const db = {
	getUser(email: string): User | undefined {
		return stmts.getUser.get(email) as User | undefined;
	},

	getUserById(id: string): User | undefined {
		return stmts.getUserById.get(id) as User | undefined;
	},

	createUser(id: string, email: string, passwordHash: string): void {
		stmts.createUser.run(id, email, passwordHash);
	},

	getProfile(userId: string): Profile | undefined {
		return stmts.getProfile.get(userId) as Profile | undefined;
	},

	createProfile(profile: Profile): void {
		stmts.createProfile.run(
			profile.user_id,
			profile.encrypted_vek,
			profile.vek_salt,
			profile.vek_iv,
			profile.master_hint ?? '',
			profile.is_pro ?? 1
		);
	},

	updateProfile(userId: string, fields: Partial<Profile>): void {
		buildUpdate('profiles', fields as Record<string, unknown>, 'user_id = ?', [userId]);
	},

	getVaultItems(userId: string): VaultItem[] {
		return stmts.getVaultItems.all(userId) as VaultItem[];
	},

	createVaultItem(item: VaultItem): void {
		stmts.createVaultItem.run(
			item.id,
			item.user_id,
			item.encrypted_data,
			item.data_iv,
			item.category ?? 'login',
			item.favorite ?? 0,
			item.created_at,
			item.updated_at
		);
	},

	updateVaultItem(id: string, userId: string, fields: Partial<VaultItem>): void {
		buildUpdate('vault_items', fields as Record<string, unknown>, 'id = ? AND user_id = ?', [id, userId]);
	},

	deleteVaultItem(id: string, userId: string): void {
		stmts.deleteVaultItem.run(id, userId);
	},

	getStats(): { users: number; items: number; dbSize: number } {
		const users = (stmts.countUsers.get() as { count: number }).count;
		const items = (stmts.countItems.get() as { count: number }).count;
		const dbSize = (stmts.dbSize.get() as { size: number }).size;
		return { users, items, dbSize };
	},

	integrityCheck(): string {
		const result = stmts.integrityCheck.get() as { integrity_check: string };
		return result.integrity_check;
	},

	close(): void {
		database.close();
	},
};
