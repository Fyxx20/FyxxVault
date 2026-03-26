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
	let checkoutLoading = $state(false);
	const proFeatures = [
		'Comptes illimités',
		'Surveillance Dark Web',
		'Emails masqués',
		'Partage sécurisé',
		'Support prioritaire'
	];

	// Settings
	let autoLockTimeout = $state(5);
	let clipboardAutoClear = $state(30);
	let showDeleteAccount = $state(false);
	let deleteAccountConfirm = $state('');

	// Load settings from localStorage
	$effect(() => {
		const storedLock = localStorage.getItem('fv_auto_lock_timeout');
		if (storedLock) autoLockTimeout = parseInt(storedLock);
		const storedClipboard = localStorage.getItem('fv_clipboard_clear');
		if (storedClipboard) clipboardAutoClear = parseInt(storedClipboard);
	});

	function saveAutoLockTimeout(value: number) {
		autoLockTimeout = value;
		localStorage.setItem('fv_auto_lock_timeout', value.toString());
	}

	function saveClipboardClear(value: number) {
		clipboardAutoClear = value;
		localStorage.setItem('fv_clipboard_clear', value.toString());
	}

	async function handleCheckout() {
		checkoutLoading = true;
		try {
			const res = await fetch('/api/checkout', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ plan: selectedPlan, email: auth.user?.email })
			});
			const data = await res.json();
			if (data.url) {
				window.location.href = data.url;
			} else {
				alert(data.error || 'Erreur lors de la création du paiement.');
			}
		} catch (e: any) {
			alert(e.message || 'Erreur réseau.');
		} finally {
			checkoutLoading = false;
		}
	}

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

	async function handleDeleteAccount() {
		if (deleteAccountConfirm !== 'SUPPRIMER') return;
		// This would call a server endpoint to delete the account
		// For now, just log out
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
				<span class="px-3 py-1 rounded-full {auth.isPro ? 'bg-[var(--fv-gold)]/10 text-[var(--fv-gold)]' : 'bg-white/10 text-[var(--fv-smoke)]'} text-xs font-bold">
					{auth.isPro ? 'Pro' : 'Gratuit'}
				</span>
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

	<!-- Upgrade to Pro — only in sidebar now -->

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
						<input type="password" bind:value={currentPassword} class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Nouveau mot de passe</label>
						<input type="password" bind:value={newPassword} class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1">Confirmer le nouveau mot de passe</label>
						<input type="password" bind:value={confirmNewPassword} class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all" />
					</div>

					{#if changeError}
						<div class="p-2 rounded-lg bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)]">{changeError}</p>
						</div>
					{/if}

					<button onclick={handleChangePassword} disabled={changeLoading} class="fv-btn fv-btn-primary w-full text-sm !py-2.5 {changeLoading ? 'opacity-60' : ''}">
						{changeLoading ? 'Modification...' : 'Modifier le mot de passe'}
					</button>
				{/if}
			</div>
		{/if}

		<!-- Auto-lock timeout -->
		<div class="mt-2 p-3 rounded-xl hover:bg-white/5 transition-colors">
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-3">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
					<div>
						<span class="text-sm text-[var(--fv-mist)]">Verrouillage automatique</span>
						<p class="text-[10px] text-[var(--fv-ash)]">Verrouille le coffre après inactivité</p>
					</div>
				</div>
				<select
					value={autoLockTimeout}
					onchange={(e: Event) => saveAutoLockTimeout(parseInt((e.target as HTMLSelectElement).value))}
					class="px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs focus:outline-none"
				>
					<option value={1}>1 min</option>
					<option value={5}>5 min</option>
					<option value={15}>15 min</option>
					<option value={30}>30 min</option>
					<option value={60}>1 heure</option>
					<option value={0}>Jamais</option>
				</select>
			</div>
		</div>

		<!-- Clipboard auto-clear -->
		<div class="p-3 rounded-xl hover:bg-white/5 transition-colors">
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-3">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
					<div>
						<span class="text-sm text-[var(--fv-mist)]">Nettoyage du presse-papier</span>
						<p class="text-[10px] text-[var(--fv-ash)]">Efface le presse-papier automatiquement</p>
					</div>
				</div>
				<select
					value={clipboardAutoClear}
					onchange={(e: Event) => saveClipboardClear(parseInt((e.target as HTMLSelectElement).value))}
					class="px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs focus:outline-none"
				>
					<option value={10}>10 sec</option>
					<option value={30}>30 sec</option>
					<option value={60}>1 min</option>
					<option value={120}>2 min</option>
					<option value={0}>Jamais</option>
				</select>
			</div>
		</div>
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

		<!-- Import -->
		<a
			href="/vault/import"
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/5 transition-colors mt-1"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
				<polyline points="17 8 12 3 7 8"/>
				<line x1="12" y1="3" x2="12" y2="15"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-mist)]">Importer des données</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Bitwarden, 1Password ou CSV</p>
			</div>
		</a>
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

	<!-- Legal -->
	<div class="fv-glass p-5 mb-4">
		<h2 class="text-sm font-bold text-white mb-4">Informations</h2>
		<div class="space-y-1">
			<a href="/privacy" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/5 transition-colors">
				<span class="text-sm text-[var(--fv-mist)]">Politique de confidentialité</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
			<a href="/terms" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/5 transition-colors">
				<span class="text-sm text-[var(--fv-mist)]">Conditions d'utilisation</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
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

		<button
			onclick={() => showDeleteAccount = !showDeleteAccount}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-[var(--fv-danger)]/5 transition-colors mt-1"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<polyline points="3 6 5 6 21 6"/>
				<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
				<line x1="10" y1="11" x2="10" y2="17"/>
				<line x1="14" y1="11" x2="14" y2="17"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-danger)]">Supprimer le compte</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Cette action est irréversible</p>
			</div>
		</button>

		{#if showDeleteAccount}
			<div class="mt-3 p-4 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/20 space-y-3">
				<p class="text-xs text-[var(--fv-danger)]">Cette action supprimera définitivement ton compte et toutes tes données. Tape <strong>SUPPRIMER</strong> pour confirmer.</p>
				<input
					type="text"
					bind:value={deleteAccountConfirm}
					placeholder="SUPPRIMER"
					class="w-full px-3 py-2.5 rounded-lg bg-white/5 border border-[var(--fv-danger)]/20 text-white text-sm focus:outline-none focus:border-[var(--fv-danger)]/50 transition-all"
				/>
				<button
					onclick={handleDeleteAccount}
					disabled={deleteAccountConfirm !== 'SUPPRIMER'}
					class="fv-btn w-full text-sm !py-2.5 bg-[var(--fv-danger)] text-white {deleteAccountConfirm !== 'SUPPRIMER' ? 'opacity-40 cursor-not-allowed' : 'hover:bg-[var(--fv-danger)]/80'}"
				>
					Supprimer définitivement
				</button>
			</div>
		{/if}
	</div>

	<!-- Footer -->
	<div class="text-center mt-8 mb-4">
		<p class="text-[10px] text-[var(--fv-ash)]">FyxxVault v1.0.0 — Chiffrement AES-256-GCM, PBKDF2 SHA-256</p>
		<p class="text-[10px] text-[var(--fv-ash)] mt-1">Zero-knowledge: tes données ne quittent jamais cet appareil en clair.</p>
	</div>
</div>
