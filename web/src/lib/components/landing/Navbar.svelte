<script lang="ts">
	let scrolled = $state(false);

	function handleScroll() {
		scrolled = window.scrollY > 50;
	}
</script>

<svelte:window onscroll={handleScroll} />

<nav class="fixed top-0 left-0 right-0 z-50 transition-all duration-300 {scrolled ? 'bg-[var(--fv-abyss)]/90 backdrop-blur-xl border-b border-white/5' : ''}">
	<div class="max-w-7xl mx-auto px-6 py-4 flex items-center justify-between">
		<a href="/" class="flex items-center gap-3">
			<div class="w-10 h-10 rounded-xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
					<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
			</div>
			<span class="text-xl font-extrabold text-white tracking-tight">FyxxVault</span>
		</a>

		<div class="hidden md:flex items-center gap-8">
			<a href="#features" class="text-sm font-medium text-[var(--fv-mist)] hover:text-white transition-colors">Fonctionnalités</a>
			<a href="#security" class="text-sm font-medium text-[var(--fv-mist)] hover:text-white transition-colors">Sécurité</a>
			<a href="#pricing" class="text-sm font-medium text-[var(--fv-mist)] hover:text-white transition-colors">Tarifs</a>
		</div>

		<div class="flex items-center gap-3">
			<a href="/login" class="fv-btn fv-btn-ghost text-sm !py-2.5 !px-5">Connexion</a>
			<a href="/register" class="fv-btn fv-btn-primary text-sm !py-2.5 !px-5">Essai gratuit</a>
		</div>
	</div>
</nav>
