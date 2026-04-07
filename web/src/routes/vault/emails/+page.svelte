<script lang="ts">
	import { t } from '$lib/i18n.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { inboxUnreadCount } from '$lib/stores/email-badge';
	import { onMount } from 'svelte';

	const auth = getAuthState();

	interface Alias {
		id: string;
		address: string;
		label: string;
		is_active: boolean;
		emails_received: number;
		created_at: string;
	}

	interface Email {
		id: string;
		alias_id: string;
		from_address: string;
		from_name: string;
		to_address: string;
		subject: string;
		body_text?: string;
		body_html?: string;
		folder: string;
		is_read: boolean;
		is_starred: boolean;
		received_at: string;
	}

	// State
	let aliases = $state<Alias[]>([]);
	let emails = $state<Email[]>([]);
	let selectedEmail = $state<Email | null>(null);
	let activeFolder = $state('inbox');
	let activeAliasFilter = $state<string | null>(null);
	let searchQuery = $state('');
	let loading = $state(true);
	let loadingEmails = $state(false);
	let creating = $state(false);
	let newAliasLabel = $state('');
	let showCreateModal = $state(false);
	let copiedId = $state<string | null>(null);
	let unreadCounts = $state<Record<string, number>>({ inbox: 0, spam: 0, trash: 0, archive: 0 });
	let totalEmails = $state(0);
	let error = $state('');

	function getToken(): string {
		return auth.session?.access_token || '';
	}

	async function apiFetch(url: string, opts: RequestInit = {}) {
		const res = await fetch(url, {
			...opts,
			headers: {
				'Content-Type': 'application/json',
				'Authorization': `Bearer ${getToken()}`,
				...(opts.headers || {})
			}
		});
		return res.json();
	}

	// Load aliases
	async function loadAliases() {
		const data = await apiFetch('/api/email/aliases');
		if (data.aliases) aliases = data.aliases;
	}

	// Load emails
	async function loadEmails() {
		loadingEmails = true;
		const params = new URLSearchParams({ folder: activeFolder });
		if (activeAliasFilter) params.set('alias_id', activeAliasFilter);
		if (searchQuery) params.set('search', searchQuery);

		const data = await apiFetch(`/api/email/messages?${params}`);
		if (data.emails) emails = data.emails;
		if (data.unreadCounts) unreadCounts = data.unreadCounts;
		if (data.total !== undefined) totalEmails = data.total;
		inboxUnreadCount.set(unreadCounts.inbox ?? 0);
		loadingEmails = false;
	}

	async function refreshMailbox() {
		if (loadingEmails) return;
		await loadAliases();
		await loadEmails();
	}

	// Create alias
	async function createAlias() {
		creating = true;
		error = '';
		const data = await apiFetch('/api/email/aliases', {
			method: 'POST',
			body: JSON.stringify({ label: newAliasLabel })
		});
		if (data.error) {
			error = data.error;
		} else {
			await loadAliases();
			showCreateModal = false;
			newAliasLabel = '';
		}
		creating = false;
	}

	// Delete alias
	async function deleteAlias(id: string) {
		await apiFetch('/api/email/aliases', {
			method: 'DELETE',
			body: JSON.stringify({ id })
		});
		await loadAliases();
		await loadEmails();
	}

	// Toggle alias
	async function toggleAlias(id: string, active: boolean) {
		await apiFetch('/api/email/aliases', {
			method: 'PATCH',
			body: JSON.stringify({ id, is_active: !active })
		});
		await loadAliases();
	}

	// Open email
	async function openEmail(email: Email) {
		const data = await apiFetch(`/api/email/messages/${email.id}`);
		if (data.email) {
			selectedEmail = data.email;
			// Update local state
			const idx = emails.findIndex(e => e.id === email.id);
			if (idx >= 0) emails[idx].is_read = true;
			if (unreadCounts[activeFolder] > 0) unreadCounts[activeFolder]--;
			inboxUnreadCount.set(unreadCounts.inbox ?? 0);
		}
	}

	// Move email
	async function moveEmail(ids: string[], folder: string) {
		await apiFetch('/api/email/messages', {
			method: 'PATCH',
			body: JSON.stringify({ ids, folder })
		});
		selectedEmail = null;
		await loadEmails();
	}

	// Toggle star
	async function toggleStar(id: string, starred: boolean) {
		await apiFetch('/api/email/messages', {
			method: 'PATCH',
			body: JSON.stringify({ ids: [id], is_starred: !starred })
		});
		const idx = emails.findIndex(e => e.id === id);
		if (idx >= 0) emails[idx].is_starred = !starred;
	}

	// Delete permanently
	async function deleteEmails(ids: string[]) {
		await apiFetch('/api/email/messages', {
			method: 'DELETE',
			body: JSON.stringify({ ids })
		});
		selectedEmail = null;
		await loadEmails();
	}

	// Mark as read/unread
	async function markRead(ids: string[], read: boolean) {
		await apiFetch('/api/email/messages', {
			method: 'PATCH',
			body: JSON.stringify({ ids, is_read: read })
		});
		await loadEmails();
	}

	// Copy to clipboard
	async function copyAddress(address: string, id: string) {
		await navigator.clipboard.writeText(address);
		copiedId = id;
		setTimeout(() => copiedId = null, 2000);
	}

	// Time ago
	function timeAgo(date: string): string {
		const diff = Date.now() - new Date(date).getTime();
		const mins = Math.floor(diff / 60000);
		if (mins < 1) return t('emails.time_now');
		if (mins < 60) return `${mins}${t('emails.time_min')}`;
		const hours = Math.floor(mins / 60);
		if (hours < 24) return `${hours}${t('emails.time_hour')}`;
		const days = Math.floor(hours / 24);
		if (days < 30) return `${days}${t('emails.time_day')}`;
		return `${Math.floor(days / 30)}${t('emails.time_month')}`;
	}

	// Get sender initial
	function getInitial(email: Email): string {
		return (email.from_name || email.from_address).charAt(0).toUpperCase();
	}

	// Get sender display
	function getSender(email: Email): string {
		return email.from_name || email.from_address.split('@')[0];
	}

	// Folder icon & label
	const folders = $derived([
		{ id: 'inbox', label: t('emails.inbox'), icon: 'inbox' },
		{ id: 'archive', label: t('emails.archive'), icon: 'archive' },
		{ id: 'spam', label: t('emails.spam'), icon: 'spam' },
		{ id: 'trash', label: t('emails.trash'), icon: 'trash' },
	]);

	// Load on mount
	onMount(async () => {
		await loadAliases();
		await loadEmails();
		loading = false;
	});

	// Reload when folder or filter changes
	$effect(() => {
		if (!loading) {
			activeFolder;
			activeAliasFilter;
			loadEmails();
		}
	});

	// Debounced search
	let searchTimeout: ReturnType<typeof setTimeout>;
	function handleSearch(value: string) {
		searchQuery = value;
		clearTimeout(searchTimeout);
		searchTimeout = setTimeout(() => loadEmails(), 300);
	}

	// Alias for selected email
	const selectedAlias = $derived(
		selectedEmail ? aliases.find(a => a.id === selectedEmail.alias_id) : null
	);

	function getStyledEmailHtml(html: string): string {
		// Wrap incoming HTML to better match the dark UI and avoid a harsh full-white block.
		return `<!doctype html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root { color-scheme: dark; }
    html, body {
      margin: 0;
      padding: 0;
      background: transparent !important;
    }
    body {
      padding: 14px;
      color: #e5ecff;
      font: 14px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    }
    img, video { max-width: 100%; height: auto; }
    table { max-width: 100% !important; }
  </style>
</head>
<body>${html}</body>
</html>`;
	}

	let deleteConfirmAlias = $state<string | null>(null);
</script>

<svelte:head>
	<title>{t('emails.title')} — FyxxVault</title>
</svelte:head>

<div class="email-page">
	<!-- Sidebar -->
	<aside class="email-sidebar">
		<!-- Create button -->
		<button
			onclick={() => showCreateModal = true}
			class="email-create-btn"
		>
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
			{t('emails.new_alias')}
		</button>

		<!-- Folders -->
		<div class="email-folders">
			<p class="email-section-title">{t('emails.folders')}</p>
			{#each folders as folder}
				<button
					onclick={() => { activeFolder = folder.id; activeAliasFilter = null; selectedEmail = null; }}
					class="email-folder-btn {activeFolder === folder.id && !activeAliasFilter ? 'active' : ''}"
				>
					<div class="email-folder-icon">
						{#if folder.icon === 'inbox'}
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/></svg>
						{:else if folder.icon === 'archive'}
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="21 8 21 21 3 21 3 8"/><rect x="1" y="3" width="22" height="5"/><line x1="10" y1="12" x2="14" y2="12"/></svg>
						{:else if folder.icon === 'spam'}
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
						{:else if folder.icon === 'trash'}
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
						{/if}
					</div>
					<span>{folder.label}</span>
					{#if unreadCounts[folder.id] > 0}
						<span class="email-badge">{unreadCounts[folder.id]}</span>
					{/if}
				</button>
			{/each}
		</div>

		<!-- Aliases -->
		<div class="email-aliases-section">
			<p class="email-section-title">{t('emails.my_aliases')}</p>
			{#if aliases.length === 0}
				<p class="email-empty-hint">{t('emails.no_alias_hint')}</p>
			{:else}
				{#each aliases as alias}
					<div class="email-alias-item {activeAliasFilter === alias.id ? 'active' : ''}">
						<button
							onclick={() => { activeAliasFilter = activeAliasFilter === alias.id ? null : alias.id; selectedEmail = null; }}
							class="email-alias-btn"
						>
							<div class="email-alias-dot {alias.is_active ? 'active' : 'inactive'}"></div>
							<div class="email-alias-info">
								<span class="email-alias-label">{alias.label || alias.address.split('@')[0]}</span>
								<span class="email-alias-address">{alias.address}</span>
							</div>
						</button>
						<div class="email-alias-actions">
							<button onclick={() => copyAddress(alias.address, alias.id)} class="email-alias-action" title={t('common.copy')}>
								{#if copiedId === alias.id}
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
								{:else}
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
								{/if}
							</button>
							<button onclick={() => toggleAlias(alias.id, alias.is_active)} class="email-alias-action" title={alias.is_active ? t('emails.deactivate') : t('emails.activate')}>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="{alias.is_active ? 'var(--fv-success)' : 'var(--fv-ash)'}" stroke-width="2">
									{#if alias.is_active}
										<path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
									{:else}
										<line x1="1" y1="1" x2="23" y2="23"/><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>
									{/if}
								</svg>
							</button>
							<button onclick={() => deleteConfirmAlias = deleteConfirmAlias === alias.id ? null : alias.id} class="email-alias-action email-alias-delete" title={t('common.delete')}>
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
							</button>
						</div>
						{#if deleteConfirmAlias === alias.id}
							<div class="email-alias-confirm-delete">
								<p>{t('emails.delete_alias_confirm')}</p>
								<div class="flex gap-2">
									<button onclick={() => deleteConfirmAlias = null} class="email-btn-sm">{t('common.cancel')}</button>
									<button onclick={() => { deleteAlias(alias.id); deleteConfirmAlias = null; }} class="email-btn-sm email-btn-danger">{t('common.delete')}</button>
								</div>
							</div>
						{/if}
					</div>
				{/each}
			{/if}
		</div>
	</aside>

	<!-- Main content -->
	<main class="email-main">
		{#if loading}
			<div class="email-loading">
				<div class="email-spinner"></div>
			</div>
		{:else if selectedEmail}
			<!-- Email detail view -->
			<div class="email-detail">
				<div class="email-detail-toolbar">
					<button onclick={() => selectedEmail = null} class="email-toolbar-btn">
						<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
						{t('common.back')}
					</button>
					<div class="email-toolbar-actions">
						{#if activeFolder !== 'archive'}
							<button onclick={() => moveEmail([selectedEmail.id], 'archive')} class="email-toolbar-btn" title={t('emails.action_archive')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="21 8 21 21 3 21 3 8"/><rect x="1" y="3" width="22" height="5"/></svg>
							</button>
						{/if}
						{#if activeFolder !== 'spam'}
							<button onclick={() => moveEmail([selectedEmail.id], 'spam')} class="email-toolbar-btn" title={t('emails.spam')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
							</button>
						{/if}
						{#if activeFolder === 'trash'}
							<button onclick={() => deleteEmails([selectedEmail.id])} class="email-toolbar-btn email-toolbar-danger" title={t('emails.delete_permanently')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
							</button>
						{:else}
							<button onclick={() => moveEmail([selectedEmail.id], 'trash')} class="email-toolbar-btn" title={t('emails.trash')}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
							</button>
						{/if}
					</div>
				</div>

				<div class="email-detail-content">
					<h2 class="email-detail-subject">{selectedEmail.subject}</h2>

					<div class="email-detail-meta">
						<div class="email-detail-avatar" style="background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));">
							{getInitial(selectedEmail)}
						</div>
						<div class="email-detail-sender">
							<span class="email-detail-name">{getSender(selectedEmail)}</span>
							<span class="email-detail-address">&lt;{selectedEmail.from_address}&gt;</span>
						</div>
						<div class="email-detail-date">
							{new Date(selectedEmail.received_at).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}
						</div>
					</div>

					{#if selectedAlias}
						<div class="email-detail-alias">
							{t('emails.received_on')} <span class="email-detail-alias-addr">{selectedAlias.address}</span>
						</div>
					{/if}

					<div class="email-detail-body">
						{#if selectedEmail.body_html}
							<div class="email-detail-iframe-wrap">
								<iframe
									srcdoc={getStyledEmailHtml(selectedEmail.body_html)}
									class="email-detail-iframe"
									sandbox="allow-same-origin"
									title={t('emails.email_content')}
								></iframe>
							</div>
						{:else}
							<pre class="email-detail-text">{selectedEmail.body_text || t('emails.no_content')}</pre>
						{/if}
					</div>
				</div>
			</div>
		{:else}
			<!-- Email list view -->
			<div class="email-list-header">
				<div class="email-list-title">
					<h2>{folders.find(f => f.id === activeFolder)?.label || t('emails.title')}</h2>
					{#if activeAliasFilter}
						{@const alias = aliases.find(a => a.id === activeAliasFilter)}
						{#if alias}
							<span class="email-filter-badge">
								{alias.address}
								<button onclick={() => activeAliasFilter = null}>
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
								</button>
							</span>
						{/if}
					{/if}
				</div>
				<div class="email-list-actions">
					<button
						onclick={refreshMailbox}
						class="email-refresh-btn"
						title={t('emails.refresh')}
						aria-label={t('emails.refresh')}
						disabled={loadingEmails}
					>
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class={loadingEmails ? 'refresh-spinning' : ''}>
							<path d="M23 4v6h-6"/>
							<path d="M1 20v-6h6"/>
							<path d="M3.51 9a9 9 0 0 1 14.13-3.36L23 10"/>
							<path d="M20.49 15a9 9 0 0 1-14.13 3.36L1 14"/>
						</svg>
					</button>

					<div class="email-search">
						<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
						<input
							type="text"
							placeholder={t('emails.search_placeholder')}
							value={searchQuery}
							oninput={(e) => handleSearch((e.target as HTMLInputElement).value)}
							class="email-search-input"
						/>
					</div>
				</div>
			</div>

			{#if loadingEmails}
				<div class="email-loading-inline">
					<div class="email-spinner-sm"></div>
				</div>
			{:else if emails.length === 0}
				<div class="email-empty">
					<div class="email-empty-icon">
						{#if activeFolder === 'inbox'}
							<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="1"><polyline points="22 12 16 12 14 15 10 15 8 12 2 12"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/></svg>
						{:else}
							<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="1"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
						{/if}
					</div>
					<p class="email-empty-title">
						{#if aliases.length === 0}
							{t('emails.create_first_alias')}
						{:else}
							{t('emails.no_emails')}
						{/if}
					</p>
					<p class="email-empty-desc">
						{#if aliases.length === 0}
							{t('emails.create_first_alias_desc')}
						{:else if activeFolder === 'inbox'}
							{t('emails.inbox_empty')}
						{:else}
							{t('emails.folder_empty')}
						{/if}
					</p>
					{#if aliases.length === 0}
						<button onclick={() => showCreateModal = true} class="email-create-btn" style="margin-top: 1rem;">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
							{t('emails.create_alias')}
						</button>
					{/if}
				</div>
			{:else}
				<div class="email-list">
					{#each emails as email}
						<div role="button" tabindex="0"
							onclick={() => openEmail(email)}
							class="email-row {!email.is_read ? 'unread' : ''}"
						>
							<div role="button" tabindex="0"
								onclick={(e) => { e.stopPropagation(); toggleStar(email.id, email.is_starred); }}
								class="email-star"
							>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="{email.is_starred ? 'var(--fv-gold)' : 'none'}" stroke="{email.is_starred ? 'var(--fv-gold)' : 'var(--fv-ash)'}" stroke-width="2">
									<path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
								</svg>
							</div>
							<div class="email-row-avatar" style="background: {!email.is_read ? 'linear-gradient(135deg, var(--fv-cyan), var(--fv-violet))' : 'rgba(255,255,255,0.06)'};">
								{getInitial(email)}
							</div>
							<div class="email-row-content">
								<div class="email-row-top">
									<span class="email-row-sender">{getSender(email)}</span>
									<span class="email-row-date">{timeAgo(email.received_at)}</span>
								</div>
								<div class="email-row-subject">{email.subject}</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}
	</main>

	<!-- Create alias modal -->
	{#if showCreateModal}
		<div class="email-modal-overlay" role="presentation" onclick={() => showCreateModal = false}>
			<div class="email-modal" role="dialog" onclick={(e) => e.stopPropagation()}>
				<h3 class="email-modal-title">{t('emails.new_alias_title')}</h3>
				<p class="email-modal-desc">
					{@html t('emails.new_alias_desc')}
				</p>


				{#if error}
					<div class="email-modal-error">{error}</div>
				{/if}

				<div class="email-modal-actions">
					<button onclick={() => { showCreateModal = false; error = ''; }} class="email-btn-secondary">{t('common.cancel')}</button>
					<button onclick={createAlias} disabled={creating} class="email-btn-primary">
						{creating ? t('emails.creating') : t('emails.create_alias')}
					</button>
				</div>

				<div class="email-modal-pro-notice">
					<span>✉️</span>
					<span>{t('emails.pro_notice')}</span>
				</div>
			</div>
		</div>
	{/if}
</div>

<style>
	.email-page {
		display: flex;
		min-height: calc(100vh - 120px);
		gap: 0;
		max-width: 1400px;
		margin: 0 auto;
	}

	/* Sidebar */
	.email-sidebar {
		width: 260px;
		flex-shrink: 0;
		border-right: 1px solid rgba(255,255,255,0.06);
		padding: 16px;
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.email-create-btn {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		width: 100%;
		padding: 12px;
		border-radius: 14px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		color: white;
		font-weight: 700;
		font-size: 13px;
		border: none;
		cursor: pointer;
		transition: all 0.2s;
	}
	.email-create-btn:hover { transform: translateY(-1px); box-shadow: 0 6px 20px rgba(0,212,255,0.25); }

	.email-section-title {
		font-size: 10px;
		font-weight: 700;
		color: var(--fv-ash);
		text-transform: uppercase;
		letter-spacing: 1.5px;
		margin-bottom: 6px;
		padding: 0 8px;
	}

	.email-folder-btn {
		display: flex;
		align-items: center;
		gap: 10px;
		width: 100%;
		padding: 8px 10px;
		border-radius: 10px;
		border: none;
		background: none;
		color: var(--fv-smoke);
		font-size: 13px;
		font-weight: 500;
		cursor: pointer;
		transition: all 0.15s;
		text-align: left;
	}
	.email-folder-btn:hover { background: rgba(255,255,255,0.04); color: white; }
	.email-folder-btn.active { background: rgba(0,212,255,0.08); color: var(--fv-cyan); }
	.email-folder-icon { width: 16px; height: 16px; flex-shrink: 0; }

	.email-badge {
		margin-left: auto;
		background: var(--fv-cyan);
		color: #050a15;
		font-size: 10px;
		font-weight: 800;
		padding: 1px 7px;
		border-radius: 10px;
	}

	/* Aliases */
	.email-aliases-section { flex: 1; min-height: 0; overflow-y: auto; }
	.email-empty-hint { font-size: 11px; color: var(--fv-ash); padding: 0 8px; }

	.email-alias-item {
		border-radius: 10px;
		margin-bottom: 2px;
		transition: background 0.15s;
	}
	.email-alias-item.active { background: rgba(0,212,255,0.06); }
	.email-alias-item:hover { background: rgba(255,255,255,0.03); }

	.email-alias-btn {
		display: flex;
		align-items: center;
		gap: 8px;
		width: 100%;
		padding: 8px 10px;
		border: none;
		background: none;
		cursor: pointer;
		text-align: left;
	}

	.email-alias-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		flex-shrink: 0;
	}
	.email-alias-dot.active { background: var(--fv-success); box-shadow: 0 0 6px rgba(0,255,136,0.4); }
	.email-alias-dot.inactive { background: var(--fv-ash); }

	.email-alias-info { min-width: 0; }
	.email-alias-label { display: block; font-size: 12px; font-weight: 600; color: var(--fv-mist); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.email-alias-address { display: block; font-size: 10px; color: var(--fv-ash); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

	.email-alias-actions {
		display: flex;
		gap: 2px;
		padding: 0 6px 4px;
		opacity: 0;
		transition: opacity 0.15s;
	}
	.email-alias-item:hover .email-alias-actions { opacity: 1; }

	.email-alias-action {
		padding: 4px;
		border-radius: 6px;
		border: none;
		background: none;
		color: var(--fv-smoke);
		cursor: pointer;
		transition: all 0.15s;
	}
	.email-alias-action:hover { background: rgba(255,255,255,0.06); }
	.email-alias-delete:hover { color: var(--fv-danger); }

	.email-alias-confirm-delete {
		padding: 8px 10px;
		font-size: 11px;
		color: var(--fv-danger);
	}

	.email-btn-sm {
		padding: 4px 12px;
		border-radius: 8px;
		border: 1px solid rgba(255,255,255,0.1);
		background: none;
		color: var(--fv-smoke);
		font-size: 11px;
		cursor: pointer;
	}
	.email-btn-danger { background: var(--fv-danger); color: white; border-color: transparent; }

	/* Main */
	.email-main { flex: 1; min-width: 0; display: flex; flex-direction: column; }

	.email-loading, .email-loading-inline {
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 60px 0;
	}

	.email-spinner {
		width: 32px;
		height: 32px;
		border: 2px solid rgba(0,212,255,0.2);
		border-top-color: var(--fv-cyan);
		border-radius: 50%;
		animation: spin 0.7s linear infinite;
	}
	.email-spinner-sm { width: 20px; height: 20px; border: 2px solid rgba(0,212,255,0.2); border-top-color: var(--fv-cyan); border-radius: 50%; animation: spin 0.7s linear infinite; }
	@keyframes spin { to { transform: rotate(360deg); } }

	/* List header */
	.email-list-header {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 16px 20px;
		border-bottom: 1px solid rgba(255,255,255,0.06);
		gap: 16px;
	}
	.email-list-title { display: flex; align-items: center; gap: 10px; }
	.email-list-title h2 { font-size: 16px; font-weight: 700; color: white; margin: 0; }
	.email-filter-badge {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 3px 10px;
		border-radius: 20px;
		background: rgba(0,212,255,0.1);
		font-size: 11px;
		color: var(--fv-cyan);
	}
	.email-filter-badge button { background: none; border: none; cursor: pointer; color: var(--fv-cyan); padding: 0; display: flex; }

	.email-search {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px 14px;
		border-radius: 12px;
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.06);
		transition: all 0.2s;
	}
	.email-search:focus-within { border-color: rgba(0,212,255,0.3); background: rgba(255,255,255,0.06); }
	.email-list-actions { display: flex; align-items: center; gap: 10px; }
	.email-refresh-btn {
		width: 38px;
		height: 38px;
		border-radius: 999px;
		border: 1px solid rgba(255,255,255,0.08);
		background: rgba(255,255,255,0.04);
		color: var(--fv-smoke);
		display: flex;
		align-items: center;
		justify-content: center;
		cursor: pointer;
		transition: all 0.15s;
	}
	.email-refresh-btn:hover {
		background: rgba(0,212,255,0.08);
		border-color: rgba(0,212,255,0.35);
		color: var(--fv-cyan);
	}
	.email-refresh-btn:disabled {
		opacity: 0.6;
		cursor: not-allowed;
	}
	.refresh-spinning { animation: spin 0.8s linear infinite; }
	.email-search-input {
		background: none;
		border: none;
		outline: none;
		color: white;
		font-size: 13px;
		width: 160px;
	}
	.email-search-input::placeholder { color: var(--fv-ash); }

	/* Email list */
	.email-list { flex: 1; overflow-y: auto; }

	.email-row {
		display: flex;
		align-items: center;
		gap: 12px;
		width: 100%;
		padding: 14px 20px;
		border: none;
		background: none;
		border-bottom: 1px solid rgba(255,255,255,0.04);
		cursor: pointer;
		text-align: left;
		transition: background 0.12s;
	}
	.email-row:hover { background: rgba(255,255,255,0.03); }
	.email-row.unread { background: rgba(0,212,255,0.02); }
	.email-row.unread .email-row-sender { color: white; font-weight: 700; }
	.email-row.unread .email-row-subject { color: var(--fv-mist); font-weight: 600; }

	.email-star {
		padding: 4px;
		border: none;
		background: none;
		cursor: pointer;
		flex-shrink: 0;
	}

	.email-row-avatar {
		width: 36px;
		height: 36px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 14px;
		font-weight: 700;
		color: white;
		flex-shrink: 0;
	}

	.email-row-content { flex: 1; min-width: 0; }
	.email-row-top { display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px; }
	.email-row-sender { font-size: 13px; font-weight: 500; color: var(--fv-smoke); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
	.email-row-date { font-size: 11px; color: var(--fv-ash); flex-shrink: 0; margin-left: 8px; }
	.email-row-subject { font-size: 13px; color: var(--fv-ash); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

	/* Empty state */
	.email-empty {
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 80px 20px;
		text-align: center;
	}
	.email-empty-icon { margin-bottom: 16px; opacity: 0.5; }
	.email-empty-title { font-size: 16px; font-weight: 700; color: var(--fv-smoke); margin-bottom: 6px; }
	.email-empty-desc { font-size: 13px; color: var(--fv-ash); max-width: 320px; line-height: 1.5; }

	/* Email detail */
	.email-detail { display: flex; flex-direction: column; height: 100%; }

	.email-detail-toolbar {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 20px;
		border-bottom: 1px solid rgba(255,255,255,0.06);
	}
	.email-toolbar-btn {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px 12px;
		border-radius: 8px;
		border: none;
		background: none;
		color: var(--fv-smoke);
		font-size: 13px;
		cursor: pointer;
		transition: all 0.15s;
	}
	.email-toolbar-btn:hover { background: rgba(255,255,255,0.06); color: white; }
	.email-toolbar-danger:hover { color: var(--fv-danger); }
	.email-toolbar-actions { display: flex; gap: 4px; }

	.email-detail-content { flex: 1; padding: 24px; overflow-y: auto; }
	.email-detail-subject { font-size: 22px; font-weight: 700; color: white; margin-bottom: 20px; line-height: 1.3; }

	.email-detail-meta { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
	.email-detail-avatar {
		width: 40px;
		height: 40px;
		border-radius: 50%;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 16px;
		font-weight: 700;
		color: white;
		flex-shrink: 0;
	}
	.email-detail-sender { flex: 1; min-width: 0; }
	.email-detail-name { display: block; font-size: 14px; font-weight: 600; color: white; }
	.email-detail-address { font-size: 12px; color: var(--fv-ash); }
	.email-detail-date { font-size: 12px; color: var(--fv-ash); flex-shrink: 0; }

	.email-detail-alias {
		padding: 8px 14px;
		border-radius: 10px;
		background: rgba(0,212,255,0.06);
		font-size: 12px;
		color: var(--fv-smoke);
		margin-bottom: 20px;
		display: inline-block;
	}
	.email-detail-alias-addr { color: var(--fv-cyan); font-weight: 600; }

	.email-detail-body {
		border-top: 1px solid rgba(255,255,255,0.06);
		padding-top: 20px;
	}
	.email-detail-iframe {
		width: 100%;
		min-height: 400px;
		border: none;
		border-radius: 12px;
		background: transparent;
	}
	.email-detail-iframe-wrap {
		border-radius: 12px;
		overflow: hidden;
		border: 1px solid rgba(255,255,255,0.08);
		background: linear-gradient(180deg, rgba(255,255,255,0.03), rgba(255,255,255,0.015));
	}
	.email-detail-text {
		font-size: 14px;
		color: var(--fv-mist);
		line-height: 1.7;
		white-space: pre-wrap;
		word-break: break-word;
		font-family: inherit;
	}

	/* Modal */
	.email-modal-overlay {
		position: fixed;
		inset: 0;
		z-index: 100;
		background: rgba(0,0,0,0.6);
		backdrop-filter: blur(8px);
		display: flex;
		align-items: center;
		justify-content: center;
		padding: 20px;
	}
	.email-modal {
		background: linear-gradient(145deg, rgba(16,24,42,0.98), rgba(12,19,34,0.98));
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 20px;
		padding: 28px;
		max-width: 440px;
		width: 100%;
		box-shadow: 0 24px 64px rgba(0,0,0,0.5);
	}
	.email-modal-title { font-size: 18px; font-weight: 700; color: white; margin-bottom: 6px; }
	.email-modal-desc { font-size: 13px; color: var(--fv-smoke); line-height: 1.5; margin-bottom: 20px; }
	.email-modal-field { margin-bottom: 16px; }
	.email-modal-field label { display: block; font-size: 11px; font-weight: 600; color: var(--fv-smoke); margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
	.email-modal-input {
		width: 100%;
		padding: 12px 14px;
		border-radius: 12px;
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.1);
		color: white;
		font-size: 14px;
		outline: none;
		transition: all 0.2s;
	}
	.email-modal-input:focus { border-color: rgba(0,212,255,0.4); box-shadow: 0 0 0 3px rgba(0,212,255,0.1); }
	.email-modal-input::placeholder { color: var(--fv-ash); }

	.email-modal-error {
		padding: 10px 14px;
		border-radius: 10px;
		background: rgba(255,68,68,0.1);
		border: 1px solid rgba(255,68,68,0.2);
		color: var(--fv-danger);
		font-size: 12px;
		margin-bottom: 16px;
	}

	.email-modal-actions { display: flex; gap: 10px; justify-content: flex-end; }

	.email-btn-secondary {
		padding: 10px 20px;
		border-radius: 12px;
		border: 1px solid rgba(255,255,255,0.1);
		background: none;
		color: var(--fv-smoke);
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		transition: all 0.15s;
	}
	.email-btn-secondary:hover { background: rgba(255,255,255,0.04); color: white; }

	.email-btn-primary {
		padding: 10px 20px;
		border-radius: 12px;
		border: none;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		color: white;
		font-size: 13px;
		font-weight: 700;
		cursor: pointer;
		transition: all 0.15s;
	}
	.email-btn-primary:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(0,212,255,0.3); }
	.email-btn-primary:disabled { opacity: 0.5; cursor: not-allowed; transform: none; }

	.email-modal-pro-notice {
		display: flex;
		align-items: center;
		gap: 8px;
		margin-top: 16px;
		padding: 10px 14px;
		border-radius: 12px;
		background: rgba(255,200,55,0.06);
		border: 1px solid rgba(255,200,55,0.15);
		font-size: 12px;
		color: var(--fv-gold);
	}
	.email-modal-pro-notice a { color: var(--fv-gold); text-decoration: underline; }

	/* Responsive */
	@media (max-width: 768px) {
		.email-page { flex-direction: column; }
		.email-sidebar {
			width: 100%;
			border-right: none;
			border-bottom: 1px solid rgba(255,255,255,0.06);
			max-height: 200px;
			overflow-y: auto;
		}
		.email-aliases-section { display: none; }
		.email-folders { display: flex; gap: 4px; flex-wrap: wrap; }
		.email-folder-btn { width: auto; }
		.email-list-header {
			flex-direction: column;
			align-items: stretch;
		}
		.email-list-actions { width: 100%; }
		.email-search { flex: 1; }
		.email-search-input { width: 100%; }
	}
</style>
