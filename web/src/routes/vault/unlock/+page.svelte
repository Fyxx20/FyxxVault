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
			error = 'Mot de passe maitre requis.';
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
				error = result.error || 'Echec du deverrouillage.';
				errorKey++;
			}
		} catch (e: any) {
			if (e?.message?.includes('Web Crypto API')) {
				error = 'Web Crypto API non disponible. Utilise HTTPS ou localhost.';
			} else if (e?.name === 'OperationError' || e?.message?.includes('decrypt') || e?.message?.includes('importKey')) {
				error = 'Mot de passe incorrect ou erreur de dechiffrement.';
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
	<title>Deverrouiller — FyxxVault</title>
</svelte:head>

<div class="unlock-page min-h-screen flex items-center justify-center px-6 py-20">
	<!-- Animated gradient mesh background -->
	<div class="unlock-bg-mesh"></div>

	<!-- Background orbs -->
	<div class="fixed inset-0 overflow-hidden pointer-events-none">
		<div class="unlock-orb unlock-orb-1"></div>
		<div class="unlock-orb unlock-orb-2"></div>
	</div>

	<div class="relative z-10 w-full max-w-[440px]">
		<!-- Logo -->
		<div class="text-center mb-8 fv-animate-in">
			<div class="inline-flex items-center gap-3 mb-6">
				<div class="unlock-logo-icon w-16 h-16 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
					<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
			</div>
			<h1 class="text-2xl font-extrabold text-white tracking-tight">Deverrouiller ton coffre</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">
				Connecte en tant que <span class="text-[var(--fv-cyan)]">{auth.user?.email ?? ''}</span>
			</p>
		</div>

		{#if unlockSuccess}
			<!-- Success animation -->
			<div class="unlock-card p-8 text-center fv-glow-cyan fv-animate-in">
				<div class="w-20 h-20 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
					<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
				</div>
				<p class="text-white font-semibold text-lg">Coffre deverrouille</p>
				<p class="text-sm text-[var(--fv-smoke)] mt-1">Redirection en cours...</p>
			</div>
		{:else}
			<!-- Unlock form -->
			<div class="unlock-card p-8 fv-animate-in" style="animation-delay: 100ms;">
				<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleUnlock(); }} class="space-y-5">
					<!-- Lock icon with animated glow ring -->
					<div class="flex justify-center mb-4">
						<div class="unlock-lock-icon w-20 h-20 rounded-full flex items-center justify-center">
							<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
								<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
								<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
								<circle cx="12" cy="16" r="1"/>
							</svg>
						</div>
					</div>

					<!-- Master password -->
					<div>
						<label for="master-password" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe maitre</label>
						<input
							id="master-password"
							type="password"
							bind:value={masterPassword}
							placeholder="••••••••••••"
							autofocus
							class="unlock-input w-full px-4 py-4 rounded-2xl text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none transition-all duration-300"
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
					<button type="submit" disabled={loading} class="unlock-submit-btn w-full py-4 rounded-2xl text-white font-bold text-sm flex items-center justify-center gap-2 transition-all duration-250 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
						{#if loading}
							<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
							Deverrouillage...
						{:else}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
							Deverrouiller
						{/if}
					</button>
				</form>

				<p class="text-center text-xs text-[var(--fv-ash)] mt-5">
					Le dechiffrement se fait localement. Ton mot de passe ne quitte jamais cet appareil.
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

<style>
	/* Page background */
	.unlock-page {
		position: relative;
		background: var(--fv-abyss);
		overflow: hidden;
	}

	/* Animated gradient mesh */
	.unlock-bg-mesh {
		position: fixed;
		inset: 0;
		background:
			radial-gradient(ellipse 80% 60% at 30% 20%, rgba(0,212,255,0.05), transparent 50%),
			radial-gradient(ellipse 60% 80% at 70% 80%, rgba(138,92,246,0.05), transparent 50%);
		background-size: 200% 200%;
		animation: meshShift 15s ease-in-out infinite alternate;
		pointer-events: none;
	}
	@keyframes meshShift {
		0% { background-position: 0% 0%, 100% 100%; }
		100% { background-position: 100% 100%, 0% 0%; }
	}

	/* Background orbs */
	.unlock-orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(120px);
		pointer-events: none;
	}
	.unlock-orb-1 {
		top: 25%;
		left: 20%;
		width: 400px;
		height: 400px;
		background: var(--fv-cyan);
		opacity: 0.06;
		animation: orbFloat 20s ease-in-out infinite alternate;
	}
	.unlock-orb-2 {
		bottom: 25%;
		right: 20%;
		width: 400px;
		height: 400px;
		background: var(--fv-violet);
		opacity: 0.06;
		animation: orbFloat 20s ease-in-out infinite alternate-reverse;
	}
	@keyframes orbFloat {
		0% { transform: translate(0, 0); }
		100% { transform: translate(30px, -20px); }
	}

	/* Logo icon with glow */
	.unlock-logo-icon {
		box-shadow: 0 0 30px rgba(0, 212, 255, 0.25), 0 0 60px rgba(138, 92, 246, 0.15);
		animation: logoGlow 3s ease-in-out infinite;
	}
	@keyframes logoGlow {
		0%, 100% { box-shadow: 0 0 30px rgba(0, 212, 255, 0.25), 0 0 60px rgba(138, 92, 246, 0.15); transform: scale(1); }
		50% { box-shadow: 0 0 40px rgba(0, 212, 255, 0.35), 0 0 80px rgba(138, 92, 246, 0.2); transform: scale(1.03); }
	}

	/* Unlock card glass */
	.unlock-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 24px;
		box-shadow: 0 16px 64px rgba(0,0,0,0.3);
	}

	/* Lock icon with pulse glow ring */
	.unlock-lock-icon {
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.08);
		box-shadow: 0 0 0 0 rgba(0, 212, 255, 0.2);
		animation: lockPulseRing 3s ease-in-out infinite;
	}
	@keyframes lockPulseRing {
		0%, 100% { box-shadow: 0 0 0 0 rgba(0, 212, 255, 0.15), 0 0 20px rgba(0, 212, 255, 0.05); }
		50% { box-shadow: 0 0 0 12px rgba(0, 212, 255, 0.05), 0 0 30px rgba(0, 212, 255, 0.1); }
	}

	/* Input with cyan glow on focus */
	.unlock-input {
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.1);
	}
	.unlock-input:focus {
		border-color: rgba(0, 212, 255, 0.5);
		box-shadow: 0 0 0 3px rgba(0,212,255,0.15), 0 0 24px rgba(0,212,255,0.08);
		background: rgba(255,255,255,0.06);
	}

	/* Submit button: gradient with shimmer */
	.unlock-submit-btn {
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		position: relative;
		overflow: hidden;
	}
	.unlock-submit-btn::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.15) 50%, transparent 60%);
		background-size: 200% 100%;
		animation: shimmer 3s ease-in-out infinite;
	}
	@keyframes shimmer {
		0% { background-position: 200% 0; }
		100% { background-position: -200% 0; }
	}
	.unlock-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 30px rgba(0, 212, 255, 0.3);
	}
</style>
