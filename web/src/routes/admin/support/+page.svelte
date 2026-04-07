<script lang="ts">
	import { getAuthState } from '$lib/stores/auth.svelte';

	const auth = getAuthState();

	// Types
	type TicketStatus = 'open' | 'waiting' | 'resolved' | 'closed';
	type MessageRole = 'user' | 'ai' | 'admin';

	interface Ticket {
		id: string;
		user_email: string;
		subject: string;
		preview: string;
		status: TicketStatus;
		created_at: string;
		updated_at: string;
	}

	interface Message {
		id: string;
		ticket_id: string;
		sender_type: MessageRole;
		sender_name?: string;
		content: string;
		created_at: string;
	}

	// State
	let tickets = $state<Ticket[]>([]);
	let selectedTicket = $state<Ticket | null>(null);
	let messages = $state<Message[]>([]);
	let loading = $state(true);
	let messagesLoading = $state(false);
	let sending = $state(false);
	let error = $state('');
	let activeFilter = $state<'all' | TicketStatus>('all');
	let replyText = $state('');
	let statusChanging = $state(false);

	// Stats
	let stats = $state({ open: 0, waiting: 0, resolved: 0, closed: 0 });

	function getToken(): string {
		return auth.session?.access_token ?? '';
	}

	async function fetchTickets() {
		loading = true;
		error = '';
		try {
			const params = new URLSearchParams();
			if (activeFilter !== 'all') params.set('status', activeFilter);

			const res = await fetch(`/api/admin/support?${params}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (!res.ok) throw new Error('Erreur de chargement des tickets');

			const data = await res.json();
			tickets = data.tickets ?? [];
			stats = data.counts ?? data.stats ?? { open: 0, waiting: 0, resolved: 0, closed: 0 };
		} catch (e: any) {
			error = e.message;
		} finally {
			loading = false;
		}
	}

	async function fetchMessages(ticketId: string) {
		messagesLoading = true;
		try {
			const res = await fetch(`/api/support/tickets/${ticketId}`, {
				headers: { Authorization: `Bearer ${getToken()}` }
			});
			if (!res.ok) throw new Error('Erreur de chargement des messages');

			const data = await res.json();
			messages = data.messages ?? [];
			if (data.ticket) {
				selectedTicket = data.ticket;
			}
		} catch (e: any) {
			error = e.message;
		} finally {
			messagesLoading = false;
		}
	}

	async function sendReply() {
		if (!replyText.trim() || !selectedTicket) return;
		sending = true;
		try {
			const res = await fetch('/api/support/messages', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${getToken()}`
				},
				body: JSON.stringify({
					ticket_id: selectedTicket.id,
					content: replyText.trim(),
					as_admin: true
				})
			});
			if (!res.ok) throw new Error('Erreur d\'envoi');

			replyText = '';
			await fetchMessages(selectedTicket.id);
		} catch (e: any) {
			error = e.message;
		} finally {
			sending = false;
		}
	}

	async function changeStatus(newStatus: TicketStatus) {
		if (!selectedTicket) return;
		statusChanging = true;
		try {
			const res = await fetch(`/api/support/tickets/${selectedTicket.id}`, {
				method: 'PATCH',
				headers: {
					'Content-Type': 'application/json',
					Authorization: `Bearer ${getToken()}`
				},
				body: JSON.stringify({ status: newStatus })
			});
			if (!res.ok) throw new Error('Erreur de changement de statut');

			selectedTicket = { ...selectedTicket, status: newStatus };
			await fetchTickets();
		} catch (e: any) {
			error = e.message;
		} finally {
			statusChanging = false;
		}
	}

	function selectTicket(ticket: Ticket) {
		selectedTicket = ticket;
		fetchMessages(ticket.id);
	}

	function setFilter(f: 'all' | TicketStatus) {
		activeFilter = f;
		fetchTickets();
	}

	function statusColor(status: TicketStatus): string {
		switch (status) {
			case 'open': return 'cyan';
			case 'waiting': return 'yellow';
			case 'resolved': return 'green';
			case 'closed': return 'gray';
		}
	}

	function statusLabel(status: TicketStatus): string {
		switch (status) {
			case 'open': return 'Ouvert';
			case 'waiting': return 'En attente';
			case 'resolved': return 'Resolu';
			case 'closed': return 'Ferme';
		}
	}

	function roleLabel(role: MessageRole): string {
		switch (role) {
			case 'user': return 'Utilisateur';
			case 'ai': return 'IA';
			case 'admin': return 'Admin';
		}
	}

	function formatDate(dateStr: string): string {
		try {
			return new Date(dateStr).toLocaleDateString('fr-FR', {
				day: '2-digit',
				month: '2-digit',
				year: 'numeric',
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return dateStr;
		}
	}

	function formatShortDate(dateStr: string): string {
		try {
			return new Date(dateStr).toLocaleDateString('fr-FR', {
				day: '2-digit',
				month: '2-digit',
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return dateStr;
		}
	}

	// Initial fetch
	$effect(() => {
		if (auth.session?.access_token) {
			fetchTickets();
		}
	});

	// Scroll to bottom when messages change
	let messagesContainer: HTMLDivElement | undefined = $state(undefined);
	$effect(() => {
		if (messages.length && messagesContainer) {
			messagesContainer.scrollTop = messagesContainer.scrollHeight;
		}
	});

	// Filter tabs config
	const filterTabs: { key: 'all' | TicketStatus; label: string }[] = [
		{ key: 'all', label: 'Tous' },
		{ key: 'open', label: 'Ouverts' },
		{ key: 'waiting', label: 'En attente' },
		{ key: 'resolved', label: 'Resolus' },
		{ key: 'closed', label: 'Fermes' }
	];
</script>

<svelte:head>
	<title>Support - Admin FyxxVault</title>
</svelte:head>

<!-- Page Header -->
<div class="mb-6">
	<h1 class="text-2xl font-extrabold text-white tracking-tight">Support</h1>
	<p class="text-sm text-[var(--fv-smoke)] mt-1">Gestion des tickets de support utilisateurs</p>
</div>

<!-- Stats Bar -->
<div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-6">
	<button class="admin-stat-card cyan {activeFilter === 'open' ? 'ring-2 ring-[var(--fv-cyan)]' : ''}" onclick={() => setFilter(activeFilter === 'open' ? 'all' : 'open')}>
		<p class="text-[11px] font-bold uppercase tracking-wider text-[var(--fv-smoke)] mb-1">Ouverts</p>
		<p class="text-2xl font-extrabold text-white">{stats.open}</p>
	</button>
	<button class="admin-stat-card gold {activeFilter === 'waiting' ? 'ring-2 ring-[var(--fv-warning)]' : ''}" onclick={() => setFilter(activeFilter === 'waiting' ? 'all' : 'waiting')}>
		<p class="text-[11px] font-bold uppercase tracking-wider text-[var(--fv-smoke)] mb-1">En attente</p>
		<p class="text-2xl font-extrabold text-white">{stats.waiting}</p>
	</button>
	<button class="admin-stat-card success {activeFilter === 'resolved' ? 'ring-2 ring-[var(--fv-success)]' : ''}" onclick={() => setFilter(activeFilter === 'resolved' ? 'all' : 'resolved')}>
		<p class="text-[11px] font-bold uppercase tracking-wider text-[var(--fv-smoke)] mb-1">Resolus</p>
		<p class="text-2xl font-extrabold text-white">{stats.resolved}</p>
	</button>
	<button class="stat-card-gray {activeFilter === 'closed' ? 'ring-2 ring-[var(--fv-smoke)]' : ''}" onclick={() => setFilter(activeFilter === 'closed' ? 'all' : 'closed')}>
		<p class="text-[11px] font-bold uppercase tracking-wider text-[var(--fv-smoke)] mb-1">Fermes</p>
		<p class="text-2xl font-extrabold text-white">{stats.closed}</p>
	</button>
</div>

<!-- Error message -->
{#if error}
	<div class="mb-4 px-4 py-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">
		{error}
		<button class="ml-2 underline" onclick={() => error = ''}>Fermer</button>
	</div>
{/if}

<!-- Main Panel: Ticket List + Conversation -->
<div class="flex gap-4 h-[calc(100vh-340px)] min-h-[500px]">
	<!-- LEFT: Ticket List -->
	<div class="w-[40%] flex flex-col rounded-2xl bg-[var(--fv-obsidian)] border border-white/5 overflow-hidden">
		<!-- Filter Tabs -->
		<div class="flex border-b border-white/5 px-2 pt-2 gap-1 flex-shrink-0">
			{#each filterTabs as tab}
				<button
					class="px-3 py-2 text-xs font-semibold rounded-t-lg transition-all
						{activeFilter === tab.key
							? 'bg-white/10 text-white'
							: 'text-[var(--fv-smoke)] hover:text-white hover:bg-white/5'}"
					onclick={() => setFilter(tab.key)}
				>
					{tab.label}
				</button>
			{/each}
		</div>

		<!-- Ticket Cards -->
		<div class="flex-1 overflow-y-auto p-2 space-y-1">
			{#if loading}
				<div class="flex items-center justify-center py-12">
					<div class="w-6 h-6 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
				</div>
			{:else if tickets.length === 0}
				<div class="text-center py-12 text-[var(--fv-ash)] text-sm">
					Aucun ticket
				</div>
			{:else}
				{#each tickets as ticket}
					<button
						class="w-full text-left px-4 py-3 rounded-xl transition-all
							{selectedTicket?.id === ticket.id
								? 'bg-[var(--fv-violet)]/10 border border-[var(--fv-violet)]/30'
								: 'hover:bg-white/5 border border-transparent'}"
						onclick={() => selectTicket(ticket)}
					>
						<div class="flex items-start justify-between gap-2 mb-1">
							<span class="text-xs text-[var(--fv-smoke)] truncate flex-1">{ticket.user_email}</span>
							<span class="ticket-badge {statusColor(ticket.status)}">{statusLabel(ticket.status)}</span>
						</div>
						<p class="text-sm text-white font-medium truncate">{ticket.subject || ticket.preview}</p>
						{#if ticket.subject && ticket.preview}
							<p class="text-xs text-[var(--fv-ash)] truncate mt-0.5">{ticket.preview}</p>
						{/if}
						<p class="text-[10px] text-[var(--fv-ash)] mt-1">{formatShortDate(ticket.created_at)}</p>
					</button>
				{/each}
			{/if}
		</div>
	</div>

	<!-- RIGHT: Conversation Panel -->
	<div class="w-[60%] flex flex-col rounded-2xl bg-[var(--fv-obsidian)] border border-white/5 overflow-hidden">
		{#if !selectedTicket}
			<div class="flex-1 flex items-center justify-center">
				<div class="text-center">
					<svg class="mx-auto mb-3 opacity-20" width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
						<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
					</svg>
					<p class="text-[var(--fv-ash)] text-sm">Selectionnez un ticket pour voir la conversation</p>
				</div>
			</div>
		{:else}
			<!-- Ticket Header -->
			<div class="px-5 py-4 border-b border-white/5 flex items-center justify-between flex-shrink-0">
				<div class="flex-1 min-w-0">
					<div class="flex items-center gap-2 mb-1">
						<span class="text-sm font-bold text-white truncate">{selectedTicket.user_email}</span>
						<span class="ticket-badge {statusColor(selectedTicket.status)}">{statusLabel(selectedTicket.status)}</span>
					</div>
					<p class="text-xs text-[var(--fv-ash)]">Cree le {formatDate(selectedTicket.created_at)}</p>
				</div>

				<!-- Status dropdown -->
				<div class="relative flex-shrink-0">
					<select
						class="appearance-none px-3 py-1.5 pr-7 rounded-lg text-xs font-semibold
							bg-white/5 border border-white/10 text-[var(--fv-silver)]
							outline-none cursor-pointer hover:bg-white/10 transition-all"
						value={selectedTicket.status}
						onchange={(e) => changeStatus((e.target as HTMLSelectElement).value as TicketStatus)}
						disabled={statusChanging}
					>
						<option value="open">Ouvrir</option>
						<option value="waiting">En attente</option>
						<option value="resolved">Resolu</option>
						<option value="closed">Ferme</option>
					</select>
					<svg class="absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<polyline points="6 9 12 15 18 9"/>
					</svg>
				</div>
			</div>

			<!-- Messages -->
			<div class="flex-1 overflow-y-auto px-5 py-4 space-y-3" bind:this={messagesContainer}>
				{#if messagesLoading}
					<div class="flex items-center justify-center py-12">
						<div class="w-6 h-6 border-2 border-[var(--fv-violet)]/30 border-t-[var(--fv-violet)] rounded-full animate-spin"></div>
					</div>
				{:else if messages.length === 0}
					<div class="text-center py-12 text-[var(--fv-ash)] text-sm">Aucun message</div>
				{:else}
					{#each messages as msg}
						<div class="flex {msg.sender_type === 'admin' ? 'justify-end' : 'justify-start'}">
							<div class="max-w-[80%] rounded-2xl px-4 py-3
								{msg.sender_type === 'admin'
									? 'bg-[var(--fv-violet)]/15 border border-[var(--fv-violet)]/20'
									: msg.sender_type === 'ai'
										? 'bg-[var(--fv-cyan)]/10 border border-[var(--fv-cyan)]/15'
										: 'bg-white/5 border border-white/8'}">
								<div class="flex items-center gap-2 mb-1">
									<span class="text-[10px] font-bold uppercase tracking-wider
										{msg.sender_type === 'admin'
											? 'text-[var(--fv-violet-light)]'
											: msg.sender_type === 'ai'
												? 'text-[var(--fv-cyan)]'
												: 'text-[var(--fv-smoke)]'}">
										{roleLabel(msg.sender_type)}
									</span>
									<span class="text-[10px] text-[var(--fv-ash)]">{formatShortDate(msg.created_at)}</span>
								</div>
								<p class="text-sm text-[var(--fv-silver)] whitespace-pre-wrap break-words">{msg.content}</p>
							</div>
						</div>
					{/each}
				{/if}
			</div>

			<!-- Reply Input -->
			<div class="px-5 py-4 border-t border-white/5 flex-shrink-0">
				<div class="flex gap-3">
					<textarea
						class="admin-input flex-1 resize-none"
						rows="2"
						placeholder="Repondre en tant qu'admin..."
						bind:value={replyText}
						onkeydown={(e) => {
							if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
								e.preventDefault();
								sendReply();
							}
						}}
					></textarea>
					<button
						class="self-end px-5 py-3 rounded-xl text-sm font-bold text-white transition-all
							{sending
								? 'bg-[var(--fv-violet)]/50 cursor-not-allowed'
								: 'bg-[var(--fv-violet)] hover:bg-[var(--fv-violet-light)] shadow-lg shadow-[var(--fv-violet)]/20'}"
						onclick={sendReply}
						disabled={sending || !replyText.trim()}
					>
						{#if sending}
							<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
						{:else}
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<line x1="22" y1="2" x2="11" y2="13"/>
								<polygon points="22 2 15 22 11 13 2 9 22 2"/>
							</svg>
						{/if}
					</button>
				</div>
				<p class="text-[10px] text-[var(--fv-ash)] mt-1.5">Cmd+Enter pour envoyer</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.ticket-badge {
		display: inline-flex;
		align-items: center;
		padding: 2px 8px;
		border-radius: 20px;
		font-size: 10px;
		font-weight: 700;
		letter-spacing: 0.02em;
		white-space: nowrap;
		flex-shrink: 0;
	}
	.ticket-badge.cyan {
		background: rgba(6, 182, 212, 0.15);
		color: var(--fv-cyan);
	}
	.ticket-badge.yellow {
		background: rgba(251, 191, 36, 0.15);
		color: var(--fv-warning);
	}
	.ticket-badge.green {
		background: rgba(52, 211, 153, 0.15);
		color: var(--fv-success);
	}
	.ticket-badge.gray {
		background: rgba(120, 138, 160, 0.15);
		color: var(--fv-smoke);
	}

	.stat-card-gray {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 16px;
		padding: 24px;
		position: relative;
		overflow: hidden;
		cursor: pointer;
		text-align: left;
		transition: transform 0.15s, box-shadow 0.15s;
		font-family: inherit;
	}
	.stat-card-gray:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 16px rgba(0,0,0,0.2);
	}
	.stat-card-gray::before {
		content: '';
		position: absolute;
		left: 0;
		top: 0;
		bottom: 0;
		width: 4px;
		border-radius: 4px 0 0 4px;
		background: var(--fv-smoke);
	}

	select option {
		background: #1a1a2e;
		color: #e0e0e0;
	}
</style>
