<script lang="ts">
	import { onMount } from 'svelte';
	import Navbar from '$lib/components/landing/Navbar.svelte';

	let mounted = $state(false);
	let heroVisible = $state(false);
	let revealedSections = $state(new Set<string>());
	let openFaq = $state<number | null>(null);

	onMount(() => {
		mounted = true;
		setTimeout(() => heroVisible = true, 150);

		const observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting) {
						const id = entry.target.getAttribute('data-reveal');
						if (id) {
							revealedSections = new Set([...revealedSections, id]);
						}
					}
				});
			},
			{ threshold: 0.1, rootMargin: '0px 0px -60px 0px' }
		);

		document.querySelectorAll('[data-reveal]').forEach((el) => observer.observe(el));

		return () => observer.disconnect();
	});

	function isRevealed(id: string): boolean {
		return revealedSections.has(id);
	}

	function toggleFaq(index: number) {
		openFaq = openFaq === index ? null : index;
	}

	// ---- Data ----

	const features = [
		{
			icon: 'shield',
			title: 'Chiffrement militaire',
			description: 'AES-256-GCM avec derivation de cle PBKDF2. Tes donnees sont illisibles sans ton mot de passe maitre.',
			color: 'var(--fv-cyan)',
		},
		{
			icon: 'zap',
			title: 'AutoFill intelligent',
			description: 'Remplissage automatique dans Safari et toutes tes apps iOS. Un tap et c\'est fait.',
			color: 'var(--fv-violet)',
		},
		{
			icon: 'sync',
			title: 'Sync multi-appareils',
			description: 'Accede a ton coffre sur iPhone, iPad et navigateur. Synchronisation chiffree de bout en bout.',
			color: 'var(--fv-success)',
		},
		{
			icon: 'key',
			title: 'Generateur de mots de passe',
			description: 'Cree des mots de passe forts et uniques en un clic. Personnalise longueur et complexite.',
			color: 'var(--fv-gold)',
		},
		{
			icon: 'eye',
			title: 'Dark Web monitoring',
			description: 'Surveillance automatique HIBP. Tu es alerte si un de tes comptes apparait dans une fuite.',
			color: 'var(--fv-rose)',
		},
		{
			icon: 'lock',
			title: '2FA integre',
			description: 'Codes TOTP integres pour chaque compte. Plus besoin d\'une app separee comme Google Authenticator.',
			color: 'var(--fv-violet-light)',
		},
	];

	const steps = [
		{
			num: '01',
			title: 'Cree ton compte',
			description: 'Inscription en 30 secondes. Choisis un mot de passe maitre fort — c\'est le seul dont tu auras besoin.',
		},
		{
			num: '02',
			title: 'Ajoute tes mots de passe',
			description: 'Importe depuis ton navigateur ou ajoute-les manuellement. FyxxVault chiffre tout localement.',
		},
		{
			num: '03',
			title: 'Accede partout',
			description: 'Retrouve tes identifiants sur tous tes appareils. AutoFill, 2FA, et surveillance en continu.',
		},
	];

	const securityItems = [
		{
			label: 'AES-256-GCM',
			detail: 'Chiffrement de grade militaire utilise par les gouvernements et les banques mondiales.',
			color: 'var(--fv-cyan)',
			icon: 'lock',
		},
		{
			label: 'PBKDF2 210K rounds',
			detail: 'Derivation de cle avec 210 000 iterations. Rend le brute-force virtuellement impossible.',
			color: 'var(--fv-violet)',
			icon: 'cpu',
		},
		{
			label: 'Zero-knowledge',
			detail: 'Ton mot de passe maitre ne quitte jamais ton appareil. Meme nous ne pouvons pas lire tes donnees.',
			color: 'var(--fv-gold)',
			icon: 'eye-off',
		},
		{
			label: 'HIBP monitoring',
			detail: 'Verification continue contre la base Have I Been Pwned. Alerte instantanee en cas de fuite.',
			color: 'var(--fv-rose)',
			icon: 'alert',
		},
	];

	const comparisonFeatures = [
		{ name: 'Prix mensuel', fyxx: '0-4,99 EUR', one: '2,99 USD', bit: '0-3 USD', last: '3 USD' },
		{ name: 'Chiffrement AES-256', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Zero-knowledge', fyxx: true, one: true, bit: true, last: false },
		{ name: 'Open source', fyxx: true, one: false, bit: true, last: false },
		{ name: '2FA/TOTP integre', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Dark Web monitoring', fyxx: true, one: true, bit: false, last: true },
		{ name: 'AutoFill iOS natif', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Emails masques', fyxx: true, one: true, bit: false, last: false },
		{ name: 'Mode panique', fyxx: true, one: false, bit: false, last: false },
		{ name: 'Partage chiffre', fyxx: true, one: true, bit: true, last: true },
	];

	const freeFeatures = [
		'5 comptes maximum',
		'Chiffrement AES-256',
		'Synchronisation cloud',
		'Codes TOTP integres',
		'Generateur de mots de passe',
		'AutoFill iOS natif',
	];

	const proFeatures = [
		'Comptes illimites',
		'Tout du plan gratuit',
		'Surveillance Dark Web',
		'Emails masques illimites',
		'Partage securise',
		'Support prioritaire',
		'Mode panique',
	];

	const testimonials = [
		{
			name: 'Sophie M.',
			role: 'Designer freelance',
			initials: 'SM',
			color: 'var(--fv-cyan)',
			stars: 5,
			text: 'Depuis que j\'utilise FyxxVault, je n\'ai plus a me souvenir de dizaines de mots de passe. L\'AutoFill est magique sur iPhone.',
		},
		{
			name: 'Marc D.',
			role: 'CTO, startup SaaS',
			initials: 'MD',
			color: 'var(--fv-violet)',
			stars: 5,
			text: 'L\'architecture zero-knowledge m\'a convaincu. En tant que dev, je sais que mes donnees sont vraiment en securite.',
		},
		{
			name: 'Julie R.',
			role: 'Responsable IT',
			initials: 'JR',
			color: 'var(--fv-gold)',
			stars: 5,
			text: 'On a deploye FyxxVault pour toute l\'equipe. Le partage securise et le monitoring dark web sont indispensables.',
		},
	];

	const faqs = [
		{
			q: 'FyxxVault est-il vraiment gratuit ?',
			a: 'Oui, le plan gratuit est 100% fonctionnel avec jusqu\'a 5 comptes. Le plan Pro debloque les comptes illimites, le monitoring dark web et les emails masques.',
		},
		{
			q: 'Mes donnees sont-elles lisibles par FyxxVault ?',
			a: 'Non. FyxxVault utilise un chiffrement zero-knowledge. Ton mot de passe maitre ne quitte jamais ton appareil. Nous n\'avons techniquement aucun moyen de lire tes donnees.',
		},
		{
			q: 'Que se passe-t-il si j\'oublie mon mot de passe maitre ?',
			a: 'Par conception zero-knowledge, nous ne pouvons pas reinitialiser ton mot de passe maitre. Nous recommandons de le noter dans un endroit physique sur.',
		},
		{
			q: 'FyxxVault fonctionne-t-il sur Android ?',
			a: 'Actuellement, FyxxVault est disponible sur iOS et en version web. Le support Android est prevu pour 2026.',
		},
		{
			q: 'Comment fonctionne le monitoring dark web ?',
			a: 'Nous verifions regulierement tes identifiants contre la base Have I Been Pwned (HIBP). Si un de tes comptes apparait dans une fuite, tu recois une alerte instantanee.',
		},
		{
			q: 'Puis-je exporter mes donnees ?',
			a: 'Oui, tu peux exporter l\'integralite de ton coffre en format chiffre ou en CSV. Tes donnees t\'appartiennent.',
		},
		{
			q: 'FyxxVault est-il open source ?',
			a: 'Oui. Notre code est auditable et transparent. L\'architecture de securite est documentee publiquement.',
		},
	];

	const badges = ['SOC 2', 'RGPD', 'E2E', 'AES-256', 'PBKDF2', 'HIBP'];
</script>

<svelte:head>
	<title>FyxxVault — Ton coffre-fort numerique</title>
	<meta name="description" content="FyxxVault — Le gestionnaire de mots de passe nouvelle generation. Chiffrement AES-256, zero-knowledge, surveillance dark web." />
</svelte:head>

<div class="fv-landing">
	<Navbar />

	<!-- ============================================================ -->
	<!-- HERO SECTION -->
	<!-- ============================================================ -->
	<section class="fv-hero">
		<!-- Gradient mesh background -->
		<div class="fv-hero__mesh">
			<div class="fv-hero__orb fv-hero__orb--1"></div>
			<div class="fv-hero__orb fv-hero__orb--2"></div>
			<div class="fv-hero__orb fv-hero__orb--3"></div>
			<div class="fv-hero__orb fv-hero__orb--4"></div>
		</div>

		<!-- Grid pattern -->
		<div class="fv-hero__grid"></div>

		<div class="fv-hero__content" class:fv-hero__content--visible={heroVisible}>
			<!-- Pill badge -->
			<div class="fv-hero__badge">
				<span class="fv-hero__badge-dot"></span>
				<span>Chiffrement de bout en bout</span>
			</div>

			<h1 class="fv-hero__title">
				Tes mots de passe
				<br />
				<span class="fv-hero__title-accent">meritent mieux.</span>
			</h1>

			<p class="fv-hero__subtitle">
				FyxxVault est le gestionnaire de mots de passe nouvelle generation.
				Chiffrement zero-knowledge, sync instantanee, surveillance du dark web.
			</p>

			<!-- CTA Buttons -->
			<div class="fv-hero__ctas">
				<a href="/register" class="fv-hero__cta-primary">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
					Commencer gratuitement
				</a>
				<a href="#features" class="fv-hero__cta-ghost">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
					Voir la demo
				</a>
			</div>

			<!-- Trust badges -->
			<div class="fv-hero__trust">
				<span class="fv-hero__trust-item">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					AES-256
				</span>
				<span class="fv-hero__trust-sep"></span>
				<span class="fv-hero__trust-item">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					Zero-knowledge
				</span>
				<span class="fv-hero__trust-sep"></span>
				<span class="fv-hero__trust-item">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					Open source
				</span>
			</div>

			<!-- Device mockup -->
			<div class="fv-hero__mockup">
				<div class="fv-hero__laptop">
					<div class="fv-hero__laptop-screen">
						<div class="fv-hero__laptop-topbar">
							<div class="fv-hero__laptop-dots">
								<span></span><span></span><span></span>
							</div>
							<div class="fv-hero__laptop-url">fyxxvault.com/vault</div>
						</div>
						<div class="fv-hero__laptop-body">
							<!-- Fake vault UI -->
							<div class="fv-mock__sidebar">
								<div class="fv-mock__sidebar-item fv-mock__sidebar-item--active"></div>
								<div class="fv-mock__sidebar-item"></div>
								<div class="fv-mock__sidebar-item"></div>
								<div class="fv-mock__sidebar-item"></div>
							</div>
							<div class="fv-mock__main">
								<div class="fv-mock__entry">
									<div class="fv-mock__entry-icon" style="background: var(--fv-cyan)"></div>
									<div class="fv-mock__entry-lines">
										<div class="fv-mock__line fv-mock__line--w60"></div>
										<div class="fv-mock__line fv-mock__line--w40 fv-mock__line--dim"></div>
									</div>
									<div class="fv-mock__entry-badge">2FA</div>
								</div>
								<div class="fv-mock__entry">
									<div class="fv-mock__entry-icon" style="background: var(--fv-violet)"></div>
									<div class="fv-mock__entry-lines">
										<div class="fv-mock__line fv-mock__line--w50"></div>
										<div class="fv-mock__line fv-mock__line--w70 fv-mock__line--dim"></div>
									</div>
								</div>
								<div class="fv-mock__entry">
									<div class="fv-mock__entry-icon" style="background: var(--fv-gold)"></div>
									<div class="fv-mock__entry-lines">
										<div class="fv-mock__line fv-mock__line--w45"></div>
										<div class="fv-mock__line fv-mock__line--w55 fv-mock__line--dim"></div>
									</div>
									<div class="fv-mock__entry-badge fv-mock__entry-badge--warn">!</div>
								</div>
								<div class="fv-mock__entry">
									<div class="fv-mock__entry-icon" style="background: var(--fv-success)"></div>
									<div class="fv-mock__entry-lines">
										<div class="fv-mock__line fv-mock__line--w55"></div>
										<div class="fv-mock__line fv-mock__line--w35 fv-mock__line--dim"></div>
									</div>
								</div>
							</div>
						</div>
					</div>
					<div class="fv-hero__laptop-base"></div>
				</div>

				<!-- iPhone -->
				<div class="fv-hero__phone">
					<div class="fv-hero__phone-notch"></div>
					<div class="fv-hero__phone-screen">
						<div class="fv-mock__phone-header">
							<div class="fv-mock__line fv-mock__line--w40" style="margin: 0 auto 8px"></div>
						</div>
						<div class="fv-mock__phone-entry">
							<div class="fv-mock__entry-icon fv-mock__entry-icon--sm" style="background: var(--fv-cyan)"></div>
							<div class="fv-mock__entry-lines">
								<div class="fv-mock__line fv-mock__line--w60"></div>
								<div class="fv-mock__line fv-mock__line--w40 fv-mock__line--dim"></div>
							</div>
						</div>
						<div class="fv-mock__phone-entry">
							<div class="fv-mock__entry-icon fv-mock__entry-icon--sm" style="background: var(--fv-violet)"></div>
							<div class="fv-mock__entry-lines">
								<div class="fv-mock__line fv-mock__line--w50"></div>
								<div class="fv-mock__line fv-mock__line--w30 fv-mock__line--dim"></div>
							</div>
						</div>
						<div class="fv-mock__phone-entry">
							<div class="fv-mock__entry-icon fv-mock__entry-icon--sm" style="background: var(--fv-gold)"></div>
							<div class="fv-mock__entry-lines">
								<div class="fv-mock__line fv-mock__line--w45"></div>
								<div class="fv-mock__line fv-mock__line--w55 fv-mock__line--dim"></div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- TRUST BAR -->
	<!-- ============================================================ -->
	<section class="fv-trust" data-reveal="trust">
		<div class="fv-trust__inner" class:fv-reveal={isRevealed('trust')}>
			<p class="fv-trust__label">Protege deja des milliers de comptes</p>
			<div class="fv-trust__scroll">
				<div class="fv-trust__track">
					{#each [...badges, ...badges] as badge}
						<div class="fv-trust__badge">
							<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
							{badge}
						</div>
					{/each}
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FEATURES GRID -->
	<!-- ============================================================ -->
	<section id="features" class="fv-features" data-reveal="features">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('features')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-cyan)">Fonctionnalites</span>
				<h2 class="fv-section__title">Tout ce qu'il te faut.</h2>
				<p class="fv-section__subtitle">Plus qu'un gestionnaire de mots de passe — un veritable hub de securite.</p>
			</div>

			<div class="fv-features__grid">
				{#each features as feature, i}
					<div
						class="fv-feature-card"
						class:fv-reveal={isRevealed('features')}
						style="--reveal-delay: {i * 100}ms; --accent: {feature.color}"
						data-reveal="feature-{i}"
					>
						<div class="fv-feature-card__icon">
							{#if feature.icon === 'shield'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
							{:else if feature.icon === 'zap'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
							{:else if feature.icon === 'sync'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
							{:else if feature.icon === 'key'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
							{:else if feature.icon === 'eye'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
							{:else if feature.icon === 'lock'}
								<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
							{/if}
						</div>
						<h3 class="fv-feature-card__title">{feature.title}</h3>
						<p class="fv-feature-card__desc">{feature.description}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- HOW IT WORKS -->
	<!-- ============================================================ -->
	<section class="fv-steps" data-reveal="steps">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('steps')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-violet)">Comment ca marche</span>
				<h2 class="fv-section__title">3 etapes. C'est tout.</h2>
				<p class="fv-section__subtitle">De l'inscription a la securite totale en moins de 2 minutes.</p>
			</div>

			<div class="fv-steps__grid" class:fv-reveal={isRevealed('steps')}>
				{#each steps as step, i}
					<div class="fv-step" style="--reveal-delay: {i * 150}ms">
						<!-- Connector line -->
						{#if i < steps.length - 1}
							<div class="fv-step__connector"></div>
						{/if}
						<div class="fv-step__num">{step.num}</div>
						<h3 class="fv-step__title">{step.title}</h3>
						<p class="fv-step__desc">{step.description}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- SECURITY SECTION -->
	<!-- ============================================================ -->
	<section id="security" class="fv-security" data-reveal="security">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('security')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-success)">Securite</span>
				<h2 class="fv-section__title">La securite n'est pas une option,<br />c'est notre fondation.</h2>
				<p class="fv-section__subtitle">Chaque decision d'architecture est prise pour que personne ne puisse acceder a tes donnees.</p>
			</div>

			<div class="fv-security__grid" class:fv-reveal={isRevealed('security')}>
				{#each securityItems as item, i}
					<div class="fv-security-card" style="--reveal-delay: {i * 120}ms; --accent: {item.color}">
						<div class="fv-security-card__icon">
							{#if item.icon === 'lock'}
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
							{:else if item.icon === 'cpu'}
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="2"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>
							{:else if item.icon === 'eye-off'}
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
							{:else if item.icon === 'alert'}
								<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
							{/if}
						</div>
						<div class="fv-security-card__content">
							<h3 class="fv-security-card__label">{item.label}</h3>
							<p class="fv-security-card__detail">{item.detail}</p>
						</div>
						<div class="fv-security-card__glow"></div>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- COMPARISON TABLE -->
	<!-- ============================================================ -->
	<section class="fv-comparison" data-reveal="comparison">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('comparison')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-rose)">Comparaison</span>
				<h2 class="fv-section__title">Pourquoi FyxxVault ?</h2>
				<p class="fv-section__subtitle">Compare les fonctionnalites et fais ton choix.</p>
			</div>

			<div class="fv-comparison__table-wrap" class:fv-reveal={isRevealed('comparison')}>
				<table class="fv-comparison__table">
					<thead>
						<tr>
							<th class="fv-comparison__th-feature">Fonctionnalite</th>
							<th class="fv-comparison__th-highlight">FyxxVault</th>
							<th>1Password</th>
							<th>Bitwarden</th>
							<th>LastPass</th>
						</tr>
					</thead>
					<tbody>
						{#each comparisonFeatures as row}
							<tr>
								<td class="fv-comparison__feature-name">{row.name}</td>
								<td class="fv-comparison__highlight-cell">
									{#if typeof row.fyxx === 'boolean'}
										{#if row.fyxx}
											<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
										{/if}
									{:else}
										<span class="fv-comparison__text-value">{row.fyxx}</span>
									{/if}
								</td>
								<td>
									{#if typeof row.one === 'boolean'}
										{#if row.one}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
										{/if}
									{:else}
										<span class="fv-comparison__dim">{row.one}</span>
									{/if}
								</td>
								<td>
									{#if typeof row.bit === 'boolean'}
										{#if row.bit}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
										{/if}
									{:else}
										<span class="fv-comparison__dim">{row.bit}</span>
									{/if}
								</td>
								<td>
									{#if typeof row.last === 'boolean'}
										{#if row.last}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
										{/if}
									{:else}
										<span class="fv-comparison__dim">{row.last}</span>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- PRICING SECTION -->
	<!-- ============================================================ -->
	<section id="pricing" class="fv-pricing" data-reveal="pricing">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('pricing')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-gold)">Tarifs</span>
				<h2 class="fv-section__title">Simple et transparent.</h2>
				<p class="fv-section__subtitle">14 jours d'essai gratuit. Sans carte bancaire.</p>
			</div>

			<div class="fv-pricing__grid" class:fv-reveal={isRevealed('pricing')}>
				<!-- Free Plan -->
				<div class="fv-pricing-card">
					<div class="fv-pricing-card__header">
						<h3 class="fv-pricing-card__name">Gratuit</h3>
						<p class="fv-pricing-card__tagline">Pour commencer en securite</p>
					</div>
					<div class="fv-pricing-card__price">
						<span class="fv-pricing-card__amount">0EUR</span>
						<span class="fv-pricing-card__period">/mois</span>
					</div>
					<ul class="fv-pricing-card__features">
						{#each freeFeatures as f}
							<li>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
								{f}
							</li>
						{/each}
					</ul>
					<a href="/register" class="fv-pricing-card__cta fv-pricing-card__cta--ghost">Creer un compte</a>
				</div>

				<!-- Pro Plan -->
				<div class="fv-pricing-card fv-pricing-card--pro">
					<div class="fv-pricing-card__popular">Populaire</div>
					<div class="fv-pricing-card__header">
						<h3 class="fv-pricing-card__name">
							Pro
							<span class="fv-pricing-card__crown">&#9733;</span>
						</h3>
						<p class="fv-pricing-card__tagline">Securite maximale</p>
					</div>
					<div class="fv-pricing-card__price">
						<span class="fv-pricing-card__amount">4,99EUR</span>
						<span class="fv-pricing-card__period">/mois</span>
					</div>
					<p class="fv-pricing-card__annual">ou 41,99EUR/an <span>(-30%)</span></p>
					<ul class="fv-pricing-card__features">
						{#each proFeatures as f}
							<li>
								<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
								{f}
							</li>
						{/each}
					</ul>
					<a href="/register" class="fv-pricing-card__cta fv-pricing-card__cta--gold">Essai gratuit 14 jours</a>
					<p class="fv-pricing-card__guarantee">
						<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
						Satisfait ou rembourse 30 jours
					</p>
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- TESTIMONIALS -->
	<!-- ============================================================ -->
	<section class="fv-testimonials" data-reveal="testimonials">
		<div class="fv-section__inner">
			<div class="fv-section__header" class:fv-reveal={isRevealed('testimonials')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-violet)">Temoignages</span>
				<h2 class="fv-section__title">Ils nous font confiance.</h2>
			</div>

			<div class="fv-testimonials__grid" class:fv-reveal={isRevealed('testimonials')}>
				{#each testimonials as t, i}
					<div class="fv-testimonial" style="--reveal-delay: {i * 120}ms; --accent: {t.color}">
						<div class="fv-testimonial__stars">
							{#each Array(t.stars) as _}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="var(--fv-gold)" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
							{/each}
						</div>
						<p class="fv-testimonial__text">{t.text}</p>
						<div class="fv-testimonial__author">
							<div class="fv-testimonial__avatar" style="--avatar-color: {t.color}">{t.initials}</div>
							<div>
								<div class="fv-testimonial__name">{t.name}</div>
								<div class="fv-testimonial__role">{t.role}</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FAQ -->
	<!-- ============================================================ -->
	<section class="fv-faq" data-reveal="faq">
		<div class="fv-section__inner fv-section__inner--narrow">
			<div class="fv-section__header" class:fv-reveal={isRevealed('faq')}>
				<span class="fv-section__pill" style="--pill-color: var(--fv-cyan)">FAQ</span>
				<h2 class="fv-section__title">Questions frequentes</h2>
			</div>

			<div class="fv-faq__list" class:fv-reveal={isRevealed('faq')}>
				{#each faqs as faq, i}
					<div class="fv-faq__item" class:fv-faq__item--open={openFaq === i}>
						<button class="fv-faq__question" onclick={() => toggleFaq(i)}>
							<span>{faq.q}</span>
							<svg class="fv-faq__chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
						</button>
						<div class="fv-faq__answer-wrap" style="grid-template-rows: {openFaq === i ? '1fr' : '0fr'}">
							<div class="fv-faq__answer">
								<p>{faq.a}</p>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FINAL CTA -->
	<!-- ============================================================ -->
	<section class="fv-final-cta" data-reveal="finalcta">
		<div class="fv-final-cta__bg">
			<div class="fv-final-cta__orb fv-final-cta__orb--1"></div>
			<div class="fv-final-cta__orb fv-final-cta__orb--2"></div>
		</div>
		<div class="fv-section__inner fv-final-cta__content" class:fv-reveal={isRevealed('finalcta')}>
			<h2 class="fv-final-cta__title">Pret a securiser tes comptes ?</h2>
			<p class="fv-final-cta__subtitle">Rejoins des milliers d'utilisateurs qui protegent leurs mots de passe avec FyxxVault.</p>
			<a href="/register" class="fv-final-cta__btn">
				Commencer gratuitement
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
			</a>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FOOTER -->
	<!-- ============================================================ -->
	<footer class="fv-footer">
		<div class="fv-footer__inner">
			<div class="fv-footer__grid">
				<!-- Brand -->
				<div class="fv-footer__brand">
					<div class="fv-footer__logo">
						<div class="fv-footer__logo-icon">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
						</div>
						<span>FyxxVault</span>
					</div>
					<p class="fv-footer__desc">Le gestionnaire de mots de passe nouvelle generation. Securite sans compromis.</p>
					<div class="fv-footer__socials">
						<a href="https://twitter.com/fyxxvault" aria-label="Twitter" class="fv-footer__social">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
						</a>
						<a href="https://github.com/fyxxvault" aria-label="GitHub" class="fv-footer__social">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
						</a>
					</div>
				</div>

				<!-- Links -->
				<div class="fv-footer__col">
					<h4>Produit</h4>
					<a href="#features">Fonctionnalites</a>
					<a href="#security">Securite</a>
					<a href="#pricing">Prix</a>
					<a href="/login">Web App</a>
				</div>
				<div class="fv-footer__col">
					<h4>Legal</h4>
					<a href="/privacy">Politique de confidentialite</a>
					<a href="/terms">CGV</a>
					<a href="/mentions-legales">Mentions legales</a>
				</div>
				<div class="fv-footer__col">
					<h4>Support</h4>
					<a href="mailto:support@fyxxvault.com">Contact</a>
					<a href="#faq">FAQ</a>
					<a href="/blog">Blog</a>
				</div>
			</div>

			<div class="fv-footer__bottom">
				<p>&copy; 2026 FyxxVault. Tous droits reserves.</p>
				<div class="fv-footer__badges">
					<span>AES-256</span>
					<span>Zero-Knowledge</span>
					<span>E2E</span>
				</div>
			</div>
		</div>
	</footer>
</div>

<style>
	/* ============================================================ */
	/* BASE / RESET */
	/* ============================================================ */
	.fv-landing {
		min-height: 100vh;
		background: var(--fv-abyss);
		overflow-x: hidden;
	}

	/* ============================================================ */
	/* REVEAL ANIMATION */
	/* ============================================================ */
	.fv-reveal {
		animation: fvRevealUp 0.8s cubic-bezier(0.16, 1, 0.3, 1) both;
		animation-delay: var(--reveal-delay, 0ms);
	}

	@keyframes fvRevealUp {
		from { opacity: 0; transform: translateY(32px); }
		to { opacity: 1; transform: translateY(0); }
	}

	/* ============================================================ */
	/* SECTION SHARED */
	/* ============================================================ */
	.fv-section__inner {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 24px;
	}

	.fv-section__inner--narrow {
		max-width: 800px;
	}

	.fv-section__header {
		text-align: center;
		margin-bottom: 64px;
		opacity: 0;
	}

	.fv-section__pill {
		display: inline-block;
		padding: 6px 16px;
		border-radius: 100px;
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		color: var(--pill-color);
		background: color-mix(in srgb, var(--pill-color) 12%, transparent);
		margin-bottom: 16px;
	}

	.fv-section__title {
		font-size: clamp(28px, 5vw, 48px);
		font-weight: 800;
		color: white;
		line-height: 1.15;
		letter-spacing: -0.02em;
		margin: 0 0 12px;
	}

	.fv-section__subtitle {
		font-size: 17px;
		color: var(--fv-mist);
		max-width: 560px;
		margin: 0 auto;
		line-height: 1.6;
	}

	/* ============================================================ */
	/* HERO */
	/* ============================================================ */
	.fv-hero {
		position: relative;
		min-height: 100vh;
		display: flex;
		align-items: center;
		justify-content: center;
		overflow: hidden;
		padding: 100px 24px 60px;
	}

	.fv-hero__mesh {
		position: absolute;
		inset: 0;
		overflow: hidden;
	}

	.fv-hero__orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(120px);
	}

	.fv-hero__orb--1 {
		width: 600px;
		height: 600px;
		top: -10%;
		left: -5%;
		background: var(--fv-cyan);
		opacity: 0.07;
		animation: fvFloat 20s ease-in-out infinite;
	}

	.fv-hero__orb--2 {
		width: 500px;
		height: 500px;
		bottom: -10%;
		right: -5%;
		background: var(--fv-violet);
		opacity: 0.06;
		animation: fvFloat 25s ease-in-out infinite reverse;
	}

	.fv-hero__orb--3 {
		width: 400px;
		height: 400px;
		top: 30%;
		left: 50%;
		background: var(--fv-rose);
		opacity: 0.04;
		animation: fvFloat 22s ease-in-out infinite 3s;
	}

	.fv-hero__orb--4 {
		width: 300px;
		height: 300px;
		top: 10%;
		right: 20%;
		background: var(--fv-gold);
		opacity: 0.03;
		animation: fvFloat 18s ease-in-out infinite 5s;
	}

	@keyframes fvFloat {
		0%, 100% { transform: translate(0, 0) scale(1); }
		33% { transform: translate(30px, -30px) scale(1.05); }
		66% { transform: translate(-20px, 20px) scale(0.95); }
	}

	.fv-hero__grid {
		position: absolute;
		inset: 0;
		opacity: 0.025;
		background-image: radial-gradient(circle, var(--fv-mist) 1px, transparent 1px);
		background-size: 48px 48px;
	}

	.fv-hero__content {
		position: relative;
		z-index: 2;
		text-align: center;
		max-width: 900px;
		opacity: 0;
		transform: translateY(24px);
		transition: all 1s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.fv-hero__content--visible {
		opacity: 1;
		transform: translateY(0);
	}

	.fv-hero__badge {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 8px 18px;
		border-radius: 100px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		font-size: 12px;
		font-weight: 600;
		color: var(--fv-mist);
		letter-spacing: 0.02em;
		margin-bottom: 32px;
	}

	.fv-hero__badge-dot {
		width: 7px;
		height: 7px;
		border-radius: 50%;
		background: var(--fv-success);
		animation: fvPulse 2s ease-in-out infinite;
	}

	@keyframes fvPulse {
		0%, 100% { opacity: 1; box-shadow: 0 0 0 0 rgba(52, 211, 153, 0.4); }
		50% { opacity: 0.8; box-shadow: 0 0 0 6px rgba(52, 211, 153, 0); }
	}

	.fv-hero__title {
		font-size: clamp(36px, 7vw, 72px);
		font-weight: 900;
		color: white;
		line-height: 1.05;
		letter-spacing: -0.03em;
		margin: 0 0 24px;
	}

	.fv-hero__title-accent {
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.fv-hero__subtitle {
		font-size: clamp(16px, 2vw, 19px);
		color: var(--fv-mist);
		line-height: 1.65;
		max-width: 600px;
		margin: 0 auto 40px;
	}

	.fv-hero__ctas {
		display: flex;
		flex-wrap: wrap;
		justify-content: center;
		gap: 12px;
		margin-bottom: 40px;
	}

	.fv-hero__cta-primary {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 16px 32px;
		border-radius: 14px;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #0a101e;
		font-size: 15px;
		font-weight: 700;
		text-decoration: none;
		transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
		box-shadow: 0 4px 24px rgba(255, 200, 55, 0.25);
	}

	.fv-hero__cta-primary:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 40px rgba(255, 200, 55, 0.4);
	}

	.fv-hero__cta-ghost {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 16px 32px;
		border-radius: 14px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.1);
		color: var(--fv-silver);
		font-size: 15px;
		font-weight: 600;
		text-decoration: none;
		transition: all 0.2s;
	}

	.fv-hero__cta-ghost:hover {
		background: rgba(255, 255, 255, 0.08);
		border-color: rgba(255, 255, 255, 0.15);
	}

	.fv-hero__trust {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		flex-wrap: wrap;
		margin-bottom: 64px;
	}

	.fv-hero__trust-item {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 13px;
		font-weight: 500;
		color: var(--fv-smoke);
	}

	.fv-hero__trust-sep {
		width: 4px;
		height: 4px;
		border-radius: 50%;
		background: var(--fv-ash);
	}

	/* Device Mockup */
	.fv-hero__mockup {
		position: relative;
		max-width: 700px;
		margin: 0 auto;
		display: flex;
		justify-content: center;
	}

	.fv-hero__laptop {
		width: 100%;
		max-width: 560px;
	}

	.fv-hero__laptop-screen {
		background: var(--fv-obsidian);
		border-radius: 12px 12px 0 0;
		border: 1px solid rgba(255, 255, 255, 0.08);
		overflow: hidden;
		aspect-ratio: 16 / 10;
	}

	.fv-hero__laptop-topbar {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 8px 12px;
		background: rgba(255, 255, 255, 0.03);
		border-bottom: 1px solid rgba(255, 255, 255, 0.05);
	}

	.fv-hero__laptop-dots {
		display: flex;
		gap: 5px;
	}

	.fv-hero__laptop-dots span {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		background: rgba(255, 255, 255, 0.1);
	}

	.fv-hero__laptop-dots span:first-child { background: #ff5f57; }
	.fv-hero__laptop-dots span:nth-child(2) { background: #febc2e; }
	.fv-hero__laptop-dots span:last-child { background: #28c840; }

	.fv-hero__laptop-url {
		flex: 1;
		text-align: center;
		font-size: 10px;
		color: var(--fv-ash);
		background: rgba(255, 255, 255, 0.03);
		padding: 3px 12px;
		border-radius: 4px;
	}

	.fv-hero__laptop-body {
		display: flex;
		height: calc(100% - 33px);
	}

	.fv-hero__laptop-base {
		height: 12px;
		background: linear-gradient(to bottom, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0.04));
		border-radius: 0 0 4px 4px;
		margin: 0 40px;
	}

	/* Mock vault UI inside laptop */
	.fv-mock__sidebar {
		width: 50px;
		border-right: 1px solid rgba(255, 255, 255, 0.05);
		padding: 12px 8px;
		display: flex;
		flex-direction: column;
		gap: 8px;
	}

	.fv-mock__sidebar-item {
		height: 28px;
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.04);
	}

	.fv-mock__sidebar-item--active {
		background: rgba(0, 212, 255, 0.15);
		border: 1px solid rgba(0, 212, 255, 0.2);
	}

	.fv-mock__main {
		flex: 1;
		padding: 10px;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}

	.fv-mock__entry {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 8px;
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.04);
	}

	.fv-mock__entry-icon {
		width: 24px;
		height: 24px;
		border-radius: 6px;
		flex-shrink: 0;
		opacity: 0.8;
	}

	.fv-mock__entry-icon--sm {
		width: 20px;
		height: 20px;
		border-radius: 5px;
	}

	.fv-mock__entry-lines {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.fv-mock__line {
		height: 6px;
		border-radius: 3px;
		background: rgba(255, 255, 255, 0.12);
	}

	.fv-mock__line--dim { opacity: 0.4; }
	.fv-mock__line--w30 { width: 30%; }
	.fv-mock__line--w35 { width: 35%; }
	.fv-mock__line--w40 { width: 40%; }
	.fv-mock__line--w45 { width: 45%; }
	.fv-mock__line--w50 { width: 50%; }
	.fv-mock__line--w55 { width: 55%; }
	.fv-mock__line--w60 { width: 60%; }
	.fv-mock__line--w70 { width: 70%; }

	.fv-mock__entry-badge {
		font-size: 8px;
		font-weight: 700;
		color: var(--fv-success);
		background: rgba(52, 211, 153, 0.15);
		padding: 2px 6px;
		border-radius: 4px;
	}

	.fv-mock__entry-badge--warn {
		color: var(--fv-danger);
		background: rgba(239, 68, 68, 0.15);
	}

	/* Phone */
	.fv-hero__phone {
		position: absolute;
		right: -30px;
		bottom: 30px;
		width: 120px;
		background: var(--fv-obsidian);
		border-radius: 16px;
		border: 2px solid rgba(255, 255, 255, 0.1);
		overflow: hidden;
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
		display: none;
	}

	@media (min-width: 640px) {
		.fv-hero__phone { display: block; }
	}

	.fv-hero__phone-notch {
		width: 40px;
		height: 5px;
		background: var(--fv-abyss);
		border-radius: 10px;
		margin: 8px auto 4px;
	}

	.fv-hero__phone-screen {
		padding: 8px;
	}

	.fv-mock__phone-header {
		padding: 4px 0 8px;
	}

	.fv-mock__phone-entry {
		display: flex;
		align-items: center;
		gap: 6px;
		padding: 6px;
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.03);
		margin-bottom: 4px;
	}

	/* ============================================================ */
	/* TRUST BAR */
	/* ============================================================ */
	.fv-trust {
		padding: 48px 0;
		border-top: 1px solid rgba(255, 255, 255, 0.04);
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
		overflow: hidden;
	}

	.fv-trust__inner {
		text-align: center;
		opacity: 0;
	}

	.fv-trust__label {
		font-size: 13px;
		font-weight: 500;
		color: var(--fv-smoke);
		letter-spacing: 0.02em;
		margin: 0 0 24px;
	}

	.fv-trust__scroll {
		overflow: hidden;
		mask-image: linear-gradient(to right, transparent, black 10%, black 90%, transparent);
		-webkit-mask-image: linear-gradient(to right, transparent, black 10%, black 90%, transparent);
	}

	.fv-trust__track {
		display: flex;
		gap: 16px;
		animation: fvScroll 25s linear infinite;
		width: max-content;
	}

	@keyframes fvScroll {
		0% { transform: translateX(0); }
		100% { transform: translateX(-50%); }
	}

	.fv-trust__badge {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 10px 20px;
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 12px;
		font-weight: 600;
		color: var(--fv-mist);
		white-space: nowrap;
	}

	/* ============================================================ */
	/* FEATURES */
	/* ============================================================ */
	.fv-features {
		padding: 120px 0;
	}

	.fv-features__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 16px;
	}

	@media (min-width: 640px) {
		.fv-features__grid { grid-template-columns: repeat(2, 1fr); }
	}

	@media (min-width: 1024px) {
		.fv-features__grid { grid-template-columns: repeat(3, 1fr); }
	}

	.fv-feature-card {
		position: relative;
		padding: 32px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.06);
		transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
		opacity: 0;
		overflow: hidden;
	}

	.fv-feature-card::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 1px;
		background: linear-gradient(90deg, transparent, var(--accent), transparent);
		opacity: 0;
		transition: opacity 0.4s;
	}

	.fv-feature-card:hover {
		transform: translateY(-4px);
		border-color: rgba(255, 255, 255, 0.12);
		box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
	}

	.fv-feature-card:hover::before {
		opacity: 0.6;
	}

	.fv-feature-card__icon {
		width: 48px;
		height: 48px;
		border-radius: 14px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: color-mix(in srgb, var(--accent) 10%, transparent);
		margin-bottom: 20px;
	}

	.fv-feature-card__title {
		font-size: 17px;
		font-weight: 700;
		color: white;
		margin: 0 0 8px;
	}

	.fv-feature-card__desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}

	/* ============================================================ */
	/* STEPS */
	/* ============================================================ */
	.fv-steps {
		padding: 120px 0;
		background: linear-gradient(180deg, transparent, rgba(138, 92, 246, 0.03), transparent);
	}

	.fv-steps__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 32px;
		opacity: 0;
	}

	@media (min-width: 768px) {
		.fv-steps__grid { grid-template-columns: repeat(3, 1fr); gap: 24px; }
	}

	.fv-step {
		position: relative;
		text-align: center;
		padding: 32px 24px;
	}

	.fv-step__connector {
		display: none;
	}

	@media (min-width: 768px) {
		.fv-step__connector {
			display: block;
			position: absolute;
			top: 40px;
			right: -12px;
			width: 24px;
			height: 2px;
			background: linear-gradient(90deg, var(--fv-violet), transparent);
			opacity: 0.3;
		}
	}

	.fv-step__num {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 56px;
		height: 56px;
		border-radius: 16px;
		background: linear-gradient(135deg, rgba(138, 92, 246, 0.15), rgba(138, 92, 246, 0.05));
		border: 1px solid rgba(138, 92, 246, 0.2);
		font-size: 18px;
		font-weight: 800;
		color: var(--fv-violet-light);
		margin-bottom: 20px;
	}

	.fv-step__title {
		font-size: 18px;
		font-weight: 700;
		color: white;
		margin: 0 0 8px;
	}

	.fv-step__desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}

	/* ============================================================ */
	/* SECURITY */
	/* ============================================================ */
	.fv-security {
		padding: 120px 0;
	}

	.fv-security__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 16px;
		opacity: 0;
	}

	@media (min-width: 768px) {
		.fv-security__grid { grid-template-columns: repeat(2, 1fr); }
	}

	.fv-security-card {
		position: relative;
		display: flex;
		align-items: flex-start;
		gap: 16px;
		padding: 28px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
		border: 1px solid rgba(255, 255, 255, 0.06);
		overflow: hidden;
		transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.fv-security-card:hover {
		border-color: color-mix(in srgb, var(--accent) 30%, transparent);
		transform: translateY(-2px);
	}

	.fv-security-card__glow {
		position: absolute;
		top: -50%;
		right: -50%;
		width: 200px;
		height: 200px;
		border-radius: 50%;
		background: var(--accent);
		opacity: 0;
		filter: blur(80px);
		transition: opacity 0.4s;
		pointer-events: none;
	}

	.fv-security-card:hover .fv-security-card__glow {
		opacity: 0.08;
	}

	.fv-security-card__icon {
		width: 48px;
		height: 48px;
		border-radius: 14px;
		display: flex;
		align-items: center;
		justify-content: center;
		background: color-mix(in srgb, var(--accent) 10%, transparent);
		flex-shrink: 0;
	}

	.fv-security-card__label {
		font-size: 17px;
		font-weight: 700;
		color: white;
		margin: 0 0 6px;
	}

	.fv-security-card__detail {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}

	/* ============================================================ */
	/* COMPARISON */
	/* ============================================================ */
	.fv-comparison {
		padding: 120px 0;
		background: linear-gradient(180deg, transparent, rgba(255, 55, 130, 0.02), transparent);
	}

	.fv-comparison__table-wrap {
		overflow-x: auto;
		border-radius: 20px;
		border: 1px solid rgba(255, 255, 255, 0.06);
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.01));
		opacity: 0;
	}

	.fv-comparison__table {
		width: 100%;
		border-collapse: collapse;
		min-width: 600px;
	}

	.fv-comparison__table thead {
		background: rgba(255, 255, 255, 0.03);
	}

	.fv-comparison__table th {
		padding: 16px 20px;
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.06em;
		color: var(--fv-smoke);
		text-align: center;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}

	.fv-comparison__th-feature {
		text-align: left !important;
	}

	.fv-comparison__th-highlight {
		color: var(--fv-gold) !important;
		background: rgba(255, 200, 55, 0.05);
	}

	.fv-comparison__table td {
		padding: 14px 20px;
		text-align: center;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		font-size: 13px;
		color: var(--fv-mist);
	}

	.fv-comparison__table tr:last-child td {
		border-bottom: none;
	}

	.fv-comparison__feature-name {
		text-align: left !important;
		font-weight: 500;
	}

	.fv-comparison__highlight-cell {
		background: rgba(255, 200, 55, 0.03);
	}

	.fv-comparison__text-value {
		font-weight: 700;
		color: var(--fv-gold);
	}

	.fv-comparison__dim {
		color: var(--fv-smoke);
	}

	/* ============================================================ */
	/* PRICING */
	/* ============================================================ */
	.fv-pricing {
		padding: 120px 0;
	}

	.fv-pricing__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 24px;
		max-width: 800px;
		margin: 0 auto;
		opacity: 0;
	}

	@media (min-width: 640px) {
		.fv-pricing__grid { grid-template-columns: repeat(2, 1fr); }
	}

	.fv-pricing-card {
		position: relative;
		padding: 36px;
		border-radius: 24px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.02));
		border: 1px solid rgba(255, 255, 255, 0.08);
		overflow: hidden;
	}

	.fv-pricing-card--pro {
		border-color: rgba(255, 200, 55, 0.25);
		box-shadow: 0 0 40px rgba(255, 200, 55, 0.1);
	}

	.fv-pricing-card__popular {
		position: absolute;
		top: 0;
		right: 0;
		padding: 6px 20px;
		font-size: 10px;
		font-weight: 800;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #0a101e;
		border-bottom-left-radius: 12px;
	}

	.fv-pricing-card__header {
		margin-bottom: 24px;
	}

	.fv-pricing-card__name {
		font-size: 22px;
		font-weight: 800;
		color: white;
		margin: 0 0 4px;
		display: flex;
		align-items: center;
		gap: 8px;
	}

	.fv-pricing-card__crown {
		color: var(--fv-gold);
		font-size: 16px;
	}

	.fv-pricing-card__tagline {
		font-size: 14px;
		color: var(--fv-smoke);
		margin: 0;
	}

	.fv-pricing-card__price {
		margin-bottom: 8px;
		display: flex;
		align-items: baseline;
		gap: 4px;
	}

	.fv-pricing-card__amount {
		font-size: 40px;
		font-weight: 900;
		color: white;
		letter-spacing: -0.02em;
	}

	.fv-pricing-card__period {
		font-size: 15px;
		color: var(--fv-smoke);
	}

	.fv-pricing-card__annual {
		font-size: 13px;
		color: var(--fv-smoke);
		margin: 0 0 24px;
	}

	.fv-pricing-card__annual span {
		color: var(--fv-gold);
		font-weight: 700;
	}

	.fv-pricing-card__features {
		list-style: none;
		padding: 0;
		margin: 0 0 28px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}

	.fv-pricing-card__features li {
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 14px;
		color: var(--fv-mist);
	}

	.fv-pricing-card__cta {
		display: block;
		width: 100%;
		text-align: center;
		padding: 14px;
		border-radius: 12px;
		font-size: 14px;
		font-weight: 700;
		text-decoration: none;
		transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.fv-pricing-card__cta--ghost {
		background: rgba(255, 255, 255, 0.06);
		color: var(--fv-silver);
		border: 1px solid rgba(255, 255, 255, 0.1);
	}

	.fv-pricing-card__cta--ghost:hover {
		background: rgba(255, 255, 255, 0.1);
	}

	.fv-pricing-card__cta--gold {
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #0a101e;
		box-shadow: 0 4px 20px rgba(255, 200, 55, 0.25);
	}

	.fv-pricing-card__cta--gold:hover {
		transform: translateY(-2px);
		box-shadow: 0 8px 32px rgba(255, 200, 55, 0.4);
	}

	.fv-pricing-card__guarantee {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		margin: 16px 0 0;
		font-size: 12px;
		color: var(--fv-smoke);
	}

	/* ============================================================ */
	/* TESTIMONIALS */
	/* ============================================================ */
	.fv-testimonials {
		padding: 120px 0;
		background: linear-gradient(180deg, transparent, rgba(138, 92, 246, 0.03), transparent);
	}

	.fv-testimonials__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 20px;
		opacity: 0;
	}

	@media (min-width: 768px) {
		.fv-testimonials__grid { grid-template-columns: repeat(3, 1fr); }
	}

	.fv-testimonial {
		padding: 28px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.02));
		border: 1px solid rgba(255, 255, 255, 0.06);
		transition: all 0.4s;
		position: relative;
		overflow: hidden;
	}

	.fv-testimonial::before {
		content: '';
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 2px;
		background: linear-gradient(90deg, transparent, var(--accent), transparent);
		opacity: 0.4;
	}

	.fv-testimonial:hover {
		transform: translateY(-3px);
		border-color: color-mix(in srgb, var(--accent) 25%, transparent);
	}

	.fv-testimonial__stars {
		display: flex;
		gap: 2px;
		margin-bottom: 16px;
	}

	.fv-testimonial__text {
		font-size: 14px;
		color: var(--fv-mist);
		line-height: 1.7;
		margin: 0 0 20px;
	}

	.fv-testimonial__author {
		display: flex;
		align-items: center;
		gap: 10px;
	}

	.fv-testimonial__avatar {
		width: 36px;
		height: 36px;
		border-radius: 10px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-size: 12px;
		font-weight: 800;
		color: white;
		background: color-mix(in srgb, var(--avatar-color) 25%, var(--fv-obsidian));
		border: 1px solid color-mix(in srgb, var(--avatar-color) 30%, transparent);
	}

	.fv-testimonial__name {
		font-size: 13px;
		font-weight: 700;
		color: white;
	}

	.fv-testimonial__role {
		font-size: 12px;
		color: var(--fv-smoke);
	}

	/* ============================================================ */
	/* FAQ */
	/* ============================================================ */
	.fv-faq {
		padding: 120px 0;
	}

	.fv-faq__list {
		display: flex;
		flex-direction: column;
		gap: 8px;
		opacity: 0;
	}

	.fv-faq__item {
		border-radius: 16px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.01));
		border: 1px solid rgba(255, 255, 255, 0.06);
		overflow: hidden;
		transition: border-color 0.3s;
	}

	.fv-faq__item--open {
		border-color: rgba(0, 212, 255, 0.2);
	}

	.fv-faq__question {
		display: flex;
		align-items: center;
		justify-content: space-between;
		width: 100%;
		padding: 20px 24px;
		background: none;
		border: none;
		color: white;
		font-size: 15px;
		font-weight: 600;
		cursor: pointer;
		text-align: left;
		gap: 16px;
		font-family: inherit;
	}

	.fv-faq__question:hover {
		color: var(--fv-cyan);
	}

	.fv-faq__chevron {
		flex-shrink: 0;
		transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
		color: var(--fv-smoke);
	}

	.fv-faq__item--open .fv-faq__chevron {
		transform: rotate(180deg);
		color: var(--fv-cyan);
	}

	.fv-faq__answer-wrap {
		display: grid;
		transition: grid-template-rows 0.4s cubic-bezier(0.16, 1, 0.3, 1);
	}

	.fv-faq__answer {
		overflow: hidden;
	}

	.fv-faq__answer p {
		padding: 0 24px 20px;
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.7;
		margin: 0;
	}

	/* ============================================================ */
	/* FINAL CTA */
	/* ============================================================ */
	.fv-final-cta {
		position: relative;
		padding: 120px 24px;
		overflow: hidden;
	}

	.fv-final-cta__bg {
		position: absolute;
		inset: 0;
	}

	.fv-final-cta__orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(100px);
	}

	.fv-final-cta__orb--1 {
		width: 500px;
		height: 500px;
		top: -30%;
		left: 20%;
		background: var(--fv-gold);
		opacity: 0.06;
		animation: fvFloat 20s ease-in-out infinite;
	}

	.fv-final-cta__orb--2 {
		width: 400px;
		height: 400px;
		bottom: -30%;
		right: 20%;
		background: var(--fv-cyan);
		opacity: 0.05;
		animation: fvFloat 24s ease-in-out infinite reverse;
	}

	.fv-final-cta__content {
		position: relative;
		z-index: 2;
		text-align: center;
		opacity: 0;
	}

	.fv-final-cta__title {
		font-size: clamp(28px, 5vw, 48px);
		font-weight: 900;
		color: white;
		letter-spacing: -0.02em;
		margin: 0 0 16px;
	}

	.fv-final-cta__subtitle {
		font-size: 17px;
		color: var(--fv-mist);
		max-width: 500px;
		margin: 0 auto 36px;
		line-height: 1.6;
	}

	.fv-final-cta__btn {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 18px 40px;
		border-radius: 16px;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		color: #0a101e;
		font-size: 16px;
		font-weight: 800;
		text-decoration: none;
		transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
		box-shadow: 0 4px 24px rgba(255, 200, 55, 0.3);
	}

	.fv-final-cta__btn:hover {
		transform: translateY(-3px);
		box-shadow: 0 12px 48px rgba(255, 200, 55, 0.45);
	}

	/* ============================================================ */
	/* FOOTER */
	/* ============================================================ */
	.fv-footer {
		border-top: 1px solid rgba(255, 255, 255, 0.05);
		padding: 64px 24px 32px;
	}

	.fv-footer__inner {
		max-width: 1200px;
		margin: 0 auto;
	}

	.fv-footer__grid {
		display: grid;
		grid-template-columns: 1fr;
		gap: 40px;
		margin-bottom: 48px;
	}

	@media (min-width: 768px) {
		.fv-footer__grid { grid-template-columns: 2fr 1fr 1fr 1fr; }
	}

	.fv-footer__logo {
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 18px;
		font-weight: 800;
		color: white;
		margin-bottom: 12px;
	}

	.fv-footer__logo-icon {
		width: 32px;
		height: 32px;
		border-radius: 8px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		display: flex;
		align-items: center;
		justify-content: center;
	}

	.fv-footer__desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0 0 16px;
	}

	.fv-footer__socials {
		display: flex;
		gap: 8px;
	}

	.fv-footer__social {
		width: 36px;
		height: 36px;
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.06);
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--fv-smoke);
		text-decoration: none;
		transition: all 0.2s;
	}

	.fv-footer__social:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.fv-footer__col h4 {
		font-size: 12px;
		font-weight: 700;
		text-transform: uppercase;
		letter-spacing: 0.08em;
		color: white;
		margin: 0 0 16px;
	}

	.fv-footer__col a {
		display: block;
		font-size: 14px;
		color: var(--fv-smoke);
		text-decoration: none;
		padding: 4px 0;
		transition: color 0.2s;
	}

	.fv-footer__col a:hover {
		color: white;
	}

	.fv-footer__bottom {
		display: flex;
		flex-wrap: wrap;
		justify-content: space-between;
		align-items: center;
		gap: 16px;
		padding-top: 32px;
		border-top: 1px solid rgba(255, 255, 255, 0.05);
	}

	.fv-footer__bottom p {
		font-size: 12px;
		color: var(--fv-ash);
		margin: 0;
	}

	.fv-footer__badges {
		display: flex;
		gap: 8px;
	}

	.fv-footer__badges span {
		font-size: 10px;
		font-weight: 700;
		padding: 4px 12px;
		border-radius: 100px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		color: var(--fv-smoke);
	}

	/* ============================================================ */
	/* SMOOTH SCROLL */
	/* ============================================================ */
	:global(html) {
		scroll-behavior: smooth;
	}
</style>
