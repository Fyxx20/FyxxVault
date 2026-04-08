<script>
	import { t } from '$lib/i18n.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	const auth = getAuthState();

	let loading = $state(true);
	let status = $state(null);
	let logs = $state('');
	let backupResult = $state(null);
	let integrityResult = $state(null);
	let toast = $state(null);
	let logsLoading = $state(false);
	let actionLoading = $state('');

	function showToast(message, type = 'success') {
		toast = { message, type };
		setTimeout(() => (toast = null), 4000);
	}

	function formatUptime(seconds) {
		if (!seconds) return '0m';
		const h = Math.floor(seconds / 3600);
		const m = Math.floor((seconds % 3600) / 60);
		if (h > 0) return `${h}h ${m}m`;
		return `${m}m`;
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
			}
		} catch (e) {
			console.error('Failed to fetch status:', e);
		} finally {
			loading = false;
		}
	}

	async function fetchLogs() {
		logsLoading = true;
		try {
			const res = await fetch('/api/panel/logs');
			if (res.ok) {
				const data = await res.json();
				logs = data.logs || '';
			}
		} catch (e) {
			console.error('Failed to fetch logs:', e);
		} finally {
			logsLoading = false;
		}
	}

	async function backupDatabase() {
		actionLoading = 'backup';
		try {
			const res = await fetch('/api/panel/backup', { method: 'POST' });
			const data = await res.json();
			if (res.ok) {
				backupResult = data;
				showToast('Backup created successfully');
			} else {
				showToast(data.error || 'Backup failed', 'error');
			}
		} catch (e) {
			showToast('Backup failed', 'error');
		} finally {
			actionLoading = '';
		}
	}

	async function integrityCheck() {
		actionLoading = 'integrity';
		try {
			const res = await fetch('/api/panel/integrity-check', { method: 'POST' });
			const data = await res.json();
			integrityResult = data;
			if (res.ok && data.ok) {
				showToast('Integrity check passed');
			} else {
				showToast(data.result || 'Integrity check found issues', 'error');
			}
		} catch (e) {
			showToast('Integrity check failed', 'error');
		} finally {
			actionLoading = '';
		}
	}

	function downloadDatabase() {
		window.open('/api/panel/download-db', '_blank');
	}

	async function downloadEmergencyKit() {
		actionLoading = 'emergency';
		try {
			const { downloadEmergencyPDF } = await import('$lib/emergencyKit');
			await downloadEmergencyPDF();
			showToast('Emergency Kit downloaded');
		} catch (e) {
			showToast('Failed to generate Emergency Kit', 'error');
		} finally {
			actionLoading = '';
		}
	}

	async function refresh() {
		loading = true;
		await Promise.all([fetchStatus(), fetchLogs()]);
	}

	onMount(() => {
		if (!auth.unlocked) {
			goto('/login');
			return;
		}
		fetchStatus();
		fetchLogs();
	});
</script>

<svelte:head>
	<title>Panel - FyxxVault</title>
</svelte:head>

{#if toast}
	<div
		class="fixed top-6 right-6 z-50 fv-animate-in px-5 py-3 rounded-xl shadow-lg text-sm font-medium {toast.type === 'error'
			? 'bg-[var(--fv-danger)]/90 text-white'
			: 'bg-[var(--fv-success)]/90 text-white'}"
	>
		{toast.message}
	</div>
{/if}

<div class="min-h-screen bg-[var(--fv-abyss)] px-4 py-8 sm:px-6 lg:px-8">
	<div class="mx-auto max-w-6xl">
		<!-- Header -->
		<div class="fv-animate-in mb-8 flex items-center justify-between">
			<div>
				<h1
					class="bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] bg-clip-text text-3xl font-bold text-transparent"
				>
					Panel
				</h1>
				<p class="mt-1 text-sm text-[var(--fv-smoke)]">Self-Hosted Administration</p>
			</div>
			<button
				onclick={refresh}
				disabled={loading}
				class="fv-glass flex items-center gap-2 rounded-xl px-4 py-2 text-sm text-[var(--fv-smoke)] transition-colors hover:text-white disabled:opacity-50"
			>
				<svg
					class="h-4 w-4 {loading ? 'animate-spin' : ''}"
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
					stroke-width="2"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
					/>
				</svg>
				Refresh
			</button>
		</div>

		{#if loading && !status}
			<div class="flex items-center justify-center py-20">
				<div
					class="h-8 w-8 animate-spin rounded-full border-2 border-[var(--fv-cyan)] border-t-transparent"
				></div>
			</div>
		{:else if status}
			<!-- Status Cards -->
			<div class="fv-animate-in mb-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
				<!-- Uptime -->
				<div class="fv-glass rounded-2xl p-6">
					<div class="flex items-center gap-3 mb-2">
						<div
							class="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--fv-cyan)]/10"
						>
							<svg
								class="h-5 w-5 text-[var(--fv-cyan)]"
								fill="none"
								viewBox="0 0 24 24"
								stroke="currentColor"
								stroke-width="2"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
								/>
							</svg>
						</div>
						<div>
							<p class="text-xs uppercase tracking-wider text-[var(--fv-smoke)]">Uptime</p>
							<p class="text-xl font-bold text-white">{formatUptime(status.uptime)}</p>
						</div>
					</div>
				</div>

				<!-- Database Size -->
				<div class="fv-glass rounded-2xl p-6">
					<div class="flex items-center gap-3 mb-2">
						<div
							class="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--fv-violet)]/10"
						>
							<svg
								class="h-5 w-5 text-[var(--fv-violet)]"
								fill="none"
								viewBox="0 0 24 24"
								stroke="currentColor"
								stroke-width="2"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4m0 5c0 2.21-3.582 4-8 4s-8-1.79-8-4"
								/>
							</svg>
						</div>
						<div>
							<p class="text-xs uppercase tracking-wider text-[var(--fv-smoke)]">Database</p>
							<p class="text-xl font-bold text-white">{formatBytes(status.dbSize)}</p>
						</div>
					</div>
				</div>

				<!-- Total Entries -->
				<div class="fv-glass rounded-2xl p-6">
					<div class="flex items-center gap-3 mb-2">
						<div
							class="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--fv-cyan)]/10"
						>
							<svg
								class="h-5 w-5 text-[var(--fv-cyan)]"
								fill="none"
								viewBox="0 0 24 24"
								stroke="currentColor"
								stroke-width="2"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"
								/>
							</svg>
						</div>
						<div>
							<p class="text-xs uppercase tracking-wider text-[var(--fv-smoke)]">Entries</p>
							<p class="text-xl font-bold text-white">{status.items ?? 0}</p>
						</div>
					</div>
				</div>

				<!-- Node Version -->
				<div class="fv-glass rounded-2xl p-6">
					<div class="flex items-center gap-3 mb-2">
						<div
							class="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--fv-violet)]/10"
						>
							<svg
								class="h-5 w-5 text-[var(--fv-violet)]"
								fill="none"
								viewBox="0 0 24 24"
								stroke="currentColor"
								stroke-width="2"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M5 12h14M5 12a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v4a2 2 0 01-2 2M5 12a2 2 0 00-2 2v4a2 2 0 002 2h14a2 2 0 002-2v-4a2 2 0 00-2-2m-2-4h.01M17 16h.01"
								/>
							</svg>
						</div>
						<div>
							<p class="text-xs uppercase tracking-wider text-[var(--fv-smoke)]">Node.js</p>
							<p class="text-xl font-bold text-white">{status.nodeVersion ?? '-'}</p>
						</div>
					</div>
				</div>
			</div>

			<!-- Actions -->
			<div class="fv-animate-in mb-8">
				<h2 class="mb-4 text-lg font-semibold text-white">Actions</h2>
				<div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
					<!-- Backup -->
					<button
						onclick={backupDatabase}
						disabled={actionLoading === 'backup'}
						class="fv-glass group flex items-center gap-3 rounded-2xl p-5 text-left transition-all hover:ring-1 hover:ring-[var(--fv-cyan)]/30 disabled:opacity-50"
					>
						<div
							class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[var(--fv-cyan)]/10 transition-colors group-hover:bg-[var(--fv-cyan)]/20"
						>
							{#if actionLoading === 'backup'}
								<div
									class="h-5 w-5 animate-spin rounded-full border-2 border-[var(--fv-cyan)] border-t-transparent"
								></div>
							{:else}
								<svg
									class="h-5 w-5 text-[var(--fv-cyan)]"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
									stroke-width="2"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"
									/>
								</svg>
							{/if}
						</div>
						<div>
							<p class="text-sm font-medium text-white">Backup Database</p>
							<p class="text-xs text-[var(--fv-smoke)]">Create a snapshot</p>
						</div>
					</button>

					<!-- Integrity Check -->
					<button
						onclick={integrityCheck}
						disabled={actionLoading === 'integrity'}
						class="fv-glass group flex items-center gap-3 rounded-2xl p-5 text-left transition-all hover:ring-1 hover:ring-[var(--fv-violet)]/30 disabled:opacity-50"
					>
						<div
							class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[var(--fv-violet)]/10 transition-colors group-hover:bg-[var(--fv-violet)]/20"
						>
							{#if actionLoading === 'integrity'}
								<div
									class="h-5 w-5 animate-spin rounded-full border-2 border-[var(--fv-violet)] border-t-transparent"
								></div>
							{:else}
								<svg
									class="h-5 w-5 text-[var(--fv-violet)]"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
									stroke-width="2"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
									/>
								</svg>
							{/if}
						</div>
						<div>
							<p class="text-sm font-medium text-white">Integrity Check</p>
							<p class="text-xs text-[var(--fv-smoke)]">Verify database health</p>
						</div>
					</button>

					<!-- Download DB -->
					<button
						onclick={downloadDatabase}
						class="fv-glass group flex items-center gap-3 rounded-2xl p-5 text-left transition-all hover:ring-1 hover:ring-[var(--fv-cyan)]/30"
					>
						<div
							class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[var(--fv-cyan)]/10 transition-colors group-hover:bg-[var(--fv-cyan)]/20"
						>
							<svg
								class="h-5 w-5 text-[var(--fv-cyan)]"
								fill="none"
								viewBox="0 0 24 24"
								stroke="currentColor"
								stroke-width="2"
							>
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
								/>
							</svg>
						</div>
						<div>
							<p class="text-sm font-medium text-white">Download Database</p>
							<p class="text-xs text-[var(--fv-smoke)]">Export raw .db file</p>
						</div>
					</button>

					<!-- Emergency Kit -->
					<button
						onclick={downloadEmergencyKit}
						disabled={actionLoading === 'emergency'}
						class="fv-glass group flex items-center gap-3 rounded-2xl p-5 text-left transition-all hover:ring-1 hover:ring-[var(--fv-danger)]/30 disabled:opacity-50"
					>
						<div
							class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[var(--fv-danger)]/10 transition-colors group-hover:bg-[var(--fv-danger)]/20"
						>
							{#if actionLoading === 'emergency'}
								<div
									class="h-5 w-5 animate-spin rounded-full border-2 border-[var(--fv-danger)] border-t-transparent"
								></div>
							{:else}
								<svg
									class="h-5 w-5 text-[var(--fv-danger)]"
									fill="none"
									viewBox="0 0 24 24"
									stroke="currentColor"
									stroke-width="2"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
									/>
								</svg>
							{/if}
						</div>
						<div>
							<p class="text-sm font-medium text-white">Emergency Kit</p>
							<p class="text-xs text-[var(--fv-smoke)]">Download recovery PDF</p>
						</div>
					</button>
				</div>

				{#if integrityResult}
					<div
						class="fv-animate-in mt-4 fv-glass rounded-xl p-4 text-sm {integrityResult.ok
							? 'text-[var(--fv-success)]'
							: 'text-[var(--fv-danger)]'}"
					>
						Integrity: {integrityResult.result ?? (integrityResult.ok ? 'OK' : 'Issues found')}
					</div>
				{/if}
			</div>

			<!-- Logs -->
			<div class="fv-animate-in">
				<div class="mb-4 flex items-center justify-between">
					<h2 class="text-lg font-semibold text-white">Logs</h2>
					<button
						onclick={fetchLogs}
						disabled={logsLoading}
						class="text-xs text-[var(--fv-smoke)] transition-colors hover:text-white disabled:opacity-50"
					>
						{logsLoading ? 'Loading...' : 'Reload'}
					</button>
				</div>
				<div class="fv-glass max-h-96 overflow-auto rounded-2xl p-4">
					{#if logsLoading && !logs}
						<div class="flex items-center justify-center py-8">
							<div
								class="h-5 w-5 animate-spin rounded-full border-2 border-[var(--fv-cyan)] border-t-transparent"
							></div>
						</div>
					{:else if logs}
						<pre
							class="text-xs leading-relaxed text-[var(--fv-ash)] font-mono whitespace-pre-wrap break-all">{logs}</pre>
					{:else}
						<p class="py-8 text-center text-sm text-[var(--fv-smoke)]">No logs available</p>
					{/if}
				</div>
			</div>
		{:else}
			<div class="fv-glass fv-animate-in rounded-2xl p-8 text-center">
				<p class="text-[var(--fv-smoke)]">Failed to load panel data. Check server status.</p>
				<button
					onclick={refresh}
					class="mt-4 rounded-xl bg-[var(--fv-cyan)]/10 px-4 py-2 text-sm text-[var(--fv-cyan)] transition-colors hover:bg-[var(--fv-cyan)]/20"
				>
					Retry
				</button>
			</div>
		{/if}
	</div>
</div>
