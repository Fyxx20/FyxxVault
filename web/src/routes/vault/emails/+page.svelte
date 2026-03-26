<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	// addy.io (AnonAddy) API integration
	let apiKey = $state('');
	let apiKeyInput = $state('');
	let showApiKeyInput = $state(false);
	let aliases = $state<AliasEntry[]>([]);
	let loading = $state(false);
	let error = $state('');
	let copiedId = $state<string | null>(null);
	let creating = $state(false);
	let newAliasDomain = $state('anonaddy.me');
	let newAliasDescription = $state('');
	let showCreateForm = $state(false);
	let deleteConfirm = $state<string | null>(null);

	interface AliasEntry {
		id: string;
		email: string;
		description: string | null;
		active: boolean;
		emails_forwarded: number;
		emails_blocked: number;
		created_at: string;
	}

	// Load API key from localStorage
	$effect(() => {
		const stored = localStorage.getItem('fv_addy_api_key');
		if (stored) {
			apiKey = stored;
			loadAliases();
		}
	});

	function saveApiKey() {
		if (!apiKeyInput.trim()) return;
		apiKey = apiKeyInput.trim();
		localStorage.setItem('fv_addy_api_key', apiKey);
		apiKeyInput = '';
		showApiKeyInput = false;
		loadAliases();
	}

	function disconnectAddy() {
		apiKey = '';
		aliases = [];
		localStorage.removeItem('fv_addy_api_key');
	}

	async function loadAliases() {
		if (!apiKey) return;
		loading = true;
		error = '';

		try {
			const res = await fetch('https://app.addy.io/api/v1/aliases', {
				headers: {
					'Authorization': `Bearer ${apiKey}`,
					'Content-Type': 'application/json',
					'X-Requested-With': 'XMLHttpRequest'
				}
			});

			if (!res.ok) {
				if (res.status === 401) {
					error = 'Clé API invalide. Vérifie ta clé addy.io.';
					return;
				}
				throw new Error(`HTTP ${res.status}`);
			}

			const data = await res.json();
			aliases = (data.data || []).map((a: any) => ({
				id: a.id,
				email: a.email,
				description: a.description,
				active: a.active,
				emails_forwarded: a.emails_forwarded || 0,
				emails_blocked: a.emails_blocked || 0,
				created_at: a.created_at
			}));
		} catch (e: any) {
			error = e.message || 'Erreur lors du chargement.';
		} finally {
			loading = false;
		}
	}

	async function createAlias() {
		if (!apiKey) return;
		creating = true;
		error = '';

		try {
			const res = await fetch('https://app.addy.io/api/v1/aliases', {
				method: 'POST',
				headers: {
					'Authorization': `Bearer ${apiKey}`,
					'Content-Type': 'application/json',
					'X-Requested-With': 'XMLHttpRequest'
				},
				body: JSON.stringify({
					domain: newAliasDomain,
					description: newAliasDescription || null,
					format: 'uuid'
				})
			});

			if (!res.ok) throw new Error(`HTTP ${res.status}`);

			const data = await res.json();
			const alias: AliasEntry = {
				id: data.data.id,
				email: data.data.email,
				description: data.data.description,
				active: data.data.active,
				emails_forwarded: 0,
				emails_blocked: 0,
				created_at: data.data.created_at
			};

			aliases = [alias, ...aliases];
			showCreateForm = false;
			newAliasDescription = '';
		} catch (e: any) {
			error = e.message || 'Erreur lors de la création.';
		} finally {
			creating = false;
		}
	}

	async function toggleAlias(id: string, active: boolean) {
		if (!apiKey) return;
		try {
			if (active) {
				// Deactivate
				await fetch(`https://app.addy.io/api/v1/active-aliases/${id}`, {
					method: 'DELETE',
					headers: {
						'Authorization': `Bearer ${apiKey}`,
						'Content-Type': 'application/json',
						'X-Requested-With': 'XMLHttpRequest'
					}
				});
			} else {
				// Activate
				await fetch('https://app.addy.io/api/v1/active-aliases', {
					method: 'POST',
					headers: {
						'Authorization': `Bearer ${apiKey}`,
						'Content-Type': 'application/json',
						'X-Requested-With': 'XMLHttpRequest'
					},
					body: JSON.stringify({ id })
				});
			}

			aliases = aliases.map(a =>
				a.id === id ? { ...a, active: !active } : a
			);
		} catch (e: any) {
			error = e.message || 'Erreur.';
		}
	}

	async function deleteAlias(id: string) {
		if (!apiKey) return;
		try {
			await fetch(`https://app.addy.io/api/v1/aliases/${id}`, {
				method: 'DELETE',
				headers: {
					'Authorization': `Bearer ${apiKey}`,
					'Content-Type': 'application/json',
					'X-Requested-With': 'XMLHttpRequest'
				}
			});

			aliases = aliases.filter(a => a.id !== id);
			deleteConfirm = null;
		} catch (e: any) {
			error = e.message || 'Erreur lors de la suppression.';
		}
	}

	async function copyAlias(email: string, id: string) {
		try {
			await navigator.clipboard.writeText(email);
			copiedId = id;
			setTimeout(() => copiedId = null, 2000);
		} catch {}
	}

	function formatDate(dateStr: string): string {
		try {
			return new Date(dateStr).toLocaleDateString('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' });
		} catch { return dateStr; }
	}
</script>

<svelte:head>
	<title>Emails masqués — FyxxVault</title>
</svelte:head>

{#if !auth.isPro}
<div class="max-w-2xl mx-auto flex items-center justify-center" style="min-height: calc(100vh - 120px);">
	<div class="fv-glass p-10 text-center">
		<div class="w-20 h-20 rounded-full bg-[var(--fv-gold)]/10 flex items-center justify-center mx-auto mb-5">
			<span class="text-4xl">👑</span>
		</div>
		<h1 class="text-2xl font-bold text-white mb-2">Fonctionnalité Pro</h1>
		<p class="text-sm text-[var(--fv-smoke)] mb-6 max-w-md mx-auto">Les emails masqués sont réservés aux abonnés FyxxVault Pro. Passe au plan Pro pour protéger ta vraie adresse email.</p>
		<a href="/vault/settings" class="fv-btn fv-btn-gold">Passer à Pro — 4,99€/mois</a>
	</div>
</div>
{:else}
<div class="max-w-2xl mx-auto">
	<div class="flex items-center justify-between mb-6">
		<div>
			<h1 class="text-2xl font-bold text-white">Emails masqués</h1>
			<p class="text-sm text-[var(--fv-smoke)]">Protège ton vrai email avec des alias</p>
		</div>
		{#if apiKey}
			<button onclick={() => showCreateForm = !showCreateForm} class="fv-btn fv-btn-primary !py-2.5 !px-5 text-sm inline-flex items-center gap-2">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
					<line x1="12" y1="5" x2="12" y2="19"/>
					<line x1="5" y1="12" x2="19" y2="12"/>
				</svg>
				Nouvel alias
			</button>
		{/if}
	</div>

	{#if !apiKey}
		<!-- Setup addy.io connection -->
		<div class="fv-glass p-8 text-center">
			<div class="w-16 h-16 rounded-full bg-[var(--fv-violet)]/15 flex items-center justify-center mx-auto mb-4">
				<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet)" stroke-width="1.5">
					<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
					<polyline points="22,6 12,13 2,6"/>
				</svg>
			</div>
			<h2 class="text-lg font-bold text-white mb-2">Connecte addy.io</h2>
			<p class="text-sm text-[var(--fv-smoke)] mb-6 max-w-sm mx-auto">
				Crée des alias email illimités pour protéger ton adresse principale. Utilise un compte addy.io gratuit ou premium.
			</p>

			{#if showApiKeyInput}
				<div class="max-w-sm mx-auto space-y-3">
					<input
						type="password"
						bind:value={apiKeyInput}
						placeholder="Colle ta clé API addy.io ici..."
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm font-mono focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
					/>
					<div class="flex gap-2">
						<button onclick={() => showApiKeyInput = false} class="fv-btn fv-btn-ghost flex-1 text-sm !py-2.5">Annuler</button>
						<button onclick={saveApiKey} class="fv-btn fv-btn-primary flex-1 text-sm !py-2.5">Connecter</button>
					</div>
					<p class="text-[10px] text-[var(--fv-ash)]">
						Trouve ta clé API sur <a href="https://app.addy.io/settings/api" target="_blank" rel="noopener noreferrer" class="text-[var(--fv-cyan)] hover:underline">app.addy.io/settings/api</a>
					</p>
				</div>
			{:else}
				<button onclick={() => showApiKeyInput = true} class="fv-btn fv-btn-primary text-sm !py-3 !px-8">
					Entrer la clé API
				</button>
			{/if}
		</div>

		<!-- Pro upsell -->
		{#if !auth.isPro}
			<div class="fv-glass p-5 mt-4 border-[var(--fv-gold)]/20">
				<div class="flex items-center gap-2 mb-2">
					<span>👑</span>
					<span class="text-xs font-bold text-[var(--fv-gold)]">Fonctionnalité Pro</span>
				</div>
				<p class="text-xs text-[var(--fv-smoke)]">Les emails masqués sont inclus dans le plan FyxxVault Pro. Passe au plan Pro pour un accès complet.</p>
			</div>
		{/if}
	{:else}
		<!-- Create form -->
		{#if showCreateForm}
			<div class="fv-glass p-5 mb-4">
				<h2 class="text-sm font-bold text-white mb-3">Créer un alias</h2>
				<div class="space-y-3">
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Domaine</label>
						<select bind:value={newAliasDomain} class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all">
							<option value="anonaddy.me">anonaddy.me</option>
							<option value="anonaddy.com">anonaddy.com</option>
						</select>
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Description (optionnel)</label>
						<input
							type="text"
							bind:value={newAliasDescription}
							placeholder="Ex: Newsletter, Shopping..."
							class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
					</div>
					<div class="flex gap-2">
						<button onclick={() => showCreateForm = false} class="fv-btn fv-btn-ghost flex-1 text-xs !py-2.5">Annuler</button>
						<button onclick={createAlias} disabled={creating} class="fv-btn fv-btn-primary flex-1 text-xs !py-2.5 {creating ? 'opacity-60' : ''}">
							{creating ? 'Création...' : 'Créer l\'alias'}
						</button>
					</div>
				</div>
			</div>
		{/if}

		{#if error}
			<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 mb-4">
				<p class="text-sm text-[var(--fv-danger)]">{error}</p>
			</div>
		{/if}

		{#if loading}
			<div class="flex items-center justify-center py-20">
				<div class="w-8 h-8 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
			</div>
		{:else if aliases.length === 0}
			<div class="fv-glass p-12 text-center">
				<p class="text-[var(--fv-smoke)] text-sm mb-4">Aucun alias email pour le moment</p>
				<button onclick={() => showCreateForm = true} class="fv-btn fv-btn-primary text-sm !py-2.5">Créer ton premier alias</button>
			</div>
		{:else}
			<!-- Alias list -->
			<div class="space-y-2">
				{#each aliases as alias (alias.id)}
					<div class="fv-glass p-4 transition-all">
						<div class="flex items-center gap-3">
							<!-- Active indicator -->
							<div class="w-2.5 h-2.5 rounded-full shrink-0 {alias.active ? 'bg-[var(--fv-success)]' : 'bg-[var(--fv-ash)]'}"></div>

							<!-- Info -->
							<div class="flex-1 min-w-0">
								<p class="text-sm font-mono text-white truncate">{alias.email}</p>
								<div class="flex items-center gap-3 mt-0.5">
									{#if alias.description}
										<span class="text-[10px] text-[var(--fv-smoke)]">{alias.description}</span>
									{/if}
									<span class="text-[9px] text-[var(--fv-ash)]">{alias.emails_forwarded} transféré{alias.emails_forwarded > 1 ? 's' : ''}</span>
									<span class="text-[9px] text-[var(--fv-ash)]">{alias.emails_blocked} bloqué{alias.emails_blocked > 1 ? 's' : ''}</span>
								</div>
							</div>

							<!-- Actions -->
							<button
								onclick={() => copyAlias(alias.email, alias.id)}
								class="p-2 rounded-lg hover:bg-white/10 text-[var(--fv-smoke)] transition-colors shrink-0"
								title="Copier"
							>
								{#if copiedId === alias.id}
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
								{:else}
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
								{/if}
							</button>

							<!-- Toggle active -->
							<button
								onclick={() => toggleAlias(alias.id, alias.active)}
								class="w-11 h-6 rounded-full transition-colors relative shrink-0 {alias.active ? 'bg-[var(--fv-success)]' : 'bg-white/10'}"
							>
								<div class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform {alias.active ? 'translate-x-[22px]' : 'translate-x-0.5'}"></div>
							</button>

							<!-- Delete -->
							<button
								onclick={() => deleteConfirm = alias.id}
								class="p-2 rounded-lg hover:bg-[var(--fv-danger)]/10 text-[var(--fv-ash)] hover:text-[var(--fv-danger)] transition-colors shrink-0"
							>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
							</button>
						</div>

						<!-- Delete confirm -->
						{#if deleteConfirm === alias.id}
							<div class="mt-3 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
								<p class="text-xs text-[var(--fv-danger)] mb-2">Supprimer cet alias ?</p>
								<div class="flex gap-2">
									<button onclick={() => deleteAlias(alias.id)} class="flex-1 fv-btn text-xs !py-2 bg-[var(--fv-danger)] text-white">Supprimer</button>
									<button onclick={() => deleteConfirm = null} class="flex-1 fv-btn fv-btn-ghost text-xs !py-2">Annuler</button>
								</div>
							</div>
						{/if}
					</div>
				{/each}
			</div>
		{/if}

		<!-- Footer actions -->
		<div class="mt-4 flex justify-end">
			<button onclick={disconnectAddy} class="text-xs text-[var(--fv-ash)] hover:text-[var(--fv-danger)] transition-colors">
				Déconnecter addy.io
			</button>
		</div>
	{/if}
</div>
{/if}
