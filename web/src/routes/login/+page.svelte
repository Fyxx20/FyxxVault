<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';

	let email = $state('');
	let password = $state('');
	let loading = $state(false);
	let error = $state('');

	async function handleLogin() {
		error = '';
		if (!email.trim() || !password) { error = 'Email et mot de passe requis.'; return; }

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
			} else {
				goto('/vault/unlock');
			}
		} catch (e: any) {
			error = e.message || 'Une erreur est survenue.';
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
		<!-- Logo -->
		<div class="text-center mb-8">
			<a href="/" class="inline-flex items-center gap-3 mb-6">
				<div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
				</div>
				<span class="text-2xl font-extrabold text-white">FyxxVault</span>
			</a>
			<h1 class="text-2xl font-bold text-white">Connexion</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">Accède à ton coffre sécurisé</p>
		</div>

		<!-- Login form -->
		<div class="fv-glass p-8">
			<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleLogin(); }} class="space-y-4">
				<!-- Email -->
				<div>
					<label for="email" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Email</label>
					<input
						id="email"
						type="email"
						bind:value={email}
						placeholder="ton@email.com"
						class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
					/>
				</div>

				<!-- Password -->
				<div>
					<label for="password" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe maître</label>
					<input
						id="password"
						type="password"
						bind:value={password}
						placeholder="••••••••••••"
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
						Connexion...
					{:else}
						Se connecter
					{/if}
				</button>
			</form>

			<!-- Register link -->
			<p class="text-center text-sm text-[var(--fv-smoke)] mt-6">
				Pas encore de compte ? <a href="/register" class="text-[var(--fv-cyan)] font-semibold hover:underline">Créer un compte</a>
			</p>
		</div>

		<!-- Footer -->
		<p class="text-center text-xs text-[var(--fv-ash)] mt-8">
			Chiffrement local, connexion sécurisée, sans compromis.
		</p>
	</div>
</div>
