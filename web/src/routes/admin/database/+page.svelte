<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	let tables = $state<Record<string, number>>({});
	let loading = $state(true);
	let error = $state('');

	// SQL runner
	let query = $state('');
	let queryResult = $state<any>(null);
	let queryError = $state('');
	let queryLoading = $state(false);
	let showConfirmDialog = $state(false);

	function getToken(): string {
		return auth.session?.access_token ?? '';
	}

	async function fetchTables() {
		loading = true;
		error = '';
		try {
			const res = await fetch('/api/admin/database', {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (!res.ok) throw new Error('Erreur de chargement');
			const data = await res.json();
			tables = data.tables ?? {};
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	$effect(() => {
		if (auth.session?.access_token) {
			fetchTables();
		}
	});

	function handleExecuteClick() {
		if (!query.trim()) return;
		showConfirmDialog = true;
	}

	async function executeQuery() {
		showConfirmDialog = false;
		queryLoading = true;
		queryError = '';
		queryResult = null;

		try {
			const res = await fetch('/api/admin/database', {
				method: 'POST',
				headers: {
					Authorization: `Bearer ${getToken()}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ query })
			});

			const data = await res.json();
			if (!res.ok) {
				queryError = data.error || 'Erreur';
				if (data.hint) queryError += ` — ${data.hint}`;
			} else {
				queryResult = data;
			}
		} catch (e: any) {
			queryError = e.message;
		} finally {
			queryLoading = false;
		}
	}

	const tableIcons: Record<string, string> = {
		profiles: 'user',
		vault_items: 'lock',
		sync_metadata: 'refresh'
	};

	function totalRows(): number {
		return Object.values(tables).reduce((sum, count) => sum + count, 0);
	}
</script>

<svelte:head>
	<title>Base de donnees - Admin FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="mb-6">
		<h1 class="text-2xl font-extrabold text-white mb-1">Base de donnees</h1>
		<p class="text-sm text-[var(--fv-smoke)]">Statistiques et requetes Supabase</p>
	</div>

	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
		</div>
	{:else if error}
		<div class="fv-glass p-6 text-center">
			<p class="text-[var(--fv-danger)]">{error}</p>
			<button onclick={fetchTables} class="mt-4 fv-btn fv-btn-ghost text-sm">Reessayer</button>
		</div>
	{:else}
		<!-- Table Stats -->
		<div class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
			{#each Object.entries(tables) as [name, count], i}
				<div class="admin-stat-card {i === 0 ? 'violet' : i === 1 ? 'cyan' : 'gold'}">
					<div class="flex items-center justify-between mb-3">
						<span class="text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider">{name}</span>
						{#if name === 'profiles'}
							<div class="w-8 h-8 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
									<path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
									<circle cx="12" cy="7" r="4"/>
								</svg>
							</div>
						{:else if name === 'vault_items'}
							<div class="w-8 h-8 rounded-lg bg-[var(--fv-cyan)]/15 flex items-center justify-center">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2">
									<rect x="3" y="11" width="18" height="11" rx="2"/>
									<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
								</svg>
							</div>
						{:else}
							<div class="w-8 h-8 rounded-lg bg-[var(--fv-gold)]/15 flex items-center justify-center">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2">
									<polyline points="23 4 23 10 17 10"/>
									<path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"/>
								</svg>
							</div>
						{/if}
					</div>
					<p class="text-3xl font-extrabold text-white">{count}</p>
					<p class="text-xs text-[var(--fv-smoke)] mt-1">lignes</p>
				</div>
			{/each}
		</div>

		<!-- Total -->
		<div class="fv-glass p-4 mb-8 flex items-center justify-between">
			<span class="text-sm text-[var(--fv-smoke)]">Total des enregistrements</span>
			<span class="text-lg font-bold text-white">{totalRows()}</span>
		</div>

		<!-- SQL Query Runner -->
		<div class="fv-glass p-6">
			<div class="flex items-center gap-3 mb-4">
				<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<polyline points="16 18 22 12 16 6"/>
					<polyline points="8 6 2 12 8 18"/>
				</svg>
				<h2 class="text-sm font-bold text-white">Requete SQL</h2>
				<span class="px-2 py-0.5 rounded-md bg-[var(--fv-warning)]/15 text-[var(--fv-warning)] text-[10px] font-bold uppercase">Avance</span>
			</div>

			<p class="text-xs text-[var(--fv-ash)] mb-4">
				Executez des requetes SQL directement sur la base de donnees Supabase.
				Les operations DROP, TRUNCATE, ALTER, CREATE, GRANT et REVOKE sont interdites.
				Necessite la fonction RPC <code class="text-[var(--fv-violet-light)]">admin_run_sql</code> dans Supabase.
			</p>

			<textarea
				bind:value={query}
				placeholder="SELECT * FROM profiles LIMIT 10;"
				rows="4"
				class="admin-input font-mono text-sm resize-y mb-4"
				style="min-height: 100px;"
			></textarea>

			<div class="flex items-center gap-3">
				<button
					onclick={handleExecuteClick}
					disabled={!query.trim() || queryLoading}
					class="fv-btn text-sm bg-[var(--fv-violet)] text-white disabled:opacity-30 disabled:cursor-not-allowed"
				>
					{#if queryLoading}
						<div class="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
						Execution...
					{:else}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<polygon points="5 3 19 12 5 21 5 3"/>
						</svg>
						Executer
					{/if}
				</button>
				{#if queryResult || queryError}
					<button
						onclick={() => { queryResult = null; queryError = ''; }}
						class="fv-btn fv-btn-ghost text-xs"
					>
						Effacer
					</button>
				{/if}
			</div>

			<!-- Query results -->
			{#if queryError}
				<div class="mt-4 p-4 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
					<p class="text-sm text-[var(--fv-danger)] font-mono">{queryError}</p>
				</div>
			{/if}

			{#if queryResult}
				<div class="mt-4">
					<div class="flex items-center justify-between mb-2">
						<p class="text-xs text-[var(--fv-smoke)]">{queryResult.rowCount} resultat{queryResult.rowCount > 1 ? 's' : ''}</p>
					</div>

					{#if Array.isArray(queryResult.data) && queryResult.data.length > 0}
						<div class="overflow-x-auto rounded-xl border border-white/5">
							<table class="admin-table">
								<thead>
									<tr>
										{#each Object.keys(queryResult.data[0]) as col}
											<th>{col}</th>
										{/each}
									</tr>
								</thead>
								<tbody>
									{#each queryResult.data.slice(0, 100) as row}
										<tr>
											{#each Object.values(row) as val}
												<td class="font-mono text-xs max-w-[300px] truncate">
													{val === null ? 'NULL' : typeof val === 'object' ? JSON.stringify(val) : String(val)}
												</td>
											{/each}
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
						{#if queryResult.data.length > 100}
							<p class="text-xs text-[var(--fv-ash)] mt-2">Affichage limite a 100 lignes</p>
						{/if}
					{:else}
						<p class="text-sm text-[var(--fv-ash)]">Aucun resultat</p>
					{/if}
				</div>
			{/if}
		</div>
	{/if}
</div>

<!-- Confirm Dialog -->
{#if showConfirmDialog}
	<div class="fixed inset-0 z-[100] flex items-center justify-center p-4">
		<button class="absolute inset-0 bg-black/70" onclick={() => showConfirmDialog = false} aria-label="Fermer"></button>
		<div class="relative w-full max-w-md fv-glass p-6 z-10">
			<div class="flex items-center gap-3 mb-4">
				<div class="w-10 h-10 rounded-lg bg-[var(--fv-warning)]/15 flex items-center justify-center">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-warning)" stroke-width="2">
						<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
						<line x1="12" y1="9" x2="12" y2="13"/>
						<line x1="12" y1="17" x2="12.01" y2="17"/>
					</svg>
				</div>
				<div>
					<p class="text-sm font-bold text-white">Confirmer l'execution</p>
					<p class="text-xs text-[var(--fv-smoke)]">Cette requete sera executee sur la base de production</p>
				</div>
			</div>

			<div class="p-3 rounded-xl bg-white/5 mb-4">
				<code class="text-xs text-[var(--fv-violet-light)] font-mono break-all">{query}</code>
			</div>

			<div class="flex gap-3">
				<button
					onclick={executeQuery}
					class="flex-1 fv-btn text-sm bg-[var(--fv-violet)] text-white"
				>
					Executer
				</button>
				<button
					onclick={() => showConfirmDialog = false}
					class="flex-1 fv-btn fv-btn-ghost text-sm"
				>
					Annuler
				</button>
			</div>
		</div>
	</div>
{/if}
