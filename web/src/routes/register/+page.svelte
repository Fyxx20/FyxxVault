<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';

	let email = $state('');
	let password = $state('');
	let confirmPassword = $state('');
	let loading = $state(false);
	let error = $state('');
	let success = $state(false);

	const requirements = $derived([
		{ label: '12 caractères minimum', met: password.length >= 12 },
		{ label: '1 majuscule', met: /[A-Z]/.test(password) },
		{ label: '1 chiffre', met: /[0-9]/.test(password) },
		{ label: '1 caractère spécial', met: /[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/\\]/.test(password) }
	]);

	const allRequirementsMet = $derived(requirements.every(r => r.met));

	async function handleRegister() {
		error = '';

		if (!email.trim()) { error = 'Email requis.'; return; }
		if (!allRequirementsMet) { error = 'Le mot de passe ne respecte pas les exigences.'; return; }
		if (password !== confirmPassword) { error = 'Les mots de passe ne correspondent pas.'; return; }

		loading = true;

		try {
			const { error: authError } = await supabase.auth.signUp({
				email: email.trim().toLowerCase(),
				password
			});

			if (authError) {
				error = authError.message;
			} else {
				success = true;
			}
		} catch (e: any) {
			error = e.message || 'Une erreur est survenue.';
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Créer un compte — FyxxVault</title>
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
			<h1 class="text-2xl font-bold text-white">Créer ton compte</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">Essai gratuit 14 jours — sans carte bancaire</p>
		</div>

		{#if success}
			<!-- Success state -->
			<div class="fv-glass p-8 text-center fv-glow-cyan">
				<div class="w-16 h-16 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
					<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
				</div>
				<h2 class="text-xl font-bold text-white mb-2">Compte créé !</h2>
				<p class="text-sm text-[var(--fv-mist)] mb-6">Vérifie tes emails pour confirmer ton adresse, puis connecte-toi.</p>
				<a href="/login" class="fv-btn fv-btn-primary w-full">Se connecter</a>
			</div>
		{:else}
			<!-- Register form -->
			<div class="fv-glass p-8">
				<!-- Tags -->
				<div class="flex items-center justify-center gap-2 mb-6">
					<span class="px-3 py-1 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-[10px] font-bold">AES-256</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet)] text-[10px] font-bold">MFA</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-success)]/10 text-[var(--fv-success)] text-[10px] font-bold">E2E</span>
				</div>

				<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleRegister(); }} class="space-y-4">
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

					<!-- Requirements -->
					{#if password.length > 0}
						<div class="p-3 rounded-xl bg-[var(--fv-abyss)]/60 space-y-1.5">
							{#each requirements as req}
								<div class="flex items-center gap-2 text-xs">
									<div class="w-4 h-4 rounded-full flex items-center justify-center {req.met ? 'bg-[var(--fv-success)]/20' : 'bg-white/5'}">
										{#if req.met}
											<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<div class="w-1.5 h-1.5 rounded-full bg-[var(--fv-ash)]"></div>
										{/if}
									</div>
									<span class="{req.met ? 'text-[var(--fv-success)]' : 'text-[var(--fv-smoke)]'}">{req.label}</span>
								</div>
							{/each}
						</div>
					{/if}

					<!-- Confirm Password -->
					<div>
						<label for="confirm" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Confirmer le mot de passe</label>
						<input
							id="confirm"
							type="password"
							bind:value={confirmPassword}
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
							Création...
						{:else}
							Créer mon compte
						{/if}
					</button>
				</form>

				<!-- Login link -->
				<p class="text-center text-sm text-[var(--fv-smoke)] mt-6">
					Déjà un compte ? <a href="/login" class="text-[var(--fv-cyan)] font-semibold hover:underline">Se connecter</a>
				</p>
			</div>
		{/if}

		<!-- Footer -->
		<p class="text-center text-xs text-[var(--fv-ash)] mt-8">
			Chiffrement local, connexion sécurisée, sans compromis.
		</p>
	</div>
</div>
