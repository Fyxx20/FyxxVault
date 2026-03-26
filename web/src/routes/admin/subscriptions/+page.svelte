<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let subscriptions = $state<any[]>([]);
	let counts = $state<any>({ active: 0, trialing: 0, canceled: 0, past_due: 0, incomplete: 0 });
	let loading = $state(true);
	let error = $state('');
	let statusFilter = $state('all');

	function getToken(): string {
		return auth.session?.access_token ?? '';
	}

	async function fetchSubscriptions() {
		loading = true;
		error = '';
		try {
			const params = new URLSearchParams();
			if (statusFilter && statusFilter !== 'all') params.set('status', statusFilter);

			const res = await fetch(`/api/admin/subscriptions?${params}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (!res.ok) throw new Error('Erreur de chargement');

			const data = await res.json();
			subscriptions = data.subscriptions ?? [];
			counts = data.counts ?? counts;
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (auth.session?.access_token) {
			fetchSubscriptions();
		}
	});

	let prevFilter = $state('all');
	$effect(() => {
		if (statusFilter !== prevFilter) {
			prevFilter = statusFilter;
			fetchSubscriptions();
		}
	});

	function formatCurrency(cents: number, currency: string = 'eur'): string {
		return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: currency.toUpperCase() }).format(cents / 100);
	}

	function formatTimestamp(ts: number | null): string {
		if (!ts) return 'N/A';
		return new Intl.DateTimeFormat('fr-FR', { day: '2-digit', month: 'short', year: 'numeric' }).format(new Date(ts * 1000));
	}

	function statusLabel(status: string): string {
		const map: Record<string, string> = {
			active: 'Actif',
			trialing: 'Essai',
			canceled: 'Annule',
			past_due: 'En retard',
			incomplete: 'Incomplet',
			incomplete_expired: 'Expire',
			unpaid: 'Impaye'
		};
		return map[status] ?? status;
	}

	const statusFilters = [
		{ value: 'all', label: 'Tous' },
		{ value: 'active', label: 'Actifs' },
		{ value: 'trialing', label: 'Essai' },
		{ value: 'canceled', label: 'Annules' },
		{ value: 'past_due', label: 'En retard' }
	];
</script>

<svelte:head>
	<title>Abonnements - Admin FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="flex items-center justify-between mb-6">
		<div>
			<h1 class="text-2xl font-extrabold text-white mb-1">Abonnements</h1>
			<p class="text-sm text-[var(--fv-smoke)]">Gestion des abonnements Stripe</p>
		</div>
		<a
			href="https://dashboard.stripe.com/subscriptions"
			target="_blank"
			rel="noopener noreferrer"
			class="fv-btn fv-btn-ghost text-xs gap-2"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
				<polyline points="15 3 21 3 21 9"/>
				<line x1="10" y1="14" x2="21" y2="3"/>
			</svg>
			Stripe Dashboard
		</a>
	</div>

	<!-- Status counts -->
	<div class="grid grid-cols-2 sm:grid-cols-5 gap-3 mb-6">
		<div class="admin-stat-card success">
			<p class="text-2xl font-extrabold text-white">{counts.active}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Actifs</p>
		</div>
		<div class="admin-stat-card violet">
			<p class="text-2xl font-extrabold text-white">{counts.trialing}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Essai</p>
		</div>
		<div class="admin-stat-card rose">
			<p class="text-2xl font-extrabold text-white">{counts.canceled}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Annules</p>
		</div>
		<div class="admin-stat-card gold">
			<p class="text-2xl font-extrabold text-white">{counts.past_due}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">En retard</p>
		</div>
		<div class="admin-stat-card cyan">
			<p class="text-2xl font-extrabold text-white">{counts.incomplete}</p>
			<p class="text-[10px] text-[var(--fv-smoke)] uppercase tracking-wider mt-1">Incomplets</p>
		</div>
	</div>

	<!-- Filters -->
	<div class="flex gap-2 mb-6 flex-wrap">
		{#each statusFilters as f}
			<button
				onclick={() => statusFilter = f.value}
				class="px-4 py-2.5 rounded-xl text-xs font-bold transition-all
					{statusFilter === f.value
						? 'bg-[var(--fv-violet)] text-white'
						: 'bg-white/5 text-[var(--fv-smoke)] hover:bg-white/10 border border-white/8'}"
			>
				{f.label}
			</button>
		{/each}
	</div>

	<!-- Subscriptions table -->
	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
		</div>
	{:else if error}
		<div class="fv-glass p-6 text-center">
			<p class="text-[var(--fv-danger)]">{error}</p>
			<button onclick={fetchSubscriptions} class="mt-4 fv-btn fv-btn-ghost text-sm">Reessayer</button>
		</div>
	{:else}
		<div class="fv-glass overflow-hidden">
			<div class="overflow-x-auto">
				<table class="admin-table">
					<thead>
						<tr>
							<th>Client</th>
							<th>Plan</th>
							<th>Statut</th>
							<th>Montant</th>
							<th>Prochaine facturation</th>
							<th>Fin d'essai</th>
							<th>Actions</th>
						</tr>
					</thead>
					<tbody>
						{#each subscriptions as sub}
							<tr>
								<td>
									<div class="flex items-center gap-3">
										<div class="w-8 h-8 rounded-full bg-gradient-to-br from-[var(--fv-violet)] to-[var(--fv-cyan)] flex items-center justify-center text-xs font-bold text-white flex-shrink-0">
											{sub.customer_email?.charAt(0).toUpperCase() ?? '?'}
										</div>
										<div>
											<p class="text-sm text-white truncate max-w-[180px]">{sub.customer_email}</p>
											{#if sub.customer_name}
												<p class="text-[10px] text-[var(--fv-ash)]">{sub.customer_name}</p>
											{/if}
										</div>
									</div>
								</td>
								<td>
									<span class="text-xs font-bold text-[var(--fv-smoke)] uppercase">
										{sub.plan === 'yearly' ? 'Annuel' : 'Mensuel'}
									</span>
								</td>
								<td>
									<span class="admin-badge {sub.status}">
										{statusLabel(sub.status)}
									</span>
								</td>
								<td class="text-white font-medium">
									{formatCurrency(sub.amount, sub.currency)}
									<span class="text-[10px] text-[var(--fv-ash)]">/{sub.plan === 'yearly' ? 'an' : 'mois'}</span>
								</td>
								<td class="text-[var(--fv-smoke)] text-xs">
									{formatTimestamp(sub.current_period_end)}
									{#if sub.cancel_at_period_end}
										<span class="block text-[var(--fv-danger)] text-[10px]">Annulation prevue</span>
									{/if}
								</td>
								<td class="text-[var(--fv-smoke)] text-xs">
									{sub.trial_end ? formatTimestamp(sub.trial_end) : '-'}
								</td>
								<td>
									<a
										href="https://dashboard.stripe.com/subscriptions/{sub.id}"
										target="_blank"
										rel="noopener noreferrer"
										class="p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)] hover:text-white transition-all inline-flex"
										title="Voir dans Stripe"
									>
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
											<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
											<polyline points="15 3 21 3 21 9"/>
											<line x1="10" y1="14" x2="21" y2="3"/>
										</svg>
									</a>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			{#if subscriptions.length === 0}
				<p class="text-sm text-[var(--fv-ash)] text-center py-12">Aucun abonnement trouve</p>
			{/if}
		</div>
	{/if}
</div>
