<script lang="ts">
	let visible = $state(false);
	import { onMount } from 'svelte';
	onMount(() => { setTimeout(() => visible = true, 100); });
</script>

<section class="relative min-h-screen flex items-center justify-center overflow-hidden pt-20">
	<!-- Animated background orbs -->
	<div class="absolute inset-0 overflow-hidden">
		<div class="absolute top-1/4 left-1/4 w-[500px] h-[500px] rounded-full bg-[var(--fv-cyan)] opacity-[0.07] blur-[120px] animate-pulse"></div>
		<div class="absolute bottom-1/4 right-1/4 w-[600px] h-[600px] rounded-full bg-[var(--fv-violet)] opacity-[0.06] blur-[140px] animate-pulse" style="animation-delay: 1s;"></div>
		<div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[400px] h-[400px] rounded-full bg-[var(--fv-rose)] opacity-[0.04] blur-[100px] animate-pulse" style="animation-delay: 2s;"></div>
	</div>

	<!-- Grid pattern overlay -->
	<div class="absolute inset-0 opacity-[0.03]" style="background-image: radial-gradient(circle, var(--fv-mist) 1px, transparent 1px); background-size: 40px 40px;"></div>

	<div class="relative z-10 max-w-5xl mx-auto px-6 text-center transition-all duration-1000 {visible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-8'}">
		<!-- Badge -->
		<div class="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-white/5 border border-white/10 mb-8">
			<div class="w-2 h-2 rounded-full bg-[var(--fv-success)] animate-pulse"></div>
			<span class="text-xs font-semibold text-[var(--fv-mist)] tracking-wide uppercase">Chiffrement AES-256 de bout en bout</span>
		</div>

		<!-- Main heading -->
		<h1 class="text-5xl sm:text-6xl lg:text-7xl font-black text-white leading-[1.1] mb-6 tracking-tight">
			Tes mots de passe,
			<br />
			<span class="fv-gradient-text">blindés.</span>
		</h1>

		<!-- Subtitle -->
		<p class="text-lg sm:text-xl text-[var(--fv-mist)] max-w-2xl mx-auto mb-10 leading-relaxed">
			FyxxVault est le gestionnaire de mots de passe nouvelle génération.
			Chiffrement militaire, synchronisation zero-knowledge, surveillance du dark web.
		</p>

		<!-- CTA buttons -->
		<div class="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16">
			<a href="/register" class="fv-btn fv-btn-primary text-base !px-8 !py-4 shadow-lg shadow-[var(--fv-cyan)]/20">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
				Commencer gratuitement
			</a>
			<a href="#features" class="fv-btn fv-btn-ghost text-base !px-8 !py-4">
				Découvrir →
			</a>
		</div>

		<!-- Stats -->
		<div class="flex items-center justify-center gap-8 sm:gap-16">
			<div class="text-center">
				<div class="text-2xl sm:text-3xl font-extrabold text-white">AES-256</div>
				<div class="text-xs sm:text-sm text-[var(--fv-smoke)] mt-1">Chiffrement</div>
			</div>
			<div class="w-px h-10 bg-white/10"></div>
			<div class="text-center">
				<div class="text-2xl sm:text-3xl font-extrabold text-white">210K</div>
				<div class="text-xs sm:text-sm text-[var(--fv-smoke)] mt-1">Rounds PBKDF2</div>
			</div>
			<div class="w-px h-10 bg-white/10"></div>
			<div class="text-center">
				<div class="text-2xl sm:text-3xl font-extrabold text-white">0</div>
				<div class="text-xs sm:text-sm text-[var(--fv-smoke)] mt-1">Données lisibles</div>
			</div>
		</div>
	</div>
</section>
