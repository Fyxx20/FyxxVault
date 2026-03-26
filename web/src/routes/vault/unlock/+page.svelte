<script lang="ts">
	import { goto } from '$app/navigation';
	import { getAuthState, unlockVault, initAuth } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let masterPassword = $state('');
	let loading = $state(false);
	let error = $state('');
	let unlockSuccess = $state(false);
	let errorKey = $state(0);

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
			errorKey++;
			return;
		}

		loading = true;

		try {
			const result = await unlockVault(masterPassword);
			if (result.success) {
				unlockSuccess = true;
				setTimeout(() => goto('/vault'), 800);
			} else {
				error = result.error || 'Échec du déverrouillage.';
				errorKey++;
			}
		} catch (e: any) {
			if (e?.message?.includes('Web Crypto API')) {
				error = 'Web Crypto API non disponible. Utilise HTTPS ou localhost.';
			} else if (e?.name === 'OperationError' || e?.message?.includes('decrypt') || e?.message?.includes('importKey')) {
				error = 'Mot de passe incorrect ou erreur de déchiffrement.';
			} else {
				error = e.message || 'Erreur inconnue.';
			}
			errorKey++;
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
		<div class="text-center mb-8 fv-animate-in">
			<div class="inline-flex items-center gap-3 mb-6">
				<div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20 fv-shield-pulse">
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

		{#if unlockSuccess}
			<!-- Success animation -->
			<div class="fv-glass p-8 text-center fv-glow-cyan fv-animate-in">
				<div class="w-20 h-20 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
					<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
				</div>
				<p class="text-white font-semibold text-lg">Coffre déverrouillé</p>
				<p class="text-sm text-[var(--fv-smoke)] mt-1">Redirection en cours...</p>
			</div>
		{:else}
			<!-- Unlock form -->
			<div class="fv-glass p-8 fv-animate-in" style="animation-delay: 100ms;">
				<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleUnlock(); }} class="space-y-5">
					<!-- Lock icon -->
					<div class="flex justify-center mb-2">
						<div class="w-20 h-20 rounded-full bg-white/5 border border-white/10 flex items-center justify-center fv-lock-bounce">
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
							class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
						/>
					</div>

					<!-- Error -->
					{#if error}
						{#key errorKey}
							<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 fv-shake">
								<p class="text-sm text-[var(--fv-danger)] flex items-center gap-2">
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
									{error}
								</p>
							</div>
						{/key}
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
		{/if}

		<!-- Powered by footer -->
		<p class="text-center text-[10px] text-[var(--fv-ash)]/60 mt-8 flex items-center justify-center gap-1.5">
			<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			Powered by AES-256-GCM
		</p>
	</div>
</div>
