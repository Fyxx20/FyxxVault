<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	// Environment variables status (check which are set - we don't show values)
	let envStatus = $state<Record<string, boolean>>({});
	let loading = $state(true);
	let maintenanceMode = $state(false);
	let maintenanceLoading = $state(false);
	let maintenanceMessage = $state('');

	// We check env status by trying a simple admin request
	$effect(() => {
		if (auth.session?.access_token) {
			checkEnvStatus();
			fetchMaintenanceStatus();
		}
	});

	async function fetchMaintenanceStatus() {
		try {
			const res = await fetch('/api/admin/maintenance', {
				headers: { Authorization: `Bearer ${auth.session?.access_token}` }
			});
			if (res.ok) {
				const data = await res.json();
				maintenanceMode = data.maintenance === true;
			}
		} catch {
			// ignore
		}
	}

	async function toggleMaintenance() {
		maintenanceLoading = true;
		maintenanceMessage = '';
		const newValue = !maintenanceMode;
		try {
			const res = await fetch('/api/admin/maintenance', {
				method: 'POST',
				headers: {
					Authorization: `Bearer ${auth.session?.access_token}`,
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ enabled: newValue })
			});
			if (res.ok) {
				maintenanceMode = newValue;
				maintenanceMessage = newValue
					? 'Mode maintenance active. Les utilisateurs ne peuvent plus acceder a la plateforme.'
					: 'Mode maintenance desactive. La plateforme est accessible.';
			} else {
				maintenanceMessage = 'Erreur lors de la mise a jour du mode maintenance.';
			}
		} catch {
			maintenanceMessage = 'Erreur reseau.';
		} finally {
			maintenanceLoading = false;
			setTimeout(() => { maintenanceMessage = ''; }, 5000);
		}
	}

	async function checkEnvStatus() {
		loading = true;
		try {
			// If stats API works, Supabase + Stripe keys are configured
			const res = await fetch('/api/admin/stats', {
				headers: { Authorization: `Bearer ${auth.session?.access_token}` }
			});
			if (res.ok) {
				envStatus = {
					PUBLIC_SUPABASE_URL: true,
					PUBLIC_SUPABASE_ANON_KEY: true,
					SUPABASE_SERVICE_ROLE_KEY: true,
					STRIPE_SECRET_KEY: true,
					STRIPE_WEBHOOK_SECRET: true
				};
			} else {
				envStatus = {
					PUBLIC_SUPABASE_URL: true,
					PUBLIC_SUPABASE_ANON_KEY: true,
					SUPABASE_SERVICE_ROLE_KEY: false,
					STRIPE_SECRET_KEY: false,
					STRIPE_WEBHOOK_SECRET: false
				};
			}
		} catch {
			envStatus = {
				PUBLIC_SUPABASE_URL: false,
				PUBLIC_SUPABASE_ANON_KEY: false,
				SUPABASE_SERVICE_ROLE_KEY: false,
				STRIPE_SECRET_KEY: false,
				STRIPE_WEBHOOK_SECRET: false
			};
		} finally {
			loading = false;
		}
	}

	const envGroups = [
		{
			title: 'Supabase',
			icon: 'database',
			vars: ['PUBLIC_SUPABASE_URL', 'PUBLIC_SUPABASE_ANON_KEY', 'SUPABASE_SERVICE_ROLE_KEY']
		},
		{
			title: 'Stripe',
			icon: 'credit-card',
			vars: ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET']
		}
	];

	const appVersion = '1.0.0';
	const buildDate = '2026-03-26';
</script>

<svelte:head>
	<title>Parametres - Admin FyxxVault</title>
</svelte:head>

<div class="max-w-4xl mx-auto">
	<!-- Header -->
	<div class="mb-6">
		<h1 class="text-2xl font-extrabold text-white mb-1">Parametres</h1>
		<p class="text-sm text-[var(--fv-smoke)]">Configuration de la plateforme</p>
	</div>

	{#if loading}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
		</div>
	{:else}
		<!-- Platform Info -->
		<div class="fv-glass p-6 mb-6">
			<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<circle cx="12" cy="12" r="10"/>
					<line x1="12" y1="16" x2="12" y2="12"/>
					<line x1="12" y1="8" x2="12.01" y2="8"/>
				</svg>
				Informations de la plateforme
			</h2>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
				<div class="p-4 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Application</p>
					<p class="text-sm text-white font-bold">FyxxVault</p>
					<p class="text-xs text-[var(--fv-smoke)]">Gestionnaire de mots de passe securise</p>
				</div>
				<div class="p-4 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Version</p>
					<p class="text-sm text-white font-mono">{appVersion}</p>
					<p class="text-xs text-[var(--fv-smoke)]">Build {buildDate}</p>
				</div>
				<div class="p-4 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Frontend</p>
					<p class="text-sm text-white">SvelteKit + Svelte 5</p>
					<p class="text-xs text-[var(--fv-smoke)]">Deploye sur Netlify</p>
				</div>
				<div class="p-4 rounded-xl bg-white/5">
					<p class="text-[10px] text-[var(--fv-ash)] uppercase tracking-wider mb-1">Backend</p>
					<p class="text-sm text-white">Supabase + Stripe</p>
					<p class="text-xs text-[var(--fv-smoke)]">PostgreSQL, Auth, RLS</p>
				</div>
			</div>
		</div>

		<!-- Environment Variables -->
		<div class="fv-glass p-6 mb-6">
			<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<rect x="3" y="11" width="18" height="11" rx="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
				Variables d'environnement
			</h2>

			<div class="space-y-4">
				{#each envGroups as group}
					<div>
						<p class="text-xs font-bold text-[var(--fv-smoke)] uppercase tracking-wider mb-2 flex items-center gap-2">
							{#if group.icon === 'database'}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<ellipse cx="12" cy="5" rx="9" ry="3"/>
									<path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
									<path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
								</svg>
							{:else}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
									<rect x="1" y="4" width="22" height="16" rx="2"/>
									<line x1="1" y1="10" x2="23" y2="10"/>
								</svg>
							{/if}
							{group.title}
						</p>
						<div class="space-y-2">
							{#each group.vars as v}
								<div class="flex items-center justify-between p-3 rounded-xl bg-white/5">
									<span class="text-xs text-[var(--fv-silver)] font-mono">{v}</span>
									<div class="flex items-center gap-2">
										{#if envStatus[v]}
											<span class="flex items-center gap-1 text-xs text-[var(--fv-success)]">
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
													<polyline points="20 6 9 17 4 12"/>
												</svg>
												Configure
											</span>
										{:else}
											<span class="flex items-center gap-1 text-xs text-[var(--fv-danger)]">
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
													<line x1="18" y1="6" x2="6" y2="18"/>
													<line x1="6" y1="6" x2="18" y2="18"/>
												</svg>
												Non configure
											</span>
										{/if}
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		</div>

		<!-- Webhook Status -->
		<div class="fv-glass p-6 mb-6">
			<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/>
					<path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>
				</svg>
				Webhooks
			</h2>

			<div class="space-y-3">
				<div class="flex items-center justify-between p-4 rounded-xl bg-white/5">
					<div>
						<p class="text-sm text-white font-medium">Stripe Webhook</p>
						<p class="text-xs text-[var(--fv-ash)] font-mono">/api/webhook/stripe</p>
					</div>
					<span class="flex items-center gap-1 text-xs {envStatus.STRIPE_WEBHOOK_SECRET ? 'text-[var(--fv-success)]' : 'text-[var(--fv-danger)]'}">
						<span class="w-2 h-2 rounded-full {envStatus.STRIPE_WEBHOOK_SECRET ? 'bg-[var(--fv-success)]' : 'bg-[var(--fv-danger)]'}"></span>
						{envStatus.STRIPE_WEBHOOK_SECRET ? 'Actif' : 'Inactif'}
					</span>
				</div>
			</div>
		</div>

		<!-- Maintenance Mode -->
		<div class="fv-glass p-6 mb-6">
			<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
				</svg>
				Maintenance
			</h2>

			<div class="flex items-center justify-between p-4 rounded-xl bg-white/5">
				<div>
					<p class="text-sm text-white font-medium">Mode maintenance</p>
					<p class="text-xs text-[var(--fv-ash)]">Desactive temporairement l'acces a la plateforme pour les utilisateurs</p>
				</div>
				<button
					onclick={toggleMaintenance}
					disabled={maintenanceLoading}
					class="relative w-12 h-7 rounded-full transition-all {maintenanceMode ? 'bg-[var(--fv-danger)]' : 'bg-[var(--fv-ash)]'} {maintenanceLoading ? 'opacity-50 cursor-not-allowed' : ''}"
				>
					<span class="absolute top-1 transition-all w-5 h-5 rounded-full bg-white {maintenanceMode ? 'left-6' : 'left-1'}"></span>
				</button>
			</div>
			{#if maintenanceMode}
				<div class="mt-3 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
					<p class="text-xs text-[var(--fv-danger)] font-medium">
						Mode maintenance actif — Seul l'administrateur (fyxxfn@gmail.com) peut acceder a la plateforme.
					</p>
				</div>
			{/if}
			{#if maintenanceMessage}
				<div class="mt-3 p-3 rounded-xl bg-[var(--fv-violet)]/10 border border-[var(--fv-violet)]/20">
					<p class="text-xs text-[var(--fv-violet-light)]">{maintenanceMessage}</p>
				</div>
			{/if}
		</div>

		<!-- Links -->
		<div class="fv-glass p-6">
			<h2 class="text-sm font-bold text-white mb-4 flex items-center gap-2">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
					<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>
					<polyline points="15 3 21 3 21 9"/>
					<line x1="10" y1="14" x2="21" y2="3"/>
				</svg>
				Liens externes
			</h2>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
				<a
					href="https://supabase.com/dashboard"
					target="_blank"
					rel="noopener noreferrer"
					class="flex items-center gap-3 p-4 rounded-xl bg-white/5 hover:bg-white/8 transition-all group"
				>
					<div class="w-10 h-10 rounded-lg bg-[var(--fv-success)]/15 flex items-center justify-center">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2">
							<ellipse cx="12" cy="5" rx="9" ry="3"/>
							<path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/>
							<path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/>
						</svg>
					</div>
					<div>
						<p class="text-sm text-white font-medium group-hover:text-[var(--fv-success)] transition-colors">Supabase Dashboard</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Base de donnees, Auth, RLS</p>
					</div>
				</a>
				<a
					href="https://dashboard.stripe.com"
					target="_blank"
					rel="noopener noreferrer"
					class="flex items-center gap-3 p-4 rounded-xl bg-white/5 hover:bg-white/8 transition-all group"
				>
					<div class="w-10 h-10 rounded-lg bg-[var(--fv-violet)]/15 flex items-center justify-center">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet-light)" stroke-width="2">
							<rect x="1" y="4" width="22" height="16" rx="2"/>
							<line x1="1" y1="10" x2="23" y2="10"/>
						</svg>
					</div>
					<div>
						<p class="text-sm text-white font-medium group-hover:text-[var(--fv-violet-light)] transition-colors">Stripe Dashboard</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Paiements, Abonnements</p>
					</div>
				</a>
				<a
					href="https://app.netlify.com"
					target="_blank"
					rel="noopener noreferrer"
					class="flex items-center gap-3 p-4 rounded-xl bg-white/5 hover:bg-white/8 transition-all group"
				>
					<div class="w-10 h-10 rounded-lg bg-[var(--fv-cyan)]/15 flex items-center justify-center">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2">
							<path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
						</svg>
					</div>
					<div>
						<p class="text-sm text-white font-medium group-hover:text-[var(--fv-cyan)] transition-colors">Netlify Dashboard</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Deployements, Logs</p>
					</div>
				</a>
				<a
					href="https://github.com"
					target="_blank"
					rel="noopener noreferrer"
					class="flex items-center gap-3 p-4 rounded-xl bg-white/5 hover:bg-white/8 transition-all group"
				>
					<div class="w-10 h-10 rounded-lg bg-white/10 flex items-center justify-center">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-silver)" stroke-width="2">
							<path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22"/>
						</svg>
					</div>
					<div>
						<p class="text-sm text-white font-medium group-hover:text-[var(--fv-silver)] transition-colors">GitHub Repository</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Code source</p>
					</div>
				</a>
			</div>
		</div>
	{/if}
</div>
