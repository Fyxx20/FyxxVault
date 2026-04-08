<script>
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	const auth = getAuthState();

	let loading = $state(true);
	let status = $state(null);
	let toast = $state(null);
	let actionLoading = $state('');
	let uptimeInterval = $state(null);
	let liveUptime = $state(0);

	function showToast(message, type = 'success') {
		toast = { message, type };
		setTimeout(() => (toast = null), 4000);
	}

	function formatUptime(seconds) {
		if (!seconds || seconds < 0) return '0s';
		const d = Math.floor(seconds / 86400);
		const h = Math.floor((seconds % 86400) / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		const s = Math.floor(seconds % 60);
		if (d > 0) return `${d}j ${h}h ${m}m`;
		if (h > 0) return `${h}h ${m}m ${s}s`;
		if (m > 0) return `${m}m ${s}s`;
		return `${s}s`;
	}

	function formatBytes(bytes) {
		if (!bytes) return '0 KB';
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}

	async function fetchStatus() {
		try {
			const res = await fetch('/api/panel/status');
			if (res.ok) {
				status = await res.json();
				liveUptime = status.uptime;
			}
		} catch (e) {
			console.error('Failed to fetch status:', e);
		} finally {
			loading = false;
		}
	}

	async function backupDatabase() {
		actionLoading = 'backup';
		try {
			const res = await fetch('/api/panel/backup', { method: 'POST' });
			const data = await res.json();
			if (res.ok) {
				showToast('Backup cree avec succes');
			} else {
				showToast(data.error || 'Echec du backup', 'error');
			}
		} catch (e) {
			showToast('Echec du backup', 'error');
		} finally {
			actionLoading = '';
		}
	}

	async function integrityCheck() {
		actionLoading = 'integrity';
		try {
			const res = await fetch('/api/panel/integrity-check', { method: 'POST' });
			const data = await res.json();
			if (res.ok && data.ok) {
				showToast('Integrite OK — base de donnees saine');
			} else {
				showToast(data.result || 'Problemes detectes', 'error');
			}
		} catch (e) {
			showToast('Echec de la verification', 'error');
		} finally {
			actionLoading = '';
		}
	}

	function downloadDatabase() {
		window.open('/api/panel/download-db', '_blank');
	}

	onMount(() => {
		if (!auth.isUnlocked) {
			goto('/vault/unlock');
			return;
		}
		fetchStatus();

		uptimeInterval = setInterval(() => {
			liveUptime += 1;
		}, 1000);

		return () => {
			if (uptimeInterval) clearInterval(uptimeInterval);
		};
	});
</script>

<svelte:head>
	<title>Panel — FyxxVault</title>
</svelte:head>

<!-- Toast -->
{#if toast}
	<div class="fixed top-6 right-6 z-50 fv-animate-in px-5 py-3 rounded-2xl shadow-2xl text-sm font-medium backdrop-blur-xl border
		{toast.type === 'error' ? 'bg-[var(--fv-danger)]/90 border-[var(--fv-danger)]/30 text-white' : 'bg-[var(--fv-success)]/90 border-[var(--fv-success)]/30 text-white'}">
		<div class="flex items-center gap-2">
			{#if toast.type === 'error'}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
			{:else}
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
			{/if}
			{toast.message}
		</div>
	</div>
{/if}

<div class="max-w-4xl mx-auto">
	<!-- Header -->
	<div class="fv-animate-in mb-8 flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-extrabold text-white">Panel</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-0.5">Administration du serveur</p>
		</div>
		<button onclick={fetchStatus} disabled={loading} class="panel-refresh-btn flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm text-[var(--fv-smoke)] hover:text-white transition-all disabled:opacity-50">
			<svg class="w-4 h-4 {loading ? 'animate-spin' : ''}" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
				<path stroke-linecap="round" stroke-linejoin="round" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
			</svg>
			Rafraichir
		</button>
	</div>

	{#if loading && !status}
		<div class="flex items-center justify-center py-20">
			<div class="w-8 h-8 animate-spin rounded-full border-2 border-[var(--fv-cyan)] border-t-transparent"></div>
		</div>
	{:else if status}
		<!-- Server status banner -->
		<div class="server-banner fv-animate-in mb-6">
			<div class="flex items-center gap-4">
				<div class="status-orb">
					<div class="status-dot"></div>
				</div>
				<div>
					<div class="flex items-center gap-2">
						<h2 class="text-lg font-bold text-white">Serveur FyxxVault</h2>
						<span class="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-[var(--fv-success)]/15 text-[var(--fv-success)]">En ligne</span>
					</div>
					<p class="text-sm text-[var(--fv-smoke)] mt-0.5">
						Port {status.port} &middot; Uptime {formatUptime(liveUptime)} &middot; PID {status.pid}
					</p>
				</div>
			</div>
		</div>

		<!-- Stats Grid -->
		<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6 fv-animate-in" style="animation-delay: 80ms;">
			<div class="stat-card">
				<div class="stat-icon cyan">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
				</div>
				<p class="stat-value">{formatUptime(liveUptime)}</p>
				<p class="stat-label">Uptime</p>
			</div>
			<div class="stat-card">
				<div class="stat-icon violet">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"/></svg>
				</div>
				<p class="stat-value">{formatBytes(status.dbSize)}</p>
				<p class="stat-label">Base de donnees</p>
			</div>
			<div class="stat-card">
				<div class="stat-icon cyan">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
				</div>
				<p class="stat-value">{status.items ?? 0}</p>
				<p class="stat-label">Entrees</p>
			</div>
			<div class="stat-card">
				<div class="stat-icon violet">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
				</div>
				<p class="stat-value">{formatBytes(status.memoryUsage)}</p>
				<p class="stat-label">Memoire</p>
			</div>
		</div>

		<!-- Quick Actions -->
		<div class="fv-animate-in" style="animation-delay: 160ms;">
			<h3 class="text-sm font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">Actions rapides</h3>
			<div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
				<button onclick={backupDatabase} disabled={actionLoading === 'backup'} class="action-card group">
					<div class="action-icon cyan">
						{#if actionLoading === 'backup'}
							<div class="w-4 h-4 animate-spin rounded-full border-2 border-[var(--fv-cyan)] border-t-transparent"></div>
						{:else}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/></svg>
						{/if}
					</div>
					<div class="text-left">
						<p class="text-sm font-medium text-white">Backup</p>
						<p class="text-[11px] text-[var(--fv-ash)]">Creer un snapshot</p>
					</div>
				</button>

				<button onclick={integrityCheck} disabled={actionLoading === 'integrity'} class="action-card group">
					<div class="action-icon violet">
						{#if actionLoading === 'integrity'}
							<div class="w-4 h-4 animate-spin rounded-full border-2 border-[var(--fv-violet)] border-t-transparent"></div>
						{:else}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
						{/if}
					</div>
					<div class="text-left">
						<p class="text-sm font-medium text-white">Integrite</p>
						<p class="text-[11px] text-[var(--fv-ash)]">Verifier la sante de la DB</p>
					</div>
				</button>

				<button onclick={downloadDatabase} class="action-card group">
					<div class="action-icon cyan">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
					</div>
					<div class="text-left">
						<p class="text-sm font-medium text-white">Exporter</p>
						<p class="text-[11px] text-[var(--fv-ash)]">Telecharger le fichier .db</p>
					</div>
				</button>
			</div>
		</div>

		<!-- System info -->
		<div class="fv-animate-in mt-6" style="animation-delay: 240ms;">
			<h3 class="text-sm font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">Systeme</h3>
			<div class="system-card">
				<div class="system-row">
					<span class="system-label">Node.js</span>
					<span class="system-value">{status.nodeVersion}</span>
				</div>
				<div class="system-row">
					<span class="system-label">Plateforme</span>
					<span class="system-value">{status.platform}</span>
				</div>
				<div class="system-row">
					<span class="system-label">PID</span>
					<span class="system-value font-mono">{status.pid}</span>
				</div>
				<div class="system-row">
					<span class="system-label">Port</span>
					<span class="system-value font-mono">{status.port}</span>
				</div>
				<div class="system-row last">
					<span class="system-label">Utilisateurs</span>
					<span class="system-value">{status.users}</span>
				</div>
			</div>
		</div>
	{:else}
		<div class="fv-glass fv-animate-in rounded-2xl p-8 text-center">
			<p class="text-[var(--fv-smoke)]">Impossible de charger les donnees. Verifie le serveur.</p>
			<button onclick={fetchStatus} class="mt-4 rounded-xl bg-[var(--fv-cyan)]/10 px-4 py-2 text-sm text-[var(--fv-cyan)] hover:bg-[var(--fv-cyan)]/20 transition-colors">
				Reessayer
			</button>
		</div>
	{/if}
</div>

<style>
	/* Server banner */
	.server-banner {
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 20px;
		padding: 24px;
		backdrop-filter: blur(16px);
	}

	.status-orb {
		width: 48px;
		height: 48px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		background: rgba(52, 211, 153, 0.08);
	}
	.status-dot {
		width: 12px;
		height: 12px;
		border-radius: 50%;
		background: var(--fv-success);
		box-shadow: 0 0 12px rgba(52, 211, 153, 0.5);
		animation: statusPulse 2s ease-in-out infinite;
	}
	@keyframes statusPulse {
		0%, 100% { box-shadow: 0 0 12px rgba(52, 211, 153, 0.3); transform: scale(1); }
		50% { box-shadow: 0 0 20px rgba(52, 211, 153, 0.6); transform: scale(1.1); }
	}

	/* Stat cards */
	.stat-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 16px;
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.stat-icon {
		width: 32px;
		height: 32px;
		border-radius: 10px;
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.stat-icon.cyan { background: rgba(0, 212, 255, 0.1); color: var(--fv-cyan); }
	.stat-icon.violet { background: rgba(138, 92, 246, 0.1); color: var(--fv-violet); }
	.stat-value { font-size: 18px; font-weight: 800; color: white; line-height: 1; margin: 0; }
	.stat-label { font-size: 11px; color: var(--fv-ash); margin: 0; }

	/* Action cards */
	.action-card {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 16px;
		border-radius: 16px;
		background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
		border: 1px solid rgba(255,255,255,0.06);
		cursor: pointer;
		transition: all 0.2s ease;
	}
	.action-card:hover { border-color: rgba(255,255,255,0.12); background: rgba(255,255,255,0.06); transform: translateY(-1px); }
	.action-card:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }
	.action-icon {
		width: 40px;
		height: 40px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}
	.action-icon.cyan { background: rgba(0, 212, 255, 0.08); color: var(--fv-cyan); }
	.action-icon.violet { background: rgba(138, 92, 246, 0.08); color: var(--fv-violet); }

	/* System info */
	.system-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01));
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 16px;
		overflow: hidden;
	}
	.system-row { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.04); }
	.system-row.last { border-bottom: none; }
	.system-label { font-size: 13px; color: var(--fv-smoke); }
	.system-value { font-size: 13px; color: white; font-weight: 500; }

	.panel-refresh-btn {
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.08);
	}
	.panel-refresh-btn:hover { background: rgba(255,255,255,0.08); }
</style>
