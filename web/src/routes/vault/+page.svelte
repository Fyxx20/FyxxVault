<script lang="ts">
	import { goto } from '$app/navigation';
	import { getVaultState, loadEntries, toggleFavorite, deleteEntry } from '$lib/stores/vault.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { CATEGORY_META, type VaultEntry, type VaultCategory } from '$lib/types';
	import { passwordStrength } from '$lib/crypto';
	import { generateTOTP, getTOTPRemaining } from '$lib/totp';
	import { createShareLink } from '$lib/sharing';

	const vault = getVaultState();
	const auth = getAuthState();

	// Free user limit
	const FREE_LIMIT = 5;
	const canAdd = $derived(auth.isPro || vault.entries.length < FREE_LIMIT);

	let showPassword = $state<Record<string, boolean>>({});
	let copiedField = $state<string | null>(null);
	let showDetail = $state(false);
	let showDeleteConfirm = $state<string | null>(null);
	let hasLoaded = $state(false);

	// TOTP state
	let totpCode = $state('');
	let totpRemaining = $state(30);
	let totpInterval = $state<ReturnType<typeof setInterval> | null>(null);

	// Share state
	let showSharePanel = $state(false);
	let shareExpiry = $state<'1h' | '6h' | '24h' | '72h'>('24h');
	let shareMaxViews = $state(5);
	let shareLink = $state('');
	let shareLoading = $state(false);
	let shareCopied = $state(false);

	// Password history state
	let showPasswordHistory = $state(false);

	// Clipboard auto-clear timeout
	let clipboardTimeout = $state<ReturnType<typeof setTimeout> | null>(null);

	// Load entries once when unlocked
	$effect(() => {
		if (auth.isUnlocked && !hasLoaded) {
			hasLoaded = true;
			loadEntries();
		}
	});

	// TOTP refresh
	$effect(() => {
		const entry = vault.selectedEntry;
		if (entry?.mfaEnabled && entry.mfaSecret) {
			refreshTOTP(entry.mfaSecret);
			const interval = setInterval(() => refreshTOTP(entry.mfaSecret), 1000);
			totpInterval = interval;
			return () => clearInterval(interval);
		} else {
			totpCode = '';
			if (totpInterval) clearInterval(totpInterval);
		}
	});

	async function refreshTOTP(secret: string) {
		try {
			totpCode = await generateTOTP(secret);
			totpRemaining = getTOTPRemaining();
		} catch {
			totpCode = '------';
		}
	}

	const filters = [
		{ key: 'all', label: 'Tous' },
		{ key: 'favorites', label: 'Favoris' },
		{ key: 'login', label: 'Login' },
		{ key: 'creditCard', label: 'Cartes' },
		{ key: 'identity', label: 'Identité' },
		{ key: 'secureNote', label: 'Notes' },
		{ key: 'bankAccount', label: 'Banque' },
		{ key: 'wifi', label: 'Wi-Fi' },
		{ key: 'softwareLicense', label: 'Licence' },
		{ key: 'passport', label: 'Passeport' },
		{ key: 'server', label: 'Serveur' },
		{ key: 'other', label: 'Autre' }
	];

	function selectEntry(entry: VaultEntry) {
		vault.selectedEntryId = entry.id;
		showDetail = true;
		showSharePanel = false;
		shareLink = '';
		showPasswordHistory = false;
	}

	function closeDetail() {
		showDetail = false;
		vault.selectedEntryId = null;
		showSharePanel = false;
		shareLink = '';
		showPasswordHistory = false;
	}

	async function copyToClipboard(text: string, fieldId: string) {
		try {
			await navigator.clipboard.writeText(text);
			copiedField = fieldId;
			setTimeout(() => { copiedField = null; }, 2000);

			// Auto-clear clipboard after 30s for sensitive fields
			if (clipboardTimeout) clearTimeout(clipboardTimeout);
			clipboardTimeout = setTimeout(async () => {
				try {
					const current = await navigator.clipboard.readText();
					if (current === text) {
						await navigator.clipboard.writeText('');
					}
				} catch {}
			}, 30000);
		} catch (e) {
			console.error('Copy failed:', e);
		}
	}

	function togglePasswordVisibility(id: string) {
		showPassword[id] = !showPassword[id];
	}

	function getStrengthDot(password: string): { color: string } {
		const s = passwordStrength(password);
		return { color: s.color };
	}

	function formatDate(dateStr: string): string {
		try {
			return new Date(dateStr).toLocaleDateString('fr-FR', {
				day: '2-digit', month: 'short', year: 'numeric'
			});
		} catch {
			return dateStr;
		}
	}

	async function handleDelete(id: string) {
		await deleteEntry(id);
		showDeleteConfirm = null;
		closeDetail();
	}

	function getDomain(url: string): string {
		if (!url) return '';
		try {
			const u = url.startsWith('http') ? url : `https://${url}`;
			return new URL(u).hostname;
		} catch {
			return url;
		}
	}

	async function handleShare(entry: VaultEntry) {
		shareLoading = true;
		try {
			const payload: any = { title: entry.title };
			if (entry.username) payload.username = entry.username;
			if (entry.password) payload.password = entry.password;
			if (entry.website) payload.website = entry.website;
			if (entry.notes) payload.notes = entry.notes;

			const { encryptedData, key, expiresAt } = await createShareLink(
				payload,
				{ expiresIn: shareExpiry, maxViews: shareMaxViews }
			);

			// The key is in the fragment (never sent to server)
			const baseUrl = window.location.origin;
			shareLink = `${baseUrl}/share?data=${encryptedData}#${key}`;
		} catch (e) {
			console.error('Share failed:', e);
		} finally {
			shareLoading = false;
		}
	}

	async function copyShareLink() {
		if (!shareLink) return;
		try {
			await navigator.clipboard.writeText(shareLink);
			shareCopied = true;
			setTimeout(() => shareCopied = false, 2000);
		} catch {}
	}

	function getCategoryFields(entry: VaultEntry): { label: string; value: string; sensitive?: boolean; fieldId: string }[] {
		const fields: { label: string; value: string; sensitive?: boolean; fieldId: string }[] = [];

		if (entry.username) fields.push({ label: 'Identifiant', value: entry.username, fieldId: `user-${entry.id}` });
		if (entry.password) fields.push({ label: 'Mot de passe', value: entry.password, sensitive: true, fieldId: `pass-${entry.id}` });
		if (entry.website) fields.push({ label: 'Site web', value: entry.website, fieldId: `web-${entry.id}` });

		// Category specific
		if (entry.category === 'creditCard') {
			if (entry.cardholderName) fields.push({ label: 'Titulaire', value: entry.cardholderName, fieldId: `ch-${entry.id}` });
			if (entry.cardNumber) fields.push({ label: 'Numéro', value: entry.cardNumber, sensitive: true, fieldId: `cn-${entry.id}` });
			if (entry.cardExpiry) fields.push({ label: 'Expiration', value: entry.cardExpiry, fieldId: `ce-${entry.id}` });
			if (entry.cardCVV) fields.push({ label: 'CVV', value: entry.cardCVV, sensitive: true, fieldId: `cv-${entry.id}` });
		} else if (entry.category === 'identity') {
			if (entry.firstName || entry.lastName) fields.push({ label: 'Nom', value: `${entry.firstName || ''} ${entry.lastName || ''}`.trim(), fieldId: `name-${entry.id}` });
			if (entry.dateOfBirth) fields.push({ label: 'Date de naissance', value: entry.dateOfBirth, fieldId: `dob-${entry.id}` });
			if (entry.address) fields.push({ label: 'Adresse', value: entry.address, fieldId: `addr-${entry.id}` });
			if (entry.phone) fields.push({ label: 'Téléphone', value: entry.phone, fieldId: `ph-${entry.id}` });
			if (entry.email) fields.push({ label: 'Email', value: entry.email, fieldId: `em-${entry.id}` });
		} else if (entry.category === 'wifi') {
			if (entry.networkName) fields.push({ label: 'Réseau', value: entry.networkName, fieldId: `net-${entry.id}` });
			if (entry.securityType) fields.push({ label: 'Sécurité', value: entry.securityType, fieldId: `sec-${entry.id}` });
		} else if (entry.category === 'softwareLicense') {
			if (entry.softwareName) fields.push({ label: 'Logiciel', value: entry.softwareName, fieldId: `sw-${entry.id}` });
			if (entry.licenseKey) fields.push({ label: 'Clé de licence', value: entry.licenseKey, sensitive: true, fieldId: `lk-${entry.id}` });
			if (entry.licenseEmail) fields.push({ label: 'Email', value: entry.licenseEmail, fieldId: `le-${entry.id}` });
			if (entry.softwareVersion) fields.push({ label: 'Version', value: entry.softwareVersion, fieldId: `sv-${entry.id}` });
		} else if (entry.category === 'passport') {
			if (entry.passportFullName) fields.push({ label: 'Nom complet', value: entry.passportFullName, fieldId: `pn-${entry.id}` });
			if (entry.passportNumber) fields.push({ label: 'Numéro', value: entry.passportNumber, sensitive: true, fieldId: `pp-${entry.id}` });
			if (entry.passportCountry) fields.push({ label: 'Pays', value: entry.passportCountry, fieldId: `pc-${entry.id}` });
			if (entry.passportExpiry) fields.push({ label: 'Expiration', value: entry.passportExpiry, fieldId: `pe-${entry.id}` });
			if (entry.passportDOB) fields.push({ label: 'Naissance', value: entry.passportDOB, fieldId: `pd-${entry.id}` });
		} else if (entry.category === 'bankAccount') {
			if (entry.bankName) fields.push({ label: 'Banque', value: entry.bankName, fieldId: `bn-${entry.id}` });
			if (entry.iban) fields.push({ label: 'IBAN', value: entry.iban, sensitive: true, fieldId: `ib-${entry.id}` });
			if (entry.bic) fields.push({ label: 'BIC', value: entry.bic, fieldId: `bc-${entry.id}` });
			if (entry.accountNumber) fields.push({ label: 'Numéro de compte', value: entry.accountNumber, sensitive: true, fieldId: `an-${entry.id}` });
		}

		return fields;
	}
</script>

<svelte:head>
	<title>Coffre — FyxxVault</title>
</svelte:head>

<div class="max-w-7xl mx-auto">
	<!-- Header -->
	<div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
		<div>
			<h1 class="text-2xl font-bold text-white">Coffre-fort</h1>
			<p class="text-sm text-[var(--fv-smoke)]">{vault.entries.length} élément{vault.entries.length !== 1 ? 's' : ''}</p>
		</div>
		<div class="flex gap-2">
			<a href="/vault/import" class="fv-btn fv-btn-ghost !py-2.5 !px-4 text-sm inline-flex items-center gap-2 w-fit">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
					<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
					<polyline points="17 8 12 3 7 8"/>
					<line x1="12" y1="3" x2="12" y2="15"/>
				</svg>
				Importer
			</a>
			<a href={canAdd ? '/vault/add' : '/vault/settings'} class="fv-btn {canAdd ? 'fv-btn-primary' : 'fv-btn-gold'} !py-2.5 !px-5 text-sm inline-flex items-center gap-2 w-fit">
				<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
					<line x1="12" y1="5" x2="12" y2="19"/>
					<line x1="5" y1="12" x2="19" y2="12"/>
				</svg>
				{canAdd ? 'Ajouter' : 'Passer à Pro'}
			</a>
		</div>
	</div>

	<!-- Search bar -->
	<div class="relative mb-4">
		<svg class="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--fv-ash)]" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
			<circle cx="11" cy="11" r="8"/>
			<line x1="21" y1="21" x2="16.65" y2="16.65"/>
		</svg>
		<input
			type="text"
			placeholder="Rechercher par titre, identifiant, site..."
			bind:value={vault.searchQuery}
			class="w-full pl-12 pr-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
		/>
	</div>

	<!-- Filter chips -->
	<div class="flex flex-wrap gap-2 mb-6 overflow-x-auto pb-1">
		{#each filters as filter}
			<button
				onclick={() => vault.activeFilter = filter.key}
				class="px-4 py-2 rounded-full text-xs font-semibold whitespace-nowrap transition-all
					{vault.activeFilter === filter.key
						? 'bg-[var(--fv-cyan)]/15 text-[var(--fv-cyan)] border border-[var(--fv-cyan)]/30'
						: 'bg-white/5 text-[var(--fv-smoke)] border border-white/5 hover:bg-white/10 hover:text-white'}"
			>
				{#if filter.key !== 'all' && filter.key !== 'favorites' && CATEGORY_META[filter.key as VaultCategory]}
					<span class="mr-1">{CATEGORY_META[filter.key as VaultCategory].icon}</span>
				{/if}
				{#if filter.key === 'favorites'}
					<span class="mr-1">&#9733;</span>
				{/if}
				{filter.label}
			</button>
		{/each}
	</div>

	<!-- Content area -->
	<div class="flex gap-6">
		<!-- Entry list -->
		<div class="flex-1 min-w-0">
			{#if vault.loading}
				<div class="flex items-center justify-center py-20">
					<div class="w-8 h-8 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
				</div>
			{:else if vault.filteredEntries.length === 0}
				<div class="fv-glass p-12 text-center">
					<div class="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mx-auto mb-4">
						<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="1.5">
							<rect x="3" y="11" width="18" height="11" rx="2"/>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
						</svg>
					</div>
					{#if vault.searchQuery}
						<p class="text-[var(--fv-smoke)] text-sm">Aucun résultat pour "{vault.searchQuery}"</p>
					{:else}
						<p class="text-[var(--fv-smoke)] text-sm mb-4">Ton coffre est vide</p>
						<a href="/vault/add" class="fv-btn fv-btn-primary text-sm !py-2.5 !px-5">Ajouter un premier élément</a>
					{/if}
				</div>
			{:else}
				<div class="space-y-2">
					{#each vault.filteredEntries as entry (entry.id)}
						<button
							onclick={() => selectEntry(entry)}
							class="w-full text-left fv-glass p-4 flex items-center gap-4 hover:border-[var(--fv-cyan)]/20 transition-all group
								{vault.selectedEntryId === entry.id ? 'border-[var(--fv-cyan)]/30 bg-[var(--fv-cyan)]/5' : ''}"
						>
							<!-- Category icon -->
							<div class="w-10 h-10 rounded-xl flex items-center justify-center text-lg shrink-0"
								style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
								{CATEGORY_META[entry.category]?.icon ?? '📦'}
							</div>

							<!-- Info -->
							<div class="flex-1 min-w-0">
								<div class="flex items-center gap-2">
									<p class="text-sm font-semibold text-white truncate">{entry.title || 'Sans titre'}</p>
									{#if entry.isFavorite}
										<span class="text-[var(--fv-gold)] text-xs">&#9733;</span>
									{/if}
									{#if entry.mfaEnabled}
										<span class="text-[10px] px-1.5 py-0.5 rounded bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] font-medium">MFA</span>
									{/if}
								</div>
								<p class="text-xs text-[var(--fv-smoke)] truncate mt-0.5">
									{entry.username || entry.website || CATEGORY_META[entry.category]?.label || ''}
								</p>
							</div>

							<!-- Folder badge -->
							{#if entry.folder}
								<span class="hidden sm:inline-flex text-[9px] px-2 py-0.5 rounded-full bg-white/5 text-[var(--fv-ash)] shrink-0">{entry.folder}</span>
							{/if}

							<!-- Strength dot -->
							{#if entry.password}
								<div class="w-2.5 h-2.5 rounded-full shrink-0" style="background: {getStrengthDot(entry.password).color};"></div>
							{/if}

							<!-- Date -->
							<span class="text-[10px] text-[var(--fv-ash)] hidden sm:block shrink-0">{formatDate(entry.lastModifiedAt)}</span>
						</button>
					{/each}
				</div>
			{/if}
		</div>

		<!-- Detail panel (desktop) -->
		{#if showDetail && vault.selectedEntry}
			{@const entry = vault.selectedEntry}
			{@const fields = getCategoryFields(entry)}
			<div class="hidden lg:block w-[400px] shrink-0">
				<div class="fv-glass p-6 sticky top-8 max-h-[calc(100vh-6rem)] overflow-y-auto">
					<!-- Header -->
					<div class="flex items-center justify-between mb-5">
						<div class="flex items-center gap-3">
							<div class="w-10 h-10 rounded-xl flex items-center justify-center text-lg"
								style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
								{CATEGORY_META[entry.category]?.icon ?? '📦'}
							</div>
							<div>
								<h2 class="text-base font-bold text-white">{entry.title || 'Sans titre'}</h2>
								<p class="text-xs text-[var(--fv-smoke)]">{CATEGORY_META[entry.category]?.label ?? ''}</p>
							</div>
						</div>
						<button onclick={closeDetail} class="p-1.5 rounded-lg hover:bg-white/5 text-[var(--fv-ash)]">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<line x1="18" y1="6" x2="6" y2="18"/>
								<line x1="6" y1="6" x2="18" y2="18"/>
							</svg>
						</button>
					</div>

					<!-- All fields (dynamic) -->
					<div class="space-y-3">
						{#each fields as field}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">{field.label}</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									{#if field.sensitive}
										<span class="flex-1 text-sm text-white font-mono truncate">
											{showPassword[field.fieldId] ? field.value : '•'.repeat(Math.min(field.value.length, 20))}
										</span>
										<button
											onclick={() => { showPassword[field.fieldId] = !showPassword[field.fieldId]; }}
											class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors shrink-0"
											title="Afficher/Masquer"
										>
											{#if showPassword[field.fieldId]}
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
											{:else}
												<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
											{/if}
										</button>
									{:else if field.label === 'Site web'}
										<a
											href={field.value.startsWith('http') ? field.value : `https://${field.value}`}
											target="_blank"
											rel="noopener noreferrer"
											class="flex-1 text-sm text-[var(--fv-cyan)] hover:text-white transition-colors truncate"
										>
											{getDomain(field.value)}
										</a>
										<a
											href={field.value.startsWith('http') ? field.value : `https://${field.value}`}
											target="_blank"
											rel="noopener noreferrer"
											class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors shrink-0"
											title="Ouvrir"
										>
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
										</a>
									{:else}
										<span class="flex-1 text-sm text-white truncate">{field.value}</span>
									{/if}
									<button
										onclick={() => copyToClipboard(field.value, field.fieldId)}
										class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors shrink-0"
										title="Copier"
									>
										{#if copiedField === field.fieldId}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
								<!-- Password strength bar -->
								{#if field.fieldId === `pass-${entry.id}` && entry.password}
									{@const s = passwordStrength(entry.password)}
									<div class="mt-1.5 flex items-center gap-2">
										<div class="flex-1 h-1 rounded-full bg-white/5 overflow-hidden">
											<div class="h-full rounded-full transition-all" style="width: {s.score}%; background: {s.color};"></div>
										</div>
										<span class="text-[10px] font-medium" style="color: {s.color};">{s.label}</span>
									</div>
								{/if}
							</div>
						{/each}

						<!-- TOTP display -->
						{#if entry.mfaEnabled && totpCode}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Code TOTP</label>
								<div class="flex items-center gap-2 bg-[var(--fv-cyan)]/5 border border-[var(--fv-cyan)]/20 rounded-lg px-3 py-2.5">
									<span class="flex-1 text-lg font-mono font-bold text-[var(--fv-cyan)] tracking-[0.3em]">
										{totpCode.slice(0, 3)} {totpCode.slice(3)}
									</span>
									<div class="relative w-8 h-8 shrink-0">
										<svg width="32" height="32" viewBox="0 0 32 32" class="-rotate-90">
											<circle cx="16" cy="16" r="12" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="3" />
											<circle cx="16" cy="16" r="12" fill="none" stroke="var(--fv-cyan)" stroke-width="3" stroke-linecap="round"
												stroke-dasharray={2 * Math.PI * 12}
												stroke-dashoffset={2 * Math.PI * 12 * (1 - totpRemaining / 30)}
												class="transition-all duration-1000"
											/>
										</svg>
										<span class="absolute inset-0 flex items-center justify-center text-[9px] font-bold text-[var(--fv-smoke)]">{totpRemaining}</span>
									</div>
									<button
										onclick={() => copyToClipboard(totpCode, `totp-${entry.id}`)}
										class="p-1 rounded hover:bg-white/10 text-[var(--fv-smoke)] hover:text-white transition-colors shrink-0"
									>
										{#if copiedField === `totp-${entry.id}`}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
							</div>
						{/if}

						<!-- Notes -->
						{#if entry.notes}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Notes</label>
								<div class="bg-white/5 rounded-lg px-3 py-2.5">
									<p class="text-sm text-[var(--fv-mist)] whitespace-pre-wrap">{entry.notes}</p>
								</div>
							</div>
						{/if}

						<!-- Tags -->
						{#if entry.tags.length > 0}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Tags</label>
								<div class="flex flex-wrap gap-1.5">
									{#each entry.tags as tag}
										<span class="px-2 py-1 rounded-md bg-[var(--fv-cyan)]/10 text-[10px] text-[var(--fv-cyan)]">{tag}</span>
									{/each}
								</div>
							</div>
						{/if}

						<!-- Folder -->
						{#if entry.folder}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Dossier</label>
								<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md bg-white/5 text-xs text-[var(--fv-smoke)]">
									<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/></svg>
									{entry.folder}
								</span>
							</div>
						{/if}

						<!-- Password History -->
						{#if entry.passwordHistory && entry.passwordHistory.length > 0}
							<div>
								<button
									onclick={() => showPasswordHistory = !showPasswordHistory}
									class="flex items-center gap-2 text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider hover:text-[var(--fv-smoke)] transition-colors"
								>
									Historique ({entry.passwordHistory.length})
									<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
										class="transition-transform {showPasswordHistory ? 'rotate-180' : ''}">
										<polyline points="6 9 12 15 18 9"/>
									</svg>
								</button>
								{#if showPasswordHistory}
									<div class="mt-2 space-y-1.5">
										{#each entry.passwordHistory as item}
											<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2 text-xs">
												<span class="flex-1 font-mono text-[var(--fv-smoke)] truncate">{item.password}</span>
												<span class="text-[9px] text-[var(--fv-ash)] shrink-0">{formatDate(item.changedAt)}</span>
												<button
													onclick={() => copyToClipboard(item.password, `hist-${item.changedAt}`)}
													class="p-0.5 rounded hover:bg-white/10 text-[var(--fv-ash)] shrink-0"
												>
													<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
												</button>
											</div>
										{/each}
									</div>
								{/if}
							</div>
						{/if}
					</div>

					<!-- Actions -->
					<div class="flex gap-2 mt-6 pt-4 border-t border-white/5">
						<button
							onclick={() => toggleFavorite(entry.id)}
							class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-3"
							title={entry.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'}
						>
							{entry.isFavorite ? '★' : '☆'}
						</button>
						<button
							onclick={() => goto(`/vault/add?edit=${entry.id}`)}
							class="flex-1 fv-btn fv-btn-ghost text-xs !py-2.5"
						>
							Modifier
						</button>
						{#if auth.isPro}
						<button
							onclick={() => { showSharePanel = !showSharePanel; shareLink = ''; }}
							class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-3"
							title="Partager"
						>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/></svg>
						</button>
						{/if}
						<button
							onclick={() => showDeleteConfirm = entry.id}
							class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-3 !text-[var(--fv-danger)] hover:!bg-[var(--fv-danger)]/10"
						>
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
						</button>
					</div>

					<!-- Share panel -->
					{#if showSharePanel}
						<div class="mt-3 p-4 rounded-xl bg-[var(--fv-abyss)]/60 border border-white/5 space-y-3">
							<h3 class="text-xs font-bold text-white">Partage sécurisé</h3>
							<div class="grid grid-cols-2 gap-2">
								<div>
									<label class="block text-[10px] text-[var(--fv-smoke)] mb-1">Expiration</label>
									<select bind:value={shareExpiry} class="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs focus:outline-none">
										<option value="1h">1 heure</option>
										<option value="6h">6 heures</option>
										<option value="24h">24 heures</option>
										<option value="72h">72 heures</option>
									</select>
								</div>
								<div>
									<label class="block text-[10px] text-[var(--fv-smoke)] mb-1">Max. vues</label>
									<select bind:value={shareMaxViews} class="w-full px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-xs focus:outline-none">
										<option value={1}>1 vue</option>
										<option value={3}>3 vues</option>
										<option value={5}>5 vues</option>
										<option value={10}>10 vues</option>
									</select>
								</div>
							</div>

							{#if shareLink}
								<div class="flex gap-2">
									<input type="text" readonly value={shareLink} class="flex-1 px-3 py-2 rounded-lg bg-white/5 border border-white/10 text-white text-[10px] font-mono truncate" />
									<button onclick={copyShareLink} class="fv-btn fv-btn-primary text-xs !py-2 !px-3">
										{shareCopied ? '✓' : 'Copier'}
									</button>
								</div>
								<p class="text-[9px] text-[var(--fv-ash)]">Le lien est chiffré de bout en bout. La clé n'est jamais envoyée au serveur.</p>
							{:else}
								<button
									onclick={() => handleShare(entry)}
									disabled={shareLoading}
									class="fv-btn fv-btn-primary w-full text-xs !py-2.5 {shareLoading ? 'opacity-60' : ''}"
								>
									{shareLoading ? 'Génération...' : 'Générer le lien'}
								</button>
							{/if}
						</div>
					{/if}

					<!-- Delete confirm -->
					{#if showDeleteConfirm === entry.id}
						<div class="mt-3 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)] mb-2">Supprimer cet élément ?</p>
							<div class="flex gap-2">
								<button onclick={() => handleDelete(entry.id)} class="flex-1 fv-btn text-xs !py-2 bg-[var(--fv-danger)] text-white hover:bg-[var(--fv-danger)]/80">Oui, supprimer</button>
								<button onclick={() => showDeleteConfirm = null} class="flex-1 fv-btn fv-btn-ghost text-xs !py-2">Annuler</button>
							</div>
						</div>
					{/if}

					<!-- Meta -->
					<div class="mt-4 pt-3 border-t border-white/5 space-y-1">
						<p class="text-[10px] text-[var(--fv-ash)]">Créé le {formatDate(entry.createdAt)}</p>
						<p class="text-[10px] text-[var(--fv-ash)]">Modifié le {formatDate(entry.lastModifiedAt)}</p>
					</div>
				</div>
			</div>
		{/if}
	</div>

	<!-- Mobile detail modal -->
	{#if showDetail && vault.selectedEntry}
		{@const entry = vault.selectedEntry}
		{@const fields = getCategoryFields(entry)}
		<div class="lg:hidden fixed inset-0 z-50 bg-[var(--fv-abyss)]/95 backdrop-blur-xl overflow-y-auto">
			<div class="p-4 max-w-lg mx-auto pb-20">
				<!-- Close button -->
				<button onclick={closeDetail} class="mb-4 p-2 rounded-lg hover:bg-white/5 text-[var(--fv-smoke)]">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="19" y1="12" x2="5" y2="12"/>
						<polyline points="12 19 5 12 12 5"/>
					</svg>
				</button>

				<div class="fv-glass p-6">
					<!-- Header -->
					<div class="flex items-center gap-3 mb-5">
						<div class="w-12 h-12 rounded-xl flex items-center justify-center text-xl"
							style="background: {CATEGORY_META[entry.category]?.color ?? 'var(--fv-ash)'}15;">
							{CATEGORY_META[entry.category]?.icon ?? '📦'}
						</div>
						<div class="flex-1">
							<h2 class="text-lg font-bold text-white">{entry.title || 'Sans titre'}</h2>
							<p class="text-xs text-[var(--fv-smoke)]">{CATEGORY_META[entry.category]?.label ?? ''}</p>
						</div>
						<button
							onclick={() => toggleFavorite(entry.id)}
							class="text-xl {entry.isFavorite ? 'text-[var(--fv-gold)]' : 'text-[var(--fv-ash)]'}"
						>
							{entry.isFavorite ? '★' : '☆'}
						</button>
					</div>

					<!-- All fields -->
					<div class="space-y-3">
						{#each fields as field}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">{field.label}</label>
								<div class="flex items-center gap-2 bg-white/5 rounded-lg px-3 py-2.5">
									{#if field.sensitive}
										<span class="flex-1 text-sm text-white font-mono truncate">
											{showPassword[field.fieldId] ? field.value : '•'.repeat(Math.min(field.value.length, 20))}
										</span>
										<button onclick={() => { showPassword[field.fieldId] = !showPassword[field.fieldId]; }} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
										</button>
									{:else if field.label === 'Site web'}
										<a href={field.value.startsWith('http') ? field.value : `https://${field.value}`} target="_blank" rel="noopener noreferrer"
											class="flex-1 text-sm text-[var(--fv-cyan)] truncate">{getDomain(field.value)}</a>
										<a href={field.value.startsWith('http') ? field.value : `https://${field.value}`} target="_blank" rel="noopener noreferrer"
											class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
										</a>
									{:else}
										<span class="flex-1 text-sm text-white truncate">{field.value}</span>
									{/if}
									<button onclick={() => copyToClipboard(field.value, `m-${field.fieldId}`)} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
										{#if copiedField === `m-${field.fieldId}`}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
										{/if}
									</button>
								</div>
							</div>
						{/each}

						<!-- TOTP on mobile -->
						{#if entry.mfaEnabled && totpCode}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Code TOTP</label>
								<div class="flex items-center gap-2 bg-[var(--fv-cyan)]/5 border border-[var(--fv-cyan)]/20 rounded-lg px-3 py-3">
									<span class="flex-1 text-xl font-mono font-bold text-[var(--fv-cyan)] tracking-[0.3em]">{totpCode.slice(0, 3)} {totpCode.slice(3)}</span>
									<span class="text-xs text-[var(--fv-smoke)] font-bold">{totpRemaining}s</span>
									<button onclick={() => copyToClipboard(totpCode, `m-totp-${entry.id}`)} class="p-1.5 rounded hover:bg-white/10 text-[var(--fv-smoke)]">
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
									</button>
								</div>
							</div>
						{/if}

						<!-- Notes on mobile -->
						{#if entry.notes}
							<div>
								<label class="block text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wider mb-1">Notes</label>
								<div class="bg-white/5 rounded-lg px-3 py-2.5">
									<p class="text-sm text-[var(--fv-mist)] whitespace-pre-wrap">{entry.notes}</p>
								</div>
							</div>
						{/if}

						<!-- Tags on mobile -->
						{#if entry.tags.length > 0}
							<div class="flex flex-wrap gap-1.5">
								{#each entry.tags as tag}
									<span class="px-2 py-1 rounded-md bg-[var(--fv-cyan)]/10 text-[10px] text-[var(--fv-cyan)]">{tag}</span>
								{/each}
							</div>
						{/if}
					</div>

					<!-- Mobile actions -->
					<div class="flex gap-2 mt-6">
						<button onclick={() => { closeDetail(); goto(`/vault/add?edit=${entry.id}`); }} class="flex-1 fv-btn fv-btn-primary text-xs !py-2.5">Modifier</button>
						<button
							onclick={() => showDeleteConfirm = entry.id}
							class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-4 !text-[var(--fv-danger)]"
						>Supprimer</button>
					</div>

					{#if showDeleteConfirm === entry.id}
						<div class="mt-3 p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20">
							<p class="text-xs text-[var(--fv-danger)] mb-2">Supprimer cet élément ?</p>
							<div class="flex gap-2">
								<button onclick={() => handleDelete(entry.id)} class="flex-1 fv-btn text-xs !py-2 bg-[var(--fv-danger)] text-white">Confirmer</button>
								<button onclick={() => showDeleteConfirm = null} class="flex-1 fv-btn fv-btn-ghost text-xs !py-2">Annuler</button>
							</div>
						</div>
					{/if}
				</div>
			</div>
		</div>
	{/if}
</div>

<!-- FAB on mobile -->
<a href={canAdd ? '/vault/add' : '/vault/settings'} class="lg:hidden fixed bottom-20 right-6 z-30 w-14 h-14 rounded-full bg-gradient-to-r {canAdd ? 'from-[var(--fv-cyan)] to-[var(--fv-violet)] shadow-[var(--fv-cyan)]/30' : 'from-[var(--fv-gold)] to-[var(--fv-gold-dark,#b8860b)] shadow-[var(--fv-gold)]/30'} flex items-center justify-center shadow-lg hover:scale-105 transition-transform">
	{#if canAdd}
		<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
			<line x1="12" y1="5" x2="12" y2="19"/>
			<line x1="5" y1="12" x2="19" y2="12"/>
		</svg>
	{:else}
		<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
			<path d="M12 2L15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26z"/>
		</svg>
	{/if}
</a>
