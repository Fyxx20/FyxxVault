<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';
	import { deriveKEK, generateSalt, generateVEK, wrapVEK } from '$lib/crypto';
	import { onMount } from 'svelte';
	import { t } from '$lib/i18n.svelte';

	let newPassword = $state('');
	let confirmPassword = $state('');
	let loading = $state(false);
	let checkingLink = $state(true);
	let validRecoverySession = $state(false);
	let error = $state('');
	let success = $state('');

	function encodeToSupabaseBytes(bytes: Uint8Array): string {
		const hex = Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
		return '\\x' + hex;
	}

	async function ensureRecoverySession() {
		try {
			const hashParams = new URLSearchParams(window.location.hash.replace(/^#/, ''));
			const accessToken = hashParams.get('access_token');
			const refreshToken = hashParams.get('refresh_token');

			if (accessToken && refreshToken) {
				await supabase.auth.setSession({
					access_token: accessToken,
					refresh_token: refreshToken
				});
			}

			const { data: { session } } = await supabase.auth.getSession();
			validRecoverySession = !!session;
		} catch {
			validRecoverySession = false;
		} finally {
			checkingLink = false;
		}
	}

	async function rebuildVaultForRecoveredAccount(userId: string, password: string) {
		const salt = generateSalt();
		const rounds = 210_000;
		const vek = generateVEK();
		const kek = await deriveKEK(password, salt, rounds);
		const wrappedVek = await wrapVEK(vek, kek);

		const { error: upsertError } = await supabase.from('profiles').upsert({
			id: userId,
			wrapped_vek: encodeToSupabaseBytes(wrappedVek),
			vek_salt: encodeToSupabaseBytes(salt),
			vek_rounds: rounds,
			updated_at: new Date().toISOString()
		});
		if (upsertError) throw upsertError;

		// Zero-knowledge: old encrypted entries cannot be decrypted with the new master password.
		const { error: deleteError } = await supabase
			.from('vault_items')
			.delete()
			.eq('user_id', userId);
		if (deleteError) throw deleteError;
	}

	async function handleResetPassword() {
		error = '';
		success = '';

		if (!newPassword || !confirmPassword) {
			error = t('reset.error.fields_required');
			return;
		}

		if (newPassword.length < 12) {
			error = t('reset.error.min_length');
			return;
		}

		if (newPassword !== confirmPassword) {
			error = t('reset.error.mismatch');
			return;
		}

		loading = true;
		try {
			const { data: { session } } = await supabase.auth.getSession();
			if (!session?.user?.id) {
				error = t('reset.error.invalid_link');
				loading = false;
				return;
			}

			const { error: updateError } = await supabase.auth.updateUser({ password: newPassword });
			if (updateError) {
				error = updateError.message;
				loading = false;
				return;
			}

			await rebuildVaultForRecoveredAccount(session.user.id, newPassword);
			success = t('reset.success');

			await supabase.auth.signOut();
			setTimeout(() => goto('/login'), 1200);
		} catch (e: any) {
			error = e?.message || t('reset.error.generic');
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		ensureRecoverySession();
	});
</script>

<svelte:head>
	<title>{t('reset.title')} — FyxxVault</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center px-6 py-20">
	<div class="fixed inset-0 overflow-hidden pointer-events-none">
		<div class="absolute top-1/3 left-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-cyan)] opacity-[0.05] blur-[120px]"></div>
		<div class="absolute bottom-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-violet)] opacity-[0.05] blur-[120px]"></div>
	</div>

	<div class="relative z-10 w-full max-w-md">
		<div class="text-center mb-8 fv-animate-in">
			<a href="/" class="inline-flex items-center gap-3 mb-6">
				<div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20 fv-shield-pulse">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
				</div>
				<span class="text-2xl font-extrabold text-white">FyxxVault</span>
			</a>
			<h1 class="text-2xl font-bold text-white">{t('reset.title')}</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">{t('reset.subtitle')}</p>
		</div>

		<div class="fv-glass p-8 fv-animate-in" style="animation-delay: 100ms;">
			{#if checkingLink}
				<div class="flex items-center justify-center py-8">
					<div class="w-7 h-7 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
				</div>
			{:else if !validRecoverySession}
				<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 mb-4">
					<p class="text-sm text-[var(--fv-danger)]">{t('reset.error.invalid_link')}</p>
				</div>
				<button onclick={() => goto('/forgot-password')} class="fv-btn fv-btn-primary w-full !py-4">
					{t('reset.request_new')}
				</button>
			{:else}
				<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleResetPassword(); }} class="space-y-4">
					<div>
						<label for="newPassword" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">{t('reset.new_password')}</label>
						<input
							id="newPassword"
							type="password"
							bind:value={newPassword}
							placeholder={t('reset.min_chars')}
							class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
						/>
					</div>

					<div>
						<label for="confirmPassword" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">{t('reset.confirm')}</label>
						<input
							id="confirmPassword"
							type="password"
							bind:value={confirmPassword}
							placeholder={t('reset.confirm_placeholder')}
							class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
						/>
					</div>

					<div class="p-3 rounded-xl bg-[var(--fv-gold)]/8 border border-[var(--fv-gold)]/20">
						<p class="text-xs text-[var(--fv-smoke)] leading-relaxed">
							{t('reset.warning')}
						</p>
					</div>

					{#if error}
						<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-sm text-[var(--fv-danger)]">{error}</p>
						</div>
					{/if}

					{#if success}
						<div class="p-3 rounded-xl bg-[var(--fv-success)]/10 border border-[var(--fv-success)]/20">
							<p class="text-sm text-[var(--fv-success)]">{success}</p>
						</div>
					{/if}

					<button type="submit" disabled={loading} class="fv-btn fv-btn-primary w-full !py-4 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
						{#if loading}
							<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
							{t('reset.submitting')}
						{:else}
							{t('reset.submit')}
						{/if}
					</button>
				</form>
			{/if}
		</div>
	</div>
</div>
