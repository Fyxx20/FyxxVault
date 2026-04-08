<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';
	import { passwordStrength } from '$lib/crypto';
	import { login, initAuth, getAuthState } from '$lib/stores/auth.svelte';

	let step = $state(0);
	let transitioning = $state(false);
	let direction = $state<'next' | 'prev'>('next');
	let password = $state('');
	let confirmPassword = $state('');
	let loading = $state(false);
	let error = $state('');
	let errorKey = $state(0);
	let setupSuccess = $state(false);
	let mounted = $state(false);

	const requirements = $derived([
		{ label: '12 caracteres minimum', met: password.length >= 12 },
		{ label: '1 majuscule', met: /[A-Z]/.test(password) },
		{ label: '1 chiffre', met: /[0-9]/.test(password) },
		{ label: '1 caractere special', met: /[!@#$%^&*()\-_=+\[\]{}|;:,.<>?/\\]/.test(password) }
	]);
	const allRequirementsMet = $derived(requirements.every(r => r.met));
	const strength = $derived(password.length > 0 ? passwordStrength(password) : null);

	const TOTAL_SLIDES = 5; // 0-4: slides, then 5 = setup form

	const slides = [
		{
			icon: 'lock',
			badge: null,
			title: 'Bienvenue sur FyxxVault',
			subtitle: 'Ton gestionnaire de mots de passe. Local. Prive. Inviolable.',
			features: null,
			visual: 'logo'
		},
		{
			icon: 'cpu',
			badge: '100% LOCAL',
			title: 'Tes donnees restent chez toi',
			subtitle: 'Zero serveur. Zero cloud. Tout est stocke sur ta machine, chiffre, et inaccessible — meme pour nous.',
			features: [
				{ icon: 'hdd', text: 'Base de donnees locale SQLite' },
				{ icon: 'wifi-off', text: 'Aucune connexion sortante' },
				{ icon: 'user', text: 'Un seul utilisateur : toi' }
			],
			visual: 'local'
		},
		{
			icon: 'shield',
			badge: 'ZERO-KNOWLEDGE',
			title: 'Chiffrement de niveau militaire',
			subtitle: 'AES-256-GCM + PBKDF2 210 000 iterations. Meme si quelqu\'un accede a ta machine, sans ton mot de passe maitre il ne verra que du bruit.',
			features: [
				{ icon: 'key', text: 'Cle de chiffrement derivee de ton mot de passe' },
				{ icon: 'eye-off', text: 'Jamais stocke en clair, nulle part' },
				{ icon: 'zap', text: 'Dechiffrement uniquement en memoire' }
			],
			visual: 'encryption'
		},
		{
			icon: 'globe',
			badge: 'PORT SECURISE',
			title: 'Meme sur le reseau, t\'es safe',
			subtitle: 'Quelqu\'un scanne ton port 3000 ? Il tombe sur un mur. Sans ton mot de passe maitre, les donnees sont du chiffre pur — illisible, inexploitable.',
			features: [
				{ icon: 'lock', text: 'Donnees chiffrees cote client avant stockage' },
				{ icon: 'server', text: 'L\'API ne retourne que des blobs chiffres' },
				{ icon: 'shield-check', text: 'Headers de securite (HSTS, CSP, X-Frame)' }
			],
			visual: 'network'
		},
		{
			icon: 'key',
			badge: 'DERNIERE ETAPE',
			title: 'Un seul mot de passe a retenir',
			subtitle: 'Ton mot de passe maitre est la seule cle qui deverrouille tout. Choisis-le bien — personne ne pourra le recuperer pour toi.',
			features: null,
			visual: 'master'
		}
	];

	onMount(async () => {
		await initAuth();
		const auth = getAuthState();
		if (auth.isAuthenticated) {
			goto('/vault/unlock');
			return;
		}
		// Check if user already exists
		try {
			const res = await fetch('/api/status');
			const data = await res.json();
			if (data.hasUser) {
				goto('/vault/unlock');
				return;
			}
		} catch {}
		mounted = true;
	});

	function nextSlide() {
		if (step >= TOTAL_SLIDES) return;
		direction = 'next';
		transitioning = true;
		setTimeout(() => {
			step++;
			transitioning = false;
		}, 300);
	}

	function prevSlide() {
		if (step <= 0) return;
		direction = 'prev';
		transitioning = true;
		setTimeout(() => {
			step--;
			transitioning = false;
		}, 300);
	}

	function goToSetup() {
		direction = 'next';
		transitioning = true;
		setTimeout(() => {
			step = TOTAL_SLIDES;
			transitioning = false;
		}, 300);
	}

	function bufToHex(buf: ArrayBuffer | Uint8Array): string {
		const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
		return Array.from(bytes).map(b => b.toString(16).padStart(2, '0')).join('');
	}

	async function handleSetup() {
		error = '';
		if (!allRequirementsMet) { error = 'Le mot de passe ne respecte pas les exigences.'; errorKey++; return; }
		if (password !== confirmPassword) { error = 'Les mots de passe ne correspondent pas.'; errorKey++; return; }

		loading = true;

		try {
			const enc = new TextEncoder();
			const keyMaterial = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);

			const vekSalt = crypto.getRandomValues(new Uint8Array(16));
			const vekIv = crypto.getRandomValues(new Uint8Array(12));

			const vek = await crypto.subtle.deriveKey(
				{ name: 'PBKDF2', salt: vekSalt, iterations: 210000, hash: 'SHA-256' },
				keyMaterial,
				{ name: 'AES-GCM', length: 256 },
				true,
				['encrypt', 'decrypt']
			);

			const rawVek = await crypto.subtle.exportKey('raw', vek);
			const encryptedVek = await crypto.subtle.encrypt({ name: 'AES-GCM', iv: vekIv }, vek, rawVek);

			const res = await fetch('/api/setup', {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({
					wrapped_vek: bufToHex(encryptedVek),
					vek_salt: bufToHex(vekSalt),
					vek_iv: bufToHex(vekIv),
					password
				})
			});

			if (!res.ok) {
				const data = await res.json().catch(() => ({}));
				error = data.error || `Erreur ${res.status}`;
				errorKey++;
				return;
			}

			// Auto-login
			setupSuccess = true;
			setTimeout(async () => {
				const result = await login('local@fyxxvault', password);
				if (result.success) {
					goto('/vault');
				} else {
					goto('/vault/unlock');
				}
			}, 1500);

		} catch (e: any) {
			error = e.message || 'Erreur inattendue.';
			errorKey++;
		} finally {
			loading = false;
		}
	}
</script>

<svelte:head>
	<title>Configuration — FyxxVault</title>
</svelte:head>

{#if !mounted}
	<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center">
		<div class="w-10 h-10 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin"></div>
	</div>
{:else}
	<div class="setup-page min-h-screen flex flex-col items-center justify-center px-6 py-12 relative overflow-hidden">
		<!-- Animated background -->
		<div class="setup-bg-mesh"></div>
		<div class="fixed inset-0 overflow-hidden pointer-events-none">
			<div class="setup-orb setup-orb-1"></div>
			<div class="setup-orb setup-orb-2"></div>
			<div class="setup-orb setup-orb-3"></div>
		</div>

		<!-- Floating particles -->
		<div class="particles-container">
			{#each Array(20) as _, i}
				<div class="particle" style="--delay: {i * 0.5}s; --x: {Math.random() * 100}%; --duration: {8 + Math.random() * 12}s; --size: {2 + Math.random() * 3}px;"></div>
			{/each}
		</div>

		<div class="relative z-10 w-full max-w-lg">
			{#if setupSuccess}
				<!-- Success state -->
				<div class="text-center fv-animate-in">
					<div class="success-ring w-24 h-24 rounded-full flex items-center justify-center mx-auto mb-6">
						<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5">
							<polyline points="20 6 9 17 4 12" class="check-draw"/>
						</svg>
					</div>
					<h1 class="text-3xl font-extrabold text-white mb-3">Coffre-fort cree !</h1>
					<p class="text-[var(--fv-smoke)] text-sm">Redirection vers ton coffre...</p>
					<div class="mt-6 w-32 h-1 rounded-full bg-white/10 mx-auto overflow-hidden">
						<div class="h-full bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)] rounded-full success-bar"></div>
					</div>
				</div>
			{:else if step < TOTAL_SLIDES}
				<!-- Onboarding slides -->
				<div class="slide-container {transitioning ? (direction === 'next' ? 'slide-out-left' : 'slide-out-right') : 'slide-in'}">
					<!-- Progress dots -->
					<div class="flex items-center justify-center gap-2 mb-8">
						{#each slides as _, i}
							<button
								onclick={() => { direction = i > step ? 'next' : 'prev'; transitioning = true; setTimeout(() => { step = i; transitioning = false; }, 300); }}
								class="transition-all duration-300 rounded-full {i === step ? 'w-8 h-2 bg-gradient-to-r from-[var(--fv-cyan)] to-[var(--fv-violet)]' : i < step ? 'w-2 h-2 bg-[var(--fv-cyan)]/50' : 'w-2 h-2 bg-white/15'}"
								aria-label="Slide {i + 1}"
							></button>
						{/each}
					</div>

					<!-- Slide visual -->
					<div class="flex justify-center mb-8">
						{#if slides[step].visual === 'logo'}
							<div class="onboarding-logo w-28 h-28 rounded-3xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center">
								<svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="1.5">
									<rect x="3" y="11" width="18" height="11" rx="2"/>
									<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
									<circle cx="12" cy="16" r="1"/>
								</svg>
							</div>
						{:else if slides[step].visual === 'local'}
							<div class="visual-card">
								<div class="visual-icon-stack">
									<div class="visual-icon-ring">
										<svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="1.5">
											<rect x="2" y="2" width="20" height="8" rx="2" ry="2"/><path d="M2 14h20"/><rect x="2" y="14" width="20" height="8" rx="2" ry="2"/>
											<circle cx="6" cy="6" r="1" fill="var(--fv-cyan)"/><circle cx="6" cy="18" r="1" fill="var(--fv-cyan)"/>
										</svg>
									</div>
									<div class="visual-badge">LOCALHOST</div>
								</div>
							</div>
						{:else if slides[step].visual === 'encryption'}
							<div class="visual-card">
								<div class="encryption-visual">
									<div class="cipher-row"><span class="cipher-text">4f 8a 2b c1 9e 7d...</span></div>
									<div class="cipher-row delay-1"><span class="cipher-text">a3 f7 01 b5 6c 22...</span></div>
									<div class="cipher-row delay-2"><span class="cipher-text">e9 3d 8f 0a c4 71...</span></div>
									<div class="cipher-lock">
										<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2">
											<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>
										</svg>
									</div>
								</div>
							</div>
						{:else if slides[step].visual === 'network'}
							<div class="visual-card">
								<div class="network-visual">
									<div class="port-badge">:3000</div>
									<div class="firewall-wall"></div>
									<div class="shield-icon">
										<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2">
											<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
											<polyline points="9 12 11 14 15 10" stroke="var(--fv-success)" stroke-width="2"/>
										</svg>
									</div>
								</div>
							</div>
						{:else if slides[step].visual === 'master'}
							<div class="visual-card">
								<div class="key-visual">
									<svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="1.5">
										<path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
									</svg>
								</div>
							</div>
						{/if}
					</div>

					<!-- Badge -->
					{#if slides[step].badge}
						<div class="flex justify-center mb-4">
							<span class="onboarding-badge">{slides[step].badge}</span>
						</div>
					{/if}

					<!-- Title & subtitle -->
					<div class="text-center mb-8">
						<h1 class="text-2xl sm:text-3xl font-extrabold text-white mb-3 leading-tight">{slides[step].title}</h1>
						<p class="text-sm sm:text-base text-[var(--fv-smoke)] leading-relaxed max-w-md mx-auto">{slides[step].subtitle}</p>
					</div>

					<!-- Features list -->
					{#if slides[step].features}
						<div class="space-y-3 mb-8 max-w-sm mx-auto">
							{#each slides[step].features as feat, i}
								<div class="feature-item fv-animate-in" style="animation-delay: {(i + 1) * 100}ms;">
									<div class="feature-icon">
										{#if feat.icon === 'hdd'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><circle cx="6" cy="6" r="1" fill="currentColor"/><circle cx="6" cy="18" r="1" fill="currentColor"/></svg>
										{:else if feat.icon === 'wifi-off'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="1" y1="1" x2="23" y2="23"/><path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/><path d="M10.71 5.05A16 16 0 0 1 22.56 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg>
										{:else if feat.icon === 'user'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>
										{:else if feat.icon === 'key'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
										{:else if feat.icon === 'eye-off'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
										{:else if feat.icon === 'zap'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>
										{:else if feat.icon === 'lock'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
										{:else if feat.icon === 'server'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="2" y="2" width="20" height="8" rx="2"/><rect x="2" y="14" width="20" height="8" rx="2"/><circle cx="6" cy="6" r="1" fill="currentColor"/><circle cx="6" cy="18" r="1" fill="currentColor"/></svg>
										{:else if feat.icon === 'shield-check'}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><polyline points="9 12 11 14 15 10"/></svg>
										{/if}
									</div>
									<span class="text-sm text-[var(--fv-mist)]">{feat.text}</span>
								</div>
							{/each}
						</div>
					{/if}

					<!-- Navigation buttons -->
					<div class="flex items-center justify-center gap-3">
						{#if step > 0}
							<button onclick={prevSlide} class="nav-btn nav-btn-ghost">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
								Retour
							</button>
						{/if}

						{#if step < TOTAL_SLIDES - 1}
							<button onclick={nextSlide} class="nav-btn nav-btn-primary">
								Suivant
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M5 12h14"/><polyline points="12 5 19 12 12 19"/></svg>
							</button>
						{:else}
							<button onclick={goToSetup} class="nav-btn nav-btn-gold">
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
								Creer mon mot de passe
							</button>
						{/if}
					</div>

					<!-- Skip link -->
					{#if step < TOTAL_SLIDES - 1}
						<button onclick={goToSetup} class="block mx-auto mt-4 text-xs text-[var(--fv-ash)] hover:text-[var(--fv-smoke)] transition-colors">
							Passer l'introduction
						</button>
					{/if}
				</div>
			{:else}
				<!-- Setup form: Master password creation -->
				<div class="slide-container {transitioning ? 'slide-out-left' : 'slide-in'}">
					<div class="text-center mb-8 fv-animate-in">
						<div class="w-16 h-16 rounded-2xl bg-gradient-to-br from-[var(--fv-gold)] to-[var(--fv-gold-light)] flex items-center justify-center mx-auto mb-4 setup-key-icon">
							<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#1a1a2e" stroke-width="2">
								<path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/>
							</svg>
						</div>
						<h1 class="text-2xl font-extrabold text-white">Cree ton mot de passe maitre</h1>
						<p class="text-sm text-[var(--fv-smoke)] mt-2">C'est la seule cle de ton coffre. Pas d'email, pas de compte — juste toi et ton mot de passe.</p>
					</div>

					<div class="setup-card p-8 fv-animate-in" style="animation-delay: 100ms;">
						<!-- Tags -->
						<div class="flex items-center justify-center gap-2 mb-6">
							<span class="px-3 py-1 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-[10px] font-bold">AES-256</span>
							<span class="px-3 py-1 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet)] text-[10px] font-bold">PBKDF2</span>
							<span class="px-3 py-1 rounded-full bg-[var(--fv-success)]/10 text-[var(--fv-success)] text-[10px] font-bold">LOCAL</span>
						</div>

						<form onsubmit={(e: SubmitEvent) => { e.preventDefault(); handleSetup(); }} class="space-y-4">
							<!-- Password -->
							<div>
								<label for="password" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Mot de passe maitre</label>
								<input
									id="password"
									type="password"
									bind:value={password}
									placeholder="••••••••••••"
									autofocus
									class="setup-input w-full px-4 py-4 rounded-2xl text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none transition-all duration-300"
								/>
							</div>

							<!-- Strength bar -->
							{#if strength}
								<div class="flex items-center gap-2">
									<div class="flex-1 h-2 rounded-full bg-white/5 overflow-hidden">
										<div class="h-full rounded-full transition-all duration-500" style="width: {strength.score}%; background: {strength.color};"></div>
									</div>
									<span class="text-[10px] font-semibold" style="color: {strength.color};">{strength.label}</span>
								</div>
							{/if}

							<!-- Requirements -->
							{#if password.length > 0}
								<div class="p-3 rounded-xl bg-[var(--fv-abyss)]/60 space-y-1.5">
									{#each requirements as req}
										<div class="flex items-center gap-2 text-xs">
											<div class="w-4 h-4 rounded-full flex items-center justify-center {req.met ? 'bg-[var(--fv-success)]/20' : 'bg-white/5'}">
												{#if req.met}
													<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
												{:else}
													<div class="w-1.5 h-1.5 rounded-full bg-[var(--fv-ash)]"></div>
												{/if}
											</div>
											<span class="{req.met ? 'text-[var(--fv-success)]' : 'text-[var(--fv-smoke)]'}">{req.label}</span>
										</div>
									{/each}
								</div>
							{/if}

							<!-- Confirm Password -->
							<div>
								<label for="confirm" class="block text-xs font-semibold text-[var(--fv-smoke)] uppercase tracking-wider mb-2">Confirmer</label>
								<div class="relative">
									<input
										id="confirm"
										type="password"
										bind:value={confirmPassword}
										placeholder="••••••••••••"
										class="setup-input w-full px-4 py-4 rounded-2xl text-white placeholder-[var(--fv-ash)] text-sm focus:outline-none transition-all duration-300
											{confirmPassword && confirmPassword === password ? '!border-[var(--fv-success)]/40' : ''}"
									/>
									{#if confirmPassword && confirmPassword === password}
										<div class="absolute right-3 top-1/2 -translate-y-1/2 text-[var(--fv-success)]">
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
										</div>
									{/if}
								</div>
							</div>

							<!-- Warning -->
							<div class="p-3 rounded-xl bg-[var(--fv-warning)]/5 border border-[var(--fv-warning)]/15">
								<p class="text-xs text-[var(--fv-warning)] flex items-start gap-2">
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="mt-0.5 shrink-0"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
									<span>Si tu oublies ce mot de passe, tes donnees seront perdues a jamais. Aucune recuperation possible.</span>
								</p>
							</div>

							<!-- Error -->
							{#if error}
								{#key errorKey}
									<div class="p-3 rounded-xl bg-[var(--fv-danger)]/10 border border-[var(--fv-danger)]/20 fv-shake">
										<p class="text-sm text-[var(--fv-danger)] flex items-center gap-2">
											<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
											{error}
										</p>
									</div>
								{/key}
							{/if}

							<!-- Submit -->
							<button type="submit" disabled={loading} class="setup-submit-btn w-full py-4 rounded-2xl text-white font-bold text-sm flex items-center justify-center gap-2 {loading ? 'opacity-60 cursor-not-allowed' : ''}">
								{#if loading}
									<div class="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
									Creation du coffre...
								{:else}
									<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
									Creer mon coffre-fort
								{/if}
							</button>
						</form>

						<!-- Back -->
						<button onclick={prevSlide} class="block mx-auto mt-4 text-xs text-[var(--fv-ash)] hover:text-[var(--fv-smoke)] transition-colors flex items-center gap-1">
							<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5"/><polyline points="12 19 5 12 12 5"/></svg>
							Retour
						</button>
					</div>
				</div>
			{/if}
		</div>

		<!-- Footer -->
		<p class="relative z-10 text-center text-[10px] text-[var(--fv-ash)]/60 mt-8 flex items-center justify-center gap-1.5">
			<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
			Open Source &middot; GPLv3 &middot; Chiffrement AES-256-GCM
		</p>
	</div>
{/if}

<style>
	.setup-page {
		background: var(--fv-abyss);
	}

	/* Background mesh */
	.setup-bg-mesh {
		position: fixed;
		inset: 0;
		background:
			radial-gradient(ellipse 80% 60% at 30% 20%, rgba(0,212,255,0.04), transparent 50%),
			radial-gradient(ellipse 60% 80% at 70% 80%, rgba(138,92,246,0.04), transparent 50%),
			radial-gradient(ellipse 50% 50% at 50% 50%, rgba(255,200,55,0.02), transparent 50%);
		background-size: 200% 200%;
		animation: meshShift 20s ease-in-out infinite alternate;
		pointer-events: none;
	}
	@keyframes meshShift {
		0% { background-position: 0% 0%, 100% 100%, 50% 50%; }
		100% { background-position: 100% 100%, 0% 0%, 50% 50%; }
	}

	/* Orbs */
	.setup-orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(120px);
		pointer-events: none;
	}
	.setup-orb-1 { top: 15%; left: 15%; width: 350px; height: 350px; background: var(--fv-cyan); opacity: 0.05; animation: orbDrift 25s ease-in-out infinite alternate; }
	.setup-orb-2 { bottom: 20%; right: 15%; width: 300px; height: 300px; background: var(--fv-violet); opacity: 0.05; animation: orbDrift 25s ease-in-out infinite alternate-reverse; }
	.setup-orb-3 { top: 50%; left: 50%; width: 200px; height: 200px; background: var(--fv-gold); opacity: 0.03; animation: orbDrift 20s ease-in-out infinite alternate; transform: translate(-50%, -50%); }
	@keyframes orbDrift {
		0% { transform: translate(0, 0); }
		100% { transform: translate(40px, -30px); }
	}

	/* Floating particles */
	.particles-container {
		position: fixed;
		inset: 0;
		pointer-events: none;
		overflow: hidden;
	}
	.particle {
		position: absolute;
		bottom: -10px;
		left: var(--x);
		width: var(--size);
		height: var(--size);
		background: rgba(0, 212, 255, 0.3);
		border-radius: 50%;
		animation: particleRise var(--duration) ease-in-out var(--delay) infinite;
	}
	@keyframes particleRise {
		0% { transform: translateY(0) scale(1); opacity: 0; }
		10% { opacity: 0.6; }
		90% { opacity: 0.1; }
		100% { transform: translateY(-100vh) scale(0.3); opacity: 0; }
	}

	/* Slide transitions */
	.slide-container {
		transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
	}
	.slide-in {
		opacity: 1;
		transform: translateX(0);
	}
	.slide-out-left {
		opacity: 0;
		transform: translateX(-30px);
	}
	.slide-out-right {
		opacity: 0;
		transform: translateX(30px);
	}

	/* Onboarding logo */
	.onboarding-logo {
		box-shadow: 0 0 40px rgba(0, 212, 255, 0.3), 0 0 80px rgba(138, 92, 246, 0.15);
		animation: logoPulse 3s ease-in-out infinite;
	}
	@keyframes logoPulse {
		0%, 100% { box-shadow: 0 0 40px rgba(0, 212, 255, 0.3), 0 0 80px rgba(138, 92, 246, 0.15); transform: scale(1); }
		50% { box-shadow: 0 0 60px rgba(0, 212, 255, 0.4), 0 0 100px rgba(138, 92, 246, 0.2); transform: scale(1.05); }
	}

	/* Onboarding badge */
	.onboarding-badge {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 6px 16px;
		border-radius: 100px;
		background: linear-gradient(135deg, rgba(0,212,255,0.1), rgba(138,92,246,0.1));
		border: 1px solid rgba(0,212,255,0.2);
		color: var(--fv-cyan);
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 1.5px;
	}

	/* Visual cards */
	.visual-card {
		width: 200px;
		height: 120px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255,255,255,0.05), rgba(255,255,255,0.02));
		border: 1px solid rgba(255,255,255,0.08);
		display: flex;
		align-items: center;
		justify-content: center;
		backdrop-filter: blur(12px);
	}

	.visual-icon-stack {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
	}
	.visual-icon-ring {
		width: 56px;
		height: 56px;
		border-radius: 16px;
		background: rgba(0, 212, 255, 0.08);
		border: 1px solid rgba(0, 212, 255, 0.2);
		display: flex;
		align-items: center;
		justify-content: center;
	}
	.visual-badge {
		font-size: 9px;
		font-weight: 800;
		letter-spacing: 2px;
		color: var(--fv-cyan);
		opacity: 0.7;
	}

	/* Encryption visual */
	.encryption-visual {
		position: relative;
		display: flex;
		flex-direction: column;
		gap: 4px;
		padding: 12px;
	}
	.cipher-row {
		overflow: hidden;
	}
	.cipher-text {
		font-family: 'SF Mono', 'Fira Code', monospace;
		font-size: 11px;
		color: var(--fv-cyan);
		opacity: 0.4;
		animation: cipherScroll 4s linear infinite;
	}
	.delay-1 .cipher-text { animation-delay: -1.3s; }
	.delay-2 .cipher-text { animation-delay: -2.6s; }
	@keyframes cipherScroll {
		0% { opacity: 0.2; }
		50% { opacity: 0.5; }
		100% { opacity: 0.2; }
	}
	.cipher-lock {
		position: absolute;
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		width: 40px;
		height: 40px;
		border-radius: 12px;
		background: rgba(10, 16, 30, 0.9);
		border: 1px solid rgba(0, 212, 255, 0.3);
		display: flex;
		align-items: center;
		justify-content: center;
	}

	/* Network visual */
	.network-visual {
		position: relative;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 12px;
		width: 100%;
		height: 100%;
	}
	.port-badge {
		font-family: 'SF Mono', 'Fira Code', monospace;
		font-size: 16px;
		font-weight: 800;
		color: var(--fv-danger);
		opacity: 0.6;
		text-decoration: line-through;
		text-decoration-color: var(--fv-danger);
	}
	.firewall-wall {
		width: 2px;
		height: 50px;
		background: linear-gradient(180deg, transparent, var(--fv-success), transparent);
		opacity: 0.6;
	}
	.shield-icon {
		animation: shieldGlow 2s ease-in-out infinite;
	}
	@keyframes shieldGlow {
		0%, 100% { filter: drop-shadow(0 0 4px rgba(52, 211, 153, 0.3)); }
		50% { filter: drop-shadow(0 0 12px rgba(52, 211, 153, 0.5)); }
	}

	/* Key visual */
	.key-visual {
		animation: keyFloat 3s ease-in-out infinite;
	}
	@keyframes keyFloat {
		0%, 100% { transform: translateY(0) rotate(0deg); }
		50% { transform: translateY(-8px) rotate(5deg); }
	}

	/* Feature items */
	.feature-item {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 10px 14px;
		border-radius: 14px;
		background: rgba(255,255,255,0.03);
		border: 1px solid rgba(255,255,255,0.06);
	}
	.feature-icon {
		width: 32px;
		height: 32px;
		border-radius: 10px;
		background: rgba(0, 212, 255, 0.08);
		color: var(--fv-cyan);
		display: flex;
		align-items: center;
		justify-content: center;
		flex-shrink: 0;
	}

	/* Navigation buttons */
	.nav-btn {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 14px 28px;
		border-radius: 16px;
		font-weight: 700;
		font-size: 14px;
		border: none;
		cursor: pointer;
		transition: all 0.25s ease;
	}
	.nav-btn-primary {
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		color: white;
		position: relative;
		overflow: hidden;
	}
	.nav-btn-primary::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.15) 50%, transparent 60%);
		background-size: 200% 100%;
		animation: shimmer 3s ease-in-out infinite;
	}
	.nav-btn-primary:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(0, 212, 255, 0.3); }

	.nav-btn-gold {
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #1a1a2e;
		position: relative;
		overflow: hidden;
	}
	.nav-btn-gold::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.2) 50%, transparent 60%);
		background-size: 200% 100%;
		animation: shimmer 3s ease-in-out infinite;
	}
	.nav-btn-gold:hover { transform: translateY(-2px); box-shadow: 0 8px 30px rgba(255, 200, 55, 0.3); }

	.nav-btn-ghost {
		background: rgba(255,255,255,0.05);
		color: var(--fv-smoke);
		border: 1px solid rgba(255,255,255,0.1);
	}
	.nav-btn-ghost:hover { background: rgba(255,255,255,0.1); color: white; }

	@keyframes shimmer {
		0% { background-position: 200% 0; }
		100% { background-position: -200% 0; }
	}

	/* Setup card */
	.setup-card {
		background: linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		border: 1px solid rgba(255,255,255,0.08);
		border-radius: 24px;
		box-shadow: 0 16px 64px rgba(0,0,0,0.3);
	}

	.setup-input {
		background: rgba(255,255,255,0.04);
		border: 1px solid rgba(255,255,255,0.1);
	}
	.setup-input:focus {
		border-color: rgba(255, 200, 55, 0.5);
		box-shadow: 0 0 0 3px rgba(255, 200, 55, 0.15), 0 0 24px rgba(255, 200, 55, 0.08);
		background: rgba(255,255,255,0.06);
	}

	.setup-key-icon {
		box-shadow: 0 0 30px rgba(255, 200, 55, 0.3);
		animation: keyIconPulse 3s ease-in-out infinite;
	}
	@keyframes keyIconPulse {
		0%, 100% { box-shadow: 0 0 30px rgba(255, 200, 55, 0.3); transform: scale(1); }
		50% { box-shadow: 0 0 40px rgba(255, 200, 55, 0.4); transform: scale(1.05); }
	}

	.setup-submit-btn {
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #1a1a2e;
		position: relative;
		overflow: hidden;
		transition: all 0.25s ease;
		border: none;
		cursor: pointer;
	}
	.setup-submit-btn::after {
		content: '';
		position: absolute;
		inset: 0;
		background: linear-gradient(105deg, transparent 40%, rgba(255,255,255,0.2) 50%, transparent 60%);
		background-size: 200% 100%;
		animation: shimmer 3s ease-in-out infinite;
	}
	.setup-submit-btn:hover:not(:disabled) {
		transform: translateY(-2px);
		box-shadow: 0 8px 30px rgba(255, 200, 55, 0.3);
	}

	/* Success animation */
	.success-ring {
		background: rgba(52, 211, 153, 0.1);
		border: 2px solid rgba(52, 211, 153, 0.3);
		animation: successPulse 2s ease-in-out infinite;
	}
	@keyframes successPulse {
		0%, 100% { box-shadow: 0 0 0 0 rgba(52, 211, 153, 0.2); }
		50% { box-shadow: 0 0 0 20px rgba(52, 211, 153, 0); }
	}

	.check-draw {
		stroke-dasharray: 30;
		stroke-dashoffset: 30;
		animation: drawCheck 0.6s ease forwards 0.3s;
	}
	@keyframes drawCheck {
		to { stroke-dashoffset: 0; }
	}

	.success-bar {
		animation: successFill 1.5s ease forwards;
	}
	@keyframes successFill {
		from { width: 0; }
		to { width: 100%; }
	}
</style>
