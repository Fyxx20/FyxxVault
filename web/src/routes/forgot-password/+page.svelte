<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';
	import { t } from '$lib/i18n.svelte';

	let email = $state('');
	let loading = $state(false);
	let error = $state('');
	let success = $state('');
	const PROD_RESET_URL = 'https://fyxxvault.com/reset-password';

	async function sendResetEmail() {
		error = '';
		success = '';

		const trimmed = email.trim().toLowerCase();
		if (!trimmed) {
			error = t('forgot.email_required');
			return;
		}

		loading = true;
		try {
			const isLocalHost = ['localhost', '127.0.0.1'].includes(window.location.hostname);
			const redirectTo = isLocalHost ? `${window.location.origin}/reset-password` : PROD_RESET_URL;
			const { error: resetError } = await supabase.auth.resetPasswordForEmail(trimmed, { redirectTo });

			if (resetError) {
				error = resetError.message;
			} else {
				success = t('forgot.success');
			}
		} catch (e: any) {
			error = e?.message || t('login.error.generic');
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>{t('forgot.title')} — FyxxVault</title>
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
			<h1 class="text-2xl font-bold text-white">{t('forgot.heading')}</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">{t('forgot.subtitle')}</p>
		</div>

		<div class="fv-glass p-8 fv-animate-in" style="animation-delay: 100ms;">
			<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); sendResetEmail(); }} class="space-y-4">
				<div>
					<label for="email" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">{t('login.email_placeholder')}</label>
					<input
						id="email"
						type="email"
						bind:value={email}
						placeholder="ton@email.com"
						class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
					/>
				</div>

				<div class="p-3 rounded-xl bg-[var(--fv-gold)]/8 border border-[var(--fv-gold)]/20">
					<p class="text-xs text-[var(--fv-smoke)] leading-relaxed">
						{t('forgot.warning')}
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
						{t('forgot.sending')}
					{:else}
						{t('forgot.send')}
					{/if}
				</button>
			</form>

			<p class="text-center text-sm text-[var(--fv-smoke)] mt-6">
				<a href="/login" class="text-[var(--fv-cyan)] font-semibold hover:underline transition-colors duration-200">
					{t('forgot.back')}
				</a>
			</p>
		</div>
	</div>
</div>
