import { encryptEntry, decryptEntry, hexToBytes, bytesToHex } from '$lib/crypto';
import { getVEK, getAuthState } from './auth.svelte';
import type { VaultEntry } from '$lib/types';

// ─── Reactive state ───
let _entries: VaultEntry[] = $state([]);
let _loading = $state(false);
let _searchQuery = $state('');
let _activeFilter = $state<string>('all');
let _selectedEntryId = $state<string | null>(null);

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
		const res = await fetch('/api/vault');
		if (!res.ok) {
			console.error('Failed to load vault items');
			_loading = false;
			return;
		}

		const data = await res.json();

		const decrypted: VaultEntry[] = [];
		for (const row of data ?? []) {
			try {
				const blob = hexToBytes(row.encrypted_blob);
				const entry = await decryptEntry(blob, vek);
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
export async function addEntry(entry: VaultEntry): Promise<{ success: boolean; error?: string; needsPro?: boolean }> {
	const vek = getVEK();
	const auth = getAuthState();
	if (!vek || !auth.user) return { success: false, error: 'Coffre non deverrouille.' };

	try {
		const blob = await encryptEntry(entry, vek);

		const res = await fetch('/api/vault', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				id: entry.id,
				encrypted_blob: bytesToHex(blob)
			})
		});

		if (!res.ok) return { success: false, error: 'Erreur lors de l\'ajout.' };

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
	if (!vek || !auth.user) return { success: false, error: 'Coffre non deverrouille.' };

	try {
		entry.lastModifiedAt = new Date().toISOString();
		const blob = await encryptEntry(entry, vek);

		const res = await fetch('/api/vault', {
			method: 'PATCH',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				id: entry.id,
				encrypted_blob: bytesToHex(blob)
			})
		});

		if (!res.ok) return { success: false, error: 'Erreur lors de la mise a jour.' };

		_entries = _entries.map((e) => (e.id === entry.id ? entry : e));
		return { success: true };
	} catch (e: any) {
		return { success: false, error: e.message || 'Erreur lors de la mise a jour.' };
	}
}

// ─── Delete entry (soft delete) ───
export async function deleteEntry(id: string): Promise<{ success: boolean; error?: string }> {
	const auth = getAuthState();
	if (!auth.user) return { success: false, error: 'Non authentifie.' };

	try {
		const res = await fetch('/api/vault', {
			method: 'DELETE',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ id })
		});

		if (!res.ok) return { success: false, error: 'Erreur lors de la suppression.' };

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
