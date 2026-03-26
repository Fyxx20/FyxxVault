<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { CATEGORY_META, newVaultEntry, type VaultCategory, type VaultEntry } from '$lib/types';
	import { generatePassword, passwordStrength } from '$lib/crypto';
	import { addEntry, updateEntry, getVaultState } from '$lib/stores/vault.svelte';

	const vault = getVaultState();

	// Determine if editing
	const editId = $derived($page.url.searchParams.get('edit'));
	const existingEntry = $derived(editId ? vault.entries.find((e) => e.id === editId) ?? null : null);

	let entry = $state<VaultEntry>(newVaultEntry());
	let loading = $state(false);
	let error = $state('');
	let success = $state(false);
	let tagInput = $state('');

	// Password generator state
	let genLength = $state(20);
	let genUppercase = $state(true);
	let genLowercase = $state(true);
	let genDigits = $state(true);
	let genSymbols = $state(true);
	let showGenerator = $state(false);
	let showPassword = $state(false);

	// Load existing entry if editing
	$effect(() => {
		if (existingEntry) {
			entry = { ...existingEntry };
		}
	});

	const strength = $derived(passwordStrength(entry.password));

	const categories = Object.entries(CATEGORY_META) as [VaultCategory, typeof CATEGORY_META[VaultCategory]][];

	function handleGeneratePassword() {
		entry.password = generatePassword(genLength, {
			uppercase: genUppercase,
			lowercase: genLowercase,
			digits: genDigits,
			symbols: genSymbols
		});
	}

	function addTag() {
		const tag = tagInput.trim();
		if (tag && !entry.tags.includes(tag)) {
			entry.tags = [...entry.tags, tag];
		}
		tagInput = '';
	}

	function removeTag(tag: string) {
		entry.tags = entry.tags.filter((t) => t !== tag);
	}

	async function handleSubmit() {
		if (!entry.title.trim()) {
			error = 'Le titre est requis.';
			return;
		}

		error = '';
		loading = true;

		try {
			entry.lastModifiedAt = new Date().toISOString();

			let result;
			if (editId && existingEntry) {
				result = await updateEntry(entry);
			} else {
				entry.createdAt = new Date().toISOString();
				result = await addEntry(entry);
			}

			if (result.success) {
				success = true;
				setTimeout(() => goto('/vault'), 800);
			} else {
				error = result.error || 'Erreur lors de la sauvegarde.';
			}
		} catch (e: any) {
			error = e.message || 'Erreur inconnue.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>{editId ? 'Modifier' : 'Ajouter'} — FyxxVault</title>
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
		<h1 class="text-xl font-bold text-white">{editId ? 'Modifier l\'élément' : 'Nouvel élément'}</h1>
	</div>

	{#if success}
		<div class="fv-glass p-8 text-center fv-glow-cyan">
			<div class="w-16 h-16 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
				<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
			</div>
			<p class="text-white font-semibold">{editId ? 'Élément modifié' : 'Élément ajouté'} !</p>
		</div>
	{:else}
		<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleSubmit(); }} class="space-y-6">
			<!-- Category selector -->
			<div class="fv-glass p-5">
				<label class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">Catégorie</label>
				<div class="grid grid-cols-4 sm:grid-cols-8 gap-2">
					{#each categories as [key, meta]}
						<button
							type="button"
							onclick={() => entry.category = key}
							class="flex flex-col items-center gap-1.5 p-3 rounded-xl transition-all
								{entry.category === key
									? 'bg-[var(--fv-cyan)]/10 border border-[var(--fv-cyan)]/30'
									: 'bg-white/5 border border-transparent hover:bg-white/10'}"
						>
							<span class="text-lg">{meta.icon}</span>
							<span class="text-[9px] text-[var(--fv-smoke)] font-medium leading-tight text-center">{meta.label}</span>
						</button>
					{/each}
				</div>
			</div>

			<!-- Main fields -->
			<div class="fv-glass p-5 space-y-4">
				<!-- Title -->
				<div>
					<label for="title" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Titre *</label>
					<input
						id="title"
						type="text"
						bind:value={entry.title}
						placeholder="Ex: Gmail, Netflix, Banque..."
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Username -->
				<div>
					<label for="username" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Identifiant / Email</label>
					<input
						id="username"
						type="text"
						bind:value={entry.username}
						placeholder="ton@email.com"
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Password -->
				<div>
					<label for="password-field" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe</label>
					<div class="relative">
						<input
							id="password-field"
							type={showPassword ? 'text' : 'password'}
							bind:value={entry.password}
							placeholder="••••••••••••"
							class="w-full px-4 py-3 pr-24 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm font-mono focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
						/>
						<div class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1">
							<button type="button" onclick={() => showPassword = !showPassword} class="p-1.5 rounded-lg hover:bg-white/10 text-[var(--fv-smoke)]">
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
							</button>
							<button type="button" onclick={() => showGenerator = !showGenerator} class="p-1.5 rounded-lg hover:bg-white/10 text-[var(--fv-smoke)]" title="Générateur">
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
							</button>
						</div>
					</div>

					<!-- Strength bar -->
					{#if entry.password}
						<div class="mt-2 flex items-center gap-2">
							<div class="flex-1 h-1.5 rounded-full bg-white/5 overflow-hidden">
								<div class="h-full rounded-full transition-all duration-300" style="width: {strength.score}%; background: {strength.color};"></div>
							</div>
							<span class="text-[10px] font-semibold" style="color: {strength.color};">{strength.label}</span>
						</div>
					{/if}

					<!-- Password generator -->
					{#if showGenerator}
						<div class="mt-3 p-4 rounded-xl bg-[var(--fv-abyss)]/60 border border-white/5 space-y-3">
							<div class="flex items-center justify-between">
								<span class="text-xs text-[var(--fv-smoke)]">Longueur: {genLength}</span>
								<input type="range" min="8" max="64" bind:value={genLength} class="w-32 accent-[var(--fv-cyan)]" />
							</div>
							<div class="flex flex-wrap gap-3">
								<label class="flex items-center gap-2 text-xs text-[var(--fv-smoke)] cursor-pointer">
									<input type="checkbox" bind:checked={genUppercase} class="accent-[var(--fv-cyan)]" />
									Majuscules
								</label>
								<label class="flex items-center gap-2 text-xs text-[var(--fv-smoke)] cursor-pointer">
									<input type="checkbox" bind:checked={genLowercase} class="accent-[var(--fv-cyan)]" />
									Minuscules
								</label>
								<label class="flex items-center gap-2 text-xs text-[var(--fv-smoke)] cursor-pointer">
									<input type="checkbox" bind:checked={genDigits} class="accent-[var(--fv-cyan)]" />
									Chiffres
								</label>
								<label class="flex items-center gap-2 text-xs text-[var(--fv-smoke)] cursor-pointer">
									<input type="checkbox" bind:checked={genSymbols} class="accent-[var(--fv-cyan)]" />
									Symboles
								</label>
							</div>
							<button
								type="button"
								onclick={handleGeneratePassword}
								class="fv-btn fv-btn-primary text-xs !py-2 w-full"
							>
								Générer un mot de passe
							</button>
						</div>
					{/if}
				</div>

				<!-- Website -->
				<div>
					<label for="website" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Site web</label>
					<input
						id="website"
						type="url"
						bind:value={entry.website}
						placeholder="https://example.com"
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Notes -->
				<div>
					<label for="notes" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Notes</label>
					<textarea
						id="notes"
						bind:value={entry.notes}
						placeholder="Notes privées..."
						rows="3"
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all resize-none"
					></textarea>
				</div>
			</div>

			<!-- Extra options -->
			<div class="fv-glass p-5 space-y-4">
				<!-- Folder -->
				<div>
					<label for="folder" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Dossier</label>
					<input
						id="folder"
						type="text"
						bind:value={entry.folder}
						placeholder="Ex: Travail, Personnel..."
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Tags -->
				<div>
					<label class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Tags</label>
					<div class="flex gap-2">
						<input
							type="text"
							bind:value={tagInput}
							placeholder="Ajouter un tag..."
							onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } }}
							class="flex-1 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
						<button type="button" onclick={addTag} class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-4">+</button>
					</div>
					{#if entry.tags.length > 0}
						<div class="flex flex-wrap gap-1.5 mt-2">
							{#each entry.tags as tag}
								<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs">
									{tag}
									<button type="button" onclick={() => removeTag(tag)} class="hover:text-white">&times;</button>
								</span>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Toggles -->
				<div class="flex items-center justify-between">
					<span class="text-sm text-[var(--fv-smoke)]">Favori</span>
					<button
						type="button"
						onclick={() => entry.isFavorite = !entry.isFavorite}
						class="w-11 h-6 rounded-full transition-colors relative {entry.isFavorite ? 'bg-[var(--fv-cyan)]' : 'bg-white/10'}"
					>
						<div class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform {entry.isFavorite ? 'translate-x-[22px]' : 'translate-x-0.5'}"></div>
					</button>
				</div>

				<div class="flex items-center justify-between">
					<span class="text-sm text-[var(--fv-smoke)]">MFA activé</span>
					<button
						type="button"
						onclick={() => entry.mfaEnabled = !entry.mfaEnabled}
						class="w-11 h-6 rounded-full transition-colors relative {entry.mfaEnabled ? 'bg-[var(--fv-cyan)]' : 'bg-white/10'}"
					>
						<div class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform {entry.mfaEnabled ? 'translate-x-[22px]' : 'translate-x-0.5'}"></div>
					</button>
				</div>

				{#if entry.mfaEnabled}
					<div>
						<label for="mfa-secret" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Secret TOTP</label>
						<input
							id="mfa-secret"
							type="text"
							bind:value={entry.mfaSecret}
							placeholder="JBSWY3DPEHPK3PXP"
							class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm font-mono focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
						/>
					</div>
				{/if}
			</div>

			<!-- Error -->
			{#if error}
				<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
					<p class="text-sm text-[var(--fv-danger)]">{error}</p>
				</div>
			{/if}

			<!-- Submit -->
			<div class="flex gap-3">
				<button type="button" onclick={() => goto('/vault')} class="fv-btn fv-btn-ghost flex-1 !py-3.5">Annuler</button>
				<button type="submit" disabled={loading} class="fv-btn fv-btn-primary flex-1 !py-3.5 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
					{#if loading}
						<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
						Sauvegarde...
					{:else}
						{editId ? 'Enregistrer' : 'Ajouter au coffre'}
					{/if}
				</button>
			</div>
		</form>
	{/if}
</div>
