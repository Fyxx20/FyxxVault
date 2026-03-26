<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let stats = $state<any>(null);
	let recentUsers = $state<any[]>([]);
	let loading = $state(true);
	let error = $state('');

	async function fetchData() {
		loading = true;
		error = '';
		const token = auth.session?.access_token;
		if (!token) return;

		try {
			const [statsRes, usersRes] = await Promise.all([
				fetch('/api/admin/stats', { headers: { Authorization: `Bearer ${token}` } }),
				fetch('/api/admin/users?perPage=10&sortBy=created_at&sortDir=desc', { headers: { Authorization: `Bearer ${token}` } })
			]);

			if (!statsRes.ok || !usersRes.ok) {
				error = 'Erreur lors du chargement des donnees';
				return;
			}

			stats = await statsRes.json();
			const usersData = await usersRes.json();
			recentUsers = usersData.users ?? [];
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (auth.session?.access_token) {
			fetchData();
		}
	});

	function formatCurrency(cents: number): string {
		return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR' }).format(cents / 100);
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return 'N/A';
		return new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(dateStr));
	}

	function relativeTime(dateStr: string): string {
		if (!dateStr) return '';
		const diff = Date.now() - new Date(dateStr).getTime();
		const minutes = Math.floor(diff / 60000);
		if (minutes < 60) return `il y a ${minutes}min`;
		const hours = Math.floor(minutes / 60);
		if (hours < 24) return `il y a ${hours}h`;
		const days = Math.floor(hours / 24);
		return `il y a ${days}j`;
	}
</script>

<svelte:head>
	<title>Admin - FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="mb-8">
		<h1 class="text-2xl font-extrabold text-white mb-1">Dashboard</h1>
		<p class="text-sm text-[var(--fv-smoke)]">Vue d'ensemble de la plateforme FyxxVault</p>
	</div>

	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
		</div>
	{:else if error}
		<div class="fv-glass p-6 text-center">
			<p class="text-[var(--fv-danger)]">{error}</p>
			<button onclick={fetchData} class="mt-4 fv-btn fv-btn-ghost text-sm">Reessayer</button>
		</div>
	{:else if stats}
		<!-- Stats Grid -->
		<div class="grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-4 gap-4 mb-8">
			<!-- Total Users -->
			<div class="admin-stat-card violet">
				<div class="flex items-center justify-between mb-3">
					<span class="text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider">Total utilisateurs</span>
					<div class="w-8 h-8 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
							<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
							<circle cx="9" cy="7" r="4"/>
							<path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
							<path d="M16 3.13a4 4 0 0 1 0 7.75"/>
						</svg>
					</div>
				</div>
				<p class="text-3xl font-extrabold text-white mb-1">{stats.totalUsers}</p>
				<p class="text-xs text-[var(--fv-smoke)]">
					+{stats.newUsersWeek} cette semaine
				</p>
			</div>

			<!-- Pro Users -->
			<div class="admin-stat-card gold">
				<div class="flex items-center justify-between mb-3">
					<span class="text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider">Utilisateurs Pro</span>
					<div class="w-8 h-8 rounded-lg bg-[var(--fv-gold)]/15 flex items-center justify-center">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2">
							<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
						</svg>
					</div>
				</div>
				<p class="text-3xl font-extrabold text-white mb-1">{stats.proUsers}</p>
				<p class="text-xs text-[var(--fv-smoke)]">
					{stats.totalUsers > 0 ? Math.round((stats.proUsers / stats.totalUsers) * 100) : 0}% du total
				</p>
			</div>

			<!-- MRR -->
			<div class="admin-stat-card success">
				<div class="flex items-center justify-between mb-3">
					<span class="text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider">Revenus mensuels</span>
					<div class="w-8 h-8 rounded-lg bg-[var(--fv-success)]/15 flex items-center justify-center">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2">
							<line x1="12" y1="1" x2="12" y2="23"/>
							<path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
						</svg>
					</div>
				</div>
				<p class="text-3xl font-extrabold text-white mb-1">{formatCurrency(stats.mrr)}</p>
				<p class="text-xs text-[var(--fv-smoke)]">
					{stats.activeSubscriptions} abonnement{stats.activeSubscriptions > 1 ? 's' : ''} actif{stats.activeSubscriptions > 1 ? 's' : ''}
				</p>
			</div>

			<!-- Vault Items -->
			<div class="admin-stat-card cyan">
				<div class="flex items-center justify-between mb-3">
					<span class="text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider">Elements stockes</span>
					<div class="w-8 h-8 rounded-lg bg-[var(--fv-cyan)]/15 flex items-center justify-center">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2">
							<rect x="3" y="11" width="18" height="11" rx="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
						</svg>
					</div>
				</div>
				<p class="text-3xl font-extrabold text-white mb-1">{stats.vaultItemsCount}</p>
				<p class="text-xs text-[var(--fv-smoke)]">dans tous les coffres</p>
			</div>
		</div>

		<!-- Growth + Quick Actions row -->
		<div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mb-8">
			<!-- New Users Chart (CSS bars) -->
			<div class="lg:col-span-2 fv-glass p-6">
				<h2 class="text-sm font-bold text-white mb-4">Nouveaux utilisateurs</h2>
				<div class="grid grid-cols-3 gap-4">
					<div class="text-center">
						<div class="relative h-32 flex items-end justify-center mb-2">
							<div
								class="w-12 rounded-t-lg bg-gradient-to-t from-[var(--fv-violet)] to-[var(--fv-violet-light)]"
								style="height: {Math.max(stats.newUsersToday * 20, 8)}px; max-height: 128px;"
							></div>
						</div>
						<p class="text-2xl font-bold text-white">{stats.newUsersToday}</p>
						<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider">Aujourd'hui</p>
					</div>
					<div class="text-center">
						<div class="relative h-32 flex items-end justify-center mb-2">
							<div
								class="w-12 rounded-t-lg bg-gradient-to-t from-[var(--fv-cyan)] to-[var(--fv-cyan-light)]"
								style="height: {Math.max(stats.newUsersWeek * 10, 8)}px; max-height: 128px;"
							></div>
						</div>
						<p class="text-2xl font-bold text-white">{stats.newUsersWeek}</p>
						<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider">Cette semaine</p>
					</div>
					<div class="text-center">
						<div class="relative h-32 flex items-end justify-center mb-2">
							<div
								class="w-12 rounded-t-lg bg-gradient-to-t from-[var(--fv-gold)] to-[var(--fv-gold-light)]"
								style="height: {Math.max(stats.newUsersMonth * 5, 8)}px; max-height: 128px;"
							></div>
						</div>
						<p class="text-2xl font-bold text-white">{stats.newUsersMonth}</p>
						<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider">Ce mois</p>
					</div>
				</div>
			</div>

			<!-- Quick Actions -->
			<div class="fv-glass p-6">
				<h2 class="text-sm font-bold text-white mb-4">Actions rapides</h2>
				<div class="space-y-3">
					<a href="/admin/users" class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/8 transition-all group">
						<div class="w-10 h-10 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
								<path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
								<circle cx="9" cy="7" r="4"/>
							</svg>
						</div>
						<div class="flex-1">
							<p class="text-xs font-semibold text-white group-hover:text-[var(--fv-violet-light)] transition-colors">Voir tous les utilisateurs</p>
							<p class="text-[10px] text-[var(--fv-ash)]">{stats.totalUsers} utilisateurs</p>
						</div>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
					</a>
					<a href="/admin/subscriptions" class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/8 transition-all group">
						<div class="w-10 h-10 rounded-lg bg-[var(--fv-gold)]/15 flex items-center justify-center">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2">
								<rect x="1" y="4" width="22" height="16" rx="2"/>
								<line x1="1" y1="10" x2="23" y2="10"/>
							</svg>
						</div>
						<div class="flex-1">
							<p class="text-xs font-semibold text-white group-hover:text-[var(--fv-gold)] transition-colors">Gerer les abonnements</p>
							<p class="text-[10px] text-[var(--fv-ash)]">{stats.activeSubscriptions} actifs</p>
						</div>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
					</a>
					<a href="/admin/database" class="flex items-center gap-3 p-3 rounded-xl bg-white/5 hover:bg-white/8 transition-all group">
						<div class="w-10 h-10 rounded-lg bg-[var(--fv-cyan)]/15 flex items-center justify-center">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2">
								<ellipse cx="12" cy="5" rx="9" ry="3"/>
								<path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
								<path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
							</svg>
						</div>
						<div class="flex-1">
							<p class="text-xs font-semibold text-white group-hover:text-[var(--fv-cyan)] transition-colors">Base de donnees</p>
							<p class="text-[10px] text-[var(--fv-ash)]">Requetes et statistiques</p>
						</div>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><polyline points="9 18 15 12 9 6"/></svg>
					</a>
				</div>
			</div>
		</div>

		<!-- Recent Users -->
		<div class="fv-glass p-6">
			<div class="flex items-center justify-between mb-4">
				<h2 class="text-sm font-bold text-white">Derniers inscrits</h2>
				<a href="/admin/users" class="text-xs text-[var(--fv-violet-light)] hover:text-white transition-colors">Voir tout</a>
			</div>
			{#if recentUsers.length > 0}
				<div class="overflow-x-auto">
					<table class="admin-table">
						<thead>
							<tr>
								<th>Utilisateur</th>
								<th>Plan</th>
								<th>Elements</th>
								<th>Inscription</th>
								<th>Derniere activite</th>
							</tr>
						</thead>
						<tbody>
							{#each recentUsers as user}
								<tr>
									<td>
										<div class="flex items-center gap-3">
											<div class="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-cyan)] flex items-center justify-center text-xs font-bold text-white flex-shrink-0">
												{user.email?.charAt(0).toUpperCase() ?? '?'}
											</div>
											<span class="text-sm text-white truncate max-w-[200px]">{user.email}</span>
										</div>
									</td>
									<td>
										<span class="admin-badge {user.is_pro ? 'pro' : 'free'}">
											{user.is_pro ? 'Pro' : 'Gratuit'}
										</span>
									</td>
									<td class="text-[var(--fv-smoke)]">{user.vault_items_count}</td>
									<td class="text-[var(--fv-smoke)] text-xs">{formatDate(user.created_at)}</td>
									<td class="text-[var(--fv-ash)] text-xs">{user.last_sign_in_at ? relativeTime(user.last_sign_in_at) : 'Jamais'}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<p class="text-sm text-[var(--fv-ash)] text-center py-8">Aucun utilisateur</p>
			{/if}
		</div>
	{/if}
</div>
