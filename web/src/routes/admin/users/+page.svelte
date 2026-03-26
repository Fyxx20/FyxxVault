<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let users = $state<any[]>([]);
	let total = $state(0);
	let currentPage = $state(1);
	let totalPages = $state(1);
	let perPage = $state(20);
	let search = $state('');
	let filter = $state('all');
	let loading = $state(true);
	let error = $state('');

	// Detail / action states
	let selectedUser = $state<any>(null);
	let showDetail = $state(false);
	let showDeleteConfirm = $state(false);
	let deleteConfirmText = $state('');
	let actionLoading = $state(false);
	let actionMessage = $state('');
	let actionMessageType = $state<'success' | 'error'>('success');
	let selectedPlan = $state('free');
	let resetLoading = $state(false);
	let detailLoading = $state(false);

	// Quick action toast
	let toastMessage = $state('');
	let toastVisible = $state(false);

	function getToken(): string {
		return auth.session?.access_token ?? '';
	}

	function showToast(msg: string) {
		toastMessage = msg;
		toastVisible = true;
		setTimeout(() => { toastVisible = false; }, 3000);
	}

	function showActionMsg(msg: string, type: 'success' | 'error' = 'success') {
		actionMessage = msg;
		actionMessageType = type;
		setTimeout(() => { actionMessage = ''; }, 5000);
	}

	async function fetchUsers() {
		loading = true;
		error = '';
		try {
			const params = new URLSearchParams({
				page: currentPage.toString(),
				perPage: perPage.toString(),
				filter,
				sortBy: 'created_at',
				sortDir: 'desc'
			});
			if (search) params.set('search', search);

			const res = await fetch(`/api/admin/users?${params}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (!res.ok) throw new Error('Erreur de chargement');

			const data = await res.json();
			users = data.users ?? [];
			total = data.total ?? 0;
			totalPages = data.totalPages ?? 1;
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (auth.session?.access_token) {
			fetchUsers();
		}
	});

	// Re-fetch when filter or page changes
	let prevFilter = $state('all');
	let prevPage = $state(1);
	$effect(() => {
		if (filter !== prevFilter) {
			prevFilter = filter;
			currentPage = 1;
			fetchUsers();
		}
		if (currentPage !== prevPage) {
			prevPage = currentPage;
			fetchUsers();
		}
	});

	let searchTimeout: ReturnType<typeof setTimeout>;
	function handleSearch(e: Event) {
		const val = (e.target as HTMLInputElement).value;
		search = val;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => {
			currentPage = 1;
			fetchUsers();
		}, 400);
	}

	async function openDetail(user: any) {
		actionMessage = '';
		detailLoading = true;
		showDetail = true;
		selectedUser = user; // show immediately with basic data
		try {
			const res = await fetch(`/api/admin/users/${user.id}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (res.ok) {
				selectedUser = await res.json();
				selectedPlan = selectedUser.plan || 'free';
			}
		} catch {
			// keep basic user data
		} finally {
			detailLoading = false;
		}
	}

	function closeDetail() {
		showDetail = false;
		selectedUser = null;
		showDeleteConfirm = false;
		deleteConfirmText = '';
		actionMessage = '';
		resetLoading = false;
	}

	async function togglePro(user: any, fromList = false) {
		if (!fromList) actionLoading = true;
		try {
			const res = await fetch(`/api/admin/users/${user.id}`, {
				method: 'PATCH',
				headers: {
					Authorization: `Bearer ${getToken()}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ is_pro: !user.is_pro })
			});
			if (res.ok) {
				const newStatus = !user.is_pro;
				if (fromList) {
					showToast(`${user.email} ${newStatus ? 'passe en Pro' : 'repasse en Gratuit'}`);
				} else {
					showActionMsg(`Utilisateur ${newStatus ? 'passe en Pro' : 'repasse en Gratuit'}`);
					if (selectedUser) {
						selectedUser = { ...selectedUser, is_pro: newStatus, plan: newStatus ? 'monthly' : 'free' };
						selectedPlan = selectedUser.plan;
					}
				}
				await fetchUsers();
			} else {
				if (fromList) {
					showToast('Erreur lors de la mise a jour');
				} else {
					showActionMsg('Erreur lors de la mise a jour', 'error');
				}
			}
		} catch {
			if (fromList) {
				showToast('Erreur reseau');
			} else {
				showActionMsg('Erreur reseau', 'error');
			}
		} finally {
			if (!fromList) actionLoading = false;
		}
	}

	async function changePlan() {
		if (!selectedUser) return;
		actionLoading = true;
		try {
			const res = await fetch(`/api/admin/users/${selectedUser.id}`, {
				method: 'PATCH',
				headers: {
					Authorization: `Bearer ${getToken()}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ plan: selectedPlan })
			});
			if (res.ok) {
				const isPro = selectedPlan !== 'free';
				selectedUser = { ...selectedUser, plan: selectedPlan, is_pro: isPro };
				showActionMsg(`Plan mis a jour: ${planLabel(selectedPlan)}`);
				await fetchUsers();
			} else {
				showActionMsg('Erreur lors du changement de plan', 'error');
			}
		} catch {
			showActionMsg('Erreur reseau', 'error');
		} finally {
			actionLoading = false;
		}
	}

	async function sendPasswordReset() {
		if (!selectedUser) return;
		resetLoading = true;
		try {
			const res = await fetch(`/api/admin/users/${selectedUser.id}`, {
				method: 'PATCH',
				headers: {
					Authorization: `Bearer ${getToken()}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ action: 'send_password_reset' })
			});
			if (res.ok) {
				showActionMsg('Lien de recuperation genere avec succes');
			} else {
				showActionMsg('Erreur lors de la generation du lien', 'error');
			}
		} catch {
			showActionMsg('Erreur reseau', 'error');
		} finally {
			resetLoading = false;
		}
	}

	async function deleteUser() {
		if (deleteConfirmText !== 'DELETE') return;
		actionLoading = true;
		actionMessage = '';
		try {
			const res = await fetch(`/api/admin/users/${selectedUser.id}`, {
				method: 'DELETE',
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (res.ok) {
				closeDetail();
				await fetchUsers();
				showToast('Utilisateur supprime');
			} else {
				showActionMsg('Erreur lors de la suppression', 'error');
			}
		} catch {
			showActionMsg('Erreur reseau', 'error');
		} finally {
			actionLoading = false;
		}
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return 'N/A';
		return new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(dateStr));
	}

	function formatDateFull(dateStr: string): string {
		if (!dateStr) return 'N/A';
		return new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(dateStr));
	}

	function relativeTime(dateStr: string): string {
		if (!dateStr) return 'Jamais';
		const diff = Date.now() - new Date(dateStr).getTime();
		const minutes = Math.floor(diff / 60000);
		if (minutes < 60) return `il y a ${minutes}min`;
		const hours = Math.floor(minutes / 60);
		if (hours < 24) return `il y a ${hours}h`;
		const days = Math.floor(hours / 24);
		return `il y a ${days}j`;
	}

	function planLabel(plan: string): string {
		switch (plan) {
			case 'monthly': return 'Pro Mensuel';
			case 'yearly': return 'Pro Annuel';
			default: return 'Gratuit';
		}
	}

	function formatAmount(amount: number, currency: string): string {
		return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: currency || 'eur' }).format(amount / 100);
	}

	const filters = [
		{ value: 'all', label: 'Tous' },
		{ value: 'pro', label: 'Pro' },
		{ value: 'free', label: 'Gratuit' }
	];

	const planOptions = [
		{ value: 'free', label: 'Gratuit' },
		{ value: 'monthly', label: 'Pro Mensuel' },
		{ value: 'yearly', label: 'Pro Annuel' }
	];
</script>

<svelte:head>
	<title>Utilisateurs - Admin FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="mb-6">
		<h1 class="text-2xl font-extrabold text-white mb-1">Utilisateurs</h1>
		<p class="text-sm text-[var(--fv-smoke)]">{total} utilisateur{total > 1 ? 's' : ''} au total</p>
	</div>

	<!-- Search + Filters -->
	<div class="flex flex-col sm:flex-row gap-3 mb-6">
		<div class="flex-1 relative">
			<svg class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-[var(--fv-ash)]" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<circle cx="11" cy="11" r="8"/>
				<line x1="21" y1="21" x2="16.65" y2="16.65"/>
			</svg>
			<input
				type="text"
				placeholder="Rechercher par email..."
				value={search}
				oninput={handleSearch}
				class="admin-input pl-11"
			/>
		</div>
		<div class="flex gap-2">
			{#each filters as f}
				<button
					onclick={() => filter = f.value}
					class="px-4 py-2.5 rounded-xl text-xs font-bold transition-all
						{filter === f.value
							? 'bg-[var(--fv-violet)] text-white'
							: 'bg-white/5 text-[var(--fv-smoke)] hover:bg-white/10 border border-white/8'}"
				>
					{f.label}
				</button>
			{/each}
		</div>
	</div>

	<!-- User list -->
	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
		</div>
	{:else if error}
		<div class="fv-glass p-6 text-center">
			<p class="text-[var(--fv-danger)]">{error}</p>
			<button onclick={fetchUsers} class="mt-4 fv-btn fv-btn-ghost text-sm">Reessayer</button>
		</div>
	{:else}
		<div class="fv-glass overflow-hidden">
			<div class="overflow-x-auto">
				<table class="admin-table">
					<thead>
						<tr>
							<th>Utilisateur</th>
							<th>Plan</th>
							<th>Elements</th>
							<th>Inscription</th>
							<th>Derniere activite</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each users as user}
							<tr>
								<td>
									<div class="flex items-center gap-3">
										<div class="w-9 h-9 rounded-full bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-cyan)] flex items-center justify-center text-xs font-bold text-white flex-shrink-0">
											{user.email?.charAt(0).toUpperCase() ?? '?'}
										</div>
										<div>
											<p class="text-sm text-white font-medium truncate max-w-[220px]">{user.email}</p>
											<p class="text-[10px] text-[var(--fv-ash)] font-mono">{user.id.slice(0, 8)}...</p>
										</div>
									</div>
								</td>
								<td>
									<span class="admin-badge {user.is_pro ? 'pro' : 'free'}">
										{user.is_pro ? 'Pro' : 'Gratuit'}
									</span>
								</td>
								<td>
									<span class="text-[var(--fv-smoke)]">{user.vault_items_count}</span>
								</td>
								<td class="text-[var(--fv-smoke)] text-xs">{formatDate(user.created_at)}</td>
								<td class="text-[var(--fv-ash)] text-xs">{relativeTime(user.last_sign_in_at)}</td>
								<td>
									<div class="flex items-center gap-2">
										<button
											onclick={() => openDetail(user)}
											class="p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)] hover:text-white transition-all"
											title="Voir les details"
										>
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
												<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/>
												<circle cx="12" cy="12" r="3"/>
											</svg>
										</button>
										<button
											onclick={() => togglePro(user, true)}
											class="p-2 rounded-lg hover:bg-white/5 transition-all {user.is_pro ? 'text-[var(--fv-gold)]' : 'text-[var(--fv-smoke)] hover:text-[var(--fv-gold)]'}"
											title="{user.is_pro ? 'Retirer Pro' : 'Passer en Pro'}"
										>
											<svg width="16" height="16" viewBox="0 0 24 24" fill="{user.is_pro ? 'var(--fv-gold)' : 'none'}" stroke="currentColor" stroke-width="2">
												<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
											</svg>
										</button>
									</div>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if users.length === 0}
				<p class="text-sm text-[var(--fv-ash)] text-center py-12">Aucun utilisateur trouve</p>
			{/if}
		</div>

		<!-- Pagination -->
		{#if totalPages > 1}
			<div class="flex items-center justify-between mt-6">
				<p class="text-xs text-[var(--fv-smoke)]">
					Page {currentPage} sur {totalPages} ({total} resultats)
				</p>
				<div class="flex gap-2">
					<button
						onclick={() => currentPage = Math.max(1, currentPage - 1)}
						disabled={currentPage <= 1}
						class="px-4 py-2 rounded-xl text-xs font-bold bg-white/5 text-[var(--fv-smoke)] hover:bg-white/10 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
					>
						Precedent
					</button>
					<button
						onclick={() => currentPage = Math.min(totalPages, currentPage + 1)}
						disabled={currentPage >= totalPages}
						class="px-4 py-2 rounded-xl text-xs font-bold bg-white/5 text-[var(--fv-smoke)] hover:bg-white/10 transition-all disabled:opacity-30 disabled:cursor-not-allowed"
					>
						Suivant
					</button>
				</div>
			</div>
		{/if}
	{/if}
</div>

<!-- Toast notification -->
{#if toastVisible}
	<div class="fixed bottom-6 right-6 z-[200] animate-in slide-in-from-bottom-4">
		<div class="fv-glass px-5 py-3 rounded-xl border border-[var(--fv-violet)]/30 shadow-lg shadow-[var(--fv-violet)]/10">
			<p class="text-sm text-white font-medium">{toastMessage}</p>
		</div>
	</div>
{/if}

<!-- User Detail Slide-in Panel -->
{#if showDetail && selectedUser}
	<div class="fixed inset-0 z-[100] flex justify-end">
		<!-- Backdrop -->
		<button class="absolute inset-0 bg-black/70 backdrop-blur-sm" onclick={closeDetail} aria-label="Fermer"></button>

		<!-- Panel -->
		<div class="relative w-full max-w-xl h-full bg-[var(--fv-obsidian)] border-l border-white/5 overflow-y-auto z-10 animate-in slide-in-from-right">
			<!-- Header -->
			<div class="sticky top-0 z-20 bg-[var(--fv-obsidian)]/95 backdrop-blur-xl border-b border-white/5 px-6 py-4 flex items-center justify-between">
				<h2 class="text-lg font-bold text-white">Detail utilisateur</h2>
				<button onclick={closeDetail} class="p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)]">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="18" y1="6" x2="6" y2="18"/>
						<line x1="6" y1="6" x2="18" y2="18"/>
					</svg>
				</button>
			</div>

			<div class="p-6 space-y-6">
				{#if detailLoading}
					<div class="flex items-center justify-center py-8">
						<div class="w-6 h-6 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
					</div>
				{/if}

				<!-- User avatar + email -->
				<div class="flex items-center gap-4">
					<div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-cyan)] flex items-center justify-center text-2xl font-bold text-white flex-shrink-0">
						{selectedUser.email?.charAt(0).toUpperCase() ?? '?'}
					</div>
					<div class="min-w-0 flex-1">
						<p class="text-lg font-bold text-white truncate">{selectedUser.email}</p>
						<div class="flex items-center gap-2 mt-1">
							<span class="admin-badge {selectedUser.is_pro ? 'pro' : 'free'}">
								{selectedUser.is_pro ? 'Pro' : 'Gratuit'}
							</span>
							{#if selectedUser.plan && selectedUser.plan !== 'free'}
								<span class="text-[10px] text-[var(--fv-violet-light)] bg-[var(--fv-violet)]/10 px-2 py-0.5 rounded-full">
									{planLabel(selectedUser.plan)}
								</span>
							{/if}
						</div>
					</div>
				</div>

				<!-- User Info Section -->
				<div class="fv-glass p-4 rounded-xl">
					<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-3 flex items-center gap-2">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
							<circle cx="12" cy="7" r="4"/>
						</svg>
						Informations
					</h3>
					<div class="grid grid-cols-2 gap-3">
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Email</p>
							<p class="text-xs text-white font-mono break-all">{selectedUser.email}</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">ID</p>
							<p class="text-[10px] text-white font-mono break-all">{selectedUser.id}</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Inscription</p>
							<p class="text-xs text-white">{formatDateFull(selectedUser.created_at)}</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Derniere connexion</p>
							<p class="text-xs text-white">{selectedUser.last_sign_in_at ? formatDateFull(selectedUser.last_sign_in_at) : 'Jamais'}</p>
						</div>
					</div>
				</div>

				<!-- Stripe Info Section -->
				{#if selectedUser.stripe_customer_id || selectedUser.stripe_subscription_id}
					<div class="fv-glass p-4 rounded-xl">
						<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-3 flex items-center gap-2">
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<rect x="1" y="4" width="22" height="16" rx="2"/>
								<line x1="1" y1="10" x2="23" y2="10"/>
							</svg>
							Stripe
						</h3>
						<div class="space-y-2">
							{#if selectedUser.stripe_customer_id}
								<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
									<span class="text-[10px] text-[var(--fv-ash)] uppercase">Customer ID</span>
									<span class="text-xs text-[var(--fv-smoke)] font-mono">{selectedUser.stripe_customer_id}</span>
								</div>
							{/if}
							{#if selectedUser.stripe_subscription_id}
								<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
									<span class="text-[10px] text-[var(--fv-ash)] uppercase">Subscription ID</span>
									<span class="text-xs text-[var(--fv-smoke)] font-mono">{selectedUser.stripe_subscription_id}</span>
								</div>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Subscription History -->
				{#if selectedUser.stripe_subscription}
					<div class="fv-glass p-4 rounded-xl">
						<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-3 flex items-center gap-2">
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<circle cx="12" cy="12" r="10"/>
								<polyline points="12 6 12 12 16 14"/>
							</svg>
							Abonnement
						</h3>
						<div class="space-y-2">
							<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
								<span class="text-[10px] text-[var(--fv-ash)] uppercase">Statut</span>
								<span class="text-xs font-bold {selectedUser.stripe_subscription.status === 'active' ? 'text-[var(--fv-success)]' : 'text-[var(--fv-warning)]'}">
									{selectedUser.stripe_subscription.status}
								</span>
							</div>
							<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
								<span class="text-[10px] text-[var(--fv-ash)] uppercase">Montant</span>
								<span class="text-xs text-white">
									{formatAmount(selectedUser.stripe_subscription.amount, selectedUser.stripe_subscription.currency)}
									/ {selectedUser.stripe_subscription.interval === 'year' ? 'an' : 'mois'}
								</span>
							</div>
							<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
								<span class="text-[10px] text-[var(--fv-ash)] uppercase">Prochaine facturation</span>
								<span class="text-xs text-white">{formatDate(selectedUser.stripe_subscription.current_period_end)}</span>
							</div>
							{#if selectedUser.stripe_subscription.trial_end}
								<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
									<span class="text-[10px] text-[var(--fv-ash)] uppercase">Fin d'essai</span>
									<span class="text-xs text-[var(--fv-warning)]">{formatDate(selectedUser.stripe_subscription.trial_end)}</span>
								</div>
							{/if}
							{#if selectedUser.stripe_subscription.cancel_at_period_end}
								<div class="p-3 rounded-xl bg-[var(--fv-warning)]/10 border border-[var(--fv-warning)]/20">
									<p class="text-xs text-[var(--fv-warning)]">Annulation prevue en fin de periode</p>
								</div>
							{/if}
						</div>
					</div>
				{/if}

				<!-- Vault Stats Section -->
				<div class="fv-glass p-4 rounded-xl">
					<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-3 flex items-center gap-2">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<rect x="3" y="11" width="18" height="11" rx="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
						</svg>
						Coffre-fort
					</h3>
					<div class="grid grid-cols-2 gap-3">
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Elements</p>
							<p class="text-xl text-white font-bold">{selectedUser.vault_items_count ?? 0}</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Categories</p>
							<p class="text-xl text-white font-bold">{selectedUser.categories_count ?? 0}</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Derniere sync</p>
							<p class="text-xs text-white">
								{selectedUser.sync_metadata?.last_sync ? relativeTime(selectedUser.sync_metadata.last_sync) : 'Aucune'}
							</p>
						</div>
						<div class="p-3 rounded-xl bg-white/5">
							<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Appareil</p>
							<p class="text-xs text-white truncate">
								{selectedUser.sync_metadata?.device_name || 'N/A'}
							</p>
						</div>
					</div>
					{#if selectedUser.categories_list?.length}
						<div class="mt-3 flex flex-wrap gap-1.5">
							{#each selectedUser.categories_list as cat}
								<span class="text-[10px] px-2 py-0.5 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet-light)] border border-[var(--fv-violet)]/20">
									{cat}
								</span>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Recovery Key Info -->
				<div class="fv-glass p-4 rounded-xl">
					<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-3 flex items-center gap-2">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
						</svg>
						Cle de recuperation
					</h3>
					<div class="p-3 rounded-xl bg-white/5 border border-white/5">
						<div class="flex items-center gap-3">
							<div class="w-10 h-10 rounded-lg bg-[var(--fv-warning)]/10 flex items-center justify-center flex-shrink-0">
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-warning)" stroke-width="2">
									<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
								</svg>
							</div>
							<div>
								<p class="text-xs text-[var(--fv-smoke)] font-medium">Zero-knowledge</p>
								<p class="text-[10px] text-[var(--fv-ash)] leading-relaxed mt-0.5">
									La cle de recuperation est chiffree cote client. L'administrateur ne peut pas y acceder en raison de l'architecture zero-knowledge. Seul l'utilisateur possede son mot de passe maitre.
								</p>
							</div>
						</div>
					</div>
				</div>

				<!-- Action Messages -->
				{#if actionMessage}
					<div class="p-3 rounded-xl {actionMessageType === 'success' ? 'bg-[var(--fv-success)]/10 border border-[var(--fv-success)]/20' : 'bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20'}">
						<p class="text-xs {actionMessageType === 'success' ? 'text-[var(--fv-success)]' : 'text-[var(--fv-danger)]'}">{actionMessage}</p>
					</div>
				{/if}

				<!-- Actions Section -->
				<div class="fv-glass p-4 rounded-xl">
					<h3 class="text-xs font-bold text-[var(--fv-violet-light)] uppercase tracking-wider mb-4 flex items-center gap-2">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<circle cx="12" cy="12" r="3"/>
							<path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9"/>
						</svg>
						Actions
					</h3>
					<div class="space-y-3">
						<!-- Toggle Pro -->
						<button
							onclick={() => togglePro(selectedUser)}
							disabled={actionLoading}
							class="w-full flex items-center justify-between px-4 py-3 rounded-xl transition-all {selectedUser.is_pro ? 'bg-white/5 hover:bg-white/8 border border-white/8' : 'bg-[var(--fv-gold)]/10 hover:bg-[var(--fv-gold)]/15 border border-[var(--fv-gold)]/20'}"
						>
							<span class="text-sm font-medium {selectedUser.is_pro ? 'text-[var(--fv-smoke)]' : 'text-[var(--fv-gold)]'}">
								{selectedUser.is_pro ? 'Retirer le statut Pro' : 'Passer en Pro'}
							</span>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="{selectedUser.is_pro ? 'var(--fv-gold)' : 'none'}" stroke="{selectedUser.is_pro ? 'var(--fv-gold)' : 'currentColor'}" stroke-width="2">
								<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>
							</svg>
						</button>

						<!-- Change Plan -->
						<div class="flex items-center gap-2">
							<select
								bind:value={selectedPlan}
								class="flex-1 admin-input text-sm"
							>
								{#each planOptions as opt}
									<option value={opt.value}>{opt.label}</option>
								{/each}
							</select>
							<button
								onclick={changePlan}
								disabled={actionLoading || selectedPlan === (selectedUser.plan || 'free')}
								class="px-4 py-2.5 rounded-xl text-xs font-bold bg-[var(--fv-violet)] text-white hover:bg-[var(--fv-violet-light)] transition-all disabled:opacity-30 disabled:cursor-not-allowed"
							>
								Appliquer
							</button>
						</div>

						<!-- Send Password Reset -->
						<button
							onclick={sendPasswordReset}
							disabled={resetLoading}
							class="w-full flex items-center justify-between px-4 py-3 rounded-xl bg-white/5 hover:bg-white/8 border border-white/8 transition-all"
						>
							<span class="text-sm font-medium text-[var(--fv-smoke)]">
								{resetLoading ? 'Envoi en cours...' : 'Envoyer un lien de recuperation'}
							</span>
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2">
								<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/>
								<polyline points="22,6 12,13 2,6"/>
							</svg>
						</button>

						<!-- Delete User -->
						{#if !showDeleteConfirm}
							<button
								onclick={() => showDeleteConfirm = true}
								class="w-full flex items-center justify-between px-4 py-3 rounded-xl bg-[var(--fv-danger)]/5 hover:bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 transition-all"
							>
								<span class="text-sm font-medium text-[var(--fv-danger)]">Supprimer l'utilisateur</span>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2">
									<polyline points="3 6 5 6 21 6"/>
									<path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
									<line x1="10" y1="11" x2="10" y2="17"/>
									<line x1="14" y1="11" x2="14" y2="17"/>
								</svg>
							</button>
						{:else}
							<div class="p-4 rounded-xl border border-[var(--fv-danger)]/30 bg-[var(--fv-danger)]/5">
								<p class="text-sm text-[var(--fv-danger)] font-bold mb-2">Confirmer la suppression</p>
								<p class="text-xs text-[var(--fv-smoke)] mb-3">
									Cette action est irreversible. Toutes les donnees de l'utilisateur seront supprimees.
									Tapez <strong class="text-white">DELETE</strong> pour confirmer.
								</p>
								<input
									type="text"
									bind:value={deleteConfirmText}
									placeholder="Tapez DELETE"
									class="admin-input mb-3 text-sm"
								/>
								<div class="flex gap-2">
									<button
										onclick={deleteUser}
										disabled={deleteConfirmText !== 'DELETE' || actionLoading}
										class="flex-1 px-4 py-2.5 rounded-xl text-xs font-bold bg-[var(--fv-danger)] text-white disabled:opacity-30 disabled:cursor-not-allowed transition-all"
									>
										{actionLoading ? 'Suppression...' : 'Confirmer'}
									</button>
									<button
										onclick={() => { showDeleteConfirm = false; deleteConfirmText = ''; }}
										class="flex-1 px-4 py-2.5 rounded-xl text-xs font-bold bg-white/5 text-[var(--fv-smoke)] hover:bg-white/10 transition-all"
									>
										Annuler
									</button>
								</div>
							</div>
						{/if}
					</div>
				</div>
			</div>
		</div>
	</div>
{/if}

<style>
	@keyframes slide-in-from-right {
		from { transform: translateX(100%); }
		to { transform: translateX(0); }
	}
	@keyframes slide-in-from-bottom-4 {
		from { transform: translateY(1rem); opacity: 0; }
		to { transform: translateY(0); opacity: 1; }
	}
	:global(.animate-in.slide-in-from-right) {
		animation: slide-in-from-right 0.3s ease-out;
	}
	:global(.animate-in.slide-in-from-bottom-4) {
		animation: slide-in-from-bottom-4 0.3s ease-out;
	}
</style>
