<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getAuthState, logout, changeMasterPassword } from '$lib/stores/auth.svelte';
	import { exportCSV, resetVault, getVaultState } from '$lib/stores/vault.svelte';
	import { t } from '$lib/i18n.svelte';

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

	async function handleChangePassword() {
		changeError = '';

		if (!currentPassword) { changeError = t('settings.error.current_required'); return; }
		if (newPassword.length < 12) { changeError = t('settings.error.min_chars'); return; }
		if (!/[A-Z]/.test(newPassword)) { changeError = t('settings.error.uppercase'); return; }
		if (!/[0-9]/.test(newPassword)) { changeError = t('settings.error.digit'); return; }
		if (!/[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/\\]/.test(newPassword)) { changeError = t('settings.error.special'); return; }
		if (newPassword !== confirmNewPassword) { changeError = t('settings.error.match'); return; }

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
				changeError = result.error || t('settings.error.change_failed');
			}
		} catch (e: any) {
			changeError = e.message || t('settings.error.unknown');
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
	<title>{t('settings.page_title')}</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
	<h1 class="text-2xl font-extrabold text-white mb-8 tracking-tight">{t('settings.title')}</h1>
	{#if false}
		<div class="mb-4 p-3 rounded-xl bg-[var(--fv-gold)]/10 border border-[var(--fv-gold)]/25">
			<p class="text-xs text-[var(--fv-gold)] font-medium">{proSyncMessage}</p>
		</div>
	{/if}

	<!-- Account info card with avatar -->
	<div class="settings-card p-6 mb-4">
		<div class="flex items-center gap-4 mb-5">
			<div class="settings-avatar w-12 h-12 rounded-full bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center text-lg font-bold text-white">
				{auth.user?.email?.charAt(0).toUpperCase() ?? '?'}
			</div>
			<div class="flex-1">
				<p class="text-sm font-bold text-white">{auth.user?.email ?? ''}</p>
				<div class="flex items-center gap-2 mt-1 flex-wrap">
					<span class="inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full text-[10px] font-bold bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)]">
						100% Gratuit
					</span>
				</div>
			</div>
		</div>
		<div class="settings-card-border-left" style="background: var(--fv-cyan);"></div>
		<div class="space-y-3">
			<div class="flex items-center justify-between py-2">
				<span class="text-sm text-[var(--fv-smoke)]">{t('settings.entries')}</span>
				<span class="text-sm text-white font-semibold tabular-nums">{vault.entries.length}</span>
			</div>
			<div class="settings-separator"></div>
			<div class="flex items-center justify-between py-2">
				<span class="text-sm text-[var(--fv-smoke)]">{t('settings.encryption')}</span>
				<span class="px-3 py-1 rounded-full bg-[var(--fv-success)]/10 text-xs font-bold text-[var(--fv-success)]">AES-256-GCM</span>
			</div>
		</div>
	</div>

	<!-- Plan info (removed - all free now) -->
	{#if false}
	<div class="settings-card p-6 mb-4 hidden">
		<div class="settings-card-border-left" style="background: var(--fv-cyan);"></div>
		<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
			Plan
			{t('settings.section.subscription')}
		</h2>

		{#if auth.isPro}
			<!-- Pro user: manage subscription -->
			<div class="p-4 rounded-xl bg-[var(--fv-gold)]/[0.04] border border-[var(--fv-gold)]/10 mb-4">
				<div class="flex items-center justify-between mb-1">
					<span class="text-sm font-bold text-[var(--fv-gold)]">{'\u{1F451}'} FyxxVault Pro</span>
					<span class="px-2.5 py-0.5 rounded-full bg-[var(--fv-success)]/10 text-[10px] font-bold text-[var(--fv-success)]">{t('common.active')}</span>
				</div>
				<p class="text-[11px] text-[var(--fv-smoke)]">{t('settings.pro_desc')}</p>
			</div>

			<div>
				<button
					onclick={handleManageBilling}
					disabled={billingLoading}
					class="w-full settings-sub-action p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200"
				>
					<div class="settings-sub-left">
						<div class="settings-sub-icon">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
						</div>
						<div class="settings-sub-text">
							<span class="settings-sub-title">{billingLoading ? t('common.loading') : t('settings.payment_method')}</span>
							<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.update_card')}</p>
						</div>
					</div>
					<svg class="shrink-0" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
				</button>

				<button
					onclick={handleManageBilling}
					disabled={billingLoading}
					class="w-full settings-sub-action p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200"
				>
					<div class="settings-sub-left">
						<div class="settings-sub-icon">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
						</div>
						<div class="settings-sub-text">
							<span class="settings-sub-title">{t('settings.change_plan')}</span>
							<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.change_plan_desc')}</p>
						</div>
					</div>
					<svg class="shrink-0" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
				</button>

				<button
					onclick={handleManageBilling}
					disabled={billingLoading}
					class="w-full settings-sub-action p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200"
				>
					<div class="settings-sub-left">
						<div class="settings-sub-icon">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>
						</div>
						<div class="settings-sub-text">
							<span class="settings-sub-title">{t('settings.invoices')}</span>
							<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.invoices_desc')}</p>
						</div>
					</div>
					<svg class="shrink-0" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
				</button>

				<div class="settings-separator my-2"></div>

				<button
					onclick={handleManageBilling}
					disabled={billingLoading}
					class="w-full settings-sub-action p-3 rounded-xl hover:bg-[var(--fv-danger)]/[0.04] transition-all duration-200 group"
				>
					<div class="settings-sub-left">
						<div class="settings-sub-icon">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2" opacity="0.7"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
						</div>
						<div class="settings-sub-text">
							<span class="settings-sub-title text-[var(--fv-smoke)] group-hover:text-[var(--fv-danger)] transition-colors">{t('settings.cancel_sub')}</span>
						</div>
					</div>
					<svg class="shrink-0" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><path d="M9 18l6-6-6-6"/></svg>
				</button>
			</div>
		{:else}
			<!-- Free user: upgrade prompt -->
			<div class="p-4 rounded-xl bg-white/[0.02] border border-white/[0.06] mb-4">
				<div class="flex items-center justify-between mb-1">
					<span class="text-sm font-bold text-[var(--fv-smoke)]">{t('settings.plan_free')}</span>
					<span class="px-2.5 py-0.5 rounded-full bg-white/10 text-[10px] font-bold text-[var(--fv-ash)]">{t('settings.free_limit')}</span>
				</div>
				<p class="text-[11px] text-[var(--fv-ash)]">{t('settings.upgrade_prompt')}</p>
			</div>

			<div class="space-y-3">
				<!-- Plan selector -->
				<div class="flex gap-2">
					<button
						onclick={() => selectedPlan = 'monthly'}
						class="flex-1 p-3 rounded-xl text-center transition-all duration-200 {selectedPlan === 'monthly' ? 'bg-[var(--fv-gold)]/10 border border-[var(--fv-gold)]/30 text-[var(--fv-gold)]' : 'bg-white/[0.03] border border-white/[0.06] text-[var(--fv-smoke)]'}"
					>
						<div class="text-lg font-extrabold">4,99{'\u20AC'}</div>
						<div class="text-[10px] font-medium opacity-70">{t('settings.per_month')}</div>
					</button>
					<button
						onclick={() => selectedPlan = 'yearly'}
						class="flex-1 p-3 rounded-xl text-center transition-all duration-200 relative {selectedPlan === 'yearly' ? 'bg-[var(--fv-gold)]/10 border border-[var(--fv-gold)]/30 text-[var(--fv-gold)]' : 'bg-white/[0.03] border border-white/[0.06] text-[var(--fv-smoke)]'}"
					>
						<span class="absolute -top-2 right-2 px-2 py-0.5 rounded-full bg-[var(--fv-success)] text-[8px] font-bold text-[#050a15]">{t('settings.discount')}</span>
						<div class="text-lg font-extrabold">49,99{'\u20AC'}</div>
						<div class="text-[10px] font-medium opacity-70">{t('settings.per_year')}</div>
					</button>
				</div>

				<!-- Features included -->
				<div class="space-y-2 px-1">
					{#each [t('settings.feature.unlimited'), t('settings.feature.dark_web'), t('settings.feature.emails'), t('settings.feature.sharing'), t('settings.feature.support')] as feature}
						<div class="flex items-center gap-2">
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
							<span class="text-xs text-[var(--fv-smoke)]">{feature}</span>
						</div>
					{/each}
				</div>

				<button
					onclick={handleCheckout}
					disabled={checkoutLoading}
					class="w-full py-3 rounded-xl text-sm font-bold transition-all duration-200 {checkoutLoading ? 'opacity-60' : 'hover:translate-y-[-1px] hover:shadow-lg hover:shadow-[var(--fv-gold)]/20'}"
					style="background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light, #ffda6b)); color: #1a1a2e;"
				>
					{checkoutLoading ? t('settings.redirecting') : selectedPlan === 'monthly' ? t('settings.upgrade_monthly') : t('settings.upgrade_yearly')}
				</button>
			</div>
		{/if}
	</div>
	{/if}

	<!-- Security -->
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: var(--fv-violet);"></div>
		<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
			<div class="w-7 h-7 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			</div>
			{t('settings.section.security')}
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
				<span class="text-sm text-[var(--fv-mist)]">{t('settings.change_password')}</span>
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
						<p class="text-sm text-[var(--fv-success)]">{t('settings.password_changed')}</p>
					</div>
				{:else}
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">{t('settings.current_password')}</label>
						<input type="password" bind:value={currentPassword} class="settings-input" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">{t('settings.new_password')}</label>
						<input type="password" bind:value={newPassword} class="settings-input" />
					</div>
					<div>
						<label class="block text-xs text-[var(--fv-smoke)] mb-1.5 font-medium">{t('settings.confirm_password')}</label>
						<input type="password" bind:value={confirmNewPassword} class="settings-input" />
					</div>

					{#if changeError}
						<div class="p-2 rounded-lg bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)]">{changeError}</p>
						</div>
					{/if}

					<button onclick={handleChangePassword} disabled={changeLoading} class="fv-btn fv-btn-primary w-full text-sm !py-2.5 !rounded-xl {changeLoading ? 'opacity-60' : ''}">
						{changeLoading ? t('settings.updating') : t('settings.update_password')}
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
						<span class="text-sm text-[var(--fv-mist)]">{t('settings.auto_lock')}</span>
						<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.auto_lock_desc')}</p>
					</div>
				</div>
				<select
					value={autoLockTimeout}
					onchange={(e: Event) => saveAutoLockTimeout(parseInt((e.target as HTMLSelectElement).value))}
					class="settings-select"
				>
					<option value={1}>{t('settings.auto_lock_1min')}</option>
					<option value={5}>{t('settings.auto_lock_5min')}</option>
					<option value={15}>{t('settings.auto_lock_15min')}</option>
					<option value={30}>{t('settings.auto_lock_30min')}</option>
					<option value={60}>{t('settings.auto_lock_1h')}</option>
					<option value={0}>{t('settings.auto_lock_never')}</option>
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
			{t('settings.section.data')}
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
				<span class="text-sm text-[var(--fv-mist)]">{t('settings.export')}</span>
				<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.export_desc')}</p>
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
				<span class="text-sm text-[var(--fv-mist)]">{t('settings.import')}</span>
				<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.import_desc')}</p>
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
			{t('settings.section.apps')}
		</h2>
		<div class="flex items-center gap-3 p-3 rounded-xl bg-white/[0.03] border border-white/[0.05]">
			<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
					<rect x="5" y="2" width="14" height="20" rx="2" ry="2"/>
					<line x1="12" y1="18" x2="12.01" y2="18"/>
				</svg>
			</div>
			<div class="flex-1">
				<p class="text-sm text-white font-medium">{t('settings.ios_app')}</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">{t('settings.ios_features')}</p>
			</div>
			<span class="px-3 py-1.5 rounded-full bg-white/5 text-[10px] text-[var(--fv-smoke)] font-medium">{t('common.coming_soon')}</span>
		</div>
	</div>

	<!-- Legal -->
	<div class="settings-card p-6 mb-4">
		<div class="settings-card-border-left" style="background: var(--fv-smoke);"></div>
		<h2 class="text-sm font-bold text-white mb-4">{t('settings.section.info')}</h2>
		<div class="space-y-1">
			<a href="/privacy" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
				<span class="text-sm text-[var(--fv-mist)]">{t('settings.privacy')}</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
			<a href="/terms" class="flex items-center justify-between p-3 rounded-xl hover:bg-white/[0.04] transition-all duration-200">
				<span class="text-sm text-[var(--fv-mist)]">{t('settings.terms')}</span>
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
			</a>
		</div>
	</div>


	<!-- Footer -->
	<div class="text-center mt-10 mb-4">
		<p class="text-[10px] text-[var(--fv-ash)]">{t('settings.version')}</p>
		<p class="text-[10px] text-[var(--fv-ash)] mt-1">{t('settings.zero_knowledge')}</p>
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

	/* Subscription action rows (fixed alignment) */
	.settings-sub-action {
		display: grid;
		grid-template-columns: 1fr auto;
		align-items: center;
		column-gap: 12px;
	}
	.settings-sub-left {
		display: grid;
		grid-template-columns: 20px minmax(0, 1fr);
		align-items: center;
		column-gap: 12px;
		min-width: 0;
	}
	.settings-sub-icon {
		width: 20px;
		height: 20px;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
	}
	.settings-sub-text {
		min-width: 0;
		text-align: left;
	}
	.settings-sub-title {
		display: block;
		font-size: 14px;
		color: var(--fv-mist);
	}
</style>
