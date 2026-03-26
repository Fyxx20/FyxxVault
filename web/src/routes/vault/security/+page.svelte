<script lang="ts">
	import { getVaultState, getSecurityStats, loadEntries } from '$lib/stores/vault.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { passwordStrength } from '$lib/crypto';
	import { CATEGORY_META } from '$lib/types';

	const vault = getVaultState();
	const auth = getAuthState();

	// Ensure entries are loaded
	$effect(() => {
		if (auth.isUnlocked && vault.entries.length === 0 && !vault.loading) {
			loadEntries();
		}
	});

	const stats = $derived(getSecurityStats());

	// Animated score
	let displayScore = $state(0);
	$effect(() => {
		const target = stats.score;
		const interval = setInterval(() => {
			if (displayScore < target) {
				displayScore = Math.min(displayScore + 2, target);
			} else if (displayScore > target) {
				displayScore = Math.max(displayScore - 2, target);
			} else {
				clearInterval(interval);
			}
		}, 20);
		return () => clearInterval(interval);
	});

	function scoreColor(score: number): string {
		if (score >= 80) return 'var(--fv-success)';
		if (score >= 60) return 'var(--fv-cyan)';
		if (score >= 40) return 'var(--fv-gold)';
		return 'var(--fv-danger)';
	}

	function scoreLabel(score: number): string {
		if (score >= 80) return 'Excellent';
		if (score >= 60) return 'Bon';
		if (score >= 40) return 'Moyen';
		return 'Faible';
	}

	// SVG circle params
	const radius = 70;
	const circumference = 2 * Math.PI * radius;
	const offset = $derived(circumference - (displayScore / 100) * circumference);

	// Weak entries detail
	const weakEntries = $derived(
		vault.entries.filter((e) => e.password && passwordStrength(e.password).score < 40)
	);

	const reusedPasswords = $derived(() => {
		const counts = new Map<string, string[]>();
		for (const e of vault.entries) {
			if (!e.password) continue;
			const existing = counts.get(e.password) ?? [];
			existing.push(e.title);
			counts.set(e.password, existing);
		}
		return Array.from(counts.entries()).filter(([_, titles]) => titles.length > 1);
	});

	const recommendations = $derived(() => {
		const recs: { icon: string; text: string; severity: 'danger' | 'warning' | 'info' }[] = [];
		if (stats.weak > 0) recs.push({ icon: '⚠️', text: `${stats.weak} mot${stats.weak > 1 ? 's' : ''} de passe faible${stats.weak > 1 ? 's' : ''} — remplace-les par des mots de passe générés.`, severity: 'danger' });
		if (stats.reused > 0) recs.push({ icon: '🔄', text: `${stats.reused} mot${stats.reused > 1 ? 's' : ''} de passe réutilisé${stats.reused > 1 ? 's' : ''} — utilise un mot de passe unique par compte.`, severity: 'danger' });
		if (stats.noMfa > 0) recs.push({ icon: '🔐', text: `${stats.noMfa} compte${stats.noMfa > 1 ? 's' : ''} sans MFA — active l'authentification à deux facteurs.`, severity: 'warning' });
		if (stats.expired > 0) recs.push({ icon: '⏳', text: `${stats.expired} mot${stats.expired > 1 ? 's' : ''} de passe non modifié${stats.expired > 1 ? 's' : ''} depuis 6 mois.`, severity: 'info' });
		if (recs.length === 0) recs.push({ icon: '✅', text: 'Ton coffre est bien sécurisé. Continue comme ça !', severity: 'info' });
		return recs;
	});
</script>

<svelte:head>
	<title>Sécurité — FyxxVault</title>
</svelte:head>

<div class="max-w-3xl mx-auto">
	<h1 class="text-2xl font-bold text-white mb-6">Tableau de sécurité</h1>

	<!-- Score gauge -->
	<div class="fv-glass p-8 mb-6 flex flex-col items-center">
		<div class="relative w-[180px] h-[180px] mb-4">
			<svg width="180" height="180" viewBox="0 0 180 180" class="-rotate-90">
				<!-- Background circle -->
				<circle
					cx="90" cy="90" r={radius}
					fill="none"
					stroke="rgba(255,255,255,0.05)"
					stroke-width="10"
				/>
				<!-- Score arc -->
				<circle
					cx="90" cy="90" r={radius}
					fill="none"
					stroke={scoreColor(displayScore)}
					stroke-width="10"
					stroke-linecap="round"
					stroke-dasharray={circumference}
					stroke-dashoffset={offset}
					class="transition-all duration-300"
				/>
			</svg>
			<!-- Score text -->
			<div class="absolute inset-0 flex flex-col items-center justify-center">
				<span class="text-4xl font-extrabold text-white">{displayScore}</span>
				<span class="text-xs font-semibold mt-1" style="color: {scoreColor(displayScore)};">{scoreLabel(displayScore)}</span>
			</div>
		</div>
		<p class="text-sm text-[var(--fv-smoke)]">Score de sécurité global</p>
	</div>

	<!-- Stats grid -->
	<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
		<div class="fv-glass p-4 text-center">
			<p class="text-2xl font-bold" style="color: {stats.weak > 0 ? 'var(--fv-danger)' : 'var(--fv-success)'};">{stats.weak}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Faibles</p>
		</div>
		<div class="fv-glass p-4 text-center">
			<p class="text-2xl font-bold" style="color: {stats.reused > 0 ? 'var(--fv-danger)' : 'var(--fv-success)'};">{stats.reused}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Réutilisés</p>
		</div>
		<div class="fv-glass p-4 text-center">
			<p class="text-2xl font-bold" style="color: {stats.noMfa > 0 ? 'var(--fv-gold)' : 'var(--fv-success)'};">{stats.noMfa}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Sans MFA</p>
		</div>
		<div class="fv-glass p-4 text-center">
			<p class="text-2xl font-bold" style="color: {stats.expired > 0 ? 'var(--fv-gold)' : 'var(--fv-success)'};">{stats.expired}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Expirés</p>
		</div>
	</div>

	<!-- Recommendations -->
	<div class="fv-glass p-5 mb-6">
		<h2 class="text-sm font-bold text-white mb-4">Recommandations</h2>
		<div class="space-y-3">
			{#each recommendations() as rec}
				<div class="flex items-start gap-3 p-3 rounded-xl
					{rec.severity === 'danger' ? 'bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10' :
					 rec.severity === 'warning' ? 'bg-[var(--fv-gold)]/5 border border-[var(--fv-gold)]/10' :
					 'bg-white/5 border border-white/5'}">
					<span class="text-base shrink-0">{rec.icon}</span>
					<p class="text-xs text-[var(--fv-mist)] leading-relaxed">{rec.text}</p>
				</div>
			{/each}
		</div>
	</div>

	<!-- Weak entries list -->
	{#if weakEntries.length > 0}
		<div class="fv-glass p-5">
			<h2 class="text-sm font-bold text-white mb-4">Mots de passe faibles</h2>
			<div class="space-y-2">
				{#each weakEntries as entry}
					{@const s = passwordStrength(entry.password)}
					<a href="/vault/add?edit={entry.id}" class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/10 transition-colors">
						<span class="text-base">{CATEGORY_META[entry.category]?.icon ?? '📦'}</span>
						<div class="flex-1 min-w-0">
							<p class="text-sm text-white truncate">{entry.title}</p>
							<p class="text-[10px] text-[var(--fv-smoke)]">{entry.username}</p>
						</div>
						<div class="flex items-center gap-2">
							<div class="w-16 h-1 rounded-full bg-white/5 overflow-hidden">
								<div class="h-full rounded-full" style="width: {s.score}%; background: {s.color};"></div>
							</div>
							<span class="text-[10px] font-semibold" style="color: {s.color};">{s.label}</span>
						</div>
					</a>
				{/each}
			</div>
		</div>
	{/if}
</div>
