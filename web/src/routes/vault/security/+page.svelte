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

	// SVG circle params — larger gauge
	const radius = 85;
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
		if (stats.weak > 0) recs.push({ icon: '&#9888;&#65039;', text: `${stats.weak} mot${stats.weak > 1 ? 's' : ''} de passe faible${stats.weak > 1 ? 's' : ''} — remplace-les par des mots de passe generes.`, severity: 'danger' });
		if (stats.reused > 0) recs.push({ icon: '&#128260;', text: `${stats.reused} mot${stats.reused > 1 ? 's' : ''} de passe reutilise${stats.reused > 1 ? 's' : ''} — utilise un mot de passe unique par compte.`, severity: 'danger' });
		if (hibpDone && hibpResults.size > 0) recs.push({ icon: '&#127760;', text: `${hibpResults.size} mot${hibpResults.size > 1 ? 's' : ''} de passe compromis trouve${hibpResults.size > 1 ? 's' : ''} dans des fuites de donnees — change-les immediatement.`, severity: 'danger' });
		if (stats.noMfa > 0) recs.push({ icon: '&#128274;', text: `${stats.noMfa} compte${stats.noMfa > 1 ? 's' : ''} sans MFA — active l'authentification a deux facteurs.`, severity: 'warning' });
		if (stats.expired > 0) recs.push({ icon: '&#9203;', text: `${stats.expired} mot${stats.expired > 1 ? 's' : ''} de passe non modifie${stats.expired > 1 ? 's' : ''} depuis 6 mois.`, severity: 'info' });
		if (recs.length === 0) recs.push({ icon: '&#9989;', text: 'Ton coffre est bien securise. Continue comme ca !', severity: 'info' });
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

	const statCards = $derived([
		{ label: 'Faibles', value: displayWeak, real: stats.weak, color: stats.weak > 0 ? 'var(--fv-danger)' : 'var(--fv-success)', icon: 'alert' },
		{ label: 'Reutilises', value: displayReused, real: stats.reused, color: stats.reused > 0 ? 'var(--fv-danger)' : 'var(--fv-success)', icon: 'repeat' },
		{ label: 'Sans MFA', value: displayNoMfa, real: stats.noMfa, color: stats.noMfa > 0 ? 'var(--fv-gold)' : 'var(--fv-success)', icon: 'shield' },
		{ label: 'Expires', value: displayExpired, real: stats.expired, color: stats.expired > 0 ? 'var(--fv-gold)' : 'var(--fv-success)', icon: 'clock' }
	]);
</script>

<svelte:head>
	<title>Securite — FyxxVault</title>
</svelte:head>

<div class="security-page max-w-3xl mx-auto">
	<!-- Subtle mesh background -->
	<div class="security-mesh"></div>

	<h1 class="text-2xl font-extrabold text-white mb-8 tracking-tight relative z-10">Tableau de securite</h1>

	<!-- Score gauge — larger -->
	<div class="score-gauge-card p-8 mb-8 flex flex-col items-center fv-animate-in relative z-10">
		<div class="relative w-[200px] h-[200px] mb-4">
			<svg width="200" height="200" viewBox="0 0 200 200" class="-rotate-90">
				<!-- Background circle -->
				<circle
					cx="100" cy="100" r={radius}
					fill="none"
					stroke="rgba(255,255,255,0.04)"
					stroke-width="12"
				/>
				<!-- Score arc with gradient -->
				<circle
					cx="100" cy="100" r={radius}
					fill="none"
					stroke={scoreColor(displayScore)}
					stroke-width="12"
					stroke-linecap="round"
					stroke-dasharray={circumference}
					stroke-dashoffset={offset}
					class="score-arc"
				/>
			</svg>
			<!-- Glow ring behind arc -->
			<div class="score-glow" style="--score-color: {scoreColor(displayScore)};"></div>
			<!-- Score text -->
			<div class="absolute inset-0 flex flex-col items-center justify-center">
				<span class="text-5xl font-extrabold text-white fv-count-up tabular-nums">{displayScore}</span>
				<span class="text-sm font-bold mt-1 transition-colors duration-300" style="color: {scoreColor(displayScore)};">{scoreLabel(displayScore)}</span>
			</div>
		</div>
		<p class="text-sm text-[var(--fv-smoke)]">Score de securite global</p>
	</div>

	<!-- Stats grid — bento style -->
	<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-8 relative z-10">
		{#each statCards as stat, idx}
			<div class="stat-card fv-animate-in" style="animation-delay: {100 + idx * 50}ms; --stat-color: {stat.color};">
				<div class="stat-card-border"></div>
				<div class="stat-card-icon" style="background: {stat.color}15;">
					{#if stat.icon === 'alert'}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={stat.color} stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
					{:else if stat.icon === 'repeat'}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={stat.color} stroke-width="2"><polyline points="17 1 21 5 17 9"/><path d="M3 11V9a4 4 0 0 1 4-4h14"/><polyline points="7 23 3 19 7 15"/><path d="M21 13v2a4 4 0 0 1-4 4H3"/></svg>
					{:else if stat.icon === 'shield'}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={stat.color} stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
					{:else}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={stat.color} stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
					{/if}
				</div>
				<p class="text-2xl font-extrabold tabular-nums mt-2" style="color: {stat.color};">{stat.value}</p>
				<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1 font-semibold">{stat.label}</p>
			</div>
		{/each}
	</div>

	<!-- Dark Web Monitoring (HIBP) — Pro only -->
	{#if !auth.isPro}
	<div class="sec-glass-card p-6 mb-6 opacity-70 relative z-10">
		<div class="flex items-center gap-3 mb-3">
			<div class="w-9 h-9 rounded-xl bg-[var(--fv-danger)]/10 flex items-center justify-center">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>
			</div>
			<div>
				<h2 class="text-sm font-bold text-white">Surveillance Dark Web</h2>
				<p class="text-[10px] text-[var(--fv-smoke)]">Verifie si tes mots de passe sont dans des fuites</p>
			</div>
		</div>
		<div class="p-4 rounded-xl bg-[var(--fv-gold)]/5 border border-[var(--fv-gold)]/20 flex items-center gap-3">
			<span>&#128081;</span>
			<div class="flex-1">
				<p class="text-xs font-semibold text-[var(--fv-gold)]">Fonctionnalite Pro</p>
				<p class="text-[10px] text-[var(--fv-smoke)]">Passe au plan Pro pour scanner le dark web</p>
			</div>
			<a href="/vault/settings" class="px-3 py-1.5 rounded-lg bg-[var(--fv-gold)] text-[#1a1a2e] text-[10px] font-bold transition-all duration-200 hover:shadow-lg hover:shadow-[var(--fv-gold)]/20">Upgrade</a>
		</div>
	</div>
	{:else}
	<div class="sec-glass-card p-6 mb-6 relative z-10">
		<div class="flex items-center justify-between mb-4">
			<div class="flex items-center gap-3">
				<div class="w-9 h-9 rounded-xl bg-[var(--fv-danger)]/12 flex items-center justify-center">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></svg>
				</div>
				<div>
					<h2 class="text-sm font-bold text-white">Surveillance Dark Web</h2>
					<p class="text-[10px] text-[var(--fv-smoke)]">Verifie si tes mots de passe sont dans des fuites de donnees (HIBP)</p>
				</div>
			</div>
			{#if !hibpScanning}
				<button
					onclick={startHIBPScan}
					class="fv-btn fv-btn-primary text-xs !py-2 !px-4 !rounded-xl"
					disabled={vault.entries.length === 0}
				>
					{hibpDone ? 'Rescanner' : 'Scanner'}
				</button>
			{/if}
		</div>

		{#if hibpScanning}
			<!-- Progress bar with gradient -->
			<div class="space-y-2">
				<div class="flex items-center justify-between text-xs text-[var(--fv-smoke)]">
					<span>Verification en cours...</span>
					<span class="tabular-nums">{hibpProgress}/{hibpTotal}</span>
				</div>
				<div class="h-2.5 rounded-full bg-white/5 overflow-hidden">
					<div
						class="h-full rounded-full bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] transition-all duration-300"
						style="width: {hibpTotal > 0 ? (hibpProgress / hibpTotal * 100) : 0}%;"
					></div>
				</div>
				<p class="text-[10px] text-[var(--fv-ash)]">Les mots de passe sont verifies de maniere anonyme (k-anonymity). Seuls les 5 premiers caracteres du hash SHA-1 sont envoyes.</p>
			</div>
		{:else if hibpDone}
			{#if hibpResults.size === 0}
				<div class="p-4 rounded-xl bg-[var(--fv-success)]/5 border border-[var(--fv-success)]/10 text-center">
					<p class="text-sm text-[var(--fv-success)] font-medium">Aucun mot de passe compromis trouve !</p>
					<p class="text-[10px] text-[var(--fv-smoke)] mt-1">Tes mots de passe n'apparaissent dans aucune fuite de donnees connue.</p>
				</div>
			{:else}
				<div class="space-y-2">
					<div class="p-3 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10 mb-3">
						<p class="text-xs text-[var(--fv-danger)] font-semibold">{hibpResults.size} mot{hibpResults.size > 1 ? 's' : ''} de passe compromis</p>
						<p class="text-[10px] text-[var(--fv-smoke)] mt-0.5">Ces mots de passe apparaissent dans des fuites de donnees. Change-les immediatement.</p>
					</div>
					{#if lastScanTime}
					<p class="text-[10px] text-[var(--fv-ash)] mb-3">Derniere analyse : {lastScanTime}</p>
				{/if}
				<div class="max-h-[300px] overflow-y-auto space-y-2 pr-1">
				{#each getBreachedEntries() as entry}
						{@const count = hibpResults.get(entry.id) ?? 0}
						<a href="/vault/add?edit={entry.id}" class="hibp-breach-item flex items-center gap-3 p-3 rounded-xl transition-all duration-200">
							<span class="text-base">{CATEGORY_META[entry.category]?.icon ?? '&#128230;'}</span>
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
				</div>
			{/if}
		{:else}
			<p class="text-xs text-[var(--fv-ash)] text-center py-2">Clique sur "Scanner" pour verifier tes mots de passe.</p>
		{/if}
	</div>
	{/if}

	<!-- Recommendations -->
	<div class="sec-glass-card p-6 mb-6 fv-animate-in relative z-10" style="animation-delay: 300ms;">
		<h2 class="text-sm font-bold text-white mb-5">Recommandations</h2>
		<div class="space-y-3">
			{#each recommendations() as rec, idx}
				<div class="rec-card flex items-start gap-3 p-4 rounded-xl transition-all duration-200 fv-animate-in
					{rec.severity === 'danger' ? 'rec-danger' :
					 rec.severity === 'warning' ? 'rec-warning' :
					 'rec-info'}"
					style="animation-delay: {350 + idx * 80}ms;"
				>
					<!-- Severity stripe on left -->
					<div class="rec-stripe {rec.severity === 'danger' ? 'bg-[var(--fv-danger)]' : rec.severity === 'warning' ? 'bg-[var(--fv-gold)]' : 'bg-[var(--fv-success)]'}"></div>
					<div class="w-8 h-8 rounded-lg flex items-center justify-center shrink-0
						{rec.severity === 'danger' ? 'bg-[var(--fv-danger)]/15' :
						 rec.severity === 'warning' ? 'bg-[var(--fv-gold)]/15' :
						 'bg-[var(--fv-success)]/15'}">
						<span class="text-sm">{@html rec.icon}</span>
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
		<div class="sec-glass-card p-6 mb-6 relative z-10">
			<h2 class="text-sm font-bold text-white mb-4">Mots de passe reutilises</h2>
			<div class="space-y-3">
				{#each reusedPasswords() as [_, titles]}
					<div class="p-3 rounded-xl bg-[var(--fv-danger)]/5 border border-[var(--fv-danger)]/10">
						<p class="text-xs text-[var(--fv-danger)] font-medium mb-1">Meme mot de passe partage par :</p>
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
		<div class="sec-glass-card p-6 relative z-10">
			<h2 class="text-sm font-bold text-white mb-4">Mots de passe faibles</h2>
			<div class="space-y-2">
				{#each weakEntries as entry}
					{@const s = passwordStrength(entry.password)}
					<a href="/vault/add?edit={entry.id}" class="flex items-center gap-3 p-3 rounded-xl bg-white/[0.03] border border-white/[0.04] hover:bg-white/[0.06] hover:border-white/[0.08] transition-all duration-200">
						<span class="text-base">{CATEGORY_META[entry.category]?.icon ?? '&#128230;'}</span>
						<div class="flex-1 min-w-0">
							<p class="text-sm text-white truncate">{entry.title}</p>
							<p class="text-[10px] text-[var(--fv-smoke)]">{entry.username}</p>
						</div>
						<div class="flex items-center gap-2">
							<div class="w-16 h-1.5 rounded-full bg-white/5 overflow-hidden">
								<div class="h-full rounded-full transition-all duration-300" style="width: {s.score}%; background: {s.color};"></div>
							</div>
							<span class="text-[10px] font-bold" style="color: {s.color};">{s.label}</span>
						</div>
					</a>
				{/each}
			</div>
		</div>
	{/if}
</div>

<style>
	/* Page with subtle mesh */
	.security-page {
		position: relative;
	}
	.security-mesh {
		position: fixed;
		inset: 0;
		background:
			radial-gradient(ellipse 80% 50% at 20% 10%, rgba(0,212,255,0.03), transparent 50%),
			radial-gradient(ellipse 60% 80% at 80% 90%, rgba(138,92,246,0.03), transparent 50%);
		pointer-events: none;
		z-index: 0;
	}

	/* Glass cards */
	.sec-glass-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.015));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 20px;
	}

	/* Score gauge card */
	.score-gauge-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.015));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 24px;
	}

	/* Score arc glow */
	.score-arc {
		transition: stroke-dashoffset 0.8s cubic-bezier(0.16, 1, 0.3, 1), stroke 0.4s ease;
		filter: drop-shadow(0 0 6px currentColor);
	}
	.score-glow {
		position: absolute;
		inset: 10px;
		border-radius: 50%;
		background: radial-gradient(circle, var(--score-color), transparent 70%);
		opacity: 0.08;
		animation: scoreGlowPulse 3s ease-in-out infinite;
	}
	@keyframes scoreGlowPulse {
		0%, 100% { opacity: 0.06; }
		50% { opacity: 0.12; }
	}

	/* Stat cards — bento style */
	.stat-card {
		position: relative;
		background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.012));
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 16px;
		padding: 16px;
		text-align: center;
		overflow: hidden;
		transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.stat-card:hover {
		transform: translateY(-2px);
		border-color: rgba(255,255,255,0.1);
		box-shadow: 0 8px 24px rgba(0,0,0,0.2);
	}

	/* Colored left border on stat cards */
	.stat-card-border {
		position: absolute;
		left: 0;
		top: 8px;
		bottom: 8px;
		width: 3px;
		border-radius: 0 3px 3px 0;
		background: var(--stat-color);
		opacity: 0.6;
	}

	/* Stat card icon */
	.stat-card-icon {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 28px;
		height: 28px;
		border-radius: 8px;
	}

	/* Recommendation cards */
	.rec-card {
		position: relative;
		overflow: hidden;
	}
	.rec-danger {
		background: rgba(239, 68, 68, 0.04);
		border: 1px solid rgba(239, 68, 68, 0.08);
	}
	.rec-warning {
		background: rgba(251, 191, 36, 0.04);
		border: 1px solid rgba(251, 191, 36, 0.08);
	}
	.rec-info {
		background: rgba(255,255,255,0.03);
		border: 1px solid rgba(255,255,255,0.05);
	}
	.rec-card:hover {
		transform: translateX(2px);
	}

	/* Severity stripe */
	.rec-stripe {
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 3px;
		border-radius: 0 3px 3px 0;
	}

	/* Breached items with glow */
	.hibp-breach-item {
		background: rgba(239, 68, 68, 0.04);
		border: 1px solid rgba(239, 68, 68, 0.08);
	}
	.hibp-breach-item:hover {
		background: rgba(239, 68, 68, 0.08);
		box-shadow: 0 0 20px rgba(239, 68, 68, 0.08);
	}
</style>
