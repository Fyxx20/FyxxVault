<script lang="ts">
	import { goto } from '$app/navigation';
	import { getVaultState, loadEntries, toggleFavorite, deleteEntry } from '$lib/stores/vault.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { CATEGORY_META, type VaultEntry, type VaultCategory } from '$lib/types';
	import { passwordStrength } from '$lib/crypto';

	const vault = getVaultState();
	const auth = getAuthState();

	let showPassword = $state<Record<string, boolean>>({});
	let copiedField = $state<string | null>(null);
	let showDetail = $state(false);
	let editingEntry = $state<VaultEntry | null>(null);
	let showDeleteConfirm = $state<string | null>(null);

	// Load entries on mount
	$effect(() => {
		if (auth.isUnlocked && vault.entries.length === 0 && !vault.loading) {
			loadEntries();
		}
	});

	const filters = [
		{ key: 'all', label: 'Tous' },
		{ key: 'favorites', label: 'Favoris' },
		{ key: 'login', label: 'Login' },
		{ key: 'creditCard', label: 'Cartes' },
		{ key: 'identity', label: 'Identité' },
		{ key: 'secureNote', label: 'Notes' },
		{ key: 'bankAccount', label: 'Banque' },
		{ key: 'wifi', label: 'Wi-Fi' },
		{ key: 'server', label: 'Serveur' },
		{ key: 'other', label: 'Autre' }
	];

	function selectEntry(entry: VaultEntry) {
		vault.selectedEntryId = entry.id;
		showDetail = true;
	}

	function closeDetail() {
		showDetail = false;
		vault.selectedEntryId = null;
	}

	async function copyToClipboard(text: string, fieldId: string) {
		try {
			await navigator.clipboard.writeText(text);
			copiedField = fieldId;
			setTimeout(() => { copiedField = null; }, 2000);
		} catch (e) {
			console.error('Copy failed:', e);
		}
	}

	function togglePasswordVisibility(id: string) {
		showPassword[id] = !showPassword[id];
	}

	function getStrengthDot(password: string): { color: string } {
		const s = passwordStrength(password);
		return { color: s.color };
	}

	function formatDate(dateStr: string): string {
		try {
			return new Date(dateStr).toLocaleDateString('fr-FR', {
				day: '2-digit', month: 'short', year: 'numeric'
			});
		} catch {
			return dateStr;
		}
	}

	async function handleDelete(id: string) {
		await deleteEntry(id);
		showDeleteConfirm = null;
		closeDetail();
	}

	function getDomain(url: string): string {
		if (!url) return '';
		try {
			const u = url.startsWith('http') ? url : `https://${url}`;
			return new URL(u).hostname;
		} catch {
			return url;
		}
	}
</script>

<svelte:head>
	<title>Coffre — FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
		<div>
			<h1 class="text-2xl font-bold text-white">Coffre-fort</h1>
			<p class="text-sm text-[var(--fv-smoke)]">{vault.entries.length} élément{vault.entries.length !== 1 ? 's' : ''}</p>
		</div>
		<a href="/vault/add" class="fv-btn fv-btn-primary !py-2.5 !px-5 text-sm inline-flex items-center gap-2 w-fit">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<line x1="12" y1="5" x2="12" y2="19"/>
				<line x1="5" y1="12" x2="19" y2="12"/>
			</svg>
			Ajouter
		</a>
	</div>

	<!-- Search bar -->
	<div class="relative mb-4">
		<svg class="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--fv-ash)]" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
			<circle cx="11" cy="11" r="8"/>
			<line x1="21" y1="21" x2="16.65" y2="16.65"/>
		</svg>
		<input
			type="text"
			placeholder="Rechercher par titre, identifiant, site..."
			bind:value={vault.searchQuery}
			class="w-full pl-12 pr-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
		/>
	</div>

	<!-- Filter chips -->
	<div class="flex flex-wrap gap-2 mb-6 overflow-x-auto pb-1">
		{#each filters as filter}
			<button
				onclick={() => vault.activeFilter = filter.key}
				class="px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all
					{vault.activeFilter === filter.key
						? 'bg-[var(--fv-cyan)]/15 text-[var(--fv-cyan)] border border-[var(--fv-cyan)]/30'
						: 'bg-white/5 text-[var(--fv-smoke)] border border-white/5 hover:bg-white/10 hover:text-white'}"
			>
				{#if filter.key !== 'all' && filter.key !== 'favorites' && CATEGORY_META[filter.key as VaultCategory]}
					<span class="mr-1">{CATEGORY_META[filter.key as VaultCategory].icon}</span>
				{/if}
				{#if filter.key === 'favorites'}
					<span class="mr-1">&#9733;</span>
				{/if}
				{filter.label}
			</button>
		{/each}
	</div>

	<!-- Content area -->
	<div class="flex gap-6">
		<!-- Entry list -->
		<div class="flex-1 min-w-0">
			{#if vault.loading}
				<div class="flex items-center justify-center py-20">
					<div class="w-8 h-8 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
				</div>
			{:else if vault.filteredEntries.length === 0}
				<div class="fv-glass p-12 text-center">
					<div class="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-4">
						<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="1.5">
							<rect x="3" y="11" width="18" height="11" rx="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
						</svg>
					</div>
					{#if vault.searchQuery}
						<p class="text-[var(--fv-smoke)] text-sm">Aucun résultat pour "{vault.searchQuery}"</p>
					{:else}
						<p class="text-[var(--fv-smoke)] text-sm mb-4">Ton coffre est vide</p>
						<a href="/vault/add" class="fv-btn fv-btn-primary text-sm !py-2.5 !px-5">Ajouter un premier élément</a>
					{/if}
				</div>
			{:else}
				<div class="space-y-2">
					{#each vault.filteredEntries as entry (entry.id)}
						<button
							onclick={() => selectEntry(entry)}
							class="w-full text-left fv-glass p-4 flex items-center gap-4 hover:border-[var(--fv-cyan)]/20 transition-all group
								{vault.selectedEntryId === entry.id ? 'border-[var(--fv-cyan)]/30 bg-[var(--fv-cyan)]/5' : ''}"
						>
							<!-- Category icon -->
							<div class="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
								style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
								{CATEGORY_META[entry.category]?.icon ?? '📦'}
							</div>

							<!-- Info -->
							<div class="flex-1 min-w-0">
								<div class="flex items-center gap-2">
									<p class="text-sm font-semibold text-white truncate">{entry.title || 'Sans titre'}</p>
									{#if entry.isFavorite}
										<span class="text-[var(--fv-gold)] text-xs">&#9733;</span>
									{/if}
								</div>
								<p class="text-xs text-[var(--fv-smoke)] truncate mt-0.5">
									{entry.username || entry.website || CATEGORY_META[entry.category]?.label || ''}
								</p>
							</div>

							<!-- Strength dot -->
							{#if entry.password}
								<div class="w-2.5 h-2.5 rounded-full shrink-0" style="background: {getStrengthDot(entry.password).color};"></div>
							{/if}

							<!-- Date -->
							<span class="text-[10px] text-[var(--fv-ash)] hidden sm:block shrink-0">{formatDate(entry.lastModifiedAt)}</span>
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Detail panel (desktop) -->
		{#if showDetail && vault.selectedEntry}
			{@const entry = vault.selectedEntry}
			<div class="hidden lg:block w-[380px] shrink-0">
				<div class="fv-glass p-6 sticky top-8">
					<!-- Header -->
					<div class="flex items-center justify-between mb-5">
						<div class="flex items-center gap-3">
							<div class="w-10 h-10 rounded-xl flex items-center justify-center text-lg"
								style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
								{CATEGORY_META[entry.category]?.icon ?? '📦'}
							</div>
							<div>
								<h2 class="text-base font-bold text-white">{entry.title || 'Sans titre'}</h2>
								<p class="text-xs text-[var(--fv-smoke)]">{CATEGORY_META[entry.category]?.label ?? ''}</p>
							</div>
						</div>
						<button onclick={closeDetail} class="p-1.5 rounded-lg hover:bg-white/5 text-[var(--fv-ash)]">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="18" y1="6" x2="6" y2="18"/>
								<line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>

					<!-- Fields -->
					<div class="space-y-4">
						{#if entry.username}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Identifiant</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									<span class="flex-1 text-sm text-white truncate">{entry.username}</span>
									<button
										onclick={() => copyToClipboard(entry.username, `user-${entry.id}`)}
										class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors"
										title="Copier"
									>
										{#if copiedField === `user-${entry.id}`}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
							</div>
						{/if}

						{#if entry.password}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Mot de passe</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									<span class="flex-1 text-sm text-white font-mono truncate">
										{showPassword[entry.id] ? entry.password : '•'.repeat(Math.min(entry.password.length, 20))}
									</span>
									<button
										onclick={() => togglePasswordVisibility(entry.id)}
										class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors"
										title="Afficher/Masquer"
									>
										{#if showPassword[entry.id]}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
										{:else}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
										{/if}
									</button>
									<button
										onclick={() => copyToClipboard(entry.password, `pass-${entry.id}`)}
										class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors"
										title="Copier"
									>
										{#if copiedField === `pass-${entry.id}`}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
								<!-- Strength bar -->
								{@const strength = passwordStrength(entry.password)}
								<div class="mt-2 flex items-center gap-2">
									<div class="flex-1 h-1 rounded-full bg-white/5 overflow-hidden">
										<div class="h-full rounded-full transition-all" style="width: {strength.score}%; background: {strength.color};"></div>
									</div>
									<span class="text-[10px] font-medium" style="color: {strength.color};">{strength.label}</span>
								</div>
							</div>
						{/if}

						{#if entry.website}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Site web</label>
								<a
									href={entry.website.startsWith('http') ? entry.website : `https://${entry.website}`}
									target="_blank"
									rel="noopener noreferrer"
									class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5 text-sm text-[var(--fv-cyan)] hover:text-white transition-colors"
								>
									{getDomain(entry.website)}
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
								</a>
							</div>
						{/if}

						{#if entry.notes}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Notes</label>
								<div class="bg-white/5 rounded-lg px-3 py-2.5">
									<p class="text-sm text-[var(--fv-mist)] whitespace-pre-wrap">{entry.notes}</p>
								</div>
							</div>
						{/if}

						{#if entry.tags.length > 0}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Tags</label>
								<div class="flex flex-wrap gap-1.5">
									{#each entry.tags as tag}
										<span class="px-2 py-1 rounded-md bg-white/5 text-[10px] text-[var(--fv-smoke)]">{tag}</span>
									{/each}
								</div>
							</div>
						{/if}
					</div>

					<!-- Actions -->
					<div class="flex gap-2 mt-6 pt-4 border-t border-white/5">
						<button
							onclick={() => toggleFavorite(entry.id)}
							class="flex-1 fv-btn fv-btn-ghost text-xs !py-2.5"
						>
							{entry.isFavorite ? '&#9733; Retirer' : '&#9734; Favori'}
						</button>
						<button
							onclick={() => goto(`/vault/add?edit=${entry.id}`)}
							class="flex-1 fv-btn fv-btn-ghost text-xs !py-2.5"
						>
							Modifier
						</button>
						<button
							onclick={() => showDeleteConfirm = entry.id}
							class="fv-btn fv-btn-ghost text-xs !py-2.5 !text-[var(--fv-danger)] hover:!bg-[var(--fv-danger)]/10"
						>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
						</button>
					</div>

					<!-- Delete confirm -->
					{#if showDeleteConfirm === entry.id}
						<div class="mt-3 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)] mb-2">Supprimer cet élément ?</p>
							<div class="flex gap-2">
								<button onclick={() => handleDelete(entry.id)} class="flex-1 fv-btn text-xs !py-2 bg-[var(--fv-danger)] text-white hover:bg-[var(--fv-danger)]/80">Oui, supprimer</button>
								<button onclick={() => showDeleteConfirm = null} class="flex-1 fv-btn fv-btn-ghost text-xs !py-2">Annuler</button>
							</div>
						</div>
					{/if}

					<!-- Meta -->
					<div class="mt-4 pt-3 border-t border-white/5 space-y-1">
						<p class="text-[10px] text-[var(--fv-ash)]">Créé le {formatDate(entry.createdAt)}</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Modifié le {formatDate(entry.lastModifiedAt)}</p>
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Mobile detail modal -->
	{#if showDetail && vault.selectedEntry}
		{@const entry = vault.selectedEntry}
		<div class="lg:hidden fixed inset-0 z-50 bg-[var(--fv-abyss)]/95 backdrop-blur-xl overflow-y-auto">
			<div class="p-4 max-w-lg mx-auto">
				<!-- Close button -->
				<button onclick={closeDetail} class="mb-4 p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)]">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="19" y1="12" x2="5" y2="12"/>
						<polyline points="12 19 5 12 12 5"/>
					</svg>
				</button>

				<div class="fv-glass p-6">
					<!-- Header -->
					<div class="flex items-center gap-3 mb-5">
						<div class="w-12 h-12 rounded-xl flex items-center justify-center text-xl"
							style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
							{CATEGORY_META[entry.category]?.icon ?? '📦'}
						</div>
						<div>
							<h2 class="text-lg font-bold text-white">{entry.title || 'Sans titre'}</h2>
							<p class="text-xs text-[var(--fv-smoke)]">{CATEGORY_META[entry.category]?.label ?? ''}</p>
						</div>
					</div>

					<!-- Fields -->
					<div class="space-y-4">
						{#if entry.username}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Identifiant</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									<span class="flex-1 text-sm text-white truncate">{entry.username}</span>
									<button onclick={() => copyToClipboard(entry.username, `m-user-${entry.id}`)} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
										{#if copiedField === `m-user-${entry.id}`}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
							</div>
						{/if}

						{#if entry.password}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Mot de passe</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									<span class="flex-1 text-sm text-white font-mono truncate">
										{showPassword[entry.id] ? entry.password : '•'.repeat(Math.min(entry.password.length, 20))}
									</span>
									<button onclick={() => togglePasswordVisibility(entry.id)} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
									</button>
									<button onclick={() => copyToClipboard(entry.password, `m-pass-${entry.id}`)} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
										{#if copiedField === `m-pass-${entry.id}`}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
							</div>
						{/if}

						{#if entry.website}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Site web</label>
								<a href={entry.website.startsWith('http') ? entry.website : `https://${entry.website}`} target="_blank" rel="noopener noreferrer"
									class="block bg-white/5 rounded-lg px-3 py-2.5 text-sm text-[var(--fv-cyan)]">{getDomain(entry.website)}</a>
							</div>
						{/if}

						{#if entry.notes}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Notes</label>
								<div class="bg-white/5 rounded-lg px-3 py-2.5">
									<p class="text-sm text-[var(--fv-mist)] whitespace-pre-wrap">{entry.notes}</p>
								</div>
							</div>
						{/if}
					</div>

					<!-- Mobile actions -->
					<div class="flex gap-2 mt-6">
						<button onclick={() => toggleFavorite(entry.id)} class="flex-1 fv-btn fv-btn-ghost text-xs !py-2.5">
							{entry.isFavorite ? '&#9733; Retirer' : '&#9734; Favori'}
						</button>
						<button onclick={() => { closeDetail(); goto(`/vault/add?edit=${entry.id}`); }} class="flex-1 fv-btn fv-btn-primary text-xs !py-2.5">Modifier</button>
					</div>
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- FAB on mobile -->
<a href="/vault/add" class="lg:hidden fixed bottom-6 right-6 z-30 w-14 h-14 rounded-full bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/30 hover:scale-105 transition-transform">
	<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
		<line x1="12" y1="5" x2="12" y2="19"/>
		<line x1="5" y1="12" x2="19" y2="12"/>
	</svg>
</a>
