<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { getAuthState, logout, lockVault, initAuth } from '$lib/stores/auth.svelte';
	import { resetVault, getSecurityStats } from '$lib/stores/vault.svelte';
	import { t, getLang, setLang } from '$lib/i18n.svelte';

	let { children } = $props();

	const auth = getAuthState();
	let sidebarOpen = $state(false);
	let lastActivity = $state(Date.now());
	let maintenanceMode = $state(false);
	let maintenanceChecked = $state(false);

	const ADMIN_EMAIL = 'fyxxfn@gmail.com';

	// Initialize auth listener
	initAuth();

	// Check maintenance mode
	$effect(() => {
		if (auth.isAuthenticated) {
			checkMaintenance();
		}
	});

	async function checkMaintenance() {
		// Self-hosted: no maintenance mode
		maintenanceMode = false;
		maintenanceChecked = true;
	}

	// Current path (reactive via store auto-subscription)
	const currentPath = $derived($page.url.pathname);
	const isAdmin = $derived(auth.user?.email === ADMIN_EMAIL);
	const showMaintenance = $derived(maintenanceMode && !isAdmin && maintenanceChecked);

	// Auth guards — redirect to unlock (no login page anymore)
	$effect(() => {
		if (!auth.loading && !auth.isAuthenticated) {
			goto('/vault/unlock');
		}
	});

	// If authenticated but not unlocked, only allow /vault/unlock
	$effect(() => {
		if (!auth.loading && auth.isAuthenticated && !auth.isUnlocked) {
			if (currentPath !== '/vault/unlock') {
				goto('/vault/unlock');
			}
		}
	});

	// Auto-lock: track user activity and lock vault on inactivity
	$effect(() => {
		if (!auth.isUnlocked) return;

		const storedTimeout = localStorage.getItem('fv_auto_lock_timeout');
		const timeout = storedTimeout ? parseInt(storedTimeout) : 5;
		if (timeout === 0) return; // Disabled

		const timeoutMs = timeout * 60 * 1000;

		function resetTimer() {
			lastActivity = Date.now();
		}

		const events = ['mousedown', 'keydown', 'touchstart', 'scroll', 'mousemove'];
		events.forEach(e => document.addEventListener(e, resetTimer, { passive: true }));

		function handleVisibilityChange() {
			if (document.hidden) {
				lastActivity = Date.now();
			}
		}
		document.addEventListener('visibilitychange', handleVisibilityChange);

		const checker = setInterval(() => {
			if (Date.now() - lastActivity > timeoutMs) {
				handleLock();
			}
		}, 10000);

		return () => {
			events.forEach(e => document.removeEventListener(e, resetTimer));
			document.removeEventListener('visibilitychange', handleVisibilityChange);
			clearInterval(checker);
		};
	});

	function handleLock() {
		resetVault();
		lockVault();
		goto('/vault/unlock');
	}

	// Security alert dot
	const securityStats = $derived(auth.isUnlocked ? getSecurityStats() : null);
	const hasSecurityAlert = $derived(securityStats ? (securityStats.weak > 0 || securityStats.reused > 0) : false);

	const navItems = [
		{ path: '/vault', label: () => t('nav.vault'), icon: 'vault', color: 'var(--fv-cyan)', mobileIcon: true },
		{ path: '/vault/security', label: () => t('nav.security'), icon: 'shield', color: 'var(--fv-violet)', mobileIcon: true },
		{ path: '/vault/identity', label: () => t('nav.identity'), icon: 'identity', color: '#10b981', mobileIcon: true },
		{ path: '/vault/settings', label: () => t('nav.settings'), icon: 'settings', color: 'var(--fv-smoke)', mobileIcon: true },
		{ path: '/panel', label: () => 'Panel', icon: 'panel', color: '#3b82f6', mobileIcon: true }
	];

	function isActive(path: string): boolean {
		if (path === '/vault') return currentPath === '/vault' || currentPath === '/vault/add' || currentPath === '/vault/import';
		return currentPath.startsWith(path);
	}

	// Logout confirmation
	let showLogoutToast = $state(false);
	let logoutToastExiting = $state(false);

	async function handleLogout() {
		showLogoutToast = true;
		logoutToastExiting = false;
		setTimeout(() => { logoutToastExiting = true; }, 1000);
		setTimeout(async () => {
			showLogoutToast = false;
			resetVault();
			lockVault();
			goto('/vault/unlock');
		}, 1300);
	}
</script>

{#if auth.loading}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center">
		<div class="w-10 h-10 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
	</div>
{:else if showMaintenance}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center p-6">
		<div class="max-w-md w-full text-center">
			<div class="w-20 h-20 mx-auto mb-6 rounded-2xl bg-[var(--fv-warning)]/10 border border-[var(--fv-warning)]/20 flex items-center justify-center">
				<svg width="40" height="40" viewBox="0 0 24 24" fill="none" stroke="var(--fv-warning)" stroke-width="1.5">
					<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
				</svg>
			</div>
			<h1 class="text-2xl font-extrabold text-white mb-3">{t('maintenance.title')}</h1>
			<p class="text-sm text-[var(--fv-smoke)] mb-6 leading-relaxed">
				{t('maintenance.description')}
			</p>
			<div class="fv-glass p-4 rounded-2xl">
				<p class="text-xs text-[var(--fv-ash)]">
					{t('maintenance.contact')}
				</p>
			</div>
			<button
				onclick={() => window.location.reload()}
				class="mt-6 px-6 py-3 rounded-xl bg-[var(--fv-violet)] text-white text-sm font-bold hover:bg-[var(--fv-violet-light)] transition-all"
			>
				{t('common.retry')}
			</button>
		</div>
	</div>
{:else if !auth.isUnlocked}
	{@render children()}
{:else}
	<div class="min-h-screen bg-[var(--fv-abyss)]">
		<!-- Mobile sidebar overlay -->
		{#if sidebarOpen}
			<button
				class="fixed inset-0 bg-black/60 z-40 lg:hidden backdrop-blur-sm"
				style="animation: fv-fade-in-up 0.2s ease both;"
				onclick={() => sidebarOpen = false}
				aria-label="Fermer le menu"
			></button>
		{/if}

		<!-- Sidebar (desktop + mobile drawer) -->
		<aside class="
			fixed top-0 left-0 z-50 h-screen w-[260px]
			bg-[var(--fv-obsidian)] border-r border-white/[0.06]
			flex flex-col overflow-hidden transition-transform duration-300
			{sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
			sidebar-premium
		">
			<!-- Subtle noise texture overlay -->
			<div class="sidebar-noise"></div>
			<!-- Subtle gradient mesh background -->
			<div class="sidebar-mesh"></div>

			<!-- Logo -->
			<div class="relative z-10 px-6 py-6 flex items-center gap-3">
				<div class="logo-icon-glow w-9 h-9 rounded-xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
				<span class="text-lg font-extrabold text-white tracking-tight">FyxxVault</span>
					<button
						onclick={() => setLang(getLang() === 'fr' ? 'en' : 'fr')}
						class="ml-auto flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-[11px] font-bold tracking-wider border border-white/10 bg-white/[0.06] hover:bg-white/[0.14] hover:border-[var(--fv-cyan)]/30 text-white transition-all duration-200"
					>
						<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
							<circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/>
						</svg>
						{getLang() === 'fr' ? 'FR' : 'EN'}
					</button>
			</div>

			<!-- Separator -->
			<div class="relative z-10 mx-5 h-px bg-gradient-to-r from-transparent via-white/[0.08] to-transparent"></div>

			<!-- Navigation -->
			<nav class="relative z-10 flex-1 min-h-0 overflow-y-auto px-3 py-3 space-y-1" style="scrollbar-width: none;">
				{#each navItems as item}
					<a
						href={item.path}
						onclick={() => sidebarOpen = false}
						class="nav-item flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-medium transition-all duration-200 relative
							{isActive(item.path)
								? 'nav-item-active text-white'
								: 'text-[var(--fv-smoke)] hover:text-white hover:bg-white/[0.04]'}"
					>
						<!-- Active indicator: gradient left border -->
						{#if isActive(item.path)}
							<div class="nav-active-border"></div>
						{/if}

						<!-- Icon with colored background -->
						<div class="nav-icon-bg flex items-center justify-center w-8 h-8 rounded-lg transition-all duration-200"
							style="background: {isActive(item.path) ? item.color : 'rgba(255,255,255,0.05)'}15; color: {isActive(item.path) ? item.color : 'currentColor'};">
							{#if item.icon === 'vault'}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<rect x="3" y="11" width="18" height="11" rx="2"/>
									<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
								</svg>
							{:else if item.icon === 'shield'}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
								</svg>
							{:else if item.icon === 'settings'}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<circle cx="12" cy="12" r="3"/>
									<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
								</svg>
							{:else if item.icon === 'identity'}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<rect x="2" y="5" width="20" height="14" rx="2"/>
									<circle cx="8" cy="12" r="2"/>
									<path d="M14 9h4M14 12h4M14 15h2"/>
								</svg>
							{:else if item.icon === 'panel'}
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<rect x="2" y="3" width="20" height="14" rx="2" ry="2"/>
									<line x1="8" y1="21" x2="16" y2="21"/>
									<line x1="12" y1="17" x2="12" y2="21"/>
								</svg>
							{/if}
						</div>
						{item.label()}
						{#if item.icon === 'shield' && hasSecurityAlert}
							<span class="ml-auto w-2 h-2 rounded-full bg-[var(--fv-danger)] shrink-0 security-alert-dot"></span>
						{/if}
					</a>
				{/each}
			</nav>

			<!-- Bottom section (fixed) -->
			<div class="flex-shrink-0">
			<div class="relative z-10 mx-5 h-px bg-gradient-to-r from-transparent via-white/[0.08] to-transparent"></div>

			<!-- Chrome Extension banner -->
			<div class="relative z-10 px-3 py-2">
				<a
					href="https://chromewebstore.google.com/detail/fyxxvault-%E2%80%93-autofill/pacioaldmfoppgnaieonkgjbipdeloll"
					target="_blank"
					rel="noopener"
					class="flex items-center gap-3 p-3 rounded-xl border border-[var(--fv-cyan)]/15 bg-[var(--fv-cyan)]/[0.04] hover:bg-[var(--fv-cyan)]/[0.08] transition-all duration-200 no-underline group"
				>
					<div class="w-8 h-8 rounded-lg bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center flex-shrink-0">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
					</div>
					<div class="flex-1 min-w-0">
						<p class="text-xs font-semibold text-white">Extension Chrome</p>
						<p class="text-[10px] text-[var(--fv-cyan)] group-hover:text-white transition-colors">Autofill sur tous les sites</p>
					</div>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2" stroke-linecap="round" class="flex-shrink-0"><path d="M18 13v6a2 2 0 01-2 2H5a2 2 0 01-2-2V8a2 2 0 012-2h6"/><path d="M15 3h6v6"/><path d="M10 14L21 3"/></svg>
				</a>
			</div>

			<!-- User section -->
			<div class="relative z-10 px-3 py-2">
				<div class="user-section-card p-2.5 rounded-xl mb-1">
					<div class="flex items-center gap-3">
						<div class="user-avatar w-9 h-9 rounded-full bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
						</div>
						<div class="flex-1 min-w-0">
							<p class="text-xs text-white font-medium">Coffre local</p>
							<p class="text-[10px] text-[var(--fv-ash)]">Self-hosted</p>
						</div>
					</div>
				</div>
				<button
					onclick={handleLogout}
					class="w-full flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm text-[var(--fv-smoke)] hover:text-[var(--fv-danger)] hover:bg-[var(--fv-danger)]/10 transition-all duration-200"
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
					Verrouiller
				</button>
			</div>
			</div><!-- end bottom section -->
		</aside>

		<!-- Main content -->
		<div class="min-h-screen lg:pl-[260px] pb-16 lg:pb-0">
			<!-- Mobile header -->
			<header class="lg:hidden sticky top-0 z-30 bg-[var(--fv-abyss)]/90 backdrop-blur-xl border-b border-white/[0.06] px-4 py-3 flex items-center gap-3">
				<button onclick={() => sidebarOpen = true} class="p-2 rounded-lg hover:bg-white/5 text-white transition-colors duration-200">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="3" y1="6" x2="21" y2="6"/>
						<line x1="3" y1="12" x2="21" y2="12"/>
						<line x1="3" y1="18" x2="21" y2="18"/>
					</svg>
				</button>
				<div class="flex items-center gap-2">
					<div class="w-6 h-6 rounded-lg bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
						<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
							<rect x="3" y="11" width="18" height="11" rx="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
						</svg>
					</div>
					<span class="text-sm font-bold text-white">FyxxVault</span>
				</div>
			</header>

			<main class="p-4 lg:px-6 lg:pt-4 lg:pb-6">
				{@render children()}
			</main>
		</div>

		<!-- Logout toast -->
		{#if showLogoutToast}
			<div class="fv-toast {logoutToastExiting ? 'fv-toast-exit' : ''}" style="color: var(--fv-smoke);">
				<span class="flex items-center gap-2">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>
					{t('sidebar.logging_out')}
				</span>
			</div>
		{/if}

		<!-- Mobile bottom navigation -->
		<nav class="lg:hidden fixed bottom-0 left-0 right-0 z-40 mobile-bottom-nav px-2 py-2">
			<div class="flex items-center justify-around">
				{#each navItems as item}
					<a
						href={item.path}
						class="flex flex-col items-center gap-1 px-3 py-1.5 rounded-xl transition-all duration-200 relative
							{isActive(item.path)
								? 'text-[var(--fv-cyan)]'
								: 'text-[var(--fv-ash)] hover:text-[var(--fv-smoke)]'}"
					>
						{#if isActive(item.path)}
							<div class="mobile-nav-active-bg"></div>
						{/if}
						{#if item.icon === 'vault'}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
						{:else if item.icon === 'shield'}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
						{:else if item.icon === 'settings'}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
						{:else if item.icon === 'identity'}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="5" width="20" height="14" rx="2"/><circle cx="8" cy="12" r="2"/><path d="M14 9h4M14 12h4M14 15h2"/></svg>
						{:else if item.icon === 'panel'}
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2" ry="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
						{/if}
						{#if item.icon === 'shield' && hasSecurityAlert}
							<span class="absolute top-1 right-2 w-1.5 h-1.5 rounded-full bg-[var(--fv-danger)] security-alert-dot"></span>
						{/if}
						<span class="text-[9px] font-semibold">{item.label().split(' ')[0]}</span>
					</a>
				{/each}
			</div>
		</nav>
	</div>
{/if}

<style>
	/* Sidebar premium background mesh */
	.sidebar-premium {
		position: fixed !important;
		overflow: hidden;
	}

	.sidebar-mesh {
		position: absolute;
		inset: 0;
		background:
			radial-gradient(ellipse 120% 80% at 10% 0%, rgba(0,212,255,0.04), transparent 50%),
			radial-gradient(ellipse 80% 120% at 90% 100%, rgba(138,92,246,0.04), transparent 50%);
		animation: sidebarMeshShift 20s ease-in-out infinite alternate;
		pointer-events: none;
	}

	@keyframes sidebarMeshShift {
		0% { opacity: 0.8; }
		50% { opacity: 1; }
		100% { opacity: 0.8; }
	}

	/* Noise texture overlay */
	.sidebar-noise {
		position: absolute;
		inset: 0;
		opacity: 0.03;
		pointer-events: none;
		background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
		background-repeat: repeat;
		background-size: 128px 128px;
		z-index: 1;
	}

	/* Logo glow */
	.logo-icon-glow {
		box-shadow: 0 0 20px rgba(0, 212, 255, 0.25), 0 0 40px rgba(138, 92, 246, 0.15);
		transition: box-shadow 0.3s ease;
	}
	.logo-icon-glow:hover {
		box-shadow: 0 0 24px rgba(0, 212, 255, 0.35), 0 0 48px rgba(138, 92, 246, 0.2);
	}

	/* Nav item icon backgrounds */
	.nav-icon-bg {
		flex-shrink: 0;
	}

	/* Active nav item */
	.nav-item-active {
		background: linear-gradient(135deg, rgba(0, 212, 255, 0.08), rgba(138, 92, 246, 0.04));
	}

	/* Gradient left border for active nav */
	.nav-active-border {
		position: absolute;
		left: 0;
		top: 6px;
		bottom: 6px;
		width: 3px;
		border-radius: 0 3px 3px 0;
		background: linear-gradient(180deg, var(--fv-cyan), var(--fv-violet));
		box-shadow: 0 0 8px rgba(0, 212, 255, 0.4);
	}

	/* Security alert dot pulse */
	.security-alert-dot {
		box-shadow: 0 0 6px rgba(239, 68, 68, 0.5);
		animation: alertPulse 2s ease-in-out infinite;
	}
	@keyframes alertPulse {
		0%, 100% { box-shadow: 0 0 6px rgba(239, 68, 68, 0.3); }
		50% { box-shadow: 0 0 12px rgba(239, 68, 68, 0.6); }
	}

	/* User section glassmorphism */
	.user-section-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.015));
		border: 1px solid rgba(255,255,255,0.06);
		backdrop-filter: blur(12px);
	}

	/* User avatar glow ring */
	.user-avatar {
		box-shadow: 0 0 0 2px var(--fv-obsidian), 0 0 0 4px rgba(0, 212, 255, 0.3);
		transition: box-shadow 0.3s ease;
	}
	.user-section-card:hover .user-avatar {
		box-shadow: 0 0 0 2px var(--fv-obsidian), 0 0 0 4px rgba(0, 212, 255, 0.5), 0 0 16px rgba(0, 212, 255, 0.15);
	}

	/* Mobile bottom nav glassmorphism */
	.mobile-bottom-nav {
		background: rgba(16, 24, 42, 0.8);
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border-top: 1px solid rgba(255,255,255,0.06);
	}

	/* Mobile nav active indicator */
	.mobile-nav-active-bg {
		position: absolute;
		inset: 0;
		border-radius: 12px;
		background: rgba(0, 212, 255, 0.08);
		pointer-events: none;
	}
</style>
