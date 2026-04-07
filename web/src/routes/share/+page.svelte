<script lang="ts">
	import { page } from '$app/stores';
	import { hexToBytes } from '$lib/crypto';

	let entry: Record<string, any> | null = $state(null);
	let error = $state('');
	let loading = $state(true);
	let expired = $state(false);

	const IV_LENGTH = 12;
	const AES_KEY_BITS = 256;

	async function decryptSharedEntry(dataHex: string, keyHex: string): Promise<Record<string, any>> {
		if (typeof globalThis.crypto?.subtle === 'undefined') {
			throw new Error('Web Crypto API non disponible. Utilise HTTPS ou localhost.');
		}

		const raw = hexToBytes(dataHex);
		const keyBytes = hexToBytes(keyHex);

		const iv = raw.slice(0, IV_LENGTH);
		const ciphertext = raw.slice(IV_LENGTH);

		const key = await crypto.subtle.importKey(
			'raw',
			keyBytes,
			{ name: 'AES-GCM', length: AES_KEY_BITS },
			false,
			['decrypt']
		);

		const plaintext = await crypto.subtle.decrypt(
			{ name: 'AES-GCM', iv },
			key,
			ciphertext
		);

		const dec = new TextDecoder();
		return JSON.parse(dec.decode(plaintext));
	}

	$effect(() => {
		const data = $page.url.searchParams.get('data');
		const expiresAt = $page.url.searchParams.get('expires');
		const keyHex = $page.url.hash.slice(1); // Remove leading #

		if (!data || !keyHex) {
			error = 'Lien de partage invalide. Paramètres manquants.';
			loading = false;
			return;
		}

		if (expiresAt) {
			const expiryDate = new Date(expiresAt);
			if (expiryDate < new Date()) {
				expired = true;
				loading = false;
				return;
			}
		}

		decryptSharedEntry(data, keyHex)
			.then((result) => {
				entry = result;
				loading = false;
			})
			.catch((e) => {
				console.error('Decryption failed:', e);
				error = 'Impossible de déchiffrer. Le lien est peut-être invalide ou corrompu.';
				loading = false;
			});
	});

	const displayFields: { key: string; label: string }[] = [
		{ key: 'title', label: 'Titre' },
		{ key: 'username', label: 'Identifiant' },
		{ key: 'password', label: 'Mot de passe' },
		{ key: 'website', label: 'Site web' },
		{ key: 'notes', label: 'Notes' },
		{ key: 'networkName', label: 'Nom du réseau' },
		{ key: 'securityType', label: 'Type de sécurité' },
		{ key: 'licenseKey', label: 'Clé de licence' },
		{ key: 'softwareName', label: 'Logiciel' },
		{ key: 'iban', label: 'IBAN' },
		{ key: 'bic', label: 'BIC / SWIFT' },
		{ key: 'bankName', label: 'Banque' }
	];

	let copiedField = $state('');

	async function copyToClipboard(value: string, key: string) {
		try {
			await navigator.clipboard.writeText(value);
			copiedField = key;
			setTimeout(() => copiedField = '', 2000);
		} catch {}
	}

	const expiresAt = $derived($page.url.searchParams.get('expires'));
	const expiryLabel = $derived(expiresAt ? new Date(expiresAt).toLocaleString('fr-FR') : null);
</script>

<svelte:head>
	<title>Partage sécurisé — FyxxVault</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center px-6 py-20">
	<!-- Background orbs -->
	<div class="fixed inset-0 overflow-hidden pointer-events-none">
		<div class="absolute top-1/3 left-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-cyan)] opacity-[0.05] blur-[120px]"></div>
		<div class="absolute bottom-1/3 right-1/4 w-[400px] h-[400px] rounded-full bg-[var(--fv-violet)] opacity-[0.05] blur-[120px]"></div>
	</div>

	<div class="relative z-10 w-full max-w-lg">
		<!-- Logo -->
		<div class="text-center mb-8">
			<div class="inline-flex items-center gap-3 mb-4">
				<div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center shadow-lg shadow-[var(--fv-cyan)]/20">
					<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
						<rect x="3" y="11" width="18" height="11" rx="2"/>
						<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
					</svg>
				</div>
			</div>
			<h1 class="text-2xl font-bold text-white">Partage sécurisé</h1>
			<p class="text-sm text-[var(--fv-smoke)] mt-2">Cet élément a été partagé de manière chiffrée via FyxxVault.</p>
		</div>

		{#if loading}
			<div class="fv-glass p-8 text-center">
				<div class="w-10 h-10 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin mx-auto mb-4"></div>
				<p class="text-sm text-[var(--fv-smoke)]">Déchiffrement en cours...</p>
			</div>
		{:else if expired}
			<div class="fv-glass p-8 text-center">
				<div class="w-16 h-16 rounded-full bg-[var(--fv-danger)]/10 flex items-center justify-center mx-auto mb-4">
					<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
				</div>
				<h2 class="text-lg font-bold text-white mb-2">Lien expiré</h2>
				<p class="text-sm text-[var(--fv-smoke)]">Ce lien de partage a expiré et n'est plus accessible.</p>
			</div>
		{:else if error}
			<div class="fv-glass p-8 text-center">
				<div class="w-16 h-16 rounded-full bg-[var(--fv-danger)]/10 flex items-center justify-center mx-auto mb-4">
					<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-danger)" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
				</div>
				<h2 class="text-lg font-bold text-white mb-2">Erreur</h2>
				<p class="text-sm text-[var(--fv-danger)]">{error}</p>
			</div>
		{:else if entry}
			<div class="fv-glass p-6 space-y-4">
				{#if expiryLabel}
					<div class="flex items-center gap-2 px-3 py-2 rounded-lg bg-[var(--fv-gold)]/10 border border-[var(--fv-gold)]/20">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
						<span class="text-xs text-[var(--fv-gold)]">Expire le {expiryLabel}</span>
					</div>
				{/if}

				{#each displayFields as field}
					{#if entry[field.key]}
						<div class="group">
							<label class="block text-[10px] font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-1">{field.label}</label>
							<div class="flex items-center gap-2">
								<span class="flex-1 px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm font-mono break-all select-all">
									{field.key === 'password' ? '••••••••••••' : entry[field.key]}
								</span>
								<button
									onclick={() => copyToClipboard(entry![field.key], field.key)}
									class="p-2.5 rounded-xl hover:bg-white/10 text-[var(--fv-smoke)] transition-colors shrink-0"
									title="Copier"
								>
									{#if copiedField === field.key}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
									{:else}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
									{/if}
								</button>
							</div>
						</div>
					{/if}
				{/each}
			</div>

			<div class="text-center mt-6">
				<p class="text-[10px] text-[var(--fv-ash)]">Chiffrement AES-256-GCM de bout en bout. La clé de déchiffrement ne transite jamais par nos serveurs.</p>
			</div>
		{/if}
	</div>
</div>
