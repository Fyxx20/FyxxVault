<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { getAuthState, initAuth } from '$lib/stores/auth.svelte';

	let { children } = $props();

	const auth = getAuthState();
	let sidebarOpen = $state(false);
	let authorized = $state(false);
	let checking = $state(true);
	let openTicketCount = $state(0);

	initAuth();

	const currentPath = $derived($page.url.pathname);

	// Auth guard: check against admin list from API
	$effect(() => {
		if (!auth.loading) {
			if (!auth.isAuthenticated) {
				goto('/');
			} else {
				// Check admin status via maintenance API (returns admins list)
				fetch('/api/admin/maintenance')
					.then(r => r.json())
					.then(data => {
						const admins: string[] = data.admins ?? ['fyxxfn@gmail.com'];
						if (admins.includes(auth.user?.email ?? '')) {
							authorized = true;
							// Fetch open ticket count for nav badge
							fetch('/api/admin/support?status=open', {
								headers: { Authorization: `Bearer ${auth.session?.access_token ?? ''}` }
							})
								.then(r => r.json())
								.then(d => { openTicketCount = d.stats?.open ?? d.tickets?.length ?? 0; })
								.catch(() => {});
						} else {
							goto('/');
						}
						checking = false;
					})
					.catch(() => {
						// Fallback: deny access if API check fails
						authorized = false; goto('/');
						checking = false;
					});
			}
		}
	});

	const navItems = [
		{ path: '/admin', label: 'Dashboard', icon: 'dashboard' },
		{ path: '/admin/users', label: 'Utilisateurs', icon: 'users' },
		{ path: '/admin/subscriptions', label: 'Abonnements', icon: 'credit-card' },
		{ path: '/admin/database', label: 'Base de donnees', icon: 'database' },
		{ path: '/admin/support', label: 'Support', icon: 'support' },
		{ path: '/admin/settings', label: 'Parametres', icon: 'settings' }
	];

	function isActive(path: string): boolean {
		if (path === '/admin') return currentPath === '/admin';
		return currentPath.startsWith(path);
	}

	function getToken(): string {
		return auth.session?.access_token ?? '';
	}
</script>

{#if checking || !authorized}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center">
		<div class="w-10 h-10 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
	</div>
{:else}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex">
		<!-- Mobile sidebar overlay -->
		{#if sidebarOpen}
			<button
				class="fixed inset-0 bg-black/60 z-40 lg:hidden"
				onclick={() => sidebarOpen = false}
				aria-label="Fermer le menu"
			></button>
		{/if}

		<!-- Sidebar -->
		<aside class="
			fixed lg:sticky top-0 left-0 z-50 h-screen w-[260px]
			bg-[var(--fv-obsidian)] border-r border-white/5
			flex flex-col transition-transform duration-300
			{sidebarOpen ? 'translate-x-0' : '-translate-x-full lg:translate-x-0'}
		">
			<!-- Logo + Admin badge -->
			<div class="px-6 py-6 flex items-center gap-3 border-b border-white/5">
				<div class="w-9 h-9 rounded-xl bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-rose)] flex items-center justify-center shadow-lg shadow-[var(--fv-violet)]/20">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
				<div class="flex items-center gap-2">
					<span class="text-lg font-extrabold text-white tracking-tight">FyxxVault</span>
					<span class="px-2 py-0.5 rounded-md bg-[var(--fv-violet)]/20 text-[var(--fv-violet-light)] text-[10px] font-bold uppercase tracking-wider">Admin</span>
				</div>
			</div>

			<!-- Navigation -->
			<nav class="flex-1 px-3 py-4 space-y-1">
				{#each navItems as item}
					<a
						href={item.path}
						onclick={() => sidebarOpen = false}
						class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all
							{isActive(item.path)
								? 'bg-[var(--fv-violet)]/10 text-[var(--fv-violet-light)]'
								: 'text-[var(--fv-smoke)] hover:text-white hover:bg-white/5'}"
					>
						{#if item.icon === 'dashboard'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<rect x="3" y="3" width="7" height="7" rx="1"/>
								<rect x="14" y="3" width="7" height="7" rx="1"/>
								<rect x="3" y="14" width="7" height="7" rx="1"/>
								<rect x="14" y="14" width="7" height="7" rx="1"/>
							</svg>
						{:else if item.icon === 'users'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
								<circle cx="9" cy="7" r="4"/>
								<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
								<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
							</svg>
						{:else if item.icon === 'credit-card'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<rect x="1" y="4" width="22" height="16" rx="2"/>
								<line x1="1" y1="10" x2="23" y2="10"/>
							</svg>
						{:else if item.icon === 'database'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<ellipse cx="12" cy="5" rx="9" ry="3"/>
								<path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
								<path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
							</svg>
						{:else if item.icon === 'support'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
							</svg>
						{:else if item.icon === 'settings'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<circle cx="12" cy="12" r="3"/>
								<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
							</svg>
						{/if}
						{item.label}
						{#if item.icon === 'support' && openTicketCount > 0}
							<span class="ml-auto px-1.5 py-0.5 rounded-full bg-red-500/20 text-red-400 text-[10px] font-bold leading-none min-w-[18px] text-center">{openTicketCount}</span>
						{/if}
					</a>
				{/each}
			</nav>

			<!-- Back to vault link -->
			<div class="px-3 pb-3">
				<a
					href="/vault"
					class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium text-[var(--fv-smoke)] hover:text-white hover:bg-white/5 transition-all"
				>
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<line x1="19" y1="12" x2="5" y2="12"/>
						<polyline points="12 19 5 12 12 5"/>
					</svg>
					Retour au coffre
				</a>
			</div>

			<!-- Admin user section -->
			<div class="px-4 py-4 border-t border-white/5">
				<div class="flex items-center gap-3 px-2">
					<div class="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-rose)] flex items-center justify-center text-xs font-bold text-white">
						A
					</div>
					<div class="flex-1 min-w-0">
						<p class="text-xs text-white font-medium truncate">{auth.user?.email ?? ''}</p>
						<p class="text-[10px] text-[var(--fv-violet-light)]">Administrateur</p>
					</div>
				</div>
			</div>
		</aside>

		<!-- Main content -->
		<div class="flex-1 min-h-screen lg:ml-0">
			<!-- Mobile header -->
			<header class="lg:hidden sticky top-0 z-30 bg-[var(--fv-abyss)]/90 backdrop-blur-xl border-b border-white/5 px-4 py-3 flex items-center gap-3">
				<button onclick={() => sidebarOpen = true} class="p-2 rounded-lg hover:bg-white/5 text-white">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="3" y1="6" x2="21" y2="6"/>
						<line x1="3" y1="12" x2="21" y2="12"/>
						<line x1="3" y1="18" x2="21" y2="18"/>
					</svg>
				</button>
				<span class="text-sm font-bold text-white">FyxxVault</span>
				<span class="px-2 py-0.5 rounded-md bg-[var(--fv-violet)]/20 text-[var(--fv-violet-light)] text-[10px] font-bold uppercase tracking-wider">Admin</span>
			</header>

			<main class="p-4 lg:p-8">
				{@render children()}
			</main>
		</div>
	</div>
{/if}

<style>
	:global(.admin-stat-card) {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 16px;
		padding: 24px;
		position: relative;
		overflow: hidden;
	}
	:global(.admin-stat-card::before) {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 4px;
		border-radius: 4px 0 0 4px;
	}
	:global(.admin-stat-card.violet::before) { background: var(--fv-violet); }
	:global(.admin-stat-card.cyan::before) { background: var(--fv-cyan); }
	:global(.admin-stat-card.gold::before) { background: var(--fv-gold); }
	:global(.admin-stat-card.success::before) { background: var(--fv-success); }
	:global(.admin-stat-card.rose::before) { background: var(--fv-rose); }

	:global(.admin-badge) {
		display: inline-flex;
		align-items: center;
		padding: 3px 10px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 0.02em;
	}
	:global(.admin-badge.pro) {
		background: var(--fv-success);
		color: #064e3b;
	}
	:global(.admin-badge.free) {
		background: var(--fv-ash);
		color: var(--fv-silver);
	}
	:global(.admin-badge.active) {
		background: rgba(52, 211, 153, 0.15);
		color: var(--fv-success);
	}
	:global(.admin-badge.trialing) {
		background: rgba(138, 92, 246, 0.15);
		color: var(--fv-violet-light);
	}
	:global(.admin-badge.canceled) {
		background: rgba(239, 68, 68, 0.15);
		color: var(--fv-danger);
	}
	:global(.admin-badge.past_due) {
		background: rgba(251, 191, 36, 0.15);
		color: var(--fv-warning);
	}
	:global(.admin-badge.incomplete) {
		background: rgba(120, 138, 160, 0.15);
		color: var(--fv-smoke);
	}

	:global(.admin-table) {
		width: 100%;
		border-collapse: separate;
		border-spacing: 0;
	}
	:global(.admin-table th) {
		text-align: left;
		padding: 12px 16px;
		font-size: 11px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.05em;
		color: var(--fv-smoke);
		border-bottom: 1px solid rgba(255,255,255,0.06);
	}
	:global(.admin-table td) {
		padding: 14px 16px;
		font-size: 13px;
		color: var(--fv-silver);
		border-bottom: 1px solid rgba(255,255,255,0.04);
	}
	:global(.admin-table tr:hover td) {
		background: rgba(255,255,255,0.02);
	}

	:global(.admin-input) {
		width: 100%;
		padding: 12px 16px;
		border-radius: 12px;
		background: rgba(255,255,255,0.05);
		border: 1px solid rgba(255,255,255,0.08);
		color: var(--fv-silver);
		font-size: 14px;
		outline: none;
		transition: border-color 0.2s;
	}
	:global(.admin-input:focus) {
		border-color: var(--fv-violet);
	}
	:global(.admin-input::placeholder) {
		color: var(--fv-ash);
	}
</style>
