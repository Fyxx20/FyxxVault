<script lang="ts">
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';
	import { passwordStrength } from '$lib/crypto';

	let email = $state('');
	let password = $state('');
	let confirmPassword = $state('');
	let loading = $state(false);
	let error = $state('');
	let success = $state(false);
	let errorKey = $state(0);

	const requirements = $derived([
		{ label: '12 caractères minimum', met: password.length >= 12 },
		{ label: '1 majuscule', met: /[A-Z]/.test(password) },
		{ label: '1 chiffre', met: /[0-9]/.test(password) },
		{ label: '1 caractère spécial', met: /[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/\\]/.test(password) }
	]);

	const allRequirementsMet = $derived(requirements.every(r => r.met));
	const strength = $derived(password.length > 0 ? passwordStrength(password) : null);

	async function handleRegister() {
		error = '';

		if (!email.trim()) { error = 'Email requis.'; errorKey++; return; }
		if (!allRequirementsMet) { error = 'Le mot de passe ne respecte pas les exigences.'; errorKey++; return; }
		if (password !== confirmPassword) { error = 'Les mots de passe ne correspondent pas.'; errorKey++; return; }

		loading = true;

		try {
			const { error: authError } = await supabase.auth.signUp({
				email: email.trim().toLowerCase(),
				password
			});

			if (authError) {
				error = authError.message;
				errorKey++;
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
		<!-- Logo + shield -->
		<div class="text-center mb-8 fv-animate-in">
			<a href="/" class="inline-flex items-center gap-3 mb-6">
				<div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20 fv-shield-pulse">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
				</div>
				<span class="text-2xl font-extrabold text-white">FyxxVault</span>
			</a>
			<h1 class="text-2xl font-bold text-white">Créer ton compte</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">Essai gratuit 14 jours — sans carte bancaire</p>
		</div>

		{#if success}
			<!-- Success state -->
			<div class="fv-glass p-8 text-center fv-glow-cyan fv-animate-in">
				<div class="w-16 h-16 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
					<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
				</div>
				<h2 class="text-xl font-bold text-white mb-2">Compte créé !</h2>
				<p class="text-sm text-[var(--fv-mist)] mb-6">Vérifie tes emails pour confirmer ton adresse, puis connecte-toi.</p>
				<a href="/login" class="fv-btn fv-btn-primary w-full">Se connecter</a>
			</div>
		{:else}
			<!-- Register form -->
			<div class="fv-glass p-8 fv-animate-in" style="animation-delay: 100ms;">
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
							class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
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
							class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300"
						/>
					</div>

					<!-- Password strength bar -->
					{#if strength}
						<div class="flex items-center gap-2">
							<div class="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
								<div class="h-full rounded-full" style="width: {strength.score}%; background: {strength.color}; transition: width 0.5s cubic-bezier(0.4, 0, 0.2, 1), background-color 0.4s ease;"></div>
							</div>
							<span class="text-[10px] font-semibold transition-colors duration-300" style="color: {strength.color};">{strength.label}</span>
						</div>
					{/if}

					<!-- Requirements -->
					{#if password.length > 0}
						<div class="p-3 rounded-xl bg-[var(--fv-abyss)]/60 space-y-1.5">
							{#each requirements as req}
								<div class="flex items-center gap-2 text-xs transition-all duration-200">
									<div class="w-4 h-4 rounded-full flex items-center justify-center transition-colors duration-200 {req.met ? 'bg-[var(--fv-success)]/20' : 'bg-white/5'}">
										{#if req.met}
											<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
										{:else}
											<div class="w-1.5 h-1.5 rounded-full bg-[var(--fv-ash)]"></div>
										{/if}
									</div>
									<span class="transition-colors duration-200 {req.met ? 'text-[var(--fv-success)]' : 'text-[var(--fv-smoke)]'}">{req.label}</span>
								</div>
							{/each}
						</div>
					{/if}

					<!-- Confirm Password -->
					<div>
						<label for="confirm" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Confirmer le mot de passe</label>
						<div class="relative">
							<input
								id="confirm"
								type="password"
								bind:value={confirmPassword}
								placeholder="••••••••••••"
								class="w-full px-4 py-3.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none fv-input-glow transition-all duration-300
									{confirmPassword && confirmPassword === password ? '!border-[var(--fv-success)]/40' : ''}"
							/>
							{#if confirmPassword && confirmPassword === password}
								<div class="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--fv-success)]">
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
								</div>
							{/if}
						</div>
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
							Création...
						{:else}
							Créer mon compte
						{/if}
					</button>
				</form>

				<!-- Login link -->
				<p class="text-center text-sm text-[var(--fv-smoke)] mt-6">
					Déjà un compte ? <a href="/login" class="text-[var(--fv-cyan)] font-semibold hover:underline transition-colors duration-200">Se connecter</a>
				</p>
			</div>
		{/if}

		<!-- Footer -->
		<p class="text-center text-[10px] text-[var(--fv-ash)]/60 mt-8 flex items-center justify-center gap-1.5 fv-animate-in" style="animation-delay: 200ms;">
			<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			Chiffrement local AES-256 &middot; Connexion sécurisée
		</p>
	</div>
</div>
