<script lang="ts">
	import { getVaultState, getSecurityStats, loadEntries } from '$lib/stores/vault.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { passwordStrength } from '$lib/crypto';
	import { CATEGORY_META } from '$lib/types';
	import { checkPasswordsBatch } from '$lib/hibp';

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

	// HIBP state
	let hibpScanning = $state(false);
	let hibpProgress = $state(0);
	let hibpTotal = $state(0);
	let hibpResults = $state<Map<string, number>>(new Map());
	let hibpDone = $state(false);

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
		if (hibpDone && hibpResults.size > 0) recs.push({ icon: '🌐', text: `${hibpResults.size} mot${hibpResults.size > 1 ? 's' : ''} de passe compromis${hibpResults.size > 1 ? '' : ''} trouvé${hibpResults.size > 1 ? 's' : ''} dans des fuites de données — change-les immédiatement.`, severity: 'danger' });
		if (stats.noMfa > 0) recs.push({ icon: '🔐', text: `${stats.noMfa} compte${stats.noMfa > 1 ? 's' : ''} sans MFA — active l'authentification à deux facteurs.`, severity: 'warning' });
		if (stats.expired > 0) recs.push({ icon: '⏳', text: `${stats.expired} mot${stats.expired > 1 ? 's' : ''} de passe non modifié${stats.expired > 1 ? 's' : ''} depuis 6 mois.`, severity: 'info' });
		if (recs.length === 0) recs.push({ icon: '✅', text: 'Ton coffre est bien sécurisé. Continue comme ça !', severity: 'info' });
		return recs;
	});

	async function startHIBPScan() {
		const entries = vault.entries.filter(e => e.password);
		if (entries.length === 0) return;

		hibpScanning = true;
		hibpDone = false;
		hibpProgress = 0;
		hibpTotal = entries.length;

		try {
			const results = await checkPasswordsBatch(
				entries.map(e => ({ id: e.id, password: e.password })),
				(checked, total) => {
					hibpProgress = checked;
					hibpTotal = total;
				}
			);
			hibpResults = results;
		} catch (e) {
			console.error('HIBP scan failed:', e);
		} finally {
			hibpScanning = false;
			hibpDone = true;
		}
	}

	function getBreachedEntries() {
		return vault.entries.filter(e => hibpResults.has(e.id));
	}

	// Animated stat counters
	let displayWeak = $state(0);
	let displayReused = $state(0);
	let displayNoMfa = $state(0);
	let displayExpired = $state(0);
	let statsAnimated = $state(false);

	$effect(() => {
		if (statsAnimated) return;
		if (vault.entries.length > 0 || stats.score > 0) {
			statsAnimated = true;
			animateCounter((v) => displayWeak = v, stats.weak, 600);
			animateCounter((v) => displayReused = v, stats.reused, 700);
			animateCounter((v) => displayNoMfa = v, stats.noMfa, 800);
			animateCounter((v) => displayExpired = v, stats.expired, 900);
		}
	});

	function animateCounter(setter: (v: number) => void, target: number, duration: number) {
		if (target === 0) { setter(0); return; }
		const start = performance.now();
		function tick(now: number) {
			const elapsed = now - start;
			const progress = Math.min(elapsed / duration, 1);
			const eased = 1 - Math.pow(1 - progress, 3);
			setter(Math.round(eased * target));
			if (progress < 1) requestAnimationFrame(tick);
		}
		requestAnimationFrame(tick);
	}

	// Last scan timestamp
	let lastScanTime = $state('');
	$effect(() => {
		if (hibpDone) {
			lastScanTime = new Date().toLocaleString('fr-FR', {
				day: '2-digit', month: 'short', year: 'numeric',
				hour: '2-digit', minute: '2-digit'
			});
		}
	});
</script>

<svelte:head>
	<title>Sécurité — FyxxVault</title>
</svelte:head>

<div class="max-w-3xl mx-auto">
	<h1 class="text-2xl font-bold text-white mb-6">Tableau de sécurité</h1>

	<!-- Score gauge -->
	<div class="fv-glass p-8 mb-6 flex flex-col items-center fv-animate-in">
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
					style="transition: stroke-dashoffset 0.8s cubic-bezier(0.4, 0, 0.2, 1), stroke 0.4s ease;"
				/>
			</svg>
			<!-- Score text -->
			<div class="absolute inset-0 flex flex-col items-center justify-center">
				<span class="text-4xl font-extrabold text-white fv-count-up">{displayScore}</span>
				<span class="text-xs font-semibold mt-1 transition-colors duration-300" style="color: {scoreColor(displayScore)};">{scoreLabel(displayScore)}</span>
			</div>
		</div>
		<p class="text-sm text-[var(--fv-smoke)]">Score de sécurité global</p>
	</div>

	<!-- Stats grid -->
	<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
		<div class="fv-glass p-4 text-center fv-animate-in" style="animation-delay: 100ms;">
			<p class="text-2xl font-bold tabular-nums" style="color: {stats.weak > 0 ? 'var(--fv-danger)' : 'var(--fv-success)'};">{displayWeak}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Faibles</p>
		</div>
		<div class="fv-glass p-4 text-center fv-animate-in" style="animation-delay: 150ms;">
			<p class="text-2xl font-bold tabular-nums" style="color: {stats.reused > 0 ? 'var(--fv-danger)' : 'var(--fv-success)'};">{displayReused}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Réutilisés</p>
		</div>
		<div class="fv-glass p-4 text-center fv-animate-in" style="animation-delay: 200ms;">
			<p class="text-2xl font-bold tabular-nums" style="color: {stats.noMfa > 0 ? 'var(--fv-gold)' : 'var(--fv-success)'};">{displayNoMfa}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Sans MFA</p>
		</div>
		<div class="fv-glass p-4 text-center fv-animate-in" style="animation-delay: 250ms;">
			<p class="text-2xl font-bold tabular-nums" style="color: {stats.expired > 0 ? 'var(--fv-gold)' : 'var(--fv-success)'};">{displayExpired}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Expirés</p>
		</div>
	</div>

	<!-- Dark Web Monitoring (HIBP) — Pro only -->
	{#if !auth.isPro}
	<div class="fv-glass p-5 mb-6 opacity-70">
		<div class="flex items-center gap-3 mb-3">
			<span class="text-lg">🌐</span>
			<div>
				<h2 class="text-sm font-bold text-white">Surveillance Dark Web</h2>
				<p class="text-[10px] text-[var(--fv-smoke)]">Vérifie si tes mots de passe sont dans des fuites</p>
			</div>
		</div>
		<div class="p-4 rounded-xl bg-[var(--fv-gold)]/5 border border-[var(--fv-gold)]/20 flex items-center gap-3">
			<span>👑</span>
			<div class="flex-1">
				<p class="text-xs font-semibold text-[var(--fv-gold)]">Fonctionnalité Pro</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">Passe au plan Pro pour scanner le dark web</p>
			</div>
			<a href="/vault/settings" class="px-3 py-1.5 rounded-lg bg-[var(--fv-gold)] text-[#1a1a2e] text-[10px] font-bold">Upgrade</a>
		</div>
	</div>
	{:else}
	<div class="fv-glass p-5 mb-6">
		<div class="flex items-center justify-between mb-4">
			<div class="flex items-center gap-3">
				<div class="w-8 h-8 rounded-lg bg-[var(--fv-danger)]/15 flex items-center justify-center">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>
				</div>
				<div>
					<h2 class="text-sm font-bold text-white">Surveillance Dark Web</h2>
					<p class="text-[10px] text-[var(--fv-smoke)]">Vérifie si tes mots de passe sont dans des fuites de données (HIBP)</p>
				</div>
			</div>
			{#if !hibpScanning}
				<button
					onclick={startHIBPScan}
					class="fv-btn fv-btn-primary text-xs !py-2 !px-4"
					disabled={vault.entries.length === 0}
				>
					{hibpDone ? 'Rescanner' : 'Scanner'}
				</button>
			{/if}
		</div>

		{#if hibpScanning}
			<!-- Progress bar -->
			<div class="space-y-2">
				<div class="flex items-center justify-between text-xs text-[var(--fv-smoke)]">
					<span>Vérification en cours...</span>
					<span>{hibpProgress}/{hibpTotal}</span>
				</div>
				<div class="h-2 rounded-full bg-white/5 overflow-hidden">
					<div
						class="h-full rounded-full bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] transition-all duration-300"
						style="width: {hibpTotal > 0 ? (hibpProgress / hibpTotal * 100) : 0}%;"
					></div>
				</div>
				<p class="text-[10px] text-[var(--fv-ash)]">Les mots de passe sont vérifiés de manière anonyme (k-anonymity). Seuls les 5 premiers caractères du hash SHA-1 sont envoyés.</p>
			</div>
		{:else if hibpDone}
			{#if hibpResults.size === 0}
				<div class="p-4 rounded-xl bg-[var(--fv-success)]/5 border border-[var(--fv-success)]/10 text-center">
					<p class="text-sm text-[var(--fv-success)] font-medium">Aucun mot de passe compromis trouvé !</p>
					<p class="text-[10px] text-[var(--fv-smoke)] mt-1">Tes mots de passe n'apparaissent dans aucune fuite de données connue.</p>
				</div>
			{:else}
				<div class="space-y-2">
					<div class="p-3 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10 mb-3">
						<p class="text-xs text-[var(--fv-danger)] font-semibold">{hibpResults.size} mot{hibpResults.size > 1 ? 's' : ''} de passe compromis</p>
						<p class="text-[10px] text-[var(--fv-smoke)] mt-0.5">Ces mots de passe apparaissent dans des fuites de données. Change-les immédiatement.</p>
					</div>
					{#if lastScanTime}
					<p class="text-[10px] text-[var(--fv-ash)] mb-3">Dernière analyse : {lastScanTime}</p>
				{/if}
				{#each getBreachedEntries() as entry}
						{@const count = hibpResults.get(entry.id) ?? 0}
						<a href="/vault/add?edit={entry.id}" class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/10 transition-colors fv-pulse-danger">
							<span class="text-base">{CATEGORY_META[entry.category]?.icon ?? '📦'}</span>
							<div class="flex-1 min-w-0">
								<p class="text-sm text-white truncate">{entry.title}</p>
								<p class="text-[10px] text-[var(--fv-smoke)]">{entry.username}</p>
							</div>
							<span class="px-2 py-1 rounded-full bg-[var(--fv-danger)]/10 text-[10px] text-[var(--fv-danger)] font-semibold shrink-0">
								{count.toLocaleString()} fuite{count > 1 ? 's' : ''}
							</span>
						</a>
					{/each}
				</div>
			{/if}
		{:else}
			<p class="text-xs text-[var(--fv-ash)] text-center py-2">Clique sur "Scanner" pour vérifier tes mots de passe.</p>
		{/if}
	</div>
	{/if}

	<!-- Recommendations -->
	<div class="fv-glass p-5 mb-6 fv-animate-in" style="animation-delay: 300ms;">
		<h2 class="text-sm font-bold text-white mb-4">Recommandations</h2>
		<div class="space-y-3">
			{#each recommendations() as rec, idx}
				<div class="flex items-start gap-3 p-3 rounded-xl transition-all duration-200 hover:translate-x-1 fv-animate-in
					{rec.severity === 'danger' ? 'bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10' :
					 rec.severity === 'warning' ? 'bg-[var(--fv-gold)]/5 border border-[var(--fv-gold)]/10' :
					 'bg-white/5 border border-white/5'}"
					style="animation-delay: {350 + idx * 80}ms;"
				>
					<div class="w-7 h-7 rounded-lg flex items-center justify-center shrink-0
						{rec.severity === 'danger' ? 'bg-[var(--fv-danger)]/15' :
						 rec.severity === 'warning' ? 'bg-[var(--fv-gold)]/15' :
						 'bg-[var(--fv-success)]/15'}">
						<span class="text-sm">{rec.icon}</span>
					</div>
					<div class="flex-1">
						<p class="text-xs text-[var(--fv-mist)] leading-relaxed">{rec.text}</p>
					</div>
					{#if rec.severity === 'danger'}
						<span class="text-[9px] px-2 py-0.5 rounded-full bg-[var(--fv-danger)]/15 text-[var(--fv-danger)] font-bold shrink-0 uppercase">Critique</span>
					{:else if rec.severity === 'warning'}
						<span class="text-[9px] px-2 py-0.5 rounded-full bg-[var(--fv-gold)]/15 text-[var(--fv-gold)] font-bold shrink-0 uppercase">Moyen</span>
					{:else}
						<span class="text-[9px] px-2 py-0.5 rounded-full bg-[var(--fv-success)]/15 text-[var(--fv-success)] font-bold shrink-0 uppercase">Info</span>
					{/if}
				</div>
			{/each}
		</div>
	</div>

	<!-- Reused passwords section -->
	{#if reusedPasswords().length > 0}
		<div class="fv-glass p-5 mb-6">
			<h2 class="text-sm font-bold text-white mb-4">Mots de passe réutilisés</h2>
			<div class="space-y-3">
				{#each reusedPasswords() as [_, titles]}
					<div class="p-3 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10">
						<p class="text-xs text-[var(--fv-danger)] font-medium mb-1">Même mot de passe partagé par :</p>
						<div class="flex flex-wrap gap-1.5">
							{#each titles as title}
								<span class="px-2 py-0.5 rounded bg-white/5 text-[10px] text-[var(--fv-smoke)]">{title}</span>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/if}

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
