<script lang="ts">
	import { goto } from '$app/navigation';
	import { newVaultEntry, type VaultEntry, type VaultCategory, CATEGORY_META } from '$lib/types';
	import { addEntry, getVaultState } from '$lib/stores/vault.svelte';
	import { t } from '$lib/i18n.svelte';

	const vault = getVaultState();

	let dragActive = $state(false);
	let file = $state<File | null>(null);
	let format = $state<'auto' | 'bitwarden' | '1password' | 'generic'>('auto');
	let detectedFormat = $state('');
	let parsedEntries = $state<VaultEntry[]>([]);
	let parseError = $state('');
	let duplicateHandling = $state<'skip' | 'overwrite' | 'keep'>('skip');
	let importing = $state(false);
	let importResult = $state<{ imported: number; skipped: number; errors: number } | null>(null);
	let selectedEntries = $state<Set<string>>(new Set());

	function handleDragOver(e: DragEvent) {
		e.preventDefault();
		dragActive = true;
	}

	function handleDragLeave() {
		dragActive = false;
	}

	function handleDrop(e: DragEvent) {
		e.preventDefault();
		dragActive = false;
		const files = e.dataTransfer?.files;
		if (files && files.length > 0) {
			handleFile(files[0]);
		}
	}

	function handleFileInput(e: Event) {
		const input = e.target as HTMLInputElement;
		if (input.files && input.files.length > 0) {
			handleFile(input.files[0]);
		}
	}

	function handleFile(f: File) {
		if (!f.name.endsWith('.csv') && !f.name.endsWith('.json')) {
			parseError = t('import.error.format');
			return;
		}
		file = f;
		parseError = '';
		importResult = null;

		const reader = new FileReader();
		reader.onload = (e) => {
			const content = e.target?.result as string;
			try {
				parseCSV(content);
			} catch (err: any) {
				parseError = err.message || t('import.error.format');
			}
		};
		reader.readAsText(f);
	}

	function parseCSV(content: string) {
		const lines = content.split('\n').filter(l => l.trim());
		if (lines.length < 2) {
			parseError = t('import.error.empty');
			return;
		}

		const header = parseCSVLine(lines[0]).map(h => h.toLowerCase().trim());

		// Detect format
		const detected = detectFormat(header);
		detectedFormat = detected;

		const entries: VaultEntry[] = [];

		for (let i = 1; i < lines.length; i++) {
			const values = parseCSVLine(lines[i]);
			if (values.length === 0 || values.every(v => !v.trim())) continue;

			const row: Record<string, string> = {};
			header.forEach((h, idx) => {
				row[h] = values[idx]?.trim() ?? '';
			});

			const entry = mapRowToEntry(row, detected);
			if (entry.title || entry.username || entry.password) {
				entries.push(entry);
			}
		}

		parsedEntries = entries;
		selectedEntries = new Set(entries.map(e => e.id));
	}

	function detectFormat(header: string[]): string {
		const headerStr = header.join(',');

		if (headerStr.includes('folder') && headerStr.includes('favorite') && headerStr.includes('type') && headerStr.includes('login_uri')) {
			return 'bitwarden';
		}
		if (headerStr.includes('title') && headerStr.includes('agilebits')) {
			return '1password';
		}
		if (headerStr.includes('title') && headerStr.includes('url') && headerStr.includes('username')) {
			return '1password';
		}
		return 'generic';
	}

	function mapRowToEntry(row: Record<string, string>, fmt: string): VaultEntry {
		if (fmt === 'bitwarden') {
			return newVaultEntry({
				title: row['name'] || row['title'] || '',
				username: row['login_username'] || row['username'] || '',
				password: row['login_password'] || row['password'] || '',
				website: row['login_uri'] || row['url'] || '',
				notes: row['notes'] || '',
				folder: row['folder'] || '',
				category: mapBitwardenType(row['type'] || ''),
				isFavorite: row['favorite'] === '1',
				tags: row['tags'] ? row['tags'].split(',').map(s => s.trim()) : []
			});
		} else if (fmt === '1password') {
			return newVaultEntry({
				title: row['title'] || row['name'] || '',
				username: row['username'] || row['login'] || '',
				password: row['password'] || '',
				website: row['url'] || row['website'] || '',
				notes: row['notes'] || row['notesplain'] || '',
				category: 'login'
			});
		} else {
			// Generic CSV
			return newVaultEntry({
				title: row['title'] || row['name'] || row['site'] || '',
				username: row['username'] || row['login'] || row['email'] || row['user'] || '',
				password: row['password'] || row['pass'] || row['pwd'] || '',
				website: row['url'] || row['website'] || row['site'] || row['uri'] || '',
				notes: row['notes'] || row['note'] || row['comments'] || '',
				category: (row['category'] || row['type'] || 'login') as VaultCategory,
				folder: row['folder'] || row['group'] || ''
			});
		}
	}

	function mapBitwardenType(type: string): VaultCategory {
		switch (type.toLowerCase()) {
			case '1': case 'login': return 'login';
			case '2': case 'note': case 'securenote': return 'secureNote';
			case '3': case 'card': return 'creditCard';
			case '4': case 'identity': return 'identity';
			default: return 'login';
		}
	}

	function parseCSVLine(line: string): string[] {
		const result: string[] = [];
		let current = '';
		let inQuotes = false;

		for (let i = 0; i < line.length; i++) {
			const char = line[i];
			if (inQuotes) {
				if (char === '"' && line[i + 1] === '"') {
					current += '"';
					i++;
				} else if (char === '"') {
					inQuotes = false;
				} else {
					current += char;
				}
			} else {
				if (char === '"') {
					inQuotes = true;
				} else if (char === ',') {
					result.push(current);
					current = '';
				} else {
					current += char;
				}
			}
		}
		result.push(current);
		return result;
	}

	function toggleEntry(id: string) {
		const next = new Set(selectedEntries);
		if (next.has(id)) {
			next.delete(id);
		} else {
			next.add(id);
		}
		selectedEntries = next;
	}

	function toggleAll() {
		if (selectedEntries.size === parsedEntries.length) {
			selectedEntries = new Set();
		} else {
			selectedEntries = new Set(parsedEntries.map(e => e.id));
		}
	}

	async function handleImport() {
		importing = true;
		let imported = 0;
		let skipped = 0;
		let errors = 0;

		const existingTitles = new Set(vault.entries.map(e => `${e.title}:${e.username}`));

		for (const entry of parsedEntries) {
			if (!selectedEntries.has(entry.id)) {
				skipped++;
				continue;
			}

			const key = `${entry.title}:${entry.username}`;
			if (existingTitles.has(key)) {
				if (duplicateHandling === 'skip') {
					skipped++;
					continue;
				} else if (duplicateHandling === 'keep') {
					// Keep both, proceed
				}
				// 'overwrite' - we just add it (existing stays, could improve later)
			}

			try {
				const result = await addEntry(entry);
				if (result.success) {
					imported++;
				} else {
					errors++;
				}
			} catch {
				errors++;
			}
		}

		importResult = { imported, skipped, errors };
		importing = false;
	}
</script>

<svelte:head>
	<title>{t('import.title')} — FyxxVault</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
	<!-- Header -->
	<div class="flex items-center gap-4 mb-6">
		<button onclick={() => goto('/vault')} class="p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)]">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<line x1="19" y1="12" x2="5" y2="12"/>
				<polyline points="12 19 5 12 12 5"/>
			</svg>
		</button>
		<div>
			<h1 class="text-xl font-bold text-white">{t('import.title')}</h1>
			<p class="text-xs text-[var(--fv-smoke)]">{t('import.subtitle')}</p>
		</div>
	</div>

	{#if importResult}
		<!-- Import result -->
		<div class="fv-glass p-8 text-center fv-glow-cyan">
			<div class="w-16 h-16 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
				<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
			</div>
			<p class="text-white font-semibold mb-2">{t('import.complete')}</p>
			<div class="flex justify-center gap-6 text-xs">
				<span class="text-[var(--fv-success)]">{importResult.imported} {t('import.imported')}{importResult.imported > 1 ? 's' : ''}</span>
				{#if importResult.skipped > 0}
					<span class="text-[var(--fv-smoke)]">{importResult.skipped} {t('import.skipped')}{importResult.skipped > 1 ? 's' : ''}</span>
				{/if}
				{#if importResult.errors > 0}
					<span class="text-[var(--fv-danger)]">{importResult.errors} {t('import.error')}{importResult.errors > 1 ? 's' : ''}</span>
				{/if}
			</div>
			<button onclick={() => goto('/vault')} class="fv-btn fv-btn-primary text-sm !py-2.5 mt-6">{t('import.back_to_vault')}</button>
		</div>
	{:else if parsedEntries.length > 0}
		<!-- Preview -->
		<div class="fv-glass p-5 mb-4">
			<div class="flex items-center justify-between mb-4">
				<div>
					<h2 class="text-sm font-bold text-white">{t('import.preview')}</h2>
					<p class="text-[10px] text-[var(--fv-smoke)]">{detectedFormat === 'bitwarden' ? t('import.format_bitwarden') : detectedFormat === '1password' ? t('import.format_1password') : t('import.format_csv')} — {parsedEntries.length} {parsedEntries.length > 1 ? t('import.items') : t('import.item')}</p>
				</div>
				<label class="flex items-center gap-2 text-xs text-[var(--fv-smoke)] cursor-pointer">
					<input type="checkbox" checked={selectedEntries.size === parsedEntries.length} onchange={toggleAll} class="accent-[var(--fv-cyan)]" />
					{t('import.select_all')}
				</label>
			</div>

			<div class="space-y-1.5 max-h-[400px] overflow-y-auto">
				{#each parsedEntries as entry (entry.id)}
					<label class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/10 transition-colors cursor-pointer">
						<input
							type="checkbox"
							checked={selectedEntries.has(entry.id)}
							onchange={() => toggleEntry(entry.id)}
							class="accent-[var(--fv-cyan)]"
						/>
						<span class="text-base shrink-0">{CATEGORY_META[entry.category]?.icon ?? '📦'}</span>
						<div class="flex-1 min-w-0">
							<p class="text-sm text-white truncate">{entry.title || t('import.untitled')}</p>
							<p class="text-[10px] text-[var(--fv-smoke)] truncate">{entry.username || entry.website || ''}</p>
						</div>
						<span class="text-[9px] text-[var(--fv-ash)] shrink-0">{CATEGORY_META[entry.category]?.label}</span>
					</label>
				{/each}
			</div>
		</div>

		<!-- Options -->
		<div class="fv-glass p-5 mb-4">
			<h2 class="text-sm font-bold text-white mb-3">{t('import.duplicates')}</h2>
			<div class="flex gap-2">
				{#each [
					{ key: 'skip', label: t('import.skip') },
					{ key: 'overwrite', label: t('import.overwrite') },
					{ key: 'keep', label: t('import.keep_both') }
				] as option}
					<button
						type="button"
						onclick={() => duplicateHandling = option.key as any}
						class="flex-1 py-2.5 rounded-xl text-xs font-medium transition-all border
							{duplicateHandling === option.key
								? 'bg-[var(--fv-cyan)]/10 border-[var(--fv-cyan)]/30 text-[var(--fv-cyan)]'
								: 'bg-white/5 border-white/10 text-[var(--fv-smoke)] hover:bg-white/10'}"
					>
						{option.label}
					</button>
				{/each}
			</div>
		</div>

		<!-- Import button -->
		<div class="flex gap-3">
			<button onclick={() => { parsedEntries = []; file = null; }} class="fv-btn fv-btn-ghost flex-1 !py-3.5">{t('add.cancel')}</button>
			<button
				onclick={handleImport}
				disabled={importing || selectedEntries.size === 0}
				class="fv-btn fv-btn-primary flex-1 !py-3.5 {importing || selectedEntries.size === 0 ? 'opacity-60 cursor-not-allowed' : ''}"
			>
				{#if importing}
					<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
					{t('import.importing')}
				{:else}
					{t('import.import')} {selectedEntries.size} {selectedEntries.size > 1 ? t('import.items') : t('import.item')}
				{/if}
			</button>
		</div>
	{:else}
		<!-- File upload zone -->
		<div
			role="button"
			tabindex="0"
			class="fv-glass p-12 text-center border-2 border-dashed transition-all cursor-pointer
				{dragActive ? 'border-[var(--fv-cyan)] bg-[var(--fv-cyan)]/5' : 'border-white/10 hover:border-white/20'}"
			ondragover={handleDragOver}
			ondragleave={handleDragLeave}
			ondrop={handleDrop}
			onclick={() => document.getElementById('file-input')?.click()}
			onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') document.getElementById('file-input')?.click(); }}
		>
			<input id="file-input" type="file" accept=".csv,.json" onchange={handleFileInput} class="hidden" />

			<div class="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-4">
				<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="{dragActive ? 'var(--fv-cyan)' : 'var(--fv-ash)'}" stroke-width="1.5">
					<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
					<polyline points="17 8 12 3 7 8"/>
					<line x1="12" y1="3" x2="12" y2="15"/>
				</svg>
			</div>
			<p class="text-sm text-white mb-2">{t('import.drag')}</p>
			<p class="text-xs text-[var(--fv-smoke)] mb-4">{t('import.or_click')}</p>

			<div class="flex justify-center gap-4 text-[10px] text-[var(--fv-ash)]">
				<span>{t('import.format_bitwarden')} CSV</span>
				<span>{t('import.format_1password')} CSV</span>
				<span>{t('import.format_csv')}</span>
			</div>
		</div>

		{#if parseError}
			<div class="mt-4 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
				<p class="text-sm text-[var(--fv-danger)]">{parseError}</p>
			</div>
		{/if}

		<!-- Format info -->
		<div class="fv-glass p-5 mt-4">
			<h2 class="text-sm font-bold text-white mb-3">{t('import.supported_formats')}</h2>
			<div class="space-y-3">
				<div class="flex items-start gap-3">
					<span class="text-base">🔒</span>
					<div>
						<p class="text-xs text-white font-medium">{t('import.format_bitwarden')}</p>
						<p class="text-[10px] text-[var(--fv-smoke)]">{t('import.bitwarden_path')}</p>
					</div>
				</div>
				<div class="flex items-start gap-3">
					<span class="text-base">🔐</span>
					<div>
						<p class="text-xs text-white font-medium">{t('import.format_1password')}</p>
						<p class="text-[10px] text-[var(--fv-smoke)]">{t('import.1password_path')}</p>
					</div>
				</div>
				<div class="flex items-start gap-3">
					<span class="text-base">📄</span>
					<div>
						<p class="text-xs text-white font-medium">{t('import.format_csv')}</p>
						<p class="text-[10px] text-[var(--fv-smoke)]">{t('import.csv_format')}</p>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>
