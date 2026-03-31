<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { CATEGORY_META, newVaultEntry, type VaultCategory, type VaultEntry } from '$lib/types';
	import { generatePassword, generatePassphrase, passwordStrength } from '$lib/crypto';
	import { addEntry, updateEntry, getVaultState } from '$lib/stores/vault.svelte';
	import { getAuthState } from '$lib/stores/auth.svelte';
	import { untrack } from 'svelte';
	import { t } from '$lib/i18n.svelte';

	const vault = getVaultState();
	const auth = getAuthState();

	// Free user limit
	const FREE_LIMIT = 5;
	const canAdd = $derived(auth.isPro || (editId ? true : vault.entries.length < FREE_LIMIT));

	// Determine if editing
	const editId = $derived($page.url.searchParams.get('edit'));
	const existingEntry = $derived(editId ? vault.entries.find((e) => e.id === editId) ?? null : null);

	let entry = $state<VaultEntry>(newVaultEntry());
	let loading = $state(false);
	let error = $state('');
	let success = $state(false);
	let tagInput = $state('');

	// Password generator state
	let genLength = $state(20);
	let genUppercase = $state(true);
	let genLowercase = $state(true);
	let genDigits = $state(true);
	let genSymbols = $state(true);
	let showGenerator = $state(false);
	let showPassword = $state(false);
	let genMode = $state<'password' | 'passphrase'>('password');
	let genWordCount = $state(5);
	let genSeparator = $state('-');
	let genCapitalize = $state(true);
	let copiedGenerated = $state(false);
	let regenSpin = $state(false);
	let categoryKey = $state(0);

	// Validation state
	let titleTouched = $state(false);
	const titleValid = $derived(entry.title.trim().length > 0);

	// Auto-save draft to localStorage
	const DRAFT_KEY = 'fv_draft_entry';

	function saveDraft() {
		if (editId) return; // Don't save drafts when editing
		try {
			localStorage.setItem(DRAFT_KEY, JSON.stringify(entry));
		} catch {}
	}

	function loadDraft() {
		if (editId) return;
		try {
			const raw = localStorage.getItem(DRAFT_KEY);
			if (raw) {
				const draft = JSON.parse(raw);
				if (draft && draft.title) {
					entry = { ...entry, ...draft };
				}
			}
		} catch {}
	}

	function clearDraft() {
		try { localStorage.removeItem(DRAFT_KEY); } catch {}
	}

	// Load draft or existing entry on mount (runs once)
	let _initialized = false;
	$effect(() => {
		// Read reactive dependencies we care about
		const existing = existingEntry;
		// Guard: only run once
		if (_initialized) return;
		_initialized = true;
		untrack(() => {
			if (existing) {
				entry = { ...existing };
			} else {
				loadDraft();
			}
		});
	});

	const strengthRaw = $derived(passwordStrength(entry.password));
	// Map CSS variables to explicit hex colors for inline styles (CSS vars don't always resolve in style attributes)
	const strengthColorMap: Record<string, string> = {
		'var(--fv-danger)': '#ef4444',
		'var(--fv-gold)': '#ffc837',
		'var(--fv-cyan)': '#00d4ff',
		'var(--fv-success)': '#34d399',
		'var(--fv-ash)': '#6b7280'
	};
	const strength = $derived({
		...strengthRaw,
		color: strengthColorMap[strengthRaw.color] ?? strengthRaw.color
	});

	const categories = Object.entries(CATEGORY_META) as [VaultCategory, typeof CATEGORY_META[VaultCategory]][];

	function handleGeneratePassword() {
		if (genMode === 'passphrase') {
			entry.password = generatePassphrase(genWordCount, genSeparator, genCapitalize);
		} else {
			entry.password = generatePassword(genLength, {
				uppercase: genUppercase,
				lowercase: genLowercase,
				digits: genDigits,
				symbols: genSymbols
			});
		}
	}

	async function copyGeneratedPassword() {
		if (!entry.password) return;
		try {
			await navigator.clipboard.writeText(entry.password);
			copiedGenerated = true;
			setTimeout(() => copiedGenerated = false, 2000);
		} catch {}
	}

	function addTag() {
		const tag = tagInput.trim();
		if (tag && !entry.tags.includes(tag)) {
			entry.tags = [...entry.tags, tag];
		}
		tagInput = '';
	}

	function removeTag(tag: string) {
		entry.tags = entry.tags.filter((tg) => tg !== tag);
	}

	function onCategoryChange(cat: VaultCategory) {
		entry.category = cat;
		categoryKey++; // trigger crossfade
		// Set default title hints based on category
		if (!entry.title) {
			const hints: Partial<Record<VaultCategory, string>> = {
				wifi: entry.networkName || '',
				softwareLicense: entry.softwareName || '',
				passport: entry.passportFullName || '',
				bankAccount: entry.bankName || ''
			};
			if (hints[cat]) entry.title = hints[cat]!;
		}
	}

	async function handleSubmit() {
		if (!entry.title.trim()) {
			error = t('add.title_required');
			return;
		}

		error = '';
		loading = true;

		try {
			entry.lastModifiedAt = new Date().toISOString();

			// Track password history if password changed
			if (editId && existingEntry && existingEntry.password !== entry.password && existingEntry.password) {
				entry.passwordHistory = [
					...(entry.passwordHistory || []),
					{ password: existingEntry.password, changedAt: new Date().toISOString() }
				].slice(-20);
			}

			let result;
			if (editId && existingEntry) {
				result = await updateEntry(entry);
			} else {
				entry.createdAt = new Date().toISOString();
				result = await addEntry(entry);
			}

			if (result.success) {
				success = true;
				clearDraft();
				setTimeout(() => goto('/vault'), 800);
			} else {
				error = result.error || t('add.save_error');
			}
		} catch (e: any) {
			error = e.message || t('add.unknown_error');
		} finally {
			loading = false;
		}
	}

	// Input field component helper
	const inputClass = "add-form-input w-full px-4 py-3.5 rounded-2xl text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none transition-all duration-250";
</script>

<svelte:head>
	<title>{editId ? t('add.title_edit') : t('add.title_new')} — FyxxVault</title>
</svelte:head>

<div class="max-w-2xl mx-auto">
	<!-- Header -->
	<div class="flex items-center gap-4 mb-8">
		<button onclick={() => { if (!editId && !entry.title.trim()) clearDraft(); goto('/vault'); }} class="p-2 rounded-xl hover:bg-white/5 text-[var(--fv-smoke)] transition-all duration-200">
			<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
				<line x1="19" y1="12" x2="5" y2="12"/>
				<polyline points="12 19 5 12 12 5"/>
			</svg>
		</button>
		<h1 class="text-xl font-extrabold text-white tracking-tight">{editId ? t('add.title_edit') : t('add.title_new')}</h1>
	</div>

	{#if !canAdd}
		<div class="fv-glass p-10 text-center" style="border: 1px solid var(--fv-gold);">
			<div class="w-20 h-20 rounded-full bg-[var(--fv-gold)]/10 flex items-center justify-center mx-auto mb-5">
				<span class="text-4xl">👑</span>
			</div>
			<h2 class="text-xl font-bold" style="color: var(--fv-gold);">{t('add.limit_reached')}</h2>
			<p class="text-sm text-[var(--fv-smoke)] mb-6 mt-2">{t('add.limit_desc')}</p>
			<a href="/vault/settings" class="fv-btn fv-btn-gold" style="display: inline-block;">{t('add.upgrade_pro')}</a>
		</div>
	{:else if success}
		<div class="fv-glass p-8 text-center fv-glow-cyan">
			<div class="w-16 h-16 rounded-full bg-[var(--fv-success)]/15 flex items-center justify-center mx-auto mb-4">
				<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
			</div>
			<p class="text-white font-semibold">{editId ? t('add.entry_modified') : t('add.entry_added')} !</p>
		</div>
	{:else}
		<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleSubmit(); }} class="add-form-wrapper space-y-6">
			<!-- Category selector -->
			<div class="add-glass-card p-6">
				<label class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-4">{t('add.category')}</label>
				<div class="grid grid-cols-5 sm:grid-cols-10 gap-2">
					{#each categories as [key, meta]}
						<button
							type="button"
							onclick={() => onCategoryChange(key)}
							class="category-card flex flex-col items-center gap-1.5 p-3 rounded-xl transition-all duration-250
								{entry.category === key
									? 'category-card-selected'
									: 'category-card-default'}"
						>
							<span class="text-lg transition-transform duration-200" class:scale-110={entry.category === key}>{meta.icon}</span>
							<span class="text-[8px] text-[var(--fv-smoke)] font-medium leading-tight text-center">{meta.label}</span>
						</button>
					{/each}
				</div>
			</div>

			<!-- Category-specific fields -->
			<div class="add-glass-card p-8 space-y-7">
				<!-- Title (always shown) -->
				<div>
					<label for="title" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.title_label')} *</label>
					<div class="relative">
						<input id="title" type="text" bind:value={entry.title} oninput={() => titleTouched = true} placeholder={t('add.title_placeholder_full')} class="{inputClass} {titleTouched && titleValid ? '!border-[var(--fv-success)]/40' : ''}" />
						{#if titleTouched && titleValid}
							<div class="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--fv-success)] transition-opacity duration-200">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12" class="fv-check-draw"/></svg>
							</div>
						{/if}
					</div>
				</div>

				{#key categoryKey}
			<div class="fv-crossfade-enter space-y-7">
			{#if entry.category === 'login' || entry.category === 'server' || entry.category === 'other'}
					<!-- LOGIN / SERVER / OTHER -->
					<div>
						<label for="website" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.website')}</label>
						<input id="website" type="text" bind:value={entry.website} placeholder="example.com" class={inputClass} />
					</div>
					<div>
						<label for="username" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.username_email')}</label>
						<input id="username" type="text" bind:value={entry.username} placeholder="ton@email.com" class={inputClass} />
					</div>
					<!-- Password field with generator -->
					{@render passwordField()}

				{:else if entry.category === 'creditCard'}
					<!-- CREDIT CARD -->
					<div>
						<label for="cardholderName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.cardholder')}</label>
						<input id="cardholderName" type="text" bind:value={entry.cardholderName} placeholder="JEAN DUPONT" class={inputClass} />
					</div>
					<div>
						<label for="cardNumber" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.card_number')}</label>
						<input id="cardNumber" type="text" bind:value={entry.cardNumber} placeholder="4242 4242 4242 4242" class="{inputClass} font-mono" maxlength="19" />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="cardExpiry" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.card_expiry')}</label>
							<input id="cardExpiry" type="text" bind:value={entry.cardExpiry} placeholder="MM/AA" class="{inputClass} font-mono" maxlength="5" />
						</div>
						<div>
							<label for="cardCVV" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.card_cvv')}</label>
							<input id="cardCVV" type="password" bind:value={entry.cardCVV} placeholder="•••" class="{inputClass} font-mono" maxlength="4" />
						</div>
					</div>

				{:else if entry.category === 'identity'}
					<!-- IDENTITY -->
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="firstName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.first_name')}</label>
							<input id="firstName" type="text" bind:value={entry.firstName} placeholder="Jean" class={inputClass} />
						</div>
						<div>
							<label for="lastName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.last_name')}</label>
							<input id="lastName" type="text" bind:value={entry.lastName} placeholder="Dupont" class={inputClass} />
						</div>
					</div>
					<div>
						<label for="dateOfBirth" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.dob')}</label>
						<input id="dateOfBirth" type="date" bind:value={entry.dateOfBirth} class={inputClass} />
					</div>
					<div>
						<label for="address" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.address')}</label>
						<input id="address" type="text" bind:value={entry.address} placeholder="123 Rue de la Paix, Paris" class={inputClass} />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="phone" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.phone')}</label>
							<input id="phone" type="tel" bind:value={entry.phone} placeholder="+33 6 12 34 56 78" class={inputClass} />
						</div>
						<div>
							<label for="email" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.email')}</label>
							<input id="email" type="email" bind:value={entry.email} placeholder="jean@email.com" class={inputClass} />
						</div>
					</div>

				{:else if entry.category === 'secureNote'}
					<!-- SECURE NOTE: just title + notes, no password field -->

				{:else if entry.category === 'wifi'}
					<!-- WI-FI -->
					<div>
						<label for="networkName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.network_ssid')}</label>
						<input id="networkName" type="text" bind:value={entry.networkName} placeholder="MonWiFi-5G" class={inputClass} />
					</div>
					<div>
						<label for="securityType" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.security_type')}</label>
						<select id="securityType" bind:value={entry.securityType} class={inputClass}>
							<option value="">{t('add.select')}</option>
							<option value="WPA3">WPA3</option>
							<option value="WPA2">WPA2</option>
							<option value="WPA">WPA</option>
							<option value="WEP">WEP</option>
							<option value="Open">{t('add.wifi_open')}</option>
						</select>
					</div>
					{@render passwordField()}

				{:else if entry.category === 'softwareLicense'}
					<!-- SOFTWARE LICENSE -->
					<div>
						<label for="softwareName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.software_name')}</label>
						<input id="softwareName" type="text" bind:value={entry.softwareName} placeholder="Adobe Photoshop" class={inputClass} />
					</div>
					<div>
						<label for="licenseKey" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.license_key')}</label>
						<input id="licenseKey" type="text" bind:value={entry.licenseKey} placeholder="XXXX-XXXX-XXXX-XXXX" class="{inputClass} font-mono" />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="licenseEmail" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.license_email')}</label>
							<input id="licenseEmail" type="email" bind:value={entry.licenseEmail} placeholder="jean@email.com" class={inputClass} />
						</div>
						<div>
							<label for="softwareVersion" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.version')}</label>
							<input id="softwareVersion" type="text" bind:value={entry.softwareVersion} placeholder="v2.1.0" class={inputClass} />
						</div>
					</div>

				{:else if entry.category === 'passport'}
					<!-- PASSPORT -->
					<div>
						<label for="passportFullName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.passport_name')}</label>
						<input id="passportFullName" type="text" bind:value={entry.passportFullName} placeholder="DUPONT Jean" class={inputClass} />
					</div>
					<div>
						<label for="passportNumber" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.passport_number')}</label>
						<input id="passportNumber" type="text" bind:value={entry.passportNumber} placeholder="12AB34567" class="{inputClass} font-mono" />
					</div>
					<div>
						<label for="passportCountry" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.passport_country')}</label>
						<input id="passportCountry" type="text" bind:value={entry.passportCountry} placeholder="France" class={inputClass} />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="passportExpiry" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.passport_expiry')}</label>
							<input id="passportExpiry" type="date" bind:value={entry.passportExpiry} class={inputClass} />
						</div>
						<div>
							<label for="passportDOB" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.passport_dob')}</label>
							<input id="passportDOB" type="date" bind:value={entry.passportDOB} class={inputClass} />
						</div>
					</div>

				{:else if entry.category === 'bankAccount'}
					<!-- BANK ACCOUNT -->
					<div>
						<label for="bankName" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.bank_name')}</label>
						<input id="bankName" type="text" bind:value={entry.bankName} placeholder="BNP Paribas" class={inputClass} />
					</div>
					<div>
						<label for="iban" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.iban')}</label>
						<input id="iban" type="text" bind:value={entry.iban} placeholder="FR76 1234 5678 9012 3456 7890 123" class="{inputClass} font-mono" />
					</div>
					<div class="grid grid-cols-2 gap-3">
						<div>
							<label for="bic" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.bic')}</label>
							<input id="bic" type="text" bind:value={entry.bic} placeholder="BNPAFRPP" class="{inputClass} font-mono" />
						</div>
						<div>
							<label for="accountNumber" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.account_number')}</label>
							<input id="accountNumber" type="text" bind:value={entry.accountNumber} placeholder="12345678901" class="{inputClass} font-mono" />
						</div>
					</div>
				{/if}
			</div>
			{/key}

				<!-- Notes (always shown) -->
				<div>
					<label for="notes" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.notes')}</label>
					<textarea
						id="notes"
						bind:value={entry.notes}
						placeholder={t('add.notes_placeholder')}
						rows={entry.category === 'secureNote' ? 8 : 3}
						class="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all resize-none"
					></textarea>
				</div>
			</div>

			<!-- Extra options -->
			<div class="add-glass-card p-6 space-y-5">
				<!-- Folder -->
				<div>
					<label for="folder" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.folder')}</label>
					<input id="folder" type="text" bind:value={entry.folder} placeholder={t('add.folder_placeholder')} class={inputClass} />
				</div>

				<!-- Tags -->
				<div>
					<label class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.tags')}</label>
					<div class="flex gap-2">
						<input
							type="text"
							bind:value={tagInput}
							placeholder={t('add.tag_placeholder')}
							onkeydown={(e: KeyboardEvent) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } }}
							class="flex-1 px-4 py-2.5 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none focus:border-[var(--fv-cyan)]/50 transition-all"
						/>
						<button type="button" onclick={addTag} class="fv-btn fv-btn-ghost text-xs !py-2.5 !px-4">+</button>
					</div>
					{#if entry.tags.length > 0}
						<div class="flex flex-wrap gap-1.5 mt-2">
							{#each entry.tags as tag}
								<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs">
									{tag}
									<button type="button" onclick={() => removeTag(tag)} class="hover:text-white">&times;</button>
								</span>
							{/each}
						</div>
					{/if}
				</div>

				<!-- Toggles -->
				<div class="flex items-center justify-between">
					<span class="text-sm text-[var(--fv-smoke)]">{t('add.favorite')}</span>
					<button
						type="button"
						onclick={() => entry.isFavorite = !entry.isFavorite}
						class="w-11 h-6 rounded-full transition-colors relative {entry.isFavorite ? 'bg-[var(--fv-cyan)]' : 'bg-white/10'}"
					>
						<div class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform {entry.isFavorite ? 'translate-x-[22px]' : 'translate-x-0.5'}"></div>
					</button>
				</div>

				{#if entry.category === 'login' || entry.category === 'server'}
					<div class="flex items-center justify-between">
						<span class="text-sm text-[var(--fv-smoke)]">{t('add.mfa_enabled')}</span>
						<button
							type="button"
							onclick={() => entry.mfaEnabled = !entry.mfaEnabled}
							class="w-11 h-6 rounded-full transition-colors relative {entry.mfaEnabled ? 'bg-[var(--fv-cyan)]' : 'bg-white/10'}"
						>
							<div class="absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform {entry.mfaEnabled ? 'translate-x-[22px]' : 'translate-x-0.5'}"></div>
						</button>
					</div>

					{#if entry.mfaEnabled}
						<div>
							<label for="mfa-secret" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.mfa_secret')}</label>
							<input id="mfa-secret" type="text" bind:value={entry.mfaSecret} placeholder="JBSWY3DPEHPK3PXP" class="{inputClass} font-mono" />
						</div>
					{/if}
				{/if}
			</div>

			<!-- Error -->
			{#if error}
				<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 fv-shake">
					<p class="text-sm text-[var(--fv-danger)] flex items-center gap-2">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
						{error}
					</p>
				</div>
			{/if}

			<!-- Submit -->
			<div class="flex gap-3">
				<button type="button" onclick={() => goto('/vault')} class="fv-btn fv-btn-ghost flex-1 !py-3.5 !rounded-2xl">{t('add.cancel')}</button>
				<button type="submit" disabled={loading} class="add-submit-btn flex-1 py-3.5 rounded-2xl text-white font-bold text-sm flex items-center justify-center gap-2 transition-all duration-250 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
					{#if loading}
						<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
						{t('add.saving_alt')}
					{:else}
						{editId ? t('add.save') : t('add.add_to_vault')}
					{/if}
				</button>
			</div>
		</form>
	{/if}
</div>

{#snippet passwordField()}
	<div>
		<label for="password-field" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-3">{t('add.password')}</label>
		<div class="relative">
			<input
				id="password-field"
				type={showPassword ? 'text' : 'password'}
				bind:value={entry.password}
				placeholder="••••••••••••"
				class="w-full px-4 py-3 pr-28 rounded-xl bg-white/5 border border-white/10 text-white placeholder-[var(--fv-ash)] text-sm font-mono focus:outline-none focus:border-[var(--fv-cyan)]/50 focus:ring-1 focus:ring-[var(--fv-cyan)]/30 transition-all"
			/>
			<div class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1 z-10">
				<button type="button" onclick={(e) => { e.stopPropagation(); showPassword = !showPassword; }} class="p-2 rounded-lg hover:bg-white/10 text-[var(--fv-smoke)] cursor-pointer" title={t('add.show_password')}>
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
				</button>
				<button type="button" onclick={(e) => { e.stopPropagation(); copyGeneratedPassword(); }} class="p-2 rounded-lg hover:bg-white/10 text-[var(--fv-smoke)] cursor-pointer" title={t('add.copy_password')}>
					{#if copiedGenerated}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					{:else}
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
					{/if}
				</button>
				<button type="button" onclick={(e) => { e.stopPropagation(); showGenerator = !showGenerator; }} class="p-2 rounded-lg transition-all duration-200 hover:bg-white/10 active:scale-90 cursor-pointer" style="color: {showGenerator ? 'var(--fv-cyan)' : 'var(--fv-smoke)'};" title={t('add.password_generator')}>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
				</button>
			</div>
		</div>

		<!-- Strength bar -->
		{#if entry.password}
			<div class="mt-3 flex items-center gap-3">
				<div class="flex-1 h-2.5 rounded-full overflow-hidden bg-white/10">
					<div class="h-full rounded-full transition-all duration-500" style="width: {strength.score}%; background: {strength.color}; box-shadow: 0 0 12px {strength.color};"></div>
				</div>
				<span class="text-xs font-bold transition-colors duration-300 min-w-[60px] text-right" style="color: {strength.color};">{strength.label}</span>
			</div>
		{/if}

		<!-- Password generator -->
		{#if showGenerator}
			<div class="mt-4 p-5 rounded-2xl border border-white/[0.08] space-y-4" style="background: rgba(255,255,255,0.03);">
				<div class="flex items-center gap-2 mb-1">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
					<span class="text-xs font-semibold text-white/80 uppercase tracking-wider">{t('add.generator')}</span>
				</div>

				<!-- Mode toggle (segmented control) -->
				<div class="flex rounded-xl p-1 bg-white/[0.05]">
					<button type="button" onclick={() => genMode = 'password'}
						class="flex-1 text-xs py-2.5 rounded-lg font-semibold transition-all duration-200 {genMode === 'password' ? 'bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] text-white shadow-md' : 'text-[var(--fv-smoke)] hover:text-white'}"
					>{t('add.gen_password')}</button>
					<button type="button" onclick={() => genMode = 'passphrase'}
						class="flex-1 text-xs py-2.5 rounded-lg font-semibold transition-all duration-200 {genMode === 'passphrase' ? 'bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] text-white shadow-md' : 'text-[var(--fv-smoke)] hover:text-white'}"
					>{t('add.gen_passphrase')}</button>
				</div>

				{#if genMode === 'password'}
					<!-- Length slider -->
					<div>
						<div class="flex items-center justify-between mb-2">
							<span class="text-xs text-white/60">{t('add.gen_length')}</span>
							<span class="text-sm font-bold text-[var(--fv-cyan)] tabular-nums" style="min-width: 28px; text-align: right;">{genLength}</span>
						</div>
						<input type="range" min="8" max="64" bind:value={genLength} class="gen-slider w-full" />
					</div>

					<!-- Character options as pills -->
					<div class="flex flex-wrap gap-2">
						{#each [
							{ label: 'ABC', desc: t('add.gen_uppercase'), checked: genUppercase, toggle: () => genUppercase = !genUppercase },
							{ label: 'abc', desc: t('add.gen_lowercase'), checked: genLowercase, toggle: () => genLowercase = !genLowercase },
							{ label: '123', desc: t('add.gen_digits'), checked: genDigits, toggle: () => genDigits = !genDigits },
							{ label: '#$&', desc: t('add.gen_symbols'), checked: genSymbols, toggle: () => genSymbols = !genSymbols }
						] as opt}
							<button type="button" onclick={opt.toggle}
								class="gen-pill px-3 py-2 rounded-xl text-xs font-medium transition-all duration-200 border {opt.checked ? 'gen-pill-active' : 'gen-pill-inactive'}"
							>
								<span class="font-bold">{opt.label}</span>
								<span class="ml-1 opacity-70">{opt.desc}</span>
							</button>
						{/each}
					</div>
				{:else}
					<!-- Passphrase options -->
					<div>
						<div class="flex items-center justify-between mb-2">
							<span class="text-xs text-white/60">{t('add.gen_word_count')}</span>
							<span class="text-sm font-bold text-[var(--fv-cyan)]">{genWordCount}</span>
						</div>
						<input type="range" min="3" max="10" bind:value={genWordCount} class="gen-slider w-full" />
					</div>
					<div class="flex gap-3">
						<div class="flex-1">
							<span class="block text-[10px] text-white/50 mb-1.5 uppercase tracking-wider">{t('add.gen_separator')}</span>
							<div class="flex gap-1.5">
								{#each [{v: '-', l: '\u2014'}, {v: '.', l: '\u00b7'}, {v: '_', l: '_'}, {v: ' ', l: '\u2423'}] as sep}
									<button type="button" onclick={() => genSeparator = sep.v}
										class="gen-pill w-9 h-9 rounded-lg text-sm font-mono flex items-center justify-center transition-all border {genSeparator === sep.v ? 'gen-pill-active' : 'gen-pill-inactive'}"
									>{sep.l}</button>
								{/each}
							</div>
						</div>
						<button type="button" onclick={() => genCapitalize = !genCapitalize}
							class="gen-pill self-end mb-0.5 px-3 py-2 rounded-xl text-xs font-medium transition-all border {genCapitalize ? 'gen-pill-active' : 'gen-pill-inactive'}"
						>{t('add.gen_capitalize')}</button>
					</div>
				{/if}

				<!-- Generate button -->
				<button type="button" onclick={handleGeneratePassword}
					class="gen-btn w-full py-3 rounded-xl text-sm font-bold transition-all duration-200 hover:brightness-110 active:scale-[0.98] flex items-center justify-center gap-2"
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
					{t('add.generate')}
				</button>
			</div>
		{/if}
	</div>
{/snippet}

<style>
	/* Form wrapper max-width */
	.add-form-wrapper {
		max-width: 640px;
		margin: 0 auto;
	}

	/* Glass card for form sections */
	.add-glass-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.015));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255,255,255,0.06);
		border-radius: 20px;
	}

	/* Form inputs premium */
	:global(.add-form-input) {
		background: rgba(255,255,255,0.04) !important;
		border: 1px solid rgba(255,255,255,0.08) !important;
	}
	:global(.add-form-input:focus) {
		border-color: rgba(0, 212, 255, 0.4) !important;
		box-shadow: 0 0 0 3px rgba(0,212,255,0.12) !important;
		background: rgba(255,255,255,0.06) !important;
	}

	/* Category cards */
	.category-card {
		cursor: pointer;
		border: 1px solid transparent;
	}
	.category-card-default {
		background: rgba(255,255,255,0.04);
		border-color: rgba(255,255,255,0.04);
	}
	.category-card-default:hover {
		background: rgba(255,255,255,0.08);
		border-color: rgba(255,255,255,0.08);
		transform: scale(1.03);
	}
	.category-card-selected {
		background: rgba(0, 212, 255, 0.08);
		border-color: rgba(0, 212, 255, 0.3);
		box-shadow: 0 0 16px rgba(0, 212, 255, 0.08);
		transform: scale(1.05);
	}

	/* Submit button gradient with shimmer */
	.add-submit-btn {
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		position: relative;
		overflow: hidden;
		border: none;
		cursor: pointer;
	}
	.add-submit-btn::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.12) 50%, transparent 60%);
		background-size: 200% 100%;
		animation: addShimmer 3s ease-in-out infinite;
	}
	@keyframes addShimmer {
		0% { background-position: 200% 0; }
		100% { background-position: -200% 0; }
	}
	.add-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 30px rgba(0, 212, 255, 0.3);
	}

	/* Generator slider */
	.gen-slider {
		height: 6px;
		border-radius: 9999px;
		appearance: none;
		-webkit-appearance: none;
		background: rgba(255,255,255,0.1);
		cursor: pointer;
		accent-color: var(--fv-cyan);
	}
	.gen-slider::-webkit-slider-thumb {
		-webkit-appearance: none;
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: var(--fv-cyan);
		border: 2px solid var(--fv-abyss);
		box-shadow: 0 0 8px rgba(0, 212, 255, 0.4);
		cursor: pointer;
	}
	.gen-slider::-moz-range-thumb {
		width: 18px;
		height: 18px;
		border-radius: 50%;
		background: var(--fv-cyan);
		border: 2px solid var(--fv-abyss);
		box-shadow: 0 0 8px rgba(0, 212, 255, 0.4);
		cursor: pointer;
	}

	/* Generator pill buttons */
	.gen-pill-active {
		background: rgba(0, 212, 255, 0.12);
		border-color: rgba(0, 212, 255, 0.4);
		color: var(--fv-cyan);
	}
	.gen-pill-inactive {
		background: transparent;
		border-color: rgba(255,255,255,0.08);
		color: var(--fv-smoke);
	}
	.gen-pill-inactive:hover {
		border-color: rgba(255,255,255,0.15);
		color: white;
	}

	/* Generate button gradient */
	.gen-btn {
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		color: white;
	}
	.gen-btn:hover {
		box-shadow: 0 4px 20px rgba(0, 212, 255, 0.3);
	}
</style>
