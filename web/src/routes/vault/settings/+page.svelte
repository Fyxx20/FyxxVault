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
		'Comptes illimites',
		'Surveillance Dark Web',
		'Emails masques',
		'Partage securise',
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
				alert(data.error || 'Erreur lors de la creation du paiement.');
			}
		} catch (e: any) {
			alert(e.message || 'Erreur reseau.');
		} finally {
			checkoutLoading = false;
		}
	}

	async function handleChangePassword() {
		changeError = '';

		if (!currentPassword) { changeError = 'Mot de passe actuel requis.'; return; }
		if (newPassword.length < 12) { changeError = 'Min 12 caracteres.'; return; }
		if (!/[A-Z]/.test(newPassword)) { changeError = '1 majuscule requise.'; return; }
		if (!/[0-9]/.test(newPassword)) { changeError = '1 chiffre requis.'; return; }
		if (!/[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/\\]/.test(newPassword)) { changeError = '1 caractere special requis.'; return; }
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
				changeError = result.error || 'Echec du changement.';
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
	<title>Parametres — FyxxVault</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
	<h1 class="text-2xl font-extrabold text-white mb-8 tracking-tight">Parametres</h1>

	<!-- Account info card with avatar -->
	<div class="settings-card p-6 mb-4">
		<div class="flex items-center gap-4 mb-5">
			<div class="settings-avatar w-12 h-12 rounded-full bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center text-lg font-bold text-white">
				{auth.user?.email?.charAt(0).toUpperCase() ?? '?'}
			</div>
			<div class="flex-1">
				<p class="text-sm font-bold text-white">{auth.user?.email ?? ''}</p>
				<span class="inline-flex items-center gap-1.5 mt-1 px-3 py-0.5 rounded-full text-[10px] font-bold {auth.isPro ? 'bg-[var(--fv-gold)]/10 text-[var(--fv-gold)]' : 'bg-white/10 text-[var(--fv-smoke)]'}">
					{auth.isPro ? '&#128081; Plan Pro' : 'Plan Gratuit'}
				</span>
			</div>
		</div>
		<div class="settings-card-border-left" style="background: var(--fv-cyan);"></div>
		<div class="space-y-3">
			<div class="flex items-center justify-between py-2">
				<span class="text-sm text-[var(--fv-smoke)]">Elements</span>
				<span class="text-sm text-white font-semibold tabular-nums">{vault.entries.length}</span>
			</div>
			<div class="settings-separator"></div>
			<div class="flex items-center justify-between py-2">
				<span class="text-sm text-[var(--fv-smoke)]">Chiffrement</span>
				<span class="px-3 py-1 rounded-full bg-[var(--fv-success)]/10 text-xs font-bold text-[var(--fv-success)]">AES-256-GCM</span>
			</div>
		</div>
	</div>

	<!-- Security -->
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: var(--fv-violet);"></div>
		<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
			<div class="w-7 h-7 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			</div>
			Securite
		</h2>

		<!-- Change password -->
		<button
			onclick={() => showChangePassword = !showChangePassword}
			class="w-full flex items-center justify-between p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200"
		>
			<div class="flex items-center gap-3">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<rect x="3" y="11" width="18" height="11" rx="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
				<span class="text-sm text-[var(--fv-mist)]">Changer le mot de passe maitre</span>
			</div>
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"
				class="transition-transform duration-200 {showChangePassword ? 'rotate-180' : ''}">
				<polyline points="6 9 12 15 18 9"/>
			</svg>
		</button>

		{#if showChangePassword}
			<div class="mt-3 p-4 rounded-xl bg-[var(--fv-abyss)]/60 border border-white/[0.06] space-y-3">
				{#if changeSuccess}
					<div class="p-3 rounded-xl bg-[var(--fv-success)]/10 border border-[var(--fv-success)]/20 text-center">
						<p class="text-sm text-[var(--fv-success)]">Mot de passe modifie avec succes !</p>
					</div>
				{:else}
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">Mot de passe actuel</label>
						<input type="password" bind:value={currentPassword} class="settings-input" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">Nouveau mot de passe</label>
						<input type="password" bind:value={newPassword} class="settings-input" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">Confirmer le nouveau mot de passe</label>
						<input type="password" bind:value={confirmNewPassword} class="settings-input" />
					</div>

					{#if changeError}
						<div class="p-2 rounded-lg bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)]">{changeError}</p>
						</div>
					{/if}

					<button onclick={handleChangePassword} disabled={changeLoading} class="fv-btn fv-btn-primary w-full text-sm !py-2.5 !rounded-xl {changeLoading ? 'opacity-60' : ''}">
						{changeLoading ? 'Modification...' : 'Modifier le mot de passe'}
					</button>
				{/if}
			</div>
		{/if}

		<!-- Auto-lock timeout -->
		<div class="mt-2 p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
			<div class="flex items-center justify-between">
				<div class="flex items-center gap-3">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
					<div>
						<span class="text-sm text-[var(--fv-mist)]">Verrouillage automatique</span>
						<p class="text-[10px] text-[var(--fv-ash)]">Verrouille le coffre apres inactivite</p>
					</div>
				</div>
				<select
					value={autoLockTimeout}
					onchange={(e: Event) => saveAutoLockTimeout(parseInt((e.target as HTMLSelectElement).value))}
					class="settings-select"
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
		<div class="p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
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
					class="settings-select"
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
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: var(--fv-cyan);"></div>
		<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
			<div class="w-7 h-7 rounded-lg bg-[var(--fv-cyan)]/15 flex items-center justify-center">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
			</div>
			Donnees
		</h2>

		<!-- Export -->
		<button
			onclick={handleExport}
			disabled={exportLoading}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
				<polyline points="7 10 12 15 17 10"/>
				<line x1="12" y1="15" x2="12" y2="3"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-mist)]">Exporter le coffre (CSV)</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Telecharge toutes tes donnees en clair</p>
			</div>
		</button>

		<!-- Import -->
		<a
			href="/vault/import"
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200 mt-1"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
				<polyline points="17 8 12 3 7 8"/>
				<line x1="12" y1="3" x2="12" y2="15"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-mist)]">Importer des donnees</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Bitwarden, 1Password ou CSV</p>
			</div>
		</a>
	</div>

	<!-- App links -->
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: #3b82f6;"></div>
		<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
			<div class="w-7 h-7 rounded-lg bg-[#3b82f6]/15 flex items-center justify-center">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#3b82f6" stroke-width="2"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>
			</div>
			Applications
		</h2>
		<div class="flex items-center gap-3 p-3 rounded-xl bg-white/[0.03] border border-white/[0.05]">
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
			<span class="px-3 py-1.5 rounded-full bg-white/5 text-[10px] text-[var(--fv-smoke)] font-medium">Bientot</span>
		</div>
	</div>

	<!-- Legal -->
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: var(--fv-smoke);"></div>
		<h2 class="text-sm font-bold text-white mb-4">Informations</h2>
		<div class="space-y-1">
			<a href="/privacy" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
				<span class="text-sm text-[var(--fv-mist)]">Politique de confidentialite</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
			<a href="/terms" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
				<span class="text-sm text-[var(--fv-mist)]">Conditions d'utilisation</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
		</div>
	</div>

	<!-- Danger zone -->
	<div class="settings-card settings-card-danger p-6">
		<div class="settings-card-border-left" style="background: var(--fv-danger);"></div>
		<h2 class="text-sm font-bold text-[var(--fv-danger)] mb-4 flex items-center gap-2">
			<div class="w-7 h-7 rounded-lg bg-[var(--fv-danger)]/15 flex items-center justify-center">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
			</div>
			Zone de danger
		</h2>

		<button
			onclick={handleLogout}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-[var(--fv-danger)]/5 transition-all duration-200"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
				<polyline points="16 17 21 12 16 7"/>
				<line x1="21" y1="12" x2="9" y2="12"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-danger)]">Deconnexion</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Efface le VEK de la memoire et deconnecte</p>
			</div>
		</button>

		<button
			onclick={() => showDeleteAccount = !showDeleteAccount}
			class="w-full flex items-center gap-3 p-3 rounded-xl hover:bg-[var(--fv-danger)]/5 transition-all duration-200 mt-1"
		>
			<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<polyline points="3 6 5 6 21 6"/>
				<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
				<line x1="10" y1="11" x2="10" y2="17"/>
				<line x1="14" y1="11" x2="14" y2="17"/>
			</svg>
			<div class="text-left">
				<span class="text-sm text-[var(--fv-danger)]">Supprimer le compte</span>
				<p class="text-[10px] text-[var(--fv-ash)]">Cette action est irreversible</p>
			</div>
		</button>

		{#if showDeleteAccount}
			<div class="mt-3 p-4 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/20 space-y-3">
				<p class="text-xs text-[var(--fv-danger)]">Cette action supprimera definitivement ton compte et toutes tes donnees. Tape <strong>SUPPRIMER</strong> pour confirmer.</p>
				<input
					type="text"
					bind:value={deleteAccountConfirm}
					placeholder="SUPPRIMER"
					class="settings-input !border-[var(--fv-danger)]/20 focus:!border-[var(--fv-danger)]/50"
				/>
				<button
					onclick={handleDeleteAccount}
					disabled={deleteAccountConfirm !== 'SUPPRIMER'}
					class="w-full py-2.5 rounded-xl bg-[var(--fv-danger)] text-white text-sm font-bold transition-all duration-200 {deleteAccountConfirm !== 'SUPPRIMER' ? 'opacity-40 cursor-not-allowed' : 'hover:bg-[var(--fv-danger)]/80'}"
				>
					Supprimer definitivement
				</button>
			</div>
		{/if}
	</div>

	<!-- Footer -->
	<div class="text-center mt-10 mb-4">
		<p class="text-[10px] text-[var(--fv-ash)]">FyxxVault v1.0.0 — Chiffrement AES-256-GCM, PBKDF2 SHA-256</p>
		<p class="text-[10px] text-[var(--fv-ash)] mt-1">Zero-knowledge: tes donnees ne quittent jamais cet appareil en clair.</p>
	</div>
</div>

<style>
	/* Settings card — glass with colored left border */
	.settings-card {
		position: relative;
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.015));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 20px;
		overflow: hidden;
	}
	.settings-card-danger {
		border-color: rgba(239, 68, 68, 0.1);
	}

	/* Colored left border */
	.settings-card-border-left {
		position: absolute;
		left: 0;
		top: 12px;
		bottom: 12px;
		width: 3px;
		border-radius: 0 3px 3px 0;
		opacity: 0.5;
	}

	/* Avatar glow */
	.settings-avatar {
		box-shadow: 0 0 0 3px rgba(10, 16, 30, 1), 0 0 0 5px rgba(0, 212, 255, 0.3), 0 0 20px rgba(0, 212, 255, 0.1);
		transition: box-shadow 0.3s ease;
	}

	/* Separator line */
	.settings-separator {
		height: 1px;
		background: linear-gradient(90deg, transparent, rgba(255,255,255,0.06), transparent);
	}

	/* Form inputs */
	.settings-input {
		width: 100%;
		padding: 10px 14px;
		border-radius: 12px;
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.08);
		color: white;
		font-size: 14px;
		outline: none;
		transition: all 0.25s ease;
	}
	.settings-input:focus {
		border-color: rgba(0, 212, 255, 0.4);
		box-shadow: 0 0 0 3px rgba(0,212,255,0.12);
	}

	/* Select dropdowns */
	.settings-select {
		padding: 8px 12px;
		border-radius: 10px;
		background: rgba(255,255,255,0.05);
		border: 1px solid rgba(255,255,255,0.08);
		color: white;
		font-size: 12px;
		outline: none;
		transition: all 0.2s ease;
		cursor: pointer;
	}
	.settings-select:focus {
		border-color: rgba(0, 212, 255, 0.3);
	}
</style>
