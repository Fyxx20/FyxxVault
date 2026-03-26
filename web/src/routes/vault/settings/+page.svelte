<script lang="ts">
	import { goto } from '$app/navigation';
	import { getAuthState, logout, changeMasterPassword } from '$lib/stores/auth.svelte';
	import { exportCSV, resetVault, getVaultState } from '$lib/stores/vault.svelte';

	const auth = getAuthState();
	const vault = getVaultState();

	// Change password state
	let showChangePassword = $state(false);
	let currentPassword = $state('');
	let newPassword = $state('');
	let confirmNewPassword = $state('');
	let changeLoading = $state(false);
	let changeError = $state('');
	let changeSuccess = $state(false);

	// Export state
	let exportLoading = $state(false);

	// Subscription
	let selectedPlan = $state<'monthly' | 'yearly'>('yearly');
	const proFeatures = [
		'Comptes illimités',
		'Surveillance Dark Web',
		'Emails masqués',
		'Partage sécurisé',
		'Support prioritaire'
	];

	async function handleChangePassword() {
		changeError = '';

		if (!currentPassword) { changeError = 'Mot de passe actuel requis.'; return; }
		if (newPassword.length < 12) { changeError = 'Le nouveau mot de passe doit contenir au moins 12 caractères.'; return; }
		if (newPassword !== confirmNewPassword) { changeError = 'Les mots de passe ne correspondent pas.'; return; }

		changeLoading = true;

		try {
			const result = await changeMasterPassword(currentPassword, newPassword);
			if (result.success) {
				changeSuccess = true;
				currentPassword = '';
				newPassword = '';
				confirmNewPassword = '';
				setTimeout(() => {
					changeSuccess = false;
					showChangePassword = false;
				}, 3000);
			} else {
				changeError = result.error || 'Échec du changement.';
			}
		} catch (e: any) {
			changeError = e.message || 'Erreur inconnue.';
		} finally {
			changeLoading = false;
		}
	}

	function handleExport() {
		exportLoading = true;
		try {
			const csv = exportCSV();
			const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = `fyxxvault-export-${new Date().toISOString().slice(0, 10)}.csv`;
			a.click();
			URL.revokeObjectURL(url);
		} finally {
			exportLoading = false;
		}
	}

	async function handleLogout() {
		resetVault();
		await logout();
		goto('/login');
	}
</script>

<svelte:head>
	<title>Paramètres — FyxxVault</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
	<h1 class="text-2xl font-bold text-white mb-6">Paramètres</h1>

	<!-- Account info -->
	<div class="fv-glass p-5 mb-4">
		<h2 class="text-sm font-bold text-white mb-4">Compte</h2>
		<div class="space-y-3">
			<div class="flex items-center justify-between">
				<span class="text-sm text-[var(--fv-smoke)]">Email</span>
				<span class="text-sm text-white">{auth.user?.email ?? ''}</span>
			</div>
			<div class="flex items-center justify-between">
				<span class="text-sm text-[var(--fv-smoke)]">Plan</span>
				<span class="px-3 py-1 rounded-full bg-white/10 text-xs font-bold text-[var(--fv-smoke)]">Gratuit</span>
			</div>
			<div class="flex items-center justify-between">
				<span class="text-sm text-[var(--fv-smoke)]">Éléments</span>
				<span class="text-sm text-white">{vault.entries.length}</span>
			</div>
			<div class="flex items-center justify-between">
				<span class="text-sm text-[var(--fv-smoke)]">Chiffrement</span>
				<span class="px-3 py-1 rounded-full bg-[var(--fv-success)]/10 text-xs font-bold text-[var(--fv-success)]">AES-256-GCM</span>
			</div>
		</div>
	</div>

	<!-- Upgrade to Pro -->
	<div class="fv-glass p-5 mb-4 border-[var(--fv-gold)]/20 fv-glow-gold relative overflow-hidden">
		<div class="absolute top-0 right-0 px-3 py-1 bg-gradient-to-r from-[var(--fv-gold)] to-[var(--fv-gold-light)] text-[#1a1a2e] text-[9px] font-extrabold uppercase tracking-wider rounded-bl-xl">
			Recommandé
		</div>
		<div class="flex items-center gap-3 mb-4">
			<span class="text-2xl">👑</span>
			<div>
				<h2 class="text-sm font-bold text-white">Passer à FyxxVault Pro</h2>
				<p class="text-[10px] text-[var(--fv-smoke)]">Débloque toutes les fonctionnalités</p>
			</div>
		</div>

		<ul class="space-y-2 mb-5">
			{#each proFeatures as f}
				<li class="flex items-center gap-2 text-xs text-[var(--fv-mist)]">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
					{f}
				</li>
			{/each}
		</ul>

		<div class="grid grid-cols-2 gap-3 mb-4">
			<button
				onclick={() => selectedPlan = 'monthly'}
				class="p-3 rounded-xl text-center transition-all border
					{selectedPlan === 'monthly'
						? 'bg-[var(--fv-gold)]/10 border-[var(--fv-gold)]/40'
						: 'bg-white/5 border-white/10 hover:bg-white/10'}"
			>
				<p class="text-sm font-bold text-white">4,99€</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">par mois</p>
			</button>
			<button
				onclick={() => selectedPlan = 'yearly'}
				class="p-3 rounded-xl text-center transition-all border relative
					{selectedPlan === 'yearly'
						? 'bg-[var(--fv-gold)]/10 border-[var(--fv-gold)]/40'
						: 'bg-white/5 border-white/10 hover:bg-white/10'}"
			>
				<span class="absolute -top-2 right-2 px-2 py-0.5 rounded-full bg-[var(--fv-gold)] text-[8px] font-bold text-[#1a1a2e]">-30%</span>
				<p class="text-sm font-bold text-white">41,99€</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">par an</p>
			</button>
		</div>

		<button class="fv-btn fv-btn-gold w-full text-sm !py-3">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
			Essai gratuit 14 jours
		</button>
		<p class="text-[9px] text-[var(--fv-ash)] text-center mt-2">Paiement sécurisé par Stripe. Annule à tout moment.</p>
	</div>

	<!-- Security -->
	<div class="fv-glass p-5 mb-4">
		<h2 class="text-sm font-bold text-white mb-4">Sécurité</h2>

		<!-- Change password -->
		<button
			onclick={() => showChangePassword = !showChangePassword}
			class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-white/5 transition-colors"
		>
			<div class="flex items-center gap-3">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<rect x="3" y="11" width="18" height="11" rx="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
				<span class="text-sm text-[var(--fv-mist)]">Changer le mot de passe maître</span>
			</div>
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"
				class="transition-transform {showChangePassword ? 'rotate-180' : ''}">
				<polyline points="6 9 12 15 18 9"/>
			</svg>
		</button>

		{#if showChangePassword}
			<div class="mt-3 p-4 rounded-xl bg-[var(--fv-abyss)]/60 border border-white/5 space-y-3">
				{#if changeSuccess}
					<div class="p-3 rounded-xl bg-[var(--fv-success)]/10 border border-[var(--fv-success)]/20 text-center">
						<p class="text-sm text-[var(--fv-success)]">Mot de passe modifié avec succès !</p>
					</div>
				{:else}
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Mot de passe actuel</label>
						<input
							type="password"
							bind:value={currentPassword}
							class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Nouveau mot de passe</label>
						<input
							type="password"
							bind:value={newPassword}
							class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Confirmer le nouveau mot de passe</label>
						<input
							type="password"
							bind:value={confirmNewPassword}
							class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
					</div>

					{#if changeError}
						<div class="p-2 rounded-lg bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)]">{changeError}</p>
						</div>
					{/if}

					<button
						onclick={handleChangePassword}
						disabled={changeLoading}
						class="fv-btn fv-btn-primary w-full text-sm !py-2.5 {changeLoading ? 'opacity-60' : ''}"
					>
						{changeLoading ? 'Modification...' : 'Modifier le mot de passe'}
					</button>
				{/if}
			</div>
		{/if}
	</div>

	<!-- Data -->
	<div class="fv-glass p-5 mb-4">
		<h2 class="text-sm font-bold text-white mb-4">Données</h2>

		<!-- Export -->
		<button
			onclick={handleExport}
			disabled={exportLoading}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/5 transition-colors"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
				<polyline points="7 10 12 15 17 10"/>
				<line x1="12" y1="15" x2="12" y2="3"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-mist)]">Exporter le coffre (CSV)</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Télécharge toutes tes données en clair</p>
			</div>
		</button>
	</div>

	<!-- App links -->
	<div class="fv-glass p-5 mb-4">
		<h2 class="text-sm font-bold text-white mb-4">Applications</h2>
		<div class="flex items-center gap-3 p-3 rounded-xl bg-white/5">
			<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
					<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/>
					<line x1="12" y1="18" x2="12.01" y2="18"/>
				</svg>
			</div>
			<div class="flex-1">
				<p class="text-sm text-white font-medium">FyxxVault pour iOS</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">Face ID, AutoFill, widgets</p>
			</div>
			<span class="px-3 py-1.5 rounded-full bg-white/5 text-[10px] text-[var(--fv-smoke)] font-medium">Bientôt</span>
		</div>
	</div>

	<!-- Danger zone -->
	<div class="fv-glass p-5 border-[var(--fv-danger)]/10">
		<h2 class="text-sm font-bold text-[var(--fv-danger)] mb-4">Zone de danger</h2>
		<button
			onclick={handleLogout}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-[var(--fv-danger)]/5 transition-colors"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
				<polyline points="16 17 21 12 16 7"/>
				<line x1="21" y1="12" x2="9" y2="12"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-danger)]">Déconnexion</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Efface le VEK de la mémoire et déconnecte</p>
			</div>
		</button>
	</div>

	<!-- Footer -->
	<div class="text-center mt-8 mb-4">
		<p class="text-[10px] text-[var(--fv-ash)]">FyxxVault v1.0 — Chiffrement AES-256-GCM, PBKDF2 SHA-256</p>
		<p class="text-[10px] text-[var(--fv-ash)] mt-1">Zero-knowledge: tes données ne quittent jamais cet appareil en clair.</p>
	</div>
</div>
