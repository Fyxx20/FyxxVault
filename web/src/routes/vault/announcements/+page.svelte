<script lang="ts">
	import { t } from '$lib/i18n.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { checkUnreadAnnouncements, markAllAnnouncementsRead } from '$lib/stores/announcements-badge';
	import { onMount } from 'svelte';

	const auth = getAuthState();

	interface Announcement {
		id: string;
		type: 'update' | 'maintenance' | 'security' | 'feature' | 'info';
		title: string;
		content: string;
		date: string;
		pinned: boolean;
	}

	let announcements = $state<Announcement[]>([]);
	let loading = $state(true);
	let activeFilter = $state<string | null>(null);

	const typeConfig = $derived<Record<string, { label: string; color: string; icon: string }>>({
		update: { label: t('announcements.type.update'), color: 'var(--fv-cyan)', icon: 'rocket' },
		maintenance: { label: t('announcements.type.maintenance'), color: 'var(--fv-warning, #f59e0b)', icon: 'wrench' },
		security: { label: t('announcements.type.security'), color: 'var(--fv-danger)', icon: 'shield' },
		feature: { label: t('announcements.type.feature'), color: 'var(--fv-violet)', icon: 'sparkle' },
		info: { label: t('announcements.type.info'), color: 'var(--fv-smoke)', icon: 'info' }
	});

	const fallbackAnnouncements: Announcement[] = [
		{
			id: 'ann-identity-generator',
			type: 'feature',
			title: 'Generateur d\'identite fictive',
			content: 'Nouveau : generez des identites fictives completes (nom, adresse, telephone, email) avec carte bancaire virtuelle. Choisissez parmi 11 pays (France, USA, UK, Allemagne, Japon...). Chaque pays genere des donnees realistes avec les bons formats.',
			date: '2026-03-30',
			pinned: true
		},
		{
			id: 'ann-multilingual',
			type: 'feature',
			title: 'FyxxVault maintenant en anglais',
			content: 'FyxxVault est desormais disponible en francais et en anglais. Cliquez sur le bouton FR/EN dans la barre laterale pour changer de langue. Votre preference est sauvegardee automatiquement.',
			date: '2026-03-30',
			pinned: true
		},
		{
			id: 'fallback-1',
			type: 'feature',
			title: 'Messagerie integree',
			content: 'Creez des adresses email jetables @fyxxmail.com directement depuis FyxxVault. Generation illimitee d\'aliases avec nom personnalisable.',
			date: '2026-03-29',
			pinned: false
		},
		{
			id: 'fallback-2',
			type: 'update',
			title: 'Session persistante',
			content: 'Plus besoin de vous reconnecter avec email + mot de passe a chaque visite. FyxxVault se souvient de vous et demande uniquement le mot de passe maitre.',
			date: '2026-03-29',
			pinned: false
		}
	];

	async function loadAnnouncements() {
		loading = true;
		try {
			const token = auth.session?.access_token;
			if (!token) {
				announcements = fallbackAnnouncements;
				return;
			}

			const res = await fetch('/api/announcements', {
				headers: { Authorization: `Bearer ${token}` }
			});

			if (!res.ok) throw new Error('Failed to load announcements');
			const data = await res.json();
			const remote = Array.isArray(data.announcements) ? data.announcements : [];
			announcements = remote.length > 0 ? remote : fallbackAnnouncements;
		} catch {
			announcements = fallbackAnnouncements;
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		loadAnnouncements().then(() => {
			// Mark all as read when visiting the page
			const ids = announcements.map(a => a.id);
			markAllAnnouncementsRead(ids);
		});
	});

	const filteredAnnouncements = $derived(
		activeFilter
			? announcements.filter(a => a.type === activeFilter)
			: announcements
	);

	const pinnedAnnouncements = $derived(filteredAnnouncements.filter(a => a.pinned));
	const regularAnnouncements = $derived(filteredAnnouncements.filter(a => !a.pinned));

	function formatDate(date: string): string {
		return new Date(date).toLocaleDateString('fr-FR', {
			day: 'numeric',
			month: 'long',
			year: 'numeric'
		});
	}

	const types = $derived(Object.entries(typeConfig));
</script>

<svelte:head>
	<title>{t('announcements.title')} — FyxxVault</title>
</svelte:head>

<div class="ann-page">
	<!-- Header -->
	<div class="ann-header">
		<div>
			<h1 class="ann-title">{t('announcements.title')}</h1>
			<p class="ann-subtitle">{t('announcements.subtitle')}</p>
		</div>
	</div>

	<!-- Filters -->
	<div class="ann-filters">
		<button
			onclick={() => activeFilter = null}
			class="ann-filter {activeFilter === null ? 'active' : ''}"
		>
			{t('common.all')}
		</button>
		{#each types as [key, config]}
			<button
				onclick={() => activeFilter = activeFilter === key ? null : key}
				class="ann-filter {activeFilter === key ? 'active' : ''}"
				style="--filter-color: {config.color};"
			>
				<span class="ann-filter-dot" style="background: {config.color};"></span>
				{config.label}
			</button>
		{/each}
	</div>

	{#if loading}
		<div class="ann-loading">
			<div class="ann-spinner"></div>
		</div>
	{:else if filteredAnnouncements.length === 0}
		<div class="ann-empty">
			<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="1">
				<path d="M3 11l18-5v12L3 13v-2z"/><path d="M11.6 16.8a3 3 0 1 1-5.8-1.6"/>
			</svg>
			<p>{t('announcements.empty')}</p>
		</div>
	{:else}
		<!-- Pinned -->
		{#if pinnedAnnouncements.length > 0}
			<div class="ann-section">
				{#each pinnedAnnouncements as ann}
					{@const config = typeConfig[ann.type]}
					<div class="ann-card ann-card-pinned" style="--accent: {config.color};">
						<div class="ann-card-pin">
							<svg width="12" height="12" viewBox="0 0 24 24" fill="var(--fv-gold)" stroke="var(--fv-gold)" stroke-width="2"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
							{t('common.pinned')}
						</div>
						<div class="ann-card-header">
							<span class="ann-badge" style="background: {config.color}15; color: {config.color}; border-color: {config.color}25;">
								{config.label}
							</span>
							<span class="ann-date">{formatDate(ann.date)}</span>
						</div>
						<h3 class="ann-card-title">{ann.title}</h3>
						<p class="ann-card-content">{ann.content}</p>
					</div>
				{/each}
			</div>
		{/if}

		<!-- Regular -->
		<div class="ann-section">
			{#each regularAnnouncements as ann}
				{@const config = typeConfig[ann.type]}
				<div class="ann-card" style="--accent: {config.color};">
					<div class="ann-card-header">
						<span class="ann-badge" style="background: {config.color}15; color: {config.color}; border-color: {config.color}25;">
							{config.label}
						</span>
						<span class="ann-date">{formatDate(ann.date)}</span>
					</div>
					<h3 class="ann-card-title">{ann.title}</h3>
					<p class="ann-card-content">{ann.content}</p>
				</div>
			{/each}
		</div>
	{/if}
</div>

<style>
	.ann-page {
		max-width: 800px;
		margin: 0 auto;
	}

	.ann-header {
		margin-bottom: 24px;
	}
	.ann-title {
		font-size: 24px;
		font-weight: 800;
		color: white;
		letter-spacing: -0.02em;
	}
	.ann-subtitle {
		font-size: 13px;
		color: var(--fv-smoke);
		margin-top: 4px;
	}

	/* Filters */
	.ann-filters {
		display: flex;
		gap: 8px;
		flex-wrap: wrap;
		margin-bottom: 24px;
	}
	.ann-filter {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 14px;
		border-radius: 20px;
		border: 1px solid rgba(255,255,255,0.08);
		background: rgba(255,255,255,0.03);
		color: var(--fv-smoke);
		font-size: 12px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}
	.ann-filter:hover {
		background: rgba(255,255,255,0.06);
		color: white;
	}
	.ann-filter.active {
		background: var(--filter-color, var(--fv-cyan));
		background: color-mix(in srgb, var(--filter-color, var(--fv-cyan)) 15%, transparent);
		color: var(--filter-color, var(--fv-cyan));
		border-color: color-mix(in srgb, var(--filter-color, var(--fv-cyan)) 30%, transparent);
	}
	.ann-filter-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}

	/* Loading */
	.ann-loading {
		display: flex;
		justify-content: center;
		padding: 60px 0;
	}
	.ann-spinner {
		width: 28px;
		height: 28px;
		border: 2px solid rgba(0,212,255,0.2);
		border-top-color: var(--fv-cyan);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	/* Empty */
	.ann-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 12px;
		padding: 60px 0;
		color: var(--fv-ash);
		font-size: 14px;
	}

	/* Section */
	.ann-section {
		display: flex;
		flex-direction: column;
		gap: 12px;
		margin-bottom: 16px;
	}

	/* Card */
	.ann-card {
		position: relative;
		padding: 20px 24px;
		border-radius: 16px;
		background: linear-gradient(135deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
		border: 1px solid rgba(255,255,255,0.06);
		transition: all 0.2s;
	}
	.ann-card::before {
		content: '';
		position: absolute;
		left: 0;
		top: 16px;
		bottom: 16px;
		width: 3px;
		border-radius: 0 3px 3px 0;
		background: var(--accent);
		opacity: 0.6;
	}
	.ann-card:hover {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.025));
		border-color: rgba(255,255,255,0.1);
	}

	/* Pinned */
	.ann-card-pinned {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
		border-color: color-mix(in srgb, var(--accent) 20%, transparent);
	}
	.ann-card-pin {
		display: flex;
		align-items: center;
		gap: 5px;
		font-size: 10px;
		font-weight: 700;
		color: var(--fv-gold);
		text-transform: uppercase;
		letter-spacing: 1px;
		margin-bottom: 10px;
	}

	/* Header */
	.ann-card-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		margin-bottom: 10px;
	}
	.ann-badge {
		padding: 3px 10px;
		border-radius: 20px;
		font-size: 10px;
		font-weight: 700;
		border: 1px solid;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}
	.ann-date {
		font-size: 11px;
		color: var(--fv-ash);
	}

	/* Content */
	.ann-card-title {
		font-size: 16px;
		font-weight: 700;
		color: white;
		margin-bottom: 6px;
	}
	.ann-card-content {
		font-size: 13px;
		color: var(--fv-smoke);
		line-height: 1.6;
	}
</style>
