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

	function getToken(): string {
		return auth.session?.access_token ?? '';
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
		try {
			const res = await fetch(`/api/admin/users/${user.id}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (res.ok) {
				selectedUser = await res.json();
			} else {
				selectedUser = user;
			}
		} catch {
			selectedUser = user;
		}
		showDetail = true;
	}

	function closeDetail() {
		showDetail = false;
		selectedUser = null;
		showDeleteConfirm = false;
		deleteConfirmText = '';
		actionMessage = '';
	}

	async function togglePro(user: any) {
		actionLoading = true;
		actionMessage = '';
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
				actionMessage = `Utilisateur ${!user.is_pro ? 'passe en Pro' : 'repasse en Gratuit'}`;
				if (selectedUser) selectedUser.is_pro = !user.is_pro;
				await fetchUsers();
			} else {
				actionMessage = 'Erreur lors de la mise a jour';
			}
		} catch {
			actionMessage = 'Erreur reseau';
		} finally {
			actionLoading = false;
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
			} else {
				actionMessage = 'Erreur lors de la suppression';
			}
		} catch {
			actionMessage = 'Erreur reseau';
		} finally {
			actionLoading = false;
		}
	}

	function formatDate(dateStr: string): string {
		if (!dateStr) return 'N/A';
		return new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(dateStr));
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

	const filters = [
		{ value: 'all', label: 'Tous' },
		{ value: 'pro', label: 'Pro' },
		{ value: 'free', label: 'Gratuit' }
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
											onclick={() => togglePro(user)}
											class="p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)] hover:text-[var(--fv-gold)] transition-all"
											title="{user.is_pro ? 'Retirer Pro' : 'Passer en Pro'}"
										>
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
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

<!-- User Detail Modal -->
{#if showDetail && selectedUser}
	<div class="fixed inset-0 z-[100] flex items-center justify-center p-4">
		<button class="absolute inset-0 bg-black/70" onclick={closeDetail} aria-label="Fermer"></button>
		<div class="relative w-full max-w-lg fv-glass p-6 max-h-[90vh] overflow-y-auto z-10">
			<!-- Close -->
			<button onclick={closeDetail} class="absolute top-4 right-4 p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)]">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<line x1="18" y1="6" x2="6" y2="18"/>
					<line x1="6" y1="6" x2="18" y2="18"/>
				</svg>
			</button>

			<!-- User avatar + email -->
			<div class="flex items-center gap-4 mb-6">
				<div class="w-14 h-14 rounded-full bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-cyan)] flex items-center justify-center text-xl font-bold text-white flex-shrink-0">
					{selectedUser.email?.charAt(0).toUpperCase() ?? '?'}
				</div>
				<div>
					<p class="text-lg font-bold text-white">{selectedUser.email}</p>
					<div class="flex items-center gap-2 mt-1">
						<span class="admin-badge {selectedUser.is_pro ? 'pro' : 'free'}">
							{selectedUser.is_pro ? 'Pro' : 'Gratuit'}
						</span>
						<span class="text-[10px] text-[var(--fv-ash)] font-mono">{selectedUser.id}</span>
					</div>
				</div>
			</div>

			<!-- Info grid -->
			<div class="grid grid-cols-2 gap-4 mb-6">
				<div class="p-3 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Inscription</p>
					<p class="text-sm text-white">{formatDate(selectedUser.created_at)}</p>
				</div>
				<div class="p-3 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Derniere connexion</p>
					<p class="text-sm text-white">{selectedUser.last_sign_in_at ? relativeTime(selectedUser.last_sign_in_at) : 'Jamais'}</p>
				</div>
				<div class="p-3 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Elements du coffre</p>
					<p class="text-sm text-white">{selectedUser.vault_items_count}</p>
				</div>
				<div class="p-3 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Plan</p>
					<p class="text-sm text-white">{selectedUser.plan || 'free'}</p>
				</div>
			</div>

			<!-- Stripe info if available -->
			{#if selectedUser.stripe_customer_id}
				<div class="p-3 rounded-xl bg-white/5 mb-6">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Stripe</p>
					<p class="text-xs text-[var(--fv-smoke)] font-mono">Customer: {selectedUser.stripe_customer_id}</p>
					{#if selectedUser.stripe_subscription_id}
						<p class="text-xs text-[var(--fv-smoke)] font-mono">Subscription: {selectedUser.stripe_subscription_id}</p>
					{/if}
				</div>
			{/if}

			{#if actionMessage}
				<p class="text-sm text-[var(--fv-success)] mb-4">{actionMessage}</p>
			{/if}

			<!-- Actions -->
			<div class="space-y-3">
				<button
					onclick={() => togglePro(selectedUser)}
					disabled={actionLoading}
					class="w-full fv-btn {selectedUser.is_pro ? 'fv-btn-ghost' : 'fv-btn-gold'} text-sm"
				>
					{selectedUser.is_pro ? 'Retirer le statut Pro' : 'Passer en Pro'}
				</button>

				{#if !showDeleteConfirm}
					<button
						onclick={() => showDeleteConfirm = true}
						class="w-full fv-btn text-sm bg-[var(--fv-danger)]/10 text-[var(--fv-danger)] border border-[var(--fv-danger)]/20 hover:bg-[var(--fv-danger)]/20"
					>
						Supprimer l'utilisateur
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
								class="flex-1 fv-btn text-sm bg-[var(--fv-danger)] text-white disabled:opacity-30 disabled:cursor-not-allowed"
							>
								{actionLoading ? 'Suppression...' : 'Confirmer'}
							</button>
							<button
								onclick={() => { showDeleteConfirm = false; deleteConfirmText = ''; }}
								class="flex-1 fv-btn fv-btn-ghost text-sm"
							>
								Annuler
							</button>
						</div>
					</div>
				{/if}
			</div>
		</div>
	</div>
{/if}
