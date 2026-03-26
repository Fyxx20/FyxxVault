<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';

	let email = $state('');
	let password = $state('');
	let loading = $state(false);
	let error = $state('');
	let errorKey = $state(0);

	async function handleLogin() {
		error = '';
		if (!email.trim() || !password) { error = 'Email et mot de passe requis.'; errorKey++; return; }

		loading = true;

		try {
			const { error: authError } = await supabase.auth.signInWithPassword({
				email: email.trim().toLowerCase(),
				password
			});

			if (authError) {
				error = authError.message === 'Invalid login credentials'
					? 'Email ou mot de passe incorrect.'
					: authError.message;
				errorKey++;
			} else {
				goto('/vault/unlock');
			}
		} catch (e: any) {
			error = e.message || 'Une erreur est survenue.';
			errorKey++;
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Connexion — FyxxVault</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center px-6 py-20">
	<!-- Background orbs -->
	<div class="fixed inset-0 overflow-hidden pointer-events-none">
		<div class="absolute top-1/3 left-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-cyan)] opacity-[0.05] blur-[120px]"></div>
		<div class="absolute bottom-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-violet)] opacity-[0.05] blur-[120px]"></div>
	</div>

	<div class="relative z-10 w-full max-w-md">
		<!-- Logo + shield -->
		<div class="text-center mb-8 fv-animate-in">
			<a href="/" class="inline-flex items-center gap-3 mb-6">
				<div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20 fv-shield-pulse">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
				</div>
				<span class="text-2xl font-extrabold text-white">FyxxVault</span>
			</a>
			<h1 class="text-2xl font-bold text-white">Connexion</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">Accède à ton coffre sécurisé</p>
		</div>

		<!-- Login form -->
		<div class="fv-glass p-8 fv-animate-in" style="animation-delay: 100ms;">
			<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleLogin(); }} class="space-y-4">
				<!-- Email -->
				<div>
					<label for="email" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Email</label>
					<input
						id="email"
						type="email"
						bind:value={email}
						placeholder="ton@email.com"
						class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
					/>
				</div>

				<!-- Password -->
				<div>
					<label for="password" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe</label>
					<input
						id="password"
						type="password"
						bind:value={password}
						placeholder="••••••••••••"
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
						Connexion...
					{:else}
						Se connecter
					{/if}
				</button>
			</form>

			<!-- Register link -->
			<p class="text-center text-sm text-[var(--fv-smoke)] mt-6">
				Pas encore de compte ? <a href="/register" class="text-[var(--fv-cyan)] font-semibold hover:underline transition-colors duration-200">Créer un compte</a>
			</p>
		</div>

		<!-- Footer -->
		<p class="text-center text-[10px] text-[var(--fv-ash)]/60 mt-8 flex items-center justify-center gap-1.5 fv-animate-in" style="animation-delay: 200ms;">
			<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			Chiffrement local AES-256 &middot; Connexion sécurisée
		</p>
	</div>
</div>
