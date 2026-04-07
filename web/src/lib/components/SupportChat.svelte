<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { t, getLang } from '$lib/i18n.svelte';

	const auth = getAuthState();

	// ─── Views ───
	type View = 'home' | 'list' | 'chat';
	let view: View = $state('home');

	// ─── State ───
	let isOpen = $state(false);
	let tickets: any[] = $state([]);
	let activeTicket: any | null = $state(null);
	let messages: any[] = $state([]);
	let input = $state('');
	let sending = $state(false);
	let unreadCount = $state(0);
	let messagesEl: HTMLDivElement | undefined = $state();
	let initialized = $state(false);
	let newSubject = $state('');

	// ─── Notification popup ───
	let notifVisible = $state(false);
	let notifMessage = $state('');
	let notifTimeout: ReturnType<typeof setTimeout> | null = null;

	// ─── Polling ───
	let pollInterval: ReturnType<typeof setInterval> | null = null;
	let bgPollInterval: ReturnType<typeof setInterval> | null = null;

	// ─── API helper ───
	async function apiFetch(url: string, opts: RequestInit = {}) {
		const token = auth.session?.access_token;
		const res = await fetch(url, {
			...opts,
			headers: {
				'Content-Type': 'application/json',
				Authorization: `Bearer ${token}`,
				...(opts.headers || {})
			}
		});
		return res.json();
	}

	// ─── Lifecycle ───
	onMount(() => {
		loadTickets();
		// Background poll every 20s for new replies when chat is closed
		bgPollInterval = setInterval(pollForNewReplies, 20000);
	});

	onDestroy(() => {
		stopPolling();
		if (bgPollInterval) clearInterval(bgPollInterval);
		if (notifTimeout) clearTimeout(notifTimeout);
	});

	function startPolling() {
		stopPolling();
		// Poll active conversation every 5s
		pollInterval = setInterval(() => {
			if (activeTicket && view === 'chat' && !sending) {
				loadMessages(activeTicket.id, true);
			}
		}, 5000);
	}

	function stopPolling() {
		if (pollInterval) {
			clearInterval(pollInterval);
			pollInterval = null;
		}
	}

	// Background polling: check for admin replies
	async function pollForNewReplies() {
		if (!auth.session?.access_token) return;
		try {
			const data = await apiFetch('/api/support/tickets');
			if (!data.tickets) return;

			const oldTickets = tickets;
			tickets = data.tickets;

			// Check if any ticket got a new admin/ai message since last check
			for (const newT of data.tickets) {
				const oldT = oldTickets.find((t: any) => t.id === newT.id);
				if (oldT && newT.updated_at !== oldT.updated_at && newT.status === 'waiting') {
					// Ticket was updated by admin
					if (!isOpen || activeTicket?.id !== newT.id) {
						unreadCount++;
						showNotification(getLang() === 'fr'
							? 'Le support a repondu a votre message !'
							: 'Support has replied to your message!');
					}
					// If we're viewing this ticket, refresh messages
					if (isOpen && activeTicket?.id === newT.id && view === 'chat') {
						loadMessages(newT.id, true);
					}
				}
			}
		} catch {
			// Silent
		}
	}

	function showNotification(msg: string) {
		notifMessage = msg;
		notifVisible = true;
		if (notifTimeout) clearTimeout(notifTimeout);
		notifTimeout = setTimeout(() => {
			notifVisible = false;
		}, 6000);
	}

	function dismissNotif() {
		notifVisible = false;
		if (notifTimeout) clearTimeout(notifTimeout);
	}

	function openFromNotif() {
		dismissNotif();
		isOpen = true;
		unreadCount = 0;
		// Open most recent waiting ticket
		const waitingTicket = tickets.find((t: any) => t.status === 'waiting');
		if (waitingTicket) {
			openTicket(waitingTicket);
		} else {
			view = tickets.length > 0 ? 'list' : 'home';
		}
	}

	async function loadTickets() {
		try {
			const data = await apiFetch('/api/support/tickets');
			if (data.tickets) {
				tickets = data.tickets;
				unreadCount = data.unread_count ?? 0;
			}
		} catch {
			// Silent fail
		} finally {
			initialized = true;
		}
	}

	async function loadMessages(ticketId: string, silent: boolean = false) {
		try {
			const data = await apiFetch(`/api/support/tickets/${ticketId}`);
			if (data.messages) {
				if (silent && messages.length === data.messages.length) return;
				messages = data.messages;
			}
			// Update ticket status (for auto-close detection)
			if (data.ticket && activeTicket) {
				activeTicket = data.ticket;
				// Stop polling if ticket is resolved/closed
				if (data.ticket.status === 'resolved' || data.ticket.status === 'closed') {
					stopPolling();
				}
			}
		} catch {
			// Silent fail
		}
	}

	async function openTicket(ticket: any) {
		activeTicket = ticket;
		messages = [];
		view = 'chat';
		await loadMessages(ticket.id);
		startPolling();
	}

	async function createNewConversation() {
		const text = newSubject.trim();
		if (!text || sending) return;

		sending = true;
		newSubject = '';
		view = 'chat';
		activeTicket = null;
		messages = [];

		// Optimistic user message
		messages = [{
			id: crypto.randomUUID(),
			sender_type: 'user',
			content: text,
			created_at: new Date().toISOString()
		}];

		try {
			const data = await apiFetch('/api/support/tickets', {
				method: 'POST',
				body: JSON.stringify({ message: text, lang: getLang() })
			});
			if (data.ticket) {
				activeTicket = data.ticket;
				tickets = [data.ticket, ...tickets];
			}
			if (data.messages) {
				messages = data.messages;
			}
			startPolling();
		} catch {
			view = 'home';
			messages = [];
		} finally {
			sending = false;
		}
	}

	async function sendMessage() {
		const text = input.trim();
		if (!text || sending) return;

		sending = true;
		input = '';

		// Optimistic user message
		const userMsg = {
			id: crypto.randomUUID(),
			sender_type: 'user',
			content: text,
			created_at: new Date().toISOString()
		};
		messages = [...messages, userMsg];

		try {
			if (!activeTicket) {
				const data = await apiFetch('/api/support/tickets', {
					method: 'POST',
					body: JSON.stringify({ message: text, lang: getLang() })
				});
				if (data.ticket) {
					activeTicket = data.ticket;
					tickets = [data.ticket, ...tickets];
				}
				if (data.messages) {
					messages = data.messages;
				}
				startPolling();
			} else {
				const data = await apiFetch('/api/support/messages', {
					method: 'POST',
					body: JSON.stringify({ ticket_id: activeTicket.id, content: text, lang: getLang() })
				});
				if (data.messages) {
					messages = messages.filter(m => m.id !== userMsg.id);
					messages = [...messages, ...data.messages];
				}
				// Reload ticket to detect status change (auto-resolve)
				if (activeTicket) {
					const ticketData = await apiFetch(`/api/support/tickets/${activeTicket.id}`);
					if (ticketData.ticket) {
						activeTicket = ticketData.ticket;
						if (ticketData.ticket.status === 'resolved' || ticketData.ticket.status === 'closed') {
							stopPolling();
						}
					}
				}
			}
		} catch {
			messages = messages.filter(m => m.id !== userMsg.id);
			input = text;
		} finally {
			sending = false;
		}
	}

	function toggleChat() {
		isOpen = !isOpen;
		if (isOpen) {
			unreadCount = 0;
			dismissNotif();
			if (tickets.length === 0 && initialized) {
				view = 'home';
			} else if (!activeTicket) {
				view = tickets.length > 0 ? 'list' : 'home';
			}
			// If we have an active ticket, start polling
			if (activeTicket && view === 'chat') {
				loadMessages(activeTicket.id, true);
				startPolling();
			}
		} else {
			stopPolling();
		}
	}

	function goHome() {
		view = 'home';
		activeTicket = null;
		messages = [];
		stopPolling();
	}

	function goToList() {
		view = 'list';
		activeTicket = null;
		messages = [];
		stopPolling();
		loadTickets();
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			sendMessage();
		}
	}

	function handleSubjectKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			createNewConversation();
		}
	}

	function formatTime(dateStr: string) {
		try {
			return new Date(dateStr).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
		} catch { return ''; }
	}

	function formatDate(dateStr: string) {
		try {
			return new Date(dateStr).toLocaleDateString([], { day: 'numeric', month: 'short' });
		} catch { return ''; }
	}

	function formatRelative(dateStr: string) {
		try {
			const d = new Date(dateStr);
			const now = new Date();
			const diff = now.getTime() - d.getTime();
			const mins = Math.floor(diff / 60000);
			if (mins < 1) return 'now';
			if (mins < 60) return `${mins}m`;
			const hours = Math.floor(mins / 60);
			if (hours < 24) return `${hours}h`;
			const days = Math.floor(hours / 24);
			if (days < 7) return `${days}d`;
			return formatDate(dateStr);
		} catch { return ''; }
	}

	function getStatusColor(status: string) {
		switch (status) {
			case 'open': return '#22c55e';
			case 'waiting': return '#eab308';
			case 'resolved': return '#06b6d4';
			case 'closed': return '#64748b';
			default: return '#64748b';
		}
	}

	function getPreview(ticket: any) {
		return ticket.subject?.slice(0, 60) || 'Conversation';
	}

	// Auto-scroll
	$effect(() => {
		if (messages.length && messagesEl) {
			requestAnimationFrame(() => {
				messagesEl?.scrollTo({ top: messagesEl.scrollHeight, behavior: 'smooth' });
			});
		}
	});

	function startQuickTopic(topicKey: string) {
		newSubject = t(topicKey);
		createNewConversation();
	}
</script>

<!-- Floating chat widget -->
<div class="support-chat-root">
	{#if isOpen}
		<div class="chat-panel" role="dialog" aria-label="Support chat">

			<!-- ═══════════ HOME VIEW ═══════════ -->
			{#if view === 'home'}
				<div class="panel-home">
					<div class="home-header">
						<button class="close-btn-abs" onclick={toggleChat} aria-label="Close">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
						<div class="home-avatar">
							<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
								<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
								<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
							</svg>
						</div>
						<h2 class="home-title">{t('support.title')}</h2>
						<p class="home-subtitle">{t('support.subtitle')}</p>
						<div class="online-indicator">
							<span class="online-dot"></span>
							<span>{t('support.online')}</span>
						</div>
					</div>

					<div class="home-body">
						<div class="new-convo-card">
							<p class="card-label">{t('support.new_conversation')}</p>
							<div class="new-convo-input-row">
								<input
									type="text"
									class="new-convo-input"
									placeholder={t('support.placeholder')}
									bind:value={newSubject}
									onkeydown={handleSubjectKeydown}
									disabled={sending}
								/>
								<button class="new-convo-send" onclick={createNewConversation} disabled={!newSubject.trim() || sending}>
									<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
										<line x1="22" y1="2" x2="11" y2="13"/>
										<polygon points="22 2 15 22 11 13 2 9 22 2"/>
									</svg>
								</button>
							</div>
						</div>

						<div class="quick-topics">
							<p class="topics-label">{t('support.common_topics')}</p>
							<div class="topics-grid">
								<button class="topic-btn" onclick={() => startQuickTopic('support.sync_issue')}>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M23 4v6h-6"/><path d="M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
									{t('support.topic.sync')}
								</button>
								<button class="topic-btn" onclick={() => startQuickTopic('support.billing_issue')}>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
									{t('support.topic.billing')}
								</button>
								<button class="topic-btn" onclick={() => startQuickTopic('support.import_issue')}>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/></svg>
									{t('support.topic.import')}
								</button>
								<button class="topic-btn" onclick={() => startQuickTopic('support.security_question')}>
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
									{t('support.topic.security')}
								</button>
							</div>
						</div>

						{#if tickets.length > 0}
							<button class="see-conversations-btn" onclick={goToList}>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
								</svg>
								{t('support.see_conversations')} ({tickets.length})
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="chevron-right">
									<polyline points="9 18 15 12 9 6"/>
								</svg>
							</button>
						{/if}
					</div>

					<div class="powered-by">
						<span>{t('support.powered_by')}</span>
						<strong>FyxxVault AI</strong>
					</div>
				</div>

			<!-- ═══════════ CONVERSATIONS LIST ═══════════ -->
			{:else if view === 'list'}
				<div class="panel-list">
					<div class="list-header">
						<button class="back-btn" onclick={goHome} aria-label="Back">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<polyline points="15 18 9 12 15 6"/>
							</svg>
						</button>
						<h3 class="list-title">{t('support.conversations')}</h3>
						<button class="close-btn-sm" onclick={toggleChat} aria-label="Close">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>

					<div class="list-body">
						<button class="new-convo-list-btn" onclick={goHome}>
							<div class="new-icon">
								<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>
								</svg>
							</div>
							<span>{t('support.new')}</span>
						</button>

						{#if tickets.length === 0}
							<div class="empty-list">
								<p>{t('support.no_conversations')}</p>
							</div>
						{:else}
							{#each tickets as ticket}
								<button class="ticket-row" onclick={() => openTicket(ticket)}>
									<div class="ticket-left">
										<div class="ticket-icon" style="background: {getStatusColor(ticket.status)}20; color: {getStatusColor(ticket.status)}">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
												<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
											</svg>
										</div>
										<div class="ticket-info">
											<span class="ticket-subject">{getPreview(ticket)}</span>
											<span class="ticket-meta">
												<span class="status-badge" style="color: {getStatusColor(ticket.status)}">{ticket.status}</span>
											</span>
										</div>
									</div>
									<span class="ticket-time">{formatRelative(ticket.updated_at)}</span>
								</button>
							{/each}
						{/if}
					</div>
				</div>

			<!-- ═══════════ CHAT VIEW ═══════════ -->
			{:else if view === 'chat'}
				<div class="panel-chat">
					<div class="chat-header">
						<button class="back-btn" onclick={goToList} aria-label="Back">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<polyline points="15 18 9 12 15 6"/>
							</svg>
						</button>
						<div class="header-center">
							<div class="header-bot-avatar">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<rect x="3" y="11" width="18" height="11" rx="2"/>
									<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
									<circle cx="9" cy="16" r="1"/><circle cx="15" cy="16" r="1"/>
								</svg>
							</div>
							<div>
								<h3 class="chat-title">FyxxBot</h3>
								<span class="chat-status">
									<span class="status-dot-sm"></span>
									{t('support.online')}
								</span>
							</div>
						</div>
						<button class="close-btn-sm" onclick={toggleChat} aria-label="Close">
							<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
								<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>

					<div class="chat-messages" bind:this={messagesEl}>
						{#if messages.length === 0 && !sending}
							<div class="chat-empty">
								<div class="spinner"></div>
							</div>
						{:else}
							{#each messages as msg, i}
								{#if i === 0 || formatDate(msg.created_at) !== formatDate(messages[i - 1].created_at)}
									<div class="date-separator">
										<span>{formatDate(msg.created_at)}</span>
									</div>
								{/if}

								<div class="message-row {msg.sender_type || msg.role || 'user'}">
									{#if (msg.sender_type || msg.role) === 'ai'}
										<div class="avatar ai-avatar">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
												<rect x="3" y="11" width="18" height="11" rx="2"/>
												<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
												<circle cx="9" cy="16" r="1"/><circle cx="15" cy="16" r="1"/>
											</svg>
										</div>
									{:else if (msg.sender_type || msg.role) === 'admin'}
										<div class="avatar admin-avatar">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
												<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
											</svg>
										</div>
									{/if}

									<div class="message-bubble {msg.sender_type || msg.role || 'user'}">
										{#if (msg.sender_type || msg.role) === 'admin'}
											<span class="sender-label admin-label">{t('support.team')}</span>
										{/if}
										<p class="message-text">{msg.content}</p>
										<span class="message-time">{formatTime(msg.created_at)}</span>
									</div>
								</div>
							{/each}

							{#if sending}
								<div class="message-row ai">
									<div class="avatar ai-avatar">
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
											<rect x="3" y="11" width="18" height="11" rx="2"/>
											<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
											<circle cx="9" cy="16" r="1"/><circle cx="15" cy="16" r="1"/>
										</svg>
									</div>
									<div class="message-bubble ai typing">
										<span class="dot"></span>
										<span class="dot"></span>
										<span class="dot"></span>
									</div>
								</div>
							{/if}
						{/if}
					</div>

					<div class="chat-input-area">
						{#if activeTicket?.status === 'resolved' || activeTicket?.status === 'closed'}
							<div class="ticket-closed-banner">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
									<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/>
									<polyline points="22 4 12 14.01 9 11.01"/>
								</svg>
								<span>{getLang() === 'fr' ? 'Ce ticket a ete resolu.' : 'This ticket has been resolved.'}</span>
							</div>
						{:else}
							<div class="input-wrapper">
								<input
									type="text"
									placeholder={t('support.type_message')}
									bind:value={input}
									onkeydown={handleKeydown}
									disabled={sending}
									class="chat-input"
								/>
								<button
									class="send-btn"
									onclick={sendMessage}
									disabled={!input.trim() || sending}
									aria-label="Send"
								>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
										<line x1="22" y1="2" x2="11" y2="13"/>
										<polygon points="22 2 15 22 11 13 2 9 22 2"/>
									</svg>
								</button>
							</div>
						{/if}
					</div>
				</div>
			{/if}
		</div>
	{/if}

	<!-- Notification popup -->
	{#if notifVisible && !isOpen}
		<!-- svelte-ignore a11y_click_events_have_key_events -->
		<!-- svelte-ignore a11y_no_static_element_interactions -->
		<div class="notif-popup" onclick={openFromNotif}>
			<div class="notif-icon">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
				</svg>
			</div>
			<div class="notif-content">
				<span class="notif-title">FyxxVault Support</span>
				<span class="notif-text">{notifMessage}</span>
			</div>
			<button class="notif-close" onclick={(e) => { e.stopPropagation(); dismissNotif(); }} aria-label="Close">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
					<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
				</svg>
			</button>
		</div>
	{/if}

	<!-- Floating button -->
	<button
		class="chat-bubble-btn"
		class:active={isOpen}
		class:has-unread={unreadCount > 0 && !isOpen}
		onclick={toggleChat}
		aria-label="Support"
	>
		{#if isOpen}
			<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
				<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
			</svg>
		{:else}
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
				<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
			</svg>
		{/if}

		{#if unreadCount > 0 && !isOpen}
			<span class="unread-badge">{unreadCount > 9 ? '9+' : unreadCount}</span>
		{/if}
	</button>
</div>

<style>
	.support-chat-root {
		position: fixed;
		bottom: 24px;
		right: 24px;
		z-index: 9999;
		display: flex;
		flex-direction: column;
		align-items: flex-end;
		gap: 12px;
	}

	.chat-bubble-btn {
		width: 60px;
		height: 60px;
		border-radius: 50%;
		border: none;
		background: linear-gradient(135deg, #06b6d4, #7c3aed);
		color: white;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 6px 24px rgba(6, 182, 212, 0.3), 0 2px 8px rgba(0, 0, 0, 0.4);
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
		position: relative;
	}

	.chat-bubble-btn:hover {
		transform: scale(1.08);
		box-shadow: 0 8px 32px rgba(6, 182, 212, 0.4), 0 4px 12px rgba(0, 0, 0, 0.4);
	}

	.chat-bubble-btn:active { transform: scale(0.95); }
	.chat-bubble-btn.active { background: rgba(255, 255, 255, 0.1); box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3); }

	.chat-bubble-btn.has-unread { animation: pulse-ring 2s ease-out infinite; }

	@keyframes pulse-ring {
		0% { box-shadow: 0 6px 24px rgba(6, 182, 212, 0.3), 0 0 0 0 rgba(6, 182, 212, 0.35); }
		70% { box-shadow: 0 6px 24px rgba(6, 182, 212, 0.3), 0 0 0 16px rgba(6, 182, 212, 0); }
		100% { box-shadow: 0 6px 24px rgba(6, 182, 212, 0.3), 0 0 0 0 rgba(6, 182, 212, 0); }
	}

	.unread-badge {
		position: absolute; top: -3px; right: -3px;
		min-width: 20px; height: 20px; padding: 0 5px;
		border-radius: 10px; background: #ef4444; color: white;
		font-size: 11px; font-weight: 700;
		display: flex; align-items: center; justify-content: center;
		border: 2px solid #0f172a;
	}

	.chat-panel {
		width: 400px; height: 560px; border-radius: 20px;
		overflow: hidden; display: flex; flex-direction: column;
		background: #0c1222;
		border: 1px solid rgba(255, 255, 255, 0.07);
		box-shadow: 0 32px 80px rgba(0, 0, 0, 0.6), 0 0 0 1px rgba(255, 255, 255, 0.04) inset;
		animation: panel-in 0.3s cubic-bezier(0.16, 1, 0.3, 1);
	}

	@keyframes panel-in {
		from { opacity: 0; transform: translateY(20px) scale(0.95); }
		to { opacity: 1; transform: translateY(0) scale(1); }
	}

	/* HOME */
	.panel-home { display: flex; flex-direction: column; height: 100%; }

	.home-header {
		padding: 28px 24px 24px;
		background: linear-gradient(145deg, rgba(6, 182, 212, 0.15), rgba(124, 58, 237, 0.15));
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
		position: relative; display: flex; flex-direction: column; align-items: center; text-align: center;
	}

	.close-btn-abs {
		position: absolute; top: 12px; right: 12px;
		width: 32px; height: 32px; border-radius: 8px; border: none;
		background: rgba(255, 255, 255, 0.06); color: #94a3b8;
		cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s;
	}
	.close-btn-abs:hover { background: rgba(255, 255, 255, 0.12); color: #f1f5f9; }

	.home-avatar {
		width: 52px; height: 52px; border-radius: 16px;
		background: linear-gradient(135deg, #06b6d4, #7c3aed);
		display: flex; align-items: center; justify-content: center; color: white; margin-bottom: 12px;
	}

	.home-title { margin: 0; font-size: 18px; font-weight: 700; color: #f1f5f9; letter-spacing: -0.02em; }
	.home-subtitle { margin: 6px 0 0; font-size: 13px; color: #94a3b8; line-height: 1.4; }

	.online-indicator {
		display: flex; align-items: center; gap: 6px; margin-top: 10px;
		font-size: 12px; color: #22c55e; font-weight: 500;
	}

	.online-dot {
		width: 7px; height: 7px; border-radius: 50%;
		background: #22c55e; box-shadow: 0 0 8px rgba(34, 197, 94, 0.5);
	}

	.home-body { flex: 1; overflow-y: auto; padding: 16px; display: flex; flex-direction: column; gap: 14px; }

	.new-convo-card {
		padding: 16px; background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06); border-radius: 14px;
	}

	.card-label { margin: 0 0 10px; font-size: 13px; font-weight: 600; color: #e2e8f0; }
	.new-convo-input-row { display: flex; gap: 8px; }

	.new-convo-input {
		flex: 1; padding: 10px 14px;
		background: rgba(255, 255, 255, 0.05); border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px; color: #f1f5f9; font-size: 13px; font-family: inherit; outline: none;
		transition: border-color 0.15s;
	}
	.new-convo-input:focus { border-color: rgba(6, 182, 212, 0.4); }
	.new-convo-input::placeholder { color: #475569; }

	.new-convo-send {
		width: 40px; height: 40px; min-width: 40px; border-radius: 10px; border: none;
		background: linear-gradient(135deg, #06b6d4, #7c3aed); color: white;
		cursor: pointer; display: flex; align-items: center; justify-content: center;
		transition: opacity 0.15s, transform 0.15s;
	}
	.new-convo-send:hover:not(:disabled) { transform: scale(1.05); }
	.new-convo-send:disabled { opacity: 0.3; cursor: not-allowed; }

	.topics-label {
		margin: 0 0 8px; font-size: 12px; font-weight: 600; color: #64748b;
		text-transform: uppercase; letter-spacing: 0.05em;
	}

	.topics-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }

	.topic-btn {
		display: flex; align-items: center; gap: 8px; padding: 10px 12px;
		background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 10px; color: #cbd5e1; font-size: 12px; font-weight: 500;
		cursor: pointer; transition: all 0.15s; font-family: inherit;
	}
	.topic-btn:hover { background: rgba(6, 182, 212, 0.08); border-color: rgba(6, 182, 212, 0.2); color: #06b6d4; }

	.see-conversations-btn {
		display: flex; align-items: center; gap: 10px; width: 100%; padding: 14px 16px;
		background: rgba(255, 255, 255, 0.03); border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 12px; color: #94a3b8; font-size: 13px; font-weight: 500;
		cursor: pointer; transition: all 0.15s; font-family: inherit;
	}
	.see-conversations-btn:hover { background: rgba(255, 255, 255, 0.06); color: #e2e8f0; }
	.chevron-right { margin-left: auto; }

	.powered-by {
		padding: 10px; text-align: center; font-size: 11px; color: #334155;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
	}
	.powered-by strong {
		color: #475569;
		background: linear-gradient(135deg, #06b6d4, #7c3aed);
		-webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text;
	}

	/* LIST */
	.panel-list { display: flex; flex-direction: column; height: 100%; }

	.list-header {
		display: flex; align-items: center; gap: 8px; padding: 14px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06); background: rgba(255, 255, 255, 0.02);
	}

	.list-title { margin: 0; flex: 1; font-size: 15px; font-weight: 600; color: #f1f5f9; }

	.back-btn, .close-btn-sm {
		width: 32px; height: 32px; border-radius: 8px; border: none;
		background: rgba(255, 255, 255, 0.05); color: #94a3b8;
		cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.15s;
	}
	.back-btn:hover, .close-btn-sm:hover { background: rgba(255, 255, 255, 0.1); color: #f1f5f9; }

	.list-body {
		flex: 1; overflow-y: auto; padding: 8px;
		scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}

	.new-convo-list-btn {
		display: flex; align-items: center; gap: 12px; width: 100%; padding: 14px 12px; margin-bottom: 4px;
		background: linear-gradient(135deg, rgba(6, 182, 212, 0.08), rgba(124, 58, 237, 0.08));
		border: 1px dashed rgba(6, 182, 212, 0.3); border-radius: 12px;
		color: #06b6d4; font-size: 13px; font-weight: 600; cursor: pointer; transition: all 0.15s; font-family: inherit;
	}
	.new-convo-list-btn:hover { background: linear-gradient(135deg, rgba(6, 182, 212, 0.12), rgba(124, 58, 237, 0.12)); }

	.new-icon {
		width: 32px; height: 32px; border-radius: 10px;
		background: rgba(6, 182, 212, 0.15); display: flex; align-items: center; justify-content: center;
	}

	.empty-list { display: flex; align-items: center; justify-content: center; padding: 40px; color: #475569; font-size: 13px; }

	.ticket-row {
		display: flex; align-items: center; gap: 10px; width: 100%; padding: 12px;
		background: transparent; border: none; border-radius: 10px;
		cursor: pointer; transition: background 0.15s; font-family: inherit; text-align: left;
	}
	.ticket-row:hover { background: rgba(255, 255, 255, 0.04); }

	.ticket-left { display: flex; align-items: center; gap: 10px; flex: 1; min-width: 0; }

	.ticket-icon {
		width: 32px; height: 32px; min-width: 32px; border-radius: 10px;
		display: flex; align-items: center; justify-content: center;
	}

	.ticket-info { display: flex; flex-direction: column; gap: 3px; min-width: 0; }

	.ticket-subject {
		font-size: 13px; font-weight: 500; color: #e2e8f0;
		white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
	}

	.ticket-meta { font-size: 11px; }
	.status-badge { font-weight: 600; text-transform: capitalize; }
	.ticket-time { font-size: 11px; color: #475569; white-space: nowrap; }

	/* CHAT */
	.panel-chat { display: flex; flex-direction: column; height: 100%; }

	.chat-header {
		display: flex; align-items: center; gap: 8px; padding: 12px 14px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06); background: rgba(255, 255, 255, 0.02);
	}

	.header-center { flex: 1; display: flex; align-items: center; gap: 10px; }

	.header-bot-avatar {
		width: 34px; height: 34px; min-width: 34px; border-radius: 10px;
		background: linear-gradient(135deg, #06b6d4, #7c3aed);
		display: flex; align-items: center; justify-content: center; color: white;
	}

	.chat-title { margin: 0; font-size: 14px; font-weight: 600; color: #f1f5f9; }

	.chat-status { display: flex; align-items: center; gap: 5px; font-size: 11px; color: #64748b; }

	.status-dot-sm {
		width: 6px; height: 6px; border-radius: 50%;
		background: #22c55e; box-shadow: 0 0 6px rgba(34, 197, 94, 0.5);
	}

	.chat-messages {
		flex: 1; overflow-y: auto; padding: 14px; display: flex; flex-direction: column; gap: 6px;
		scrollbar-width: thin; scrollbar-color: rgba(255, 255, 255, 0.08) transparent;
	}
	.chat-messages::-webkit-scrollbar { width: 4px; }
	.chat-messages::-webkit-scrollbar-track { background: transparent; }
	.chat-messages::-webkit-scrollbar-thumb { background: rgba(255, 255, 255, 0.08); border-radius: 2px; }

	.chat-empty { flex: 1; display: flex; align-items: center; justify-content: center; }

	.spinner {
		width: 24px; height: 24px;
		border: 2.5px solid rgba(255, 255, 255, 0.08); border-top-color: #06b6d4;
		border-radius: 50%; animation: spin 0.7s linear infinite;
	}
	@keyframes spin { to { transform: rotate(360deg); } }

	.date-separator { display: flex; align-items: center; justify-content: center; padding: 6px 0; }
	.date-separator span { font-size: 10px; color: #475569; background: rgba(15, 23, 42, 0.9); padding: 2px 10px; border-radius: 8px; }

	.message-row { display: flex; gap: 8px; max-width: 85%; align-items: flex-end; }
	.message-row.user { align-self: flex-end; flex-direction: row-reverse; }
	.message-row.ai { align-self: flex-start; }
	.message-row.admin { align-self: flex-start; }

	.avatar {
		width: 26px; height: 26px; min-width: 26px; border-radius: 8px;
		display: flex; align-items: center; justify-content: center; flex-shrink: 0;
	}
	.ai-avatar { background: rgba(124, 58, 237, 0.12); color: #a78bfa; }
	.admin-avatar { background: rgba(234, 179, 8, 0.12); color: #fbbf24; }

	.message-bubble { padding: 10px 14px; border-radius: 16px; position: relative; }
	.message-bubble.user { background: linear-gradient(135deg, #0891b2, #0d6b8a); border-bottom-right-radius: 4px; color: white; }
	.message-bubble.ai { background: rgba(124, 58, 237, 0.08); border: 1px solid rgba(124, 58, 237, 0.1); border-bottom-left-radius: 4px; color: #e2e8f0; }
	.message-bubble.admin { background: rgba(234, 179, 8, 0.06); border: 1px solid rgba(234, 179, 8, 0.12); border-bottom-left-radius: 4px; color: #e2e8f0; }

	.sender-label { display: block; font-size: 10px; font-weight: 700; margin-bottom: 3px; text-transform: uppercase; letter-spacing: 0.04em; }
	.admin-label { color: #fbbf24; }

	.message-text { margin: 0; font-size: 13px; line-height: 1.5; word-break: break-word; white-space: pre-wrap; }
	.message-time { display: block; font-size: 10px; opacity: 0.45; margin-top: 4px; text-align: right; }

	.message-bubble.typing { display: flex; align-items: center; gap: 4px; padding: 12px 18px; }
	.dot { width: 5px; height: 5px; border-radius: 50%; background: #a78bfa; animation: typing-bounce 1.2s ease-in-out infinite; }
	.dot:nth-child(2) { animation-delay: 0.15s; }
	.dot:nth-child(3) { animation-delay: 0.3s; }
	@keyframes typing-bounce {
		0%, 60%, 100% { transform: translateY(0); opacity: 0.35; }
		30% { transform: translateY(-4px); opacity: 1; }
	}

	.chat-input-area { padding: 10px 14px 14px; border-top: 1px solid rgba(255, 255, 255, 0.05); background: rgba(12, 18, 34, 0.8); }

	.input-wrapper {
		display: flex; align-items: center; gap: 8px;
		background: rgba(255, 255, 255, 0.04); border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 12px; padding: 4px 4px 4px 14px; transition: border-color 0.15s;
	}
	.input-wrapper:focus-within { border-color: rgba(6, 182, 212, 0.35); }

	.chat-input { flex: 1; border: none; background: none; outline: none; color: #f1f5f9; font-size: 13px; font-family: inherit; padding: 6px 0; }
	.chat-input::placeholder { color: #475569; }
	.chat-input:disabled { opacity: 0.5; }

	.send-btn {
		width: 34px; height: 34px; min-width: 34px; border-radius: 10px; border: none;
		background: linear-gradient(135deg, #06b6d4, #7c3aed); color: white;
		cursor: pointer; display: flex; align-items: center; justify-content: center;
		transition: opacity 0.15s, transform 0.15s;
	}
	.send-btn:hover:not(:disabled) { transform: scale(1.05); }
	.send-btn:active:not(:disabled) { transform: scale(0.95); }
	.send-btn:disabled { opacity: 0.3; cursor: not-allowed; }

	/* TICKET CLOSED BANNER */
	.ticket-closed-banner {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 8px;
		padding: 14px;
		color: #22c55e;
		font-size: 13px;
		font-weight: 500;
		background: rgba(34, 197, 94, 0.06);
		border-radius: 10px;
		border: 1px solid rgba(34, 197, 94, 0.12);
	}

	/* NOTIFICATION POPUP */
	.notif-popup {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 14px 16px;
		background: #0c1222;
		border: 1px solid rgba(6, 182, 212, 0.2);
		border-radius: 16px;
		cursor: pointer;
		box-shadow: 0 12px 40px rgba(0, 0, 0, 0.5), 0 0 0 1px rgba(255, 255, 255, 0.04) inset;
		animation: notif-in 0.4s cubic-bezier(0.16, 1, 0.3, 1);
		max-width: 320px;
		font-family: inherit;
		text-align: left;
		transition: background 0.15s;
	}
	.notif-popup:hover { background: #111830; }

	@keyframes notif-in {
		from { opacity: 0; transform: translateY(12px) scale(0.95); }
		to { opacity: 1; transform: translateY(0) scale(1); }
	}

	.notif-icon {
		width: 36px; height: 36px; min-width: 36px; border-radius: 10px;
		background: linear-gradient(135deg, #06b6d4, #7c3aed);
		display: flex; align-items: center; justify-content: center; color: white;
	}

	.notif-content {
		flex: 1; display: flex; flex-direction: column; gap: 2px; min-width: 0;
	}

	.notif-title {
		font-size: 12px; font-weight: 700; color: #f1f5f9;
	}

	.notif-text {
		font-size: 12px; color: #94a3b8; line-height: 1.3;
		overflow: hidden; text-overflow: ellipsis;
		display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical;
	}

	.notif-close {
		width: 28px; height: 28px; min-width: 28px; border-radius: 6px;
		border: none; background: rgba(255, 255, 255, 0.05); color: #64748b;
		cursor: pointer; display: flex; align-items: center; justify-content: center;
		transition: all 0.15s;
	}
	.notif-close:hover { background: rgba(255, 255, 255, 0.1); color: #f1f5f9; }

	@media (max-width: 480px) {
		.support-chat-root { bottom: 16px; right: 16px; }
		.chat-panel { width: calc(100vw - 32px); height: calc(100dvh - 100px); max-height: 560px; }
		.notif-popup { max-width: calc(100vw - 100px); }
	}
</style>
