<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { getAuthState, logout, initAuth } from '$lib/stores/auth.svelte';
	import { resetVault } from '$lib/stores/vault.svelte';

	let { children } = $props();

	const auth = getAuthState();
	let sidebarOpen = $state(false);

	// Initialize auth listener
	initAuth();

	// Current path (reactive via store auto-subscription)
	const currentPath = $derived($page.url.pathname);

	// Auth guards
	$effect(() => {
		if (!auth.loading && !auth.isAuthenticated) {
			goto('/login');
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

	async function handleSidebarCheckout() {
		try {
			const res = await fetch('/api/checkout', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ plan: 'monthly', email: auth.user?.email })
			});
			const data = await res.json();
			if (data.url) window.location.href = data.url;
		} catch (e) {
			console.error('Checkout error:', e);
		}
	}

	async function handleLogout() {
		resetVault();
		await logout();
		goto('/login');
	}

	const navItems = [
		{ path: '/vault', label: 'Coffre', icon: 'vault' },
		{ path: '/vault/security', label: 'Sécurité', icon: 'shield' },
		{ path: '/vault/settings', label: 'Paramètres', icon: 'settings' }
	];

	function isActive(path: string): boolean {
		if (path === '/vault') return currentPath === '/vault' || currentPath === '/vault/add';
		return currentPath.startsWith(path);
	}
</script>

{#if auth.loading}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center">
		<div class="w-10 h-10 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
	</div>
{:else if !auth.isUnlocked}
	{@render children()}
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
			<!-- Logo -->
			<div class="px-6 py-6 flex items-center gap-3 border-b border-white/5">
				<div class="w-9 h-9 rounded-xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
				<span class="text-lg font-extrabold text-white tracking-tight">FyxxVault</span>
			</div>

			<!-- Navigation -->
			<nav class="flex-1 px-3 py-4 space-y-1">
				{#each navItems as item}
					<a
						href={item.path}
						onclick={() => sidebarOpen = false}
						class="flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-medium transition-all
							{isActive(item.path)
								? 'bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)]'
								: 'text-[var(--fv-smoke)] hover:text-white hover:bg-white/5'}"
					>
						{#if item.icon === 'vault'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<rect x="3" y="11" width="18" height="11" rx="2"/>
								<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
							</svg>
						{:else if item.icon === 'shield'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
							</svg>
						{:else if item.icon === 'settings'}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<circle cx="12" cy="12" r="3"/>
								<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/>
							</svg>
						{/if}
						{item.label}
					</a>
				{/each}
			</nav>

			<!-- Upgrade Pro -->
			<div class="px-3 pb-3">
				<div class="p-4 rounded-2xl bg-gradient-to-br from-[var(--fv-gold)]/10 to-[var(--fv-gold)]/5 border border-[var(--fv-gold)]/20">
					<div class="flex items-center gap-2 mb-2">
						<span class="text-lg">👑</span>
						<span class="text-xs font-bold text-[var(--fv-gold)]">FyxxVault Pro</span>
					</div>
					<p class="text-[10px] text-[var(--fv-smoke)] mb-3 leading-relaxed">Comptes illimités, Dark Web, emails masqués</p>
					<button
						onclick={handleSidebarCheckout}
						class="block w-full text-center px-3 py-2 rounded-xl bg-gradient-to-r from-[var(--fv-gold)] to-[var(--fv-gold-light)] text-[#1a1a2e] text-xs font-bold hover:shadow-lg hover:shadow-[var(--fv-gold)]/20 transition-all"
					>
						4,99€/mois — Essai gratuit
					</button>
				</div>
			</div>

			<!-- User section -->
			<div class="px-4 py-4 border-t border-white/5">
				<div class="flex items-center gap-3 px-2 mb-3">
					<div class="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center text-xs font-bold text-white">
						{auth.user?.email?.charAt(0).toUpperCase() ?? '?'}
					</div>
					<div class="flex-1 min-w-0">
						<p class="text-xs text-white font-medium truncate">{auth.user?.email ?? ''}</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Plan Gratuit</p>
					</div>
				</div>
				<button
					onclick={handleLogout}
					class="w-full flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm text-[var(--fv-smoke)] hover:text-[var(--fv-danger)] hover:bg-[var(--fv-danger)]/10 transition-all"
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
						<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
						<polyline points="16 17 21 12 16 7"/>
						<line x1="21" y1="12" x2="9" y2="12"/>
					</svg>
					Déconnexion
				</button>
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
			</header>

			<main class="p-4 lg:p-8">
				{@render children()}
			</main>
		</div>
	</div>
{/if}
