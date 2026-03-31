import { supabase } from '$lib/supabase';
import { encryptEntry, decryptEntry } from '$lib/crypto';
import { getVEK, getAuthState } from './auth.svelte';
import type { VaultEntry } from '$lib/types';

// ─── Reactive state ───
let _entries: VaultEntry[] = $state([]);
let _loading = $state(false);
let _searchQuery = $state('');
let _activeFilter = $state<string>('all');
let _selectedEntryId = $state<string | null>(null);
const FREE_VAULT_LIMIT = 5;

// ─── Public accessor ───
export function getVaultState() {
	const filtered = $derived.by(() => {
		let result = _entries;

		// Filter by category/favorites
		if (_activeFilter === 'favorites') {
			result = result.filter((e) => e.isFavorite);
		} else if (_activeFilter !== 'all') {
			result = result.filter((e) => e.category === _activeFilter);
		}

		// Filter by search query
		if (_searchQuery.trim()) {
			const q = _searchQuery.toLowerCase().trim();
			result = result.filter(
				(e) =>
					e.title.toLowerCase().includes(q) ||
					e.username.toLowerCase().includes(q) ||
					e.website.toLowerCase().includes(q) ||
					e.notes.toLowerCase().includes(q) ||
					e.tags.some((t) => t.toLowerCase().includes(q))
			);
		}

		return result;
	});

	return {
		get entries() { return _entries; },
		get filteredEntries() { return filtered; },
		get loading() { return _loading; },
		get searchQuery() { return _searchQuery; },
		set searchQuery(q: string) { _searchQuery = q; },
		get activeFilter() { return _activeFilter; },
		set activeFilter(f: string) { _activeFilter = f; },
		get selectedEntryId() { return _selectedEntryId; },
		set selectedEntryId(id: string | null) { _selectedEntryId = id; },
		get selectedEntry() { return _entries.find((e) => e.id === _selectedEntryId) ?? null; }
	};
}

// ─── Load all entries ───
export async function loadEntries(): Promise<void> {
	const vek = getVEK();
	const auth = getAuthState();
	if (!vek || !auth.user) return;

	_loading = true;

	try {
		const { data, error } = await supabase
			.from('vault_items')
			.select('id, user_id, encrypted_blob, updated_at, deleted_at')
			.eq('user_id', auth.user.id)
			.is('deleted_at', null)
			.order('updated_at', { ascending: false });

		if (error) {
			console.error('Failed to load vault items:', error);
			_loading = false;
			return;
		}

		const decrypted: VaultEntry[] = [];
		for (const row of data ?? []) {
			try {
				const blob = decodeSupabaseBytes(row.encrypted_blob);
				const entry = await decryptEntry(blob, vek);
				// Ensure the entry ID matches the DB row ID
				entry.id = row.id;
				decrypted.push(entry);
			} catch (e) {
				console.error(`Failed to decrypt entry ${row.id}:`, e);
			}
		}

		_entries = decrypted;
	} catch (e) {
		console.error('Failed to load entries:', e);
	} finally {
		_loading = false;
	}
}

// ─── Add entry ───
// skipLimit: true for imports (CSV migration), false for manual creation
export async function addEntry(entry: VaultEntry, { skipLimit = false } = {}): Promise<{ success: boolean; error?: string }> {
	const vek = getVEK();
	const auth = getAuthState();
	if (!vek || !auth.user) return { success: false, error: 'Coffre non déverrouillé.' };

	try {
		// Enforce free plan limit (skip for imports)
		if (!skipLimit && !auth.isPro) {
			if (_entries.length >= FREE_VAULT_LIMIT) {
				return { success: false, error: `Plan gratuit limite a ${FREE_VAULT_LIMIT} elements. Passe a Pro pour illimite.` };
			}

			const { count: serverCount, error: countError } = await supabase
				.from('vault_items')
				.select('id', { count: 'exact', head: true })
				.eq('user_id', auth.user.id)
				.is('deleted_at', null);

			if (!countError && (serverCount || 0) >= FREE_VAULT_LIMIT) {
				return { success: false, error: `Plan gratuit limite a ${FREE_VAULT_LIMIT} elements. Passe a Pro pour illimite.` };
			}
		}

		const blob = await encryptEntry(entry, vek);

		const { error } = await supabase.from('vault_items').insert({
			id: entry.id,
			user_id: auth.user.id,
			encrypted_blob: encodeToSupabaseBytes(blob),
			updated_at: new Date().toISOString()
		});

		if (error) return { success: false, error: error.message };

		_entries = [entry, ..._entries];
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de l\'ajout.' };
	}
}

// ─── Update entry ───
export async function updateEntry(entry: VaultEntry): Promise<{ success: boolean; error?: string }> {
	const vek = getVEK();
	const auth = getAuthState();
	if (!vek || !auth.user) return { success: false, error: 'Coffre non déverrouillé.' };

	try {
		entry.lastModifiedAt = new Date().toISOString();
		const blob = await encryptEntry(entry, vek);

		const { error } = await supabase
			.from('vault_items')
			.update({
				encrypted_blob: encodeToSupabaseBytes(blob),
				updated_at: new Date().toISOString()
			})
			.eq('id', entry.id)
			.eq('user_id', auth.user.id);

		if (error) return { success: false, error: error.message };

		_entries = _entries.map((e) => (e.id === entry.id ? entry : e));
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la mise à jour.' };
	}
}

// ─── Delete entry (soft delete) ───
export async function deleteEntry(id: string): Promise<{ success: boolean; error?: string }> {
	const auth = getAuthState();
	if (!auth.user) return { success: false, error: 'Non authentifié.' };

	try {
		const { error } = await supabase
			.from('vault_items')
			.update({ deleted_at: new Date().toISOString() })
			.eq('id', id)
			.eq('user_id', auth.user.id);

		if (error) return { success: false, error: error.message };

		_entries = _entries.filter((e) => e.id !== id);
		if (_selectedEntryId === id) _selectedEntryId = null;
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la suppression.' };
	}
}

// ─── Toggle favorite ───
export async function toggleFavorite(id: string): Promise<void> {
	const entry = _entries.find((e) => e.id === id);
	if (!entry) return;
	const updated = { ...entry, isFavorite: !entry.isFavorite };
	await updateEntry(updated);
}

// ─── Export vault as CSV ───
export function exportCSV(): string {
	const headers = ['Title', 'Username', 'Password', 'Website', 'Category', 'Notes', 'Tags'];
	const rows = _entries.map((e) => [
		e.title,
		e.username,
		e.password,
		e.website,
		e.category,
		e.notes.replace(/\n/g, ' '),
		e.tags.join('; ')
	]);

	const csvContent = [
		headers.join(','),
		...rows.map((row) => row.map((cell) => `"${cell.replace(/"/g, '""')}"`).join(','))
	].join('\n');

	return csvContent;
}

// ─── Security stats ───
export function getSecurityStats() {
	const entries = _entries;
	const passwords = entries.map((e) => e.password).filter(Boolean);
	const uniquePasswords = new Set(passwords);

	const weak = passwords.filter((p) => p.length < 12 || /^[a-z]+$/i.test(p)).length;
	const reused = passwords.length - uniquePasswords.size;
	const noMfa = entries.filter((e) => e.category === 'login' && !e.mfaEnabled).length;

	// Entries not modified in 6+ months
	const sixMonthsAgo = new Date();
	sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
	const expired = entries.filter((e) => new Date(e.lastModifiedAt) < sixMonthsAgo).length;

	const total = entries.length || 1;
	const score = Math.max(0, Math.round(100 - (weak / total) * 30 - (reused / total) * 30 - (noMfa / total) * 20 - (expired / total) * 20));

	return { weak, reused, noMfa, expired, score, total: entries.length };
}

// ─── Reset state ───
export function resetVault() {
	_entries = [];
	_loading = false;
	_searchQuery = '';
	_activeFilter = 'all';
	_selectedEntryId = null;
}

// ─── Supabase BYTEA helpers ───
function decodeSupabaseBytes(value: any): Uint8Array {
	if (value instanceof Uint8Array) return value;
	if (value instanceof ArrayBuffer) return new Uint8Array(value);

	if (typeof value === 'string') {
		let hex = value;
		if (hex.startsWith('\\x')) hex = hex.slice(2);
		if (hex.startsWith('0x')) hex = hex.slice(2);

		const bytes = new Uint8Array(hex.length / 2);
		for (let i = 0; i < hex.length; i += 2) {
			bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
		}
		return bytes;
	}

	throw new Error('Unexpected BYTEA format');
}

function encodeToSupabaseBytes(bytes: Uint8Array): string {
	const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
	return '\\x' + hex;
}
