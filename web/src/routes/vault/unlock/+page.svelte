<script lang="ts">
	import { goto } from '$app/navigation';
	import { getAuthState, unlockVault, initAuth } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let masterPassword = $state('');
	let loading = $state(false);
	let error = $state('');

	// Initialize auth listener
	initAuth();

	// Redirect if not authenticated
	$effect(() => {
		if (!auth.loading && !auth.isAuthenticated) {
			goto('/login');
		}
	});

	// Redirect if already unlocked
	$effect(() => {
		if (auth.isUnlocked) {
			goto('/vault');
		}
	});

	async function handleUnlock() {
		error = '';
		if (!masterPassword) {
			error = 'Mot de passe maître requis.';
			return;
		}

		loading = true;

		try {
			const result = await unlockVault(masterPassword);
			if (result.success) {
				goto('/vault');
			} else {
				error = result.error || 'Échec du déverrouillage.';
			}
		} catch (e: any) {
			error = e.message || 'Erreur inconnue.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Déverrouiller — FyxxVault</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center px-6 py-20">
	<!-- Background orbs -->
	<div class="fixed inset-0 overflow-hidden pointer-events-none">
		<div class="absolute top-1/3 left-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-cyan)] opacity-[0.05] blur-[120px]"></div>
		<div class="absolute bottom-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-violet)] opacity-[0.05] blur-[120px]"></div>
	</div>

	<div class="relative z-10 w-full max-w-md">
		<!-- Logo -->
		<div class="text-center mb-8">
			<div class="inline-flex items-center gap-3 mb-6">
				<div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20">
					<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
			</div>
			<h1 class="text-2xl font-bold text-white">Déverrouiller ton coffre</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">
				Connecté en tant que <span class="text-[var(--fv-cyan)]">{auth.user?.email ?? ''}</span>
			</p>
		</div>

		<!-- Unlock form -->
		<div class="fv-glass p-8">
			<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleUnlock(); }} class="space-y-5">
				<!-- Lock icon -->
				<div class="flex justify-center mb-2">
					<div class="w-20 h-20 rounded-full bg-white/5 border border-white/10 flex items-center justify-center">
						<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
							<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
							<circle cx="12" cy="16" r="1"/>
						</svg>
					</div>
				</div>

				<!-- Master password -->
				<div>
					<label for="master-password" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe maître</label>
					<input
						id="master-password"
						type="password"
						bind:value={masterPassword}
						placeholder="••••••••••••"
						autofocus
						class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Error -->
				{#if error}
					<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
						<p class="text-sm text-[var(--fv-danger)]">{error}</p>
					</div>
				{/if}

				<!-- Submit -->
				<button type="submit" disabled={loading} class="fv-btn fv-btn-primary w-full !py-4 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
					{#if loading}
						<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
						Déverrouillage...
					{:else}
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
						Déverrouiller
					{/if}
				</button>
			</form>

			<p class="text-center text-xs text-[var(--fv-ash)] mt-5">
				Le déchiffrement se fait localement. Ton mot de passe ne quitte jamais cet appareil.
			</p>
		</div>
	</div>
</div>
