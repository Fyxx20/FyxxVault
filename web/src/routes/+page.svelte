<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase } from '$lib/supabase';
	import { goto } from '$app/navigation';
	import Navbar from '$lib/components/landing/Navbar.svelte';

	let mounted = $state(false);
	let heroVisible = $state(false);
	let hasSession = $state(false);
	let sessionChecked = $state(false);
	let sessionEmail = $state('');
	let showLanding = $state(false);
	let revealedSections = $state(new Set<string>());
	let openFaq = $state<number | null>(null);
	let scrollY = $state(0);
	let scrollProgress = $state(0);
	let demoPasswordVisible = $state(false);
	let demoCopied = $state(false);
	let totpSeconds = $state(22);
	let activeTestimonial = $state(0);
	let ctaTyped = $state('');
	let faqSearch = $state('');

	// Counter values
	let counterAccounts = $state(0);
	let counterBits = $state(0);
	let counterUptime = $state(0);
	let counterLeaks = $state(0);
	let countersStarted = false;

	// Pricing counter
	let pricingAmount = $state('0,00');
	let pricingCounterStarted = false;

	// Easter egg
	let konamiBuffer = '';
	let showParticles = $state(false);

	const ctaFullText = 'Pret a securiser tes comptes ?';

	onMount(async () => {
		// Check for existing session before showing landing
		const { data: { session } } = await supabase.auth.getSession();
		if (session) {
			hasSession = true;
			sessionEmail = session.user?.email ?? '';
		}
		sessionChecked = true;

		mounted = true;
		setTimeout(() => heroVisible = true, 200);

		// Mouse-following gradient
		const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
		if (!isTouchDevice) {
			document.addEventListener('mousemove', (e: MouseEvent) => {
				document.documentElement.style.setProperty('--mouse-x', e.clientX + 'px');
				document.documentElement.style.setProperty('--mouse-y', e.clientY + 'px');
			});
		}

		// Scroll tracking
		const onScroll = () => {
			scrollY = window.scrollY;
			const docH = document.documentElement.scrollHeight - window.innerHeight;
			scrollProgress = docH > 0 ? (window.scrollY / docH) * 100 : 0;
		};
		window.addEventListener('scroll', onScroll, { passive: true });

		// IntersectionObserver for reveals
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
			{ threshold: 0.1, rootMargin: '0px 0px -40px 0px' }
		);
		document.querySelectorAll('[data-reveal]').forEach((el) => observer.observe(el));

		// Counter observer
		const counterObserver = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting && !countersStarted) {
						countersStarted = true;
						animateCounter('accounts', 0, 10000, 2000);
						animateCounter('bits', 0, 256, 1500);
						animateCounter('uptime', 0, 99.9, 1800);
						// leaks stays at 0
					}
				});
			},
			{ threshold: 0.3 }
		);
		const statsEl = document.querySelector('[data-reveal="stats"]');
		if (statsEl) counterObserver.observe(statsEl);

		// CTA typewriter observer
		const ctaObserver = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting && ctaTyped === '') {
						typeWriter();
					}
				});
			},
			{ threshold: 0.5 }
		);
		const ctaEl = document.querySelector('[data-reveal="finalcta"]');
		if (ctaEl) ctaObserver.observe(ctaEl);

		// Magnetic buttons
		if (!isTouchDevice) {
			setTimeout(() => {
				document.querySelectorAll<HTMLElement>('.magnetic-btn').forEach((btn) => {
					btn.addEventListener('mousemove', (e: MouseEvent) => {
						const rect = btn.getBoundingClientRect();
						const x = e.clientX - rect.left - rect.width / 2;
						const y = e.clientY - rect.top - rect.height / 2;
						btn.style.transform = `translate(${x * 0.15}px, ${y * 0.15}px)`;
					});
					btn.addEventListener('mouseleave', () => {
						btn.style.transform = 'translate(0, 0)';
						btn.style.transition = 'transform 0.4s cubic-bezier(0.16, 1, 0.3, 1)';
					});
					btn.addEventListener('mouseenter', () => {
						btn.style.transition = 'transform 0.1s ease-out';
					});
				});
			}, 500);

			// Bento card mouse glow
			setTimeout(() => {
				document.querySelectorAll<HTMLElement>('.bento-card').forEach((card) => {
					card.addEventListener('mousemove', (e: MouseEvent) => {
						const rect = card.getBoundingClientRect();
						const x = e.clientX - rect.left;
						const y = e.clientY - rect.top;
						card.style.setProperty('--card-x', x + 'px');
						card.style.setProperty('--card-y', y + 'px');
					});
				});
			}, 500);

			// Demo card tilt
			setTimeout(() => {
				const demoCard = document.querySelector<HTMLElement>('.demo-tilt');
				if (demoCard) {
					demoCard.addEventListener('mousemove', (e: MouseEvent) => {
						const rect = demoCard.getBoundingClientRect();
						const x = (e.clientX - rect.left) / rect.width - 0.5;
						const y = (e.clientY - rect.top) / rect.height - 0.5;
						demoCard.style.transform = `perspective(800px) rotateY(${x * 8}deg) rotateX(${-y * 8}deg)`;
					});
					demoCard.addEventListener('mouseleave', () => {
						demoCard.style.transform = 'perspective(800px) rotateY(0) rotateX(0)';
						demoCard.style.transition = 'transform 0.5s ease-out';
					});
					demoCard.addEventListener('mouseenter', () => {
						demoCard.style.transition = 'transform 0.1s ease-out';
					});
				}
			}, 500);
		}

		// TOTP countdown
		const totpInterval = setInterval(() => {
			totpSeconds = totpSeconds <= 0 ? 30 : totpSeconds - 1;
		}, 1000);

		// Testimonial carousel
		const testimonialInterval = setInterval(() => {
			activeTestimonial = (activeTestimonial + 1) % testimonials.length;
		}, 5000);

		// Pricing counter observer
		const pricingObserver = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					if (entry.isIntersecting && !pricingCounterStarted) {
						pricingCounterStarted = true;
						animatePricing(0, 4.99, 1600);
					}
				});
			},
			{ threshold: 0.3 }
		);
		const pricingEl = document.querySelector('[data-reveal="pricing"]');
		if (pricingEl) pricingObserver.observe(pricingEl);

		// Easter egg: type "vault" anywhere
		const onKeyDown = (e: KeyboardEvent) => {
			konamiBuffer += e.key.toLowerCase();
			if (konamiBuffer.includes('vault')) {
				triggerParticleBurst();
				konamiBuffer = '';
			}
			if (konamiBuffer.length > 20) konamiBuffer = konamiBuffer.slice(-10);
		};
		window.addEventListener('keydown', onKeyDown);

		return () => {
			observer.disconnect();
			pricingObserver.disconnect();
			window.removeEventListener('scroll', onScroll);
			window.removeEventListener('keydown', onKeyDown);
			clearInterval(totpInterval);
			clearInterval(testimonialInterval);
		};
	});

	function isRevealed(id: string): boolean {
		return revealedSections.has(id);
	}

	function toggleFaq(index: number) {
		openFaq = openFaq === index ? null : index;
	}

	function animateCounter(type: string, start: number, end: number, duration: number) {
		const startTime = performance.now();
		function step(now: number) {
			const elapsed = now - startTime;
			const progress = Math.min(elapsed / duration, 1);
			const eased = 1 - Math.pow(1 - progress, 3);
			const current = start + (end - start) * eased;
			if (type === 'accounts') counterAccounts = Math.round(current);
			else if (type === 'bits') counterBits = Math.round(current);
			else if (type === 'uptime') counterUptime = Math.round(current * 10) / 10;
			if (progress < 1) requestAnimationFrame(step);
		}
		requestAnimationFrame(step);
	}

	function typeWriter() {
		let i = 0;
		function tick() {
			if (i <= ctaFullText.length) {
				ctaTyped = ctaFullText.slice(0, i);
				i++;
				setTimeout(tick, 40 + Math.random() * 30);
			}
		}
		tick();
	}

	function handleCopy() {
		demoCopied = true;
		setTimeout(() => demoCopied = false, 2000);
	}

	function animatePricing(start: number, end: number, duration: number) {
		const startTime = performance.now();
		function step(now: number) {
			const elapsed = now - startTime;
			const progress = Math.min(elapsed / duration, 1);
			const eased = 1 - Math.pow(1 - progress, 3);
			const current = start + (end - start) * eased;
			pricingAmount = current.toFixed(2).replace('.', ',');
			if (progress < 1) requestAnimationFrame(step);
		}
		requestAnimationFrame(step);
	}

	function triggerParticleBurst() {
		showParticles = true;
		setTimeout(() => showParticles = false, 1000);
	}

	// ---- Data ----
	const features = [
		{
			icon: 'shield',
			title: 'Chiffrement militaire',
			description: 'AES-256-GCM avec derivation de cle PBKDF2. Tes donnees sont illisibles sans ton mot de passe maitre.',
			color: 'var(--fv-cyan)',
			size: 'medium',
		},
		{
			icon: 'mail',
			title: 'Emails masques @fyxxmail.com',
			description: 'Cree des alias jetables et recois les messages directement dans la messagerie FyxxVault sans exposer ton vrai email.',
			color: 'var(--fv-violet)',
			size: 'medium',
		},
		{
			icon: 'sync',
			title: 'Sync multi-appareils',
			description: 'Accede a ton coffre sur iPhone, iPad et navigateur. Synchronisation chiffree de bout en bout.',
			color: 'var(--fv-success)',
			size: 'medium',
		},
		{
			icon: 'key',
			title: 'Generateur de mots de passe',
			description: 'Cree des mots de passe forts et uniques en un clic. Personnalise longueur et complexite.',
			color: 'var(--fv-gold)',
			size: 'small',
		},
		{
			icon: 'eye',
			title: 'Dark Web monitoring',
			description: 'Surveillance automatique HIBP. Tu es alerte si un de tes comptes apparait dans une fuite.',
			color: 'var(--fv-rose)',
			size: 'small',
		},
		{
			icon: 'lock',
			title: '2FA integre',
			description: 'Codes TOTP integres pour chaque compte. Plus besoin d\'une app separee comme Google Authenticator.',
			color: 'var(--fv-violet-light)',
			size: 'small',
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
		{ name: 'Prix mensuel', fyxx: 'Gratuit', one: '2,99 USD', bit: '0-3 USD', last: '3 USD' },
		{ name: 'Chiffrement AES-256', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Zero-knowledge', fyxx: true, one: true, bit: true, last: false },
		{ name: 'Comptes illimites', fyxx: true, one: true, bit: true, last: true },
		{ name: '2FA/TOTP integre', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Dark Web monitoring', fyxx: true, one: true, bit: false, last: true },
		{ name: 'Emails masques illimites', fyxx: true, one: true, bit: false, last: false },
		{ name: 'Generateur d\'identite fictive', fyxx: true, one: false, bit: false, last: false },
		{ name: 'Mode panique', fyxx: true, one: false, bit: false, last: false },
		{ name: 'Partage chiffre', fyxx: true, one: true, bit: true, last: true },
		{ name: 'Open Source', fyxx: true, one: false, bit: true, last: false },
	];

	const freeFeatures = [
		'Comptes illimites',
		'Chiffrement AES-256',
		'Synchronisation cloud',
		'Codes TOTP integres',
		'Generateur de mots de passe',
		'Generateur d\'identite fictive',
	];

	const proFeatures = [
		'Surveillance Dark Web',
		'Emails masques illimites',
		'Partage securise',
		'Mode panique',
		'Open Source',
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
			a: 'Oui ! FyxxVault est 100% gratuit, sans limites. Stockage illimite, monitoring dark web, emails masques — tout est inclus pour tout le monde.',
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
			q: 'FyxxVault fonctionne sur quelles plateformes ?',
			a: 'iOS (iPhone + iPad), Web (fyxxvault.com), et desktop (Mac, Windows, Linux) via l\'app web installable. Une app native macOS est prevue.',
		},
	];

	function getFilteredFaqs() {
		if (!faqSearch.trim()) return faqs;
		const s = faqSearch.toLowerCase();
		return faqs.filter(f => f.q.toLowerCase().includes(s) || f.a.toLowerCase().includes(s));
	}
</script>

<svelte:head>
	<title>FyxxVault — Ton coffre-fort numerique</title>
	<meta name="description" content="FyxxVault — Le gestionnaire de mots de passe nouvelle generation. Chiffrement AES-256, zero-knowledge, surveillance dark web." />
</svelte:head>

<!-- Welcome back overlay (shown when session exists) -->
{#if hasSession && !showLanding && sessionChecked}
	<div style="position:fixed;inset:0;z-index:9999;background:#050a15;display:flex;align-items:center;justify-content:center;padding:1.5rem;">
		<div style="position:absolute;top:25%;left:25%;width:500px;height:500px;border-radius:50%;background:#00d4ff;opacity:0.04;filter:blur(120px);"></div>
		<div style="position:absolute;bottom:25%;right:25%;width:400px;height:400px;border-radius:50%;background:#8a5cf6;opacity:0.04;filter:blur(120px);"></div>

		<div style="position:relative;z-index:10;width:100%;max-width:28rem;text-align:center;animation:wbFadeIn 0.6s ease both;">
			<div style="display:inline-flex;align-items:center;justify-content:center;width:5rem;height:5rem;border-radius:1rem;background:linear-gradient(135deg,#00d4ff,#8a5cf6);margin-bottom:2rem;box-shadow:0 0 40px rgba(0,212,255,0.2),0 0 80px rgba(138,92,246,0.1);">
				<svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5">
					<rect x="3" y="11" width="18" height="11" rx="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
			</div>

			<h1 style="font-size:1.875rem;font-weight:800;color:white;margin-bottom:0.5rem;letter-spacing:-0.025em;">Bon retour</h1>
			<p style="font-size:0.875rem;color:#788a9f;margin-bottom:2.5rem;">
				Connecte en tant que <span style="color:#00d4ff;">{sessionEmail}</span>
			</p>

			<div style="display:flex;flex-direction:column;gap:0.75rem;">
				<a
					href="/vault/unlock"
					style="display:flex;align-items:center;justify-content:center;gap:0.75rem;width:100%;padding:1rem;border-radius:1rem;color:white;font-weight:700;font-size:0.875rem;text-decoration:none;background:linear-gradient(135deg,#00d4ff,#8a5cf6);box-shadow:0 8px 32px rgba(0,212,255,0.25);transition:transform 0.2s;"
				>
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
					Ouvrir mon coffre
				</a>
				<button
					onclick={() => showLanding = true}
					style="display:flex;align-items:center;justify-content:center;gap:0.5rem;width:100%;padding:1rem;border-radius:1rem;color:#b4c3d7;font-weight:500;font-size:0.875rem;background:rgba(255,255,255,0.03);border:1px solid rgba(255,255,255,0.06);cursor:pointer;transition:all 0.2s;"
				>
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>
					Visiter le site
				</button>
			</div>

			<p style="font-size:10px;color:#3a4a5c;margin-top:2.5rem;display:flex;align-items:center;justify-content:center;gap:0.375rem;">
				<svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
				Chiffrement AES-256 · Zero-Knowledge
			</p>
		</div>
	</div>
{/if}

<!-- Scroll progress bar -->
<div class="scroll-progress" style="width: {scrollProgress}%"></div>

<!-- Film grain overlay -->
<div class="grain"></div>

<!-- Mouse-following spotlight -->
<div class="mouse-spotlight"></div>

<div class="landing landing-bg-animate">
	<Navbar />

	<!-- Easter egg particle burst -->
	{#if showParticles}
		<div class="particle-burst">
			{#each Array(30) as _, i}
				{@const angle = (i / 30) * Math.PI * 2 + (Math.random() - 0.5) * 0.5}
				{@const dist = 80 + Math.random() * 200}
				<div
					class="gold-particle"
					style="--px: {Math.cos(angle) * dist}px; --py: {Math.sin(angle) * dist}px; animation-delay: {Math.random() * 0.15}s; width: {4 + Math.random() * 5}px; height: {4 + Math.random() * 5}px;"
				></div>
			{/each}
		</div>
	{/if}

	<!-- ============================================================ -->
	<!-- HERO SECTION -->
	<!-- ============================================================ -->
	<section class="hero">
		<div class="hero-bg">
			<div class="hero-orb hero-orb--1" style="transform: translateY({scrollY * -0.15}px)"></div>
			<div class="hero-orb hero-orb--2" style="transform: translateY({scrollY * -0.08}px)"></div>
			<div class="hero-orb hero-orb--3" style="transform: translateY({scrollY * -0.12}px)"></div>
			<div class="hero-particles"></div>
			<div class="hero-grid"></div>
		</div>

		<div class="hero-content" class:hero-content--visible={heroVisible}>
			<!-- Pill badge -->
			<div class="hero-badge">
				<span class="hero-badge-dot"></span>
				<span>Chiffrement de bout en bout</span>
			</div>

			<h1 class="hero-title">
				<span class="reveal-word" style="animation-delay: 0s">Tes</span>{' '}
				<span class="reveal-word" style="animation-delay: 0.08s">mots</span>{' '}
				<span class="reveal-word" style="animation-delay: 0.16s">de</span>{' '}
				<span class="reveal-word" style="animation-delay: 0.24s">passe</span>
				<br />
				<span class="reveal-word hero-title-gold" style="animation-delay: 0.4s">meritent</span>{' '}
				<span class="reveal-word hero-title-gold" style="animation-delay: 0.48s">mieux.</span>
			</h1>

			<p class="hero-subtitle">
				FyxxVault est le gestionnaire de mots de passe nouvelle generation.<br />
				Chiffrement zero-knowledge, sync instantanee, surveillance du dark web.
			</p>

			<div style="display: flex; gap: 10px; justify-content: center; margin-bottom: 16px; flex-wrap: wrap;">
				<a href="https://github.com/Fyxx20/FyxxVault" target="_blank" rel="noopener" style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px; border-radius: 20px; background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.1); color: #E2E8F0; font-size: 12px; font-weight: 600; text-decoration: none; transition: all 0.2s;">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0C5.37 0 0 5.37 0 12c0 5.3 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61-.546-1.385-1.335-1.755-1.335-1.755-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 21.795 24 17.295 24 12c0-6.63-5.37-12-12-12"/></svg>
					Open Source
				</a>
				<span style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px; border-radius: 20px; background: rgba(0,212,255,0.08); border: 1px solid rgba(0,212,255,0.2); color: #00D4FF; font-size: 12px; font-weight: 600;">
					100% Gratuit
				</span>
				<span style="display: inline-flex; align-items: center; gap: 6px; padding: 6px 14px; border-radius: 20px; background: rgba(34,197,94,0.08); border: 1px solid rgba(34,197,94,0.2); color: #22C55E; font-size: 12px; font-weight: 600;">
					GPLv3
				</span>
			</div>

			<div class="hero-ctas">
				<a href="/register" class="hero-cta-primary magnetic-btn">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
					Commencer gratuitement
				</a>
				<a href="#demo" class="hero-cta-ghost magnetic-btn">
					<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
					Voir la demo
				</a>
			</div>

			<div class="hero-trust">
				<span class="hero-trust-item trust-tooltip-wrap">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					AES-256
					<span class="trust-tooltip">Chiffrement de grade militaire, utilisé par les gouvernements.</span>
				</span>
				<span class="hero-trust-sep"></span>
				<span class="hero-trust-item trust-tooltip-wrap">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					Zero-knowledge
					<span class="trust-tooltip">Personne, pas meme nous, ne peut lire tes données.</span>
				</span>
				<span class="hero-trust-sep"></span>
				<span class="hero-trust-item trust-tooltip-wrap">
					<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
					Multi-plateforme
					<span class="trust-tooltip">Disponible sur iOS, Web, et bientot desktop natif.</span>
				</span>
			</div>
		</div>

		<div class="hero-scroll-indicator" style="opacity: {1 - scrollY * 0.01}">
			<div class="hero-scroll-mouse">
				<div class="hero-scroll-wheel"></div>
			</div>
			<span>Scroll</span>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- STATS BAR -->
	<!-- ============================================================ -->
	<section class="stats" data-reveal="stats">
		<div class="stats-inner" class:revealed={isRevealed('stats')}>
			<div class="stat-item">
				<span class="stat-number">{counterAccounts.toLocaleString('fr-FR')}+</span>
				<span class="stat-label">comptes proteges</span>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<span class="stat-number">AES-{counterBits}</span>
				<span class="stat-label">bits de chiffrement</span>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<span class="stat-number">{counterUptime}%</span>
				<span class="stat-label">uptime garanti</span>
			</div>
			<div class="stat-divider"></div>
			<div class="stat-item">
				<span class="stat-number">{counterLeaks}</span>
				<span class="stat-label">fuites de donnees</span>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- BENTO FEATURES -->
	<!-- ============================================================ -->
	<section id="features" class="features" data-reveal="features">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('features')}>
				<span class="section-pill" style="--pill-color: var(--fv-cyan)">Fonctionnalites</span>
				<h2 class="section-title">Tout ce qu'il te faut.</h2>
				<p class="section-subtitle">Plus qu'un gestionnaire de mots de passe — un veritable hub de securite.</p>
			</div>

			<div class="bento-grid" class:revealed={isRevealed('features')}>
				{#each features as feature, i}
					<div
						class="bento-card bento-card--{feature.size}"
						style="--reveal-delay: {i * 80}ms; --accent: {feature.color}; --card-x: 50%; --card-y: 50%"
					>
						<div class="bento-card-glow"></div>
						<div class="bento-card-border"></div>
						<div class="bento-card-content">
							<div class="bento-card-icon">
								{#if feature.icon === 'shield'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
								{:else if feature.icon === 'zap'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
								{:else if feature.icon === 'mail'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><rect x="2.5" y="4.5" width="19" height="15" rx="2"/><path d="m3 6 9 7 9-7"/></svg>
								{:else if feature.icon === 'sync'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
								{:else if feature.icon === 'key'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
								{:else if feature.icon === 'eye'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
								{:else if feature.icon === 'lock'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={feature.color} stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
								{/if}
							</div>
							<h3 class="bento-card-title">{feature.title}</h3>
							<p class="bento-card-desc">{feature.description}</p>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- INTERACTIVE DEMO -->
	<!-- ============================================================ -->
	<section id="demo" class="demo" data-reveal="demo">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('demo')}>
				<span class="section-pill" style="--pill-color: var(--fv-gold)">Demo interactive</span>
				<h2 class="section-title">Essaie par toi-meme.</h2>
				<p class="section-subtitle">Un apercu de l'experience FyxxVault. Clique, explore, decouvre.</p>
			</div>

			<div class="demo-container" class:revealed={isRevealed('demo')}>
				<div class="demo-glow"></div>
				<div class="demo-tilt">
					<div class="demo-card">
						<div class="demo-card-header">
							<div class="demo-card-icon">
								<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M8 14s1.5 2 4 2 4-2 4-2"/><line x1="9" y1="9" x2="9.01" y2="9"/><line x1="15" y1="9" x2="15.01" y2="9"/></svg>
							</div>
							<div class="demo-card-info">
								<span class="demo-card-site">Google</span>
								<span class="demo-card-email">user@fyxxmail.com</span>
							</div>
							<div class="demo-card-badge">2FA</div>
						</div>

						<div class="demo-field">
							<span class="demo-field-label">Mot de passe</span>
							<div class="demo-field-row">
								<span class="demo-field-value">
									{#if demoPasswordVisible}
										kX9#mP2$vL7@nQ4
									{:else}
										&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;&#x2022;
									{/if}
								</span>
								<button class="demo-field-btn" onclick={() => demoPasswordVisible = !demoPasswordVisible} aria-label="Toggle password">
									{#if demoPasswordVisible}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
									{:else}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
									{/if}
								</button>
								<button class="demo-field-btn demo-copy-btn" onclick={handleCopy} aria-label="Copy">
									{#if demoCopied}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
									{:else}
										<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
									{/if}
								</button>
							</div>
							{#if demoCopied}
								<span class="demo-copied-toast">Copie !</span>
							{/if}
						</div>

						<div class="demo-totp">
							<span class="demo-totp-label">Code TOTP</span>
							<div class="demo-totp-row">
								<span class="demo-totp-code">4&nbsp;8&nbsp;3&nbsp;&nbsp;7&nbsp;2&nbsp;1</span>
								<div class="demo-totp-timer">
									<svg width="24" height="24" viewBox="0 0 24 24">
										<circle cx="12" cy="12" r="10" fill="none" stroke="rgba(255,255,255,0.1)" stroke-width="2"/>
										<circle cx="12" cy="12" r="10" fill="none" stroke={totpSeconds > 10 ? 'var(--fv-cyan)' : 'var(--fv-rose)'} stroke-width="2" stroke-dasharray="62.83" stroke-dashoffset={62.83 - (62.83 * totpSeconds / 30)} stroke-linecap="round" transform="rotate(-90 12 12)" style="transition: stroke-dashoffset 1s linear, stroke 0.3s ease"/>
										<text x="12" y="16" text-anchor="middle" fill="white" font-size="10" font-weight="600">{totpSeconds}</text>
									</svg>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- SECURITY SECTION -->
	<!-- ============================================================ -->
	<section id="security" class="security" data-reveal="security">
		<div class="security-bg" style="transform: translateY({scrollY * -0.05}px)"></div>
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('security')}>
				<span class="section-pill" style="--pill-color: var(--fv-success)">Securite</span>
				<h2 class="section-title">La securite dans notre ADN.</h2>
				<p class="section-subtitle">Chaque decision d'architecture est prise pour que personne ne puisse acceder a tes donnees.</p>
			</div>

			<div class="security-grid" class:revealed={isRevealed('security')}>
				{#each securityItems as item, i}
					<div class="security-card bento-card" style="--reveal-delay: {i * 120}ms; --accent: {item.color}; --card-x: 50%; --card-y: 50%">
						<div class="bento-card-glow"></div>
						<div class="bento-card-border"></div>
						<div class="security-card-inner">
							<div class="security-card-icon">
								{#if item.icon === 'lock'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="1.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
								{:else if item.icon === 'cpu'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="1.5"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><line x1="9" y1="1" x2="9" y2="4"/><line x1="15" y1="1" x2="15" y2="4"/><line x1="9" y1="20" x2="9" y2="23"/><line x1="15" y1="20" x2="15" y2="23"/><line x1="20" y1="9" x2="23" y2="9"/><line x1="20" y1="14" x2="23" y2="14"/><line x1="1" y1="9" x2="4" y2="9"/><line x1="1" y1="14" x2="4" y2="14"/></svg>
								{:else if item.icon === 'eye-off'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="1.5"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
								{:else if item.icon === 'alert'}
									<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke={item.color} stroke-width="1.5"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
								{/if}
							</div>
							<h3 class="security-card-label">{item.label}</h3>
							<p class="security-card-detail">{item.detail}</p>
						</div>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- HOW IT WORKS -->
	<!-- ============================================================ -->
	<section class="steps" data-reveal="steps">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('steps')}>
				<span class="section-pill" style="--pill-color: var(--fv-violet)">Comment ca marche</span>
				<h2 class="section-title">3 etapes. C'est tout.</h2>
				<p class="section-subtitle">De l'inscription a la securite totale en moins de 2 minutes.</p>
			</div>

			<div class="steps-grid" class:revealed={isRevealed('steps')}>
				{#each steps as step, i}
					<div class="step-card" style="--reveal-delay: {i * 150}ms">
						{#if i < steps.length - 1}
							<div class="step-connector"></div>
						{/if}
						<div class="step-num">{step.num}</div>
						<h3 class="step-title">{step.title}</h3>
						<p class="step-desc">{step.description}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- COMPARISON TABLE -->
	<!-- ============================================================ -->
	<section class="comparison" data-reveal="comparison">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('comparison')}>
				<span class="section-pill" style="--pill-color: var(--fv-rose)">Comparaison</span>
				<h2 class="section-title">Pourquoi FyxxVault ?</h2>
				<p class="section-subtitle">Compare les fonctionnalites et fais ton choix.</p>
			</div>

			<div class="comparison-table-wrap" class:revealed={isRevealed('comparison')}>
				<table class="comparison-table">
					<thead>
						<tr>
							<th class="comparison-th-feature">Fonctionnalite</th>
							<th class="comparison-th-highlight">FyxxVault</th>
							<th>1Password</th>
							<th>Bitwarden</th>
							<th>LastPass</th>
						</tr>
					</thead>
					<tbody>
						{#each comparisonFeatures as row}
							<tr class="comparison-row">
								<td class="comparison-feature-name">{row.name}</td>
								<td class="comparison-highlight-cell">
									{#if typeof row.fyxx === 'boolean'}
										{#if row.fyxx}
											<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
										{:else}
											<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-ash)" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>
										{/if}
									{:else}
										<span class="comparison-text-value">{row.fyxx}</span>
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
										<span class="comparison-dim">{row.one}</span>
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
										<span class="comparison-dim">{row.bit}</span>
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
										<span class="comparison-dim">{row.last}</span>
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
	<!-- EXTENSION SECTION -->
	<!-- ============================================================ -->
	<section id="extension" class="extension" data-reveal="extension">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('extension')}>
				<span class="section-pill" style="--pill-color: var(--fv-cyan)">Extension Chrome</span>
				<h2 class="section-title">Autofill sur tous tes sites.</h2>
				<p class="section-subtitle">Installe l'extension et tes identifiants se remplissent automatiquement.</p>
			</div>

			<div class="ext-card" class:revealed={isRevealed('extension')}>
				<div class="ext-card-inner">
					<div class="ext-left">
						<div class="ext-icon-row">
							<div class="ext-logo">
								<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="48" height="48">
									<defs><linearGradient id="ebg" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#0A101E"/><stop offset="100%" stop-color="#162A42"/></linearGradient><linearGradient id="elk" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#00D4FF"/><stop offset="100%" stop-color="#8A5CF6"/></linearGradient></defs>
									<rect width="512" height="512" rx="108" fill="url(#ebg)"/>
									<g transform="translate(256,240)" fill="url(#elk)"><rect x="-80" y="-10" width="160" height="120" rx="20"/><path d="M-50,-10 L-50,-60 C-50,-95 50,-95 50,-60 L50,-10" fill="none" stroke="url(#elk)" stroke-width="24" stroke-linecap="round"/><circle cx="0" cy="45" r="18" fill="#0A101E"/><rect x="-6" y="45" width="12" height="25" rx="4" fill="#0A101E"/></g>
								</svg>
							</div>
							<div>
								<div class="ext-name">FyxxVault – Autofill</div>
								<div class="ext-rating">
									<span class="ext-stars">★★★★★</span>
									<span class="ext-label">Extension Chrome</span>
								</div>
							</div>
						</div>
						<ul class="ext-features">
							<li>Remplissage automatique email + mot de passe</li>
							<li>Sauvegarde des nouveaux identifiants</li>
							<li>Import depuis Chrome en 1 clic</li>
							<li>Codes 2FA / TOTP automatiques</li>
							<li>Zero-knowledge — tout est chiffre</li>
						</ul>
						<a href="https://chromewebstore.google.com/detail/fyxxvault-%E2%80%93-autofill/pacioaldmfoppgnaieonkgjbipdeloll" target="_blank" rel="noopener" class="ext-cta">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="10" stroke="currentColor" stroke-width="2"/><path d="M12 16.5c2.49 0 4.5-2.01 4.5-4.5S14.49 7.5 12 7.5 7.5 9.51 7.5 12s2.01 4.5 4.5 4.5z" fill="currentColor" opacity="0.3"/><path d="M3.47 8.5L7.5 12H3c0-1.24.17-2.43.47-3.5z" fill="#EA4335"/><path d="M3.47 8.5A9 9 0 0112 3v4.5c-1.93 0-3.6 1.22-4.24 2.93L3.47 8.5z" fill="#FBBC05"/><path d="M12 3a9 9 0 017.94 4.77L16.24 10.43A4.49 4.49 0 0012 7.5V3z" fill="#4285F4"/><path d="M19.94 7.77A9 9 0 0121 12h-4.5c0-.87-.25-1.68-.68-2.37l4.12-1.86z" fill="#4285F4"/></svg>
							Ajouter a Chrome — Gratuit
						</a>
						<div class="ext-compat">Fonctionne aussi sur Edge, Brave, Arc et Opera</div>
					</div>
					<div class="ext-right">
						<div class="ext-mockup">
							<div class="ext-popup-mock">
								<div class="ext-popup-header">
									<div class="ext-popup-logo"></div>
									<span>FyxxVault</span>
								</div>
								<div class="ext-popup-search">Rechercher...</div>
								<div class="ext-popup-item">
									<div class="ext-popup-favicon" style="background:#E34133">N</div>
									<div><div class="ext-popup-title">Netflix</div><div class="ext-popup-user">test@fyxxmail.com</div></div>
								</div>
								<div class="ext-popup-item">
									<div class="ext-popup-favicon" style="background:#003580">B</div>
									<div><div class="ext-popup-title">Booking</div><div class="ext-popup-user">test@fyxxmail.com</div></div>
								</div>
								<div class="ext-popup-item">
									<div class="ext-popup-favicon" style="background:#3ECF8E">S</div>
									<div><div class="ext-popup-title">Supabase</div><div class="ext-popup-user">test@fyxxmail.com</div></div>
								</div>
							</div>
						</div>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- PRICING SECTION -->
	<!-- ============================================================ -->
	<section id="pricing" class="pricing" data-reveal="pricing">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('pricing')}>
				<span class="section-pill" style="--pill-color: var(--fv-cyan)">Gratuit</span>
				<h2 class="section-title">100% gratuit. Pour toujours.</h2>
				<p class="section-subtitle">Pas de plan payant. Pas de limites. Toutes les fonctionnalites pour tout le monde.</p>
			</div>

			<div class="pricing-grid" class:revealed={isRevealed('pricing')}>
				<div class="pricing-card pricing-card--pro" style="--reveal-delay: 0ms">
					<div class="pricing-card-border pricing-card-border--gold"></div>
					<div class="pricing-card-popular">Open Source</div>
					<div class="pricing-card-inner">
						<div class="pricing-card-header">
							<h3 class="pricing-card-name">FyxxVault</h3>
							<p class="pricing-card-tagline">Securite maximale, zero compromis</p>
						</div>
						<div class="pricing-card-price">
							<span class="pricing-card-amount">0</span>
							<span class="pricing-card-currency">EUR</span>
							<span class="pricing-card-period">/toujours</span>
						</div>
						<ul class="pricing-card-features">
							{#each [...freeFeatures, ...proFeatures] as f}
								<li>
									<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
									{f}
								</li>
							{/each}
						</ul>
						<a href="/register" class="pricing-card-cta pricing-card-cta--gold magnetic-btn">Creer un compte gratuit</a>
					</div>
				</div>
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- TESTIMONIALS -->
	<!-- ============================================================ -->
	<section class="testimonials" data-reveal="testimonials">
		<div class="section-inner">
			<div class="section-header" class:revealed={isRevealed('testimonials')}>
				<span class="section-pill" style="--pill-color: var(--fv-violet)">Temoignages</span>
				<h2 class="section-title">Ils nous font confiance.</h2>
			</div>

			<div class="testimonials-grid" class:revealed={isRevealed('testimonials')}>
				{#each testimonials as t, i}
					<div
						class="testimonial-card"
						class:testimonial-card--active={activeTestimonial === i}
						style="--reveal-delay: {i * 120}ms; --accent: {t.color}"
					>
						<div class="testimonial-gradient-bar"></div>
						<div class="testimonial-stars">
							{#each Array(t.stars) as _}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="var(--fv-gold)" stroke="none"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>
							{/each}
						</div>
						<p class="testimonial-text">{t.text}</p>
						<div class="testimonial-author">
							<div class="testimonial-avatar" style="--avatar-color: {t.color}">{t.initials}</div>
							<div>
								<div class="testimonial-name">{t.name}</div>
								<div class="testimonial-role">{t.role}</div>
							</div>
						</div>
					</div>
				{/each}
			</div>
			<div class="testimonials-dots">
				{#each testimonials as _, i}
					<button
						class="testimonial-dot"
						class:testimonial-dot--active={activeTestimonial === i}
						onclick={() => activeTestimonial = i}
						aria-label="Testimonial {i + 1}"
					></button>
				{/each}
			</div>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FAQ -->
	<!-- ============================================================ -->
	<section id="faq" class="faq" data-reveal="faq">
		<div class="section-inner section-inner--narrow">
			<div class="section-header" class:revealed={isRevealed('faq')}>
				<span class="section-pill" style="--pill-color: var(--fv-cyan)">FAQ</span>
				<h2 class="section-title">Questions frequentes</h2>
			</div>

			<div class="faq-search" class:revealed={isRevealed('faq')}>
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-smoke)" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
				<input type="text" placeholder="Rechercher..." bind:value={faqSearch} class="faq-search-input" />
			</div>

			<div class="faq-list" class:revealed={isRevealed('faq')}>
				{#each getFilteredFaqs() as faq, i}
					<div class="faq-item" class:faq-item--open={openFaq === i}>
						<button class="faq-question" onclick={() => toggleFaq(i)}>
							<span>{faq.q}</span>
							<svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
						</button>
						<div class="faq-answer-wrap" style="grid-template-rows: {openFaq === i ? '1fr' : '0fr'}">
							<div class="faq-answer">
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
	<section class="final-cta" data-reveal="finalcta">
		<div class="final-cta-bg">
			<div class="final-cta-orb final-cta-orb--1"></div>
			<div class="final-cta-orb final-cta-orb--2"></div>
		</div>
		<div class="section-inner final-cta-content" class:revealed={isRevealed('finalcta')}>
			<h2 class="final-cta-title">
				{ctaTyped}<span class="cta-cursor">|</span>
			</h2>
			<p class="final-cta-subtitle">Rejoins des milliers d'utilisateurs qui protegent leurs mots de passe avec FyxxVault.</p>
			<a href="/register" class="final-cta-btn magnetic-btn">
				Commencer gratuitement
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
			</a>
		</div>
	</section>

	<!-- ============================================================ -->
	<!-- FOOTER -->
	<!-- ============================================================ -->
	<footer class="footer">
		<div class="footer-inner">
			<div class="footer-grid">
				<div class="footer-brand">
					<div class="footer-logo">
						<div class="footer-logo-icon">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
						</div>
						<span>FyxxVault</span>
					</div>
					<p class="footer-desc">Le gestionnaire de mots de passe nouvelle generation. Securite sans compromis.</p>
					<div class="footer-socials">
						<a href="https://twitter.com/fyxxvault" aria-label="Twitter" class="footer-social">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
						</a>
						<a href="https://github.com/Fyxx20/FyxxVault" aria-label="GitHub" class="footer-social">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
						</a>
					</div>
				</div>

				<div class="footer-col">
					<h4>Produit</h4>
					<a href="#features">Fonctionnalites</a>
					<a href="#security">Securite</a>
					<a href="#pricing">Prix</a>
					<a href="/login">Web App</a>
				</div>
				<div class="footer-col">
					<h4>Legal</h4>
					<a href="/privacy">Politique de confidentialite</a>
					<a href="/terms">CGV</a>
					<a href="/mentions-legales">Mentions legales</a>
				</div>
				<div class="footer-col">
					<h4>Support</h4>
					<a href="mailto:support@fyxxvault.com">Contact</a>
					<a href="#faq">FAQ</a>
					<a href="/blog">Blog</a>
				</div>
			</div>

			<div class="footer-bottom">
				<p>&copy; 2026 FyxxVault. Tous droits reserves.</p>
				<div class="footer-badges">
					<span>AES-256</span>
					<span>Zero-Knowledge</span>
					<span>E2E</span>
				</div>
			</div>
		</div>
	</footer>
</div>

<style>
	@keyframes wbFadeIn {
		from { opacity: 0; transform: translateY(20px); }
		to { opacity: 1; transform: translateY(0); }
	}

	/* ============================================================ */
	/* CSS CUSTOM PROPERTIES & KEYFRAMES */
	/* ============================================================ */
	:root {
		--mouse-x: 50vw;
		--mouse-y: 50vh;
		--angle: 0deg;
	}

	@property --angle {
		syntax: '<angle>';
		initial-value: 0deg;
		inherits: false;
	}

	@keyframes revealWord {
		from { opacity: 0; transform: translateY(30px) scale(0.97); }
		to { opacity: 1; transform: translateY(0) scale(1); }
	}

	@keyframes rotateGradient {
		to { --angle: 360deg; }
	}

	@keyframes fadeInUp {
		from { opacity: 0; transform: translateY(40px); }
		to { opacity: 1; transform: translateY(0); }
	}

	@keyframes scaleIn {
		from { opacity: 0; transform: scale(0.8); }
		to { opacity: 1; transform: scale(1); }
	}

	@keyframes slideInBottom {
		from { opacity: 0; transform: translateY(60px); }
		to { opacity: 1; transform: translateY(0); }
	}

	@keyframes float {
		0%, 100% { transform: translateY(0); }
		50% { transform: translateY(-10px); }
	}

	@keyframes pulse {
		0%, 100% { opacity: 1; }
		50% { opacity: 0.5; }
	}

	@keyframes shimmer {
		0% { background-position: -200% 0; }
		100% { background-position: 200% 0; }
	}

	@keyframes scrollWheel {
		0% { transform: translateY(0); opacity: 1; }
		100% { transform: translateY(6px); opacity: 0; }
	}

	@keyframes blink {
		0%, 100% { opacity: 1; }
		50% { opacity: 0; }
	}

	@keyframes dashMove {
		to { stroke-dashoffset: -20; }
	}

	@keyframes popularPulse {
		0%, 100% { box-shadow: 0 0 0 0 rgba(255, 200, 55, 0.4); }
		50% { box-shadow: 0 0 0 8px rgba(255, 200, 55, 0); }
	}

	@keyframes orbFloat1 {
		0%, 100% { transform: translate(0, 0) scale(1); }
		33% { transform: translate(30px, -50px) scale(1.05); }
		66% { transform: translate(-20px, 20px) scale(0.95); }
	}

	@keyframes orbFloat2 {
		0%, 100% { transform: translate(0, 0) scale(1); }
		33% { transform: translate(-40px, 30px) scale(0.95); }
		66% { transform: translate(50px, -20px) scale(1.05); }
	}

	/* ============================================================ */
	/* SCROLL PROGRESS */
	/* ============================================================ */
	.scroll-progress {
		position: fixed;
		top: 0;
		left: 0;
		height: 2px;
		background: linear-gradient(90deg, var(--fv-cyan), var(--fv-violet));
		z-index: 10000;
		transition: width 0.1s linear;
	}

	/* ============================================================ */
	/* GRAIN OVERLAY */
	/* ============================================================ */
	.grain::after {
		content: '';
		position: fixed;
		inset: 0;
		background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E");
		opacity: 0.025;
		pointer-events: none;
		z-index: 9999;
	}

	/* ============================================================ */
	/* MOUSE SPOTLIGHT */
	/* ============================================================ */
	.mouse-spotlight {
		position: fixed;
		inset: 0;
		background: radial-gradient(600px circle at var(--mouse-x) var(--mouse-y), rgba(0, 212, 255, 0.04), transparent 40%);
		pointer-events: none;
		z-index: 1;
	}

	/* ============================================================ */
	/* LANDING BASE */
	/* ============================================================ */
	.landing {
		min-height: 100vh;
		background: var(--fv-abyss);
		overflow-x: hidden;
		position: relative;
	}

	/* ============================================================ */
	/* SECTION SHARED */
	/* ============================================================ */
	.section-inner {
		max-width: 1200px;
		margin: 0 auto;
		padding: 0 24px;
	}
	.section-inner--narrow {
		max-width: 800px;
	}
	.section-header {
		text-align: center;
		margin-bottom: 64px;
		opacity: 0;
		transform: translateY(30px);
		transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.section-header.revealed {
		opacity: 1;
		transform: translateY(0);
	}
	.section-pill {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		padding: 6px 16px;
		border-radius: 100px;
		font-size: 12px;
		font-weight: 700;
		letter-spacing: 1.5px;
		text-transform: uppercase;
		color: var(--pill-color);
		background: color-mix(in srgb, var(--pill-color) 10%, transparent);
		border: 1px solid color-mix(in srgb, var(--pill-color) 20%, transparent);
		margin-bottom: 20px;
	}
	.section-title {
		font-size: clamp(32px, 5vw, 48px);
		font-weight: 800;
		color: white;
		line-height: 1.15;
		margin: 0 0 16px;
		letter-spacing: -0.02em;
	}
	.section-subtitle {
		font-size: 18px;
		color: var(--fv-smoke);
		line-height: 1.6;
		max-width: 600px;
		margin: 0 auto;
	}

	/* ============================================================ */
	/* HERO */
	/* ============================================================ */
	.hero {
		position: relative;
		min-height: 100vh;
		display: flex;
		flex-direction: column;
		align-items: center;
		justify-content: center;
		padding: 120px 24px 80px;
		overflow: hidden;
	}

	.hero-bg {
		position: absolute;
		inset: 0;
		overflow: hidden;
	}

	.hero-orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(100px);
		will-change: transform;
	}
	.hero-orb--1 {
		width: 600px;
		height: 600px;
		background: radial-gradient(circle, rgba(0, 212, 255, 0.12), transparent 70%);
		top: -200px;
		left: -100px;
		animation: orbFloat1 20s ease-in-out infinite;
	}
	.hero-orb--2 {
		width: 500px;
		height: 500px;
		background: radial-gradient(circle, rgba(138, 92, 246, 0.1), transparent 70%);
		top: -100px;
		right: -150px;
		animation: orbFloat2 25s ease-in-out infinite;
	}
	.hero-orb--3 {
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, rgba(255, 200, 55, 0.06), transparent 70%);
		bottom: -100px;
		left: 30%;
		animation: orbFloat1 18s ease-in-out infinite reverse;
	}

	.hero-particles {
		position: absolute;
		inset: 0;
	}
	.hero-particles::before,
	.hero-particles::after {
		content: '';
		position: absolute;
		width: 2px;
		height: 2px;
		border-radius: 50%;
		animation: float 6s ease-in-out infinite;
	}
	.hero-particles::before {
		box-shadow:
			100px 100px 0 rgba(0, 212, 255, 0.3),
			300px 200px 0 rgba(138, 92, 246, 0.2),
			500px 150px 0 rgba(255, 200, 55, 0.2),
			700px 300px 0 rgba(0, 212, 255, 0.15),
			200px 400px 0 rgba(138, 92, 246, 0.25),
			900px 100px 0 rgba(255, 55, 130, 0.15),
			150px 350px 0 rgba(0, 212, 255, 0.2),
			800px 250px 0 rgba(138, 92, 246, 0.15),
			400px 500px 0 rgba(255, 200, 55, 0.2),
			600px 50px 0 rgba(0, 212, 255, 0.1),
			1000px 400px 0 rgba(138, 92, 246, 0.2),
			50px 250px 0 rgba(255, 200, 55, 0.15);
	}
	.hero-particles::after {
		box-shadow:
			250px 150px 0 rgba(138, 92, 246, 0.2),
			450px 350px 0 rgba(0, 212, 255, 0.15),
			650px 100px 0 rgba(255, 200, 55, 0.2),
			850px 450px 0 rgba(0, 212, 255, 0.2),
			350px 50px 0 rgba(138, 92, 246, 0.15),
			50px 500px 0 rgba(255, 55, 130, 0.2),
			750px 200px 0 rgba(0, 212, 255, 0.15),
			550px 400px 0 rgba(255, 200, 55, 0.1);
		animation-delay: -3s;
	}

	.hero-grid {
		position: absolute;
		inset: 0;
		background-image:
			linear-gradient(rgba(255, 255, 255, 0.02) 1px, transparent 1px),
			linear-gradient(90deg, rgba(255, 255, 255, 0.02) 1px, transparent 1px);
		background-size: 80px 80px;
		mask-image: radial-gradient(ellipse 60% 50% at 50% 50%, black, transparent);
	}

	.hero-content {
		position: relative;
		z-index: 2;
		text-align: center;
		max-width: 800px;
		opacity: 0;
		transition: opacity 0.3s ease;
	}
	.hero-content--visible {
		opacity: 1;
	}

	.hero-badge {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		padding: 8px 20px;
		border-radius: 100px;
		font-size: 13px;
		font-weight: 600;
		color: var(--fv-cyan);
		background: rgba(0, 212, 255, 0.08);
		border: 1px solid rgba(0, 212, 255, 0.15);
		margin-bottom: 32px;
		backdrop-filter: blur(10px);
	}
	.hero-badge-dot {
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background: var(--fv-success);
		animation: pulse 2s ease-in-out infinite;
	}

	.hero-title {
		font-size: clamp(42px, 7vw, 80px);
		font-weight: 850;
		line-height: 1.05;
		letter-spacing: -0.03em;
		color: white;
		margin: 0 0 24px;
	}

	.reveal-word {
		display: inline-block;
		opacity: 0;
		transform: translateY(30px);
		animation: revealWord 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}
	.hero-content:not(.hero-content--visible) .reveal-word {
		animation: none;
		opacity: 0;
	}

	.hero-title-gold {
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light), var(--fv-gold));
		background-size: 200% auto;
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}

	.hero-subtitle {
		font-size: 18px;
		color: var(--fv-smoke);
		line-height: 1.7;
		margin: 0 0 40px;
		opacity: 0;
		animation: fadeInUp 0.8s 0.7s cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}
	.hero-content:not(.hero-content--visible) .hero-subtitle {
		animation: none;
	}

	.hero-ctas {
		display: flex;
		gap: 16px;
		justify-content: center;
		flex-wrap: wrap;
		margin-bottom: 40px;
		opacity: 0;
		animation: fadeInUp 0.8s 0.9s cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}
	.hero-content:not(.hero-content--visible) .hero-ctas {
		animation: none;
	}

	.hero-cta-primary {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 16px 32px;
		border-radius: 14px;
		font-weight: 700;
		font-size: 16px;
		color: #1a1a2e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		text-decoration: none;
		transition: box-shadow 0.3s ease;
		will-change: transform;
	}
	.hero-cta-primary:hover {
		box-shadow: 0 8px 40px rgba(255, 200, 55, 0.35), 0 0 0 1px rgba(255, 200, 55, 0.1);
	}

	.hero-cta-ghost {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 16px 32px;
		border-radius: 14px;
		font-weight: 600;
		font-size: 16px;
		color: var(--fv-silver);
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.1);
		text-decoration: none;
		transition: background 0.3s ease, border-color 0.3s ease;
		will-change: transform;
	}
	.hero-cta-ghost:hover {
		background: rgba(255, 255, 255, 0.1);
		border-color: rgba(255, 255, 255, 0.2);
	}

	.hero-trust {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 16px;
		flex-wrap: wrap;
		opacity: 0;
		animation: fadeInUp 0.8s 1.1s cubic-bezier(0.16, 1, 0.3, 1) forwards;
	}
	.hero-content:not(.hero-content--visible) .hero-trust {
		animation: none;
	}
	.hero-trust-item {
		display: flex;
		align-items: center;
		gap: 6px;
		font-size: 13px;
		color: var(--fv-mist);
		font-weight: 500;
	}
	.hero-trust-sep {
		width: 4px;
		height: 4px;
		border-radius: 50%;
		background: var(--fv-ash);
	}

	.hero-scroll-indicator {
		position: absolute;
		bottom: 32px;
		left: 50%;
		transform: translateX(-50%);
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 8px;
		color: var(--fv-ash);
		font-size: 11px;
		font-weight: 500;
		letter-spacing: 2px;
		text-transform: uppercase;
		transition: opacity 0.3s ease;
	}
	.hero-scroll-mouse {
		width: 22px;
		height: 34px;
		border: 2px solid var(--fv-ash);
		border-radius: 12px;
		position: relative;
	}
	.hero-scroll-wheel {
		width: 3px;
		height: 8px;
		border-radius: 2px;
		background: var(--fv-smoke);
		position: absolute;
		top: 6px;
		left: 50%;
		transform: translateX(-50%);
		animation: scrollWheel 1.5s ease-in-out infinite;
	}

	/* ============================================================ */
	/* STATS BAR */
	/* ============================================================ */
	.stats {
		padding: 0 24px;
		margin-top: -40px;
		position: relative;
		z-index: 3;
	}
	.stats-inner {
		max-width: 1000px;
		margin: 0 auto;
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 40px;
		padding: 32px 48px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.06), rgba(255, 255, 255, 0.02));
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
		border: 1px solid rgba(255, 255, 255, 0.08);
		opacity: 0;
		transform: translateY(20px);
		transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
		flex-wrap: wrap;
	}
	.stats-inner.revealed {
		opacity: 1;
		transform: translateY(0);
	}
	.stat-item {
		display: flex;
		flex-direction: column;
		align-items: center;
		gap: 4px;
	}
	.stat-number {
		font-size: 28px;
		font-weight: 800;
		color: white;
		letter-spacing: -0.02em;
		font-variant-numeric: tabular-nums;
	}
	.stat-label {
		font-size: 13px;
		color: var(--fv-smoke);
		font-weight: 500;
	}
	.stat-divider {
		width: 1px;
		height: 40px;
		background: rgba(255, 255, 255, 0.1);
	}

	/* ============================================================ */
	/* BENTO FEATURES */
	/* ============================================================ */
	.features {
		padding: 120px 24px;
	}

	.bento-grid {
		display: grid;
		grid-template-columns: repeat(4, 1fr);
		grid-auto-rows: minmax(200px, auto);
		gap: 16px;
	}
	.bento-grid.revealed .bento-card {
		animation: scaleIn 0.6s calc(var(--reveal-delay, 0ms)) cubic-bezier(0.16, 1, 0.3, 1) both;
	}

	.bento-card {
		position: relative;
		border-radius: 20px;
		overflow: hidden;
		opacity: 0;
		cursor: default;
		transition: transform 0.3s ease;
	}
	.bento-card:hover {
		transform: scale(1.02);
	}
	.bento-card--large {
		grid-column: span 2;
		grid-row: span 2;
	}
	.bento-card--medium {
		grid-column: span 2;
		grid-row: span 1;
	}
	.bento-card--small {
		grid-column: span 1;
		grid-row: span 1;
	}

	/* Card mouse-following inner glow */
	.bento-card-glow {
		position: absolute;
		inset: 0;
		background: radial-gradient(400px circle at var(--card-x) var(--card-y), color-mix(in srgb, var(--accent) 8%, transparent), transparent 50%);
		z-index: 0;
		pointer-events: none;
		opacity: 0;
		transition: opacity 0.3s ease;
	}
	.bento-card:hover .bento-card-glow {
		opacity: 1;
	}

	/* Animated gradient border */
	.bento-card-border {
		position: absolute;
		inset: 0;
		border-radius: 20px;
		padding: 1px;
		background: conic-gradient(from var(--angle, 0deg), transparent 40%, var(--accent, var(--fv-cyan)) 50%, transparent 60%);
		-webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
		mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
		mask-composite: exclude;
		-webkit-mask-composite: xor;
		animation: rotateGradient 4s linear infinite;
		opacity: 0;
		transition: opacity 0.3s ease;
		z-index: 1;
		pointer-events: none;
	}
	.bento-card:hover .bento-card-border {
		opacity: 1;
	}

	.bento-card-content {
		position: relative;
		z-index: 2;
		height: 100%;
		padding: 32px;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.015));
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 20px;
	}

	.bento-card-icon {
		width: 52px;
		height: 52px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 14px;
		background: color-mix(in srgb, var(--accent) 10%, transparent);
		margin-bottom: 20px;
	}

	.bento-card-title {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 10px;
	}
	.bento-card--large .bento-card-title {
		font-size: 26px;
	}
	.bento-card-desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}
	.bento-card--large .bento-card-desc {
		font-size: 16px;
		max-width: 400px;
	}

	/* ============================================================ */
	/* INTERACTIVE DEMO */
	/* ============================================================ */
	.demo {
		padding: 120px 24px;
		position: relative;
	}

	.demo-container {
		position: relative;
		display: flex;
		justify-content: center;
		opacity: 0;
		transform: translateY(60px);
		transition: all 1s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.demo-container.revealed {
		opacity: 1;
		transform: translateY(0);
	}

	.demo-glow {
		position: absolute;
		width: 500px;
		height: 500px;
		background: radial-gradient(circle, rgba(0, 212, 255, 0.08), transparent 60%);
		top: 50%;
		left: 50%;
		transform: translate(-50%, -50%);
		pointer-events: none;
	}

	.demo-tilt {
		transition: transform 0.5s ease-out;
		will-change: transform;
	}

	.demo-card {
		width: 420px;
		max-width: 100%;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.07), rgba(255, 255, 255, 0.02));
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 20px;
		padding: 28px;
		backdrop-filter: blur(20px);
		-webkit-backdrop-filter: blur(20px);
	}

	.demo-card-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 24px;
		padding-bottom: 20px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.demo-card-icon {
		width: 40px;
		height: 40px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 10px;
		background: rgba(0, 212, 255, 0.1);
	}
	.demo-card-info {
		flex: 1;
		display: flex;
		flex-direction: column;
		gap: 2px;
	}
	.demo-card-site {
		font-weight: 700;
		color: white;
		font-size: 16px;
	}
	.demo-card-email {
		font-size: 13px;
		color: var(--fv-smoke);
	}
	.demo-card-badge {
		padding: 4px 10px;
		border-radius: 6px;
		font-size: 11px;
		font-weight: 700;
		color: var(--fv-cyan);
		background: rgba(0, 212, 255, 0.12);
	}

	.demo-field {
		margin-bottom: 20px;
		position: relative;
	}
	.demo-field-label {
		font-size: 11px;
		font-weight: 600;
		color: var(--fv-smoke);
		text-transform: uppercase;
		letter-spacing: 1px;
		margin-bottom: 8px;
		display: block;
	}
	.demo-field-row {
		display: flex;
		align-items: center;
		gap: 8px;
		padding: 12px 16px;
		border-radius: 12px;
		background: rgba(0, 0, 0, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
	}
	.demo-field-value {
		flex: 1;
		font-family: 'SF Mono', 'Fira Code', monospace;
		font-size: 15px;
		color: var(--fv-silver);
		letter-spacing: 1px;
	}
	.demo-field-btn {
		width: 32px;
		height: 32px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 8px;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		color: var(--fv-smoke);
		cursor: pointer;
		transition: all 0.2s ease;
	}
	.demo-field-btn:hover {
		background: rgba(255, 255, 255, 0.12);
		color: white;
	}

	.demo-copied-toast {
		position: absolute;
		right: 16px;
		bottom: -28px;
		font-size: 12px;
		font-weight: 600;
		color: var(--fv-success);
		animation: fadeInUp 0.3s ease;
	}

	.demo-totp {
		position: relative;
	}
	.demo-totp-label {
		font-size: 11px;
		font-weight: 600;
		color: var(--fv-smoke);
		text-transform: uppercase;
		letter-spacing: 1px;
		margin-bottom: 8px;
		display: block;
	}
	.demo-totp-row {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding: 12px 16px;
		border-radius: 12px;
		background: rgba(0, 0, 0, 0.3);
		border: 1px solid rgba(255, 255, 255, 0.06);
	}
	.demo-totp-code {
		font-family: 'SF Mono', 'Fira Code', monospace;
		font-size: 28px;
		font-weight: 700;
		color: var(--fv-cyan);
		letter-spacing: 4px;
	}
	.demo-totp-timer {
		flex-shrink: 0;
	}

	/* ============================================================ */
	/* SECURITY */
	/* ============================================================ */
	.security {
		padding: 120px 24px;
		position: relative;
		overflow: hidden;
	}
	.security-bg {
		position: absolute;
		inset: 0;
		background: radial-gradient(ellipse 80% 50% at 50% 0%, rgba(0, 212, 255, 0.04), transparent 60%);
		pointer-events: none;
	}
	.security-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 16px;
	}
	.security-grid.revealed .security-card {
		animation: scaleIn 0.6s calc(var(--reveal-delay, 0ms)) cubic-bezier(0.16, 1, 0.3, 1) both;
	}
	.security-card {
		opacity: 0;
	}
	.security-card-inner {
		position: relative;
		z-index: 2;
		height: 100%;
		padding: 32px;
		display: flex;
		flex-direction: column;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.015));
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 20px;
	}
	.security-card-icon {
		width: 52px;
		height: 52px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 14px;
		background: color-mix(in srgb, var(--accent) 10%, transparent);
		margin-bottom: 16px;
	}
	.security-card-label {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 8px;
	}
	.security-card-detail {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}

	/* ============================================================ */
	/* STEPS */
	/* ============================================================ */
	.steps {
		padding: 120px 24px;
	}
	.steps-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 32px;
		position: relative;
	}
	.steps-grid.revealed .step-card {
		animation: fadeInUp 0.7s calc(var(--reveal-delay, 0ms)) cubic-bezier(0.16, 1, 0.3, 1) both;
	}
	.step-card {
		position: relative;
		text-align: center;
		padding: 40px 24px;
		opacity: 0;
	}
	.step-connector {
		position: absolute;
		top: 52px;
		right: -16px;
		width: 32px;
		height: 2px;
		overflow: hidden;
	}
	.step-connector::after {
		content: '';
		display: block;
		width: 100%;
		height: 100%;
		background: repeating-linear-gradient(90deg, var(--fv-cyan) 0, var(--fv-cyan) 4px, transparent 4px, transparent 10px);
		animation: shimmer 3s linear infinite;
	}
	.step-num {
		display: inline-flex;
		align-items: center;
		justify-content: center;
		width: 56px;
		height: 56px;
		border-radius: 16px;
		font-size: 20px;
		font-weight: 800;
		color: var(--fv-cyan);
		background: rgba(0, 212, 255, 0.08);
		border: 1px solid rgba(0, 212, 255, 0.15);
		margin-bottom: 20px;
	}
	.step-title {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 12px;
	}
	.step-desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
	}

	/* ============================================================ */
	/* COMPARISON TABLE */
	/* ============================================================ */
	.comparison {
		padding: 120px 24px;
	}
	.comparison-table-wrap {
		overflow-x: auto;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.04), rgba(255, 255, 255, 0.01));
		border: 1px solid rgba(255, 255, 255, 0.06);
		opacity: 0;
		transform: translateY(30px);
		transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.comparison-table-wrap.revealed {
		opacity: 1;
		transform: translateY(0);
	}
	.comparison-table {
		width: 100%;
		border-collapse: collapse;
		text-align: center;
		font-size: 14px;
	}
	.comparison-table thead th {
		padding: 20px 16px;
		font-weight: 700;
		color: var(--fv-smoke);
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		font-size: 13px;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}
	.comparison-th-feature {
		text-align: left;
		padding-left: 24px !important;
	}
	.comparison-th-highlight {
		color: var(--fv-cyan) !important;
		background: rgba(0, 212, 255, 0.04);
	}
	.comparison-row {
		transition: background 0.2s ease;
	}
	.comparison-row:hover {
		background: rgba(255, 255, 255, 0.03);
	}
	.comparison-table tbody td {
		padding: 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.03);
		color: var(--fv-mist);
	}
	.comparison-feature-name {
		text-align: left;
		padding-left: 24px !important;
		font-weight: 500;
		color: var(--fv-silver);
	}
	.comparison-highlight-cell {
		background: rgba(0, 212, 255, 0.04);
		position: relative;
	}
	.comparison-highlight-cell::after {
		content: '';
		position: absolute;
		top: 0;
		bottom: 0;
		left: 0;
		width: 1px;
		background: rgba(0, 212, 255, 0.1);
	}
	.comparison-text-value {
		font-weight: 700;
		color: var(--fv-cyan);
	}
	.comparison-dim {
		color: var(--fv-smoke);
	}

	/* ============================================================ */
	/* EXTENSION */
	/* ============================================================ */
	.extension { padding: 120px 24px; }

	.ext-card {
		max-width: 900px; margin: 0 auto;
		background: linear-gradient(135deg, rgba(0,212,255,0.04), rgba(138,92,246,0.04));
		border: 1px solid rgba(0,212,255,0.12);
		border-radius: 24px; overflow: hidden;
		opacity: 0; transform: translateY(30px);
		transition: all 0.8s cubic-bezier(0.16,1,0.3,1);
	}
	.ext-card.revealed { opacity: 1; transform: translateY(0); }
	.ext-card-inner { display: flex; gap: 40px; padding: 48px; align-items: center; }

	.ext-left { flex: 1; }
	.ext-right { flex-shrink: 0; }

	.ext-icon-row { display: flex; align-items: center; gap: 16px; margin-bottom: 24px; }
	.ext-logo { width: 48px; height: 48px; flex-shrink: 0; }
	.ext-name { font-size: 20px; font-weight: 800; color: white; }
	.ext-rating { display: flex; align-items: center; gap: 8px; margin-top: 2px; }
	.ext-stars { color: #FBBF24; font-size: 14px; letter-spacing: 1px; }
	.ext-label { font-size: 12px; color: var(--fv-ash); }

	.ext-features {
		list-style: none; padding: 0; margin: 0 0 28px;
	}
	.ext-features li {
		font-size: 14px; color: var(--fv-smoke); padding: 6px 0;
		padding-left: 24px; position: relative;
	}
	.ext-features li::before {
		content: ''; position: absolute; left: 0; top: 50%; transform: translateY(-50%);
		width: 16px; height: 16px; border-radius: 50%;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		opacity: 0.8;
	}
	.ext-features li::after {
		content: ''; position: absolute; left: 5px; top: 50%; transform: translateY(-50%) rotate(45deg);
		width: 4px; height: 8px; border-bottom: 2px solid white; border-right: 2px solid white;
	}

	.ext-cta {
		display: inline-flex; align-items: center; gap: 10px;
		padding: 14px 28px; border-radius: 14px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		color: white; font-size: 15px; font-weight: 700;
		text-decoration: none; transition: all 0.2s;
		box-shadow: 0 4px 20px rgba(0,212,255,0.25);
	}
	.ext-cta:hover { transform: translateY(-2px); box-shadow: 0 6px 28px rgba(0,212,255,0.35); filter: brightness(1.05); }

	.ext-compat { font-size: 12px; color: var(--fv-ash); margin-top: 12px; }

	/* Popup mockup */
	.ext-mockup { position: relative; }
	.ext-popup-mock {
		width: 260px; background: #0F172A; border: 1px solid rgba(0,212,255,0.15);
		border-radius: 14px; overflow: hidden; box-shadow: 0 8px 40px rgba(0,0,0,0.4);
	}
	.ext-popup-header {
		display: flex; align-items: center; gap: 8px;
		padding: 12px 16px; border-bottom: 1px solid rgba(255,255,255,0.06);
		font-size: 14px; font-weight: 700; color: var(--fv-cyan);
	}
	.ext-popup-logo {
		width: 20px; height: 20px; border-radius: 5px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
	}
	.ext-popup-search {
		margin: 10px 12px; padding: 8px 12px; border-radius: 8px;
		background: rgba(255,255,255,0.04); font-size: 12px; color: var(--fv-ash);
	}
	.ext-popup-item {
		display: flex; align-items: center; gap: 10px;
		padding: 10px 16px; border-bottom: 1px solid rgba(255,255,255,0.04);
	}
	.ext-popup-item:last-child { border-bottom: none; }
	.ext-popup-favicon {
		width: 28px; height: 28px; border-radius: 7px;
		display: flex; align-items: center; justify-content: center;
		font-size: 13px; font-weight: 700; color: white; flex-shrink: 0;
	}
	.ext-popup-title { font-size: 13px; font-weight: 600; color: white; }
	.ext-popup-user { font-size: 11px; color: var(--fv-ash); }

	@media (max-width: 768px) {
		.ext-card-inner { flex-direction: column; padding: 32px 24px; gap: 24px; }
		.ext-right { display: none; }
	}

	/* ============================================================ */
	/* PRICING */
	/* ============================================================ */
	.pricing {
		padding: 120px 24px;
	}
	.pricing-grid {
		display: grid;
		grid-template-columns: repeat(2, 1fr);
		gap: 24px;
		max-width: 800px;
		margin: 0 auto;
		align-items: start;
	}
	.pricing-grid.revealed .pricing-card {
		animation: scaleIn 0.7s calc(var(--reveal-delay, 0ms)) cubic-bezier(0.16, 1, 0.3, 1) both;
	}

	.pricing-card {
		position: relative;
		border-radius: 24px;
		overflow: hidden;
		opacity: 0;
	}

	.pricing-card-border {
		position: absolute;
		inset: 0;
		border-radius: 24px;
		padding: 1px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.1), rgba(255, 255, 255, 0.03));
		-webkit-mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
		mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
		mask-composite: exclude;
		-webkit-mask-composite: xor;
		z-index: 0;
		pointer-events: none;
	}
	.pricing-card-border--gold {
		background: conic-gradient(from var(--angle, 0deg), transparent 30%, var(--fv-gold) 50%, transparent 70%);
		animation: rotateGradient 3s linear infinite;
	}

	.pricing-card-shimmer {
		position: absolute;
		inset: 0;
		background: linear-gradient(90deg, transparent, rgba(255, 200, 55, 0.03), transparent);
		background-size: 200% 100%;
		animation: shimmer 4s linear infinite;
		z-index: 0;
		pointer-events: none;
	}

	.pricing-card-popular {
		position: absolute;
		top: 16px;
		right: 16px;
		padding: 4px 14px;
		border-radius: 100px;
		font-size: 11px;
		font-weight: 700;
		color: #1a1a2e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		z-index: 3;
		animation: popularPulse 2s ease-in-out infinite;
	}

	.pricing-card-inner {
		position: relative;
		z-index: 2;
		padding: 36px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.015));
		border-radius: 24px;
	}
	.pricing-card--pro .pricing-card-inner {
		background: linear-gradient(135deg, rgba(255, 200, 55, 0.04), rgba(255, 255, 255, 0.015));
	}

	.pricing-card-header {
		margin-bottom: 24px;
	}
	.pricing-card-name {
		font-size: 24px;
		font-weight: 800;
		color: white;
		margin: 0 0 6px;
	}
	.pricing-crown {
		color: var(--fv-gold);
	}
	.pricing-card-tagline {
		font-size: 14px;
		color: var(--fv-smoke);
		margin: 0;
	}

	.pricing-card-price {
		display: flex;
		align-items: baseline;
		gap: 4px;
		margin-bottom: 8px;
	}
	.pricing-card-amount {
		font-size: 48px;
		font-weight: 850;
		color: white;
		letter-spacing: -0.03em;
	}
	.pricing-card-currency {
		font-size: 18px;
		font-weight: 700;
		color: var(--fv-smoke);
	}
	.pricing-card-period {
		font-size: 16px;
		color: var(--fv-ash);
	}
	.pricing-card-annual {
		font-size: 13px;
		color: var(--fv-smoke);
		margin: 0 0 24px;
	}
	.pricing-card-annual span {
		color: var(--fv-success);
		font-weight: 700;
	}

	.pricing-card-features {
		list-style: none;
		padding: 0;
		margin: 0 0 28px;
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.pricing-card-features li {
		display: flex;
		align-items: center;
		gap: 10px;
		font-size: 14px;
		color: var(--fv-mist);
	}

	.pricing-card-cta {
		display: block;
		text-align: center;
		padding: 14px 24px;
		border-radius: 14px;
		font-weight: 700;
		font-size: 15px;
		text-decoration: none;
		transition: all 0.3s ease;
		will-change: transform;
	}
	.pricing-card-cta--ghost {
		color: var(--fv-silver);
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.1);
	}
	.pricing-card-cta--ghost:hover {
		background: rgba(255, 255, 255, 0.1);
	}
	.pricing-card-cta--gold {
		color: #1a1a2e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
	}
	.pricing-card-cta--gold:hover {
		box-shadow: 0 8px 30px rgba(255, 200, 55, 0.3);
	}

	.pricing-card-guarantee {
		display: flex;
		align-items: center;
		justify-content: center;
		gap: 6px;
		font-size: 12px;
		color: var(--fv-smoke);
		margin: 16px 0 0;
	}

	/* ============================================================ */
	/* TESTIMONIALS */
	/* ============================================================ */
	.testimonials {
		padding: 120px 24px;
	}
	.testimonials-grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 20px;
	}
	.testimonials-grid.revealed .testimonial-card {
		animation: fadeInUp 0.7s calc(var(--reveal-delay, 0ms)) cubic-bezier(0.16, 1, 0.3, 1) both;
	}

	.testimonial-card {
		position: relative;
		padding: 28px;
		border-radius: 20px;
		background: linear-gradient(135deg, rgba(255, 255, 255, 0.05), rgba(255, 255, 255, 0.015));
		border: 1px solid rgba(255, 255, 255, 0.06);
		opacity: 0;
		transition: border-color 0.3s ease, box-shadow 0.3s ease;
		overflow: hidden;
	}
	.testimonial-card--active {
		border-color: rgba(255, 255, 255, 0.12);
		box-shadow: 0 0 40px rgba(0, 212, 255, 0.05);
	}

	.testimonial-gradient-bar {
		position: absolute;
		top: 0;
		left: 0;
		right: 0;
		height: 3px;
		background: linear-gradient(90deg, var(--accent), transparent);
		opacity: 0;
		transition: opacity 0.3s ease;
	}
	.testimonial-card--active .testimonial-gradient-bar,
	.testimonial-card:hover .testimonial-gradient-bar {
		opacity: 1;
	}

	.testimonial-stars {
		display: flex;
		gap: 2px;
		margin-bottom: 16px;
	}
	.testimonial-text {
		font-size: 14px;
		color: var(--fv-mist);
		line-height: 1.7;
		margin: 0 0 20px;
	}
	.testimonial-author {
		display: flex;
		align-items: center;
		gap: 12px;
	}
	.testimonial-avatar {
		width: 40px;
		height: 40px;
		border-radius: 12px;
		display: flex;
		align-items: center;
		justify-content: center;
		font-weight: 700;
		font-size: 13px;
		color: white;
		background: color-mix(in srgb, var(--avatar-color) 20%, transparent);
		border: 1px solid color-mix(in srgb, var(--avatar-color) 30%, transparent);
	}
	.testimonial-name {
		font-size: 14px;
		font-weight: 600;
		color: white;
	}
	.testimonial-role {
		font-size: 12px;
		color: var(--fv-smoke);
	}

	.testimonials-dots {
		display: flex;
		justify-content: center;
		gap: 8px;
		margin-top: 32px;
	}
	.testimonial-dot {
		width: 8px;
		height: 8px;
		border-radius: 50%;
		border: none;
		background: var(--fv-ash);
		cursor: pointer;
		transition: all 0.3s ease;
		padding: 0;
	}
	.testimonial-dot--active {
		background: var(--fv-cyan);
		width: 24px;
		border-radius: 4px;
	}

	/* ============================================================ */
	/* FAQ */
	/* ============================================================ */
	.faq {
		padding: 120px 24px;
	}
	.faq-search {
		display: flex;
		align-items: center;
		gap: 12px;
		padding: 14px 20px;
		border-radius: 14px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		margin-bottom: 24px;
		opacity: 0;
		transform: translateY(20px);
		transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.faq-search.revealed {
		opacity: 1;
		transform: translateY(0);
	}
	.faq-search-input {
		flex: 1;
		background: none;
		border: none;
		outline: none;
		color: var(--fv-silver);
		font-size: 15px;
		font-family: inherit;
	}
	.faq-search-input::placeholder {
		color: var(--fv-ash);
	}

	.faq-list {
		display: flex;
		flex-direction: column;
		gap: 8px;
		opacity: 0;
		transform: translateY(20px);
		transition: all 0.6s 0.1s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.faq-list.revealed {
		opacity: 1;
		transform: translateY(0);
	}
	.faq-item {
		border-radius: 16px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		overflow: hidden;
		transition: border-color 0.3s ease;
	}
	.faq-item--open {
		border-color: rgba(0, 212, 255, 0.15);
	}
	.faq-question {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		width: 100%;
		padding: 20px 24px;
		background: none;
		border: none;
		color: white;
		font-size: 15px;
		font-weight: 600;
		text-align: left;
		cursor: pointer;
		font-family: inherit;
	}
	.faq-chevron {
		flex-shrink: 0;
		transition: transform 0.3s ease;
		color: var(--fv-smoke);
	}
	.faq-item--open .faq-chevron {
		transform: rotate(180deg);
		color: var(--fv-cyan);
	}
	.faq-answer-wrap {
		display: grid;
		transition: grid-template-rows 0.3s ease;
	}
	.faq-answer {
		overflow: hidden;
	}
	.faq-answer p {
		padding: 0 24px 20px;
		margin: 0;
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.7;
	}

	/* ============================================================ */
	/* FINAL CTA */
	/* ============================================================ */
	.final-cta {
		position: relative;
		padding: 120px 24px;
		overflow: hidden;
	}
	.final-cta-bg {
		position: absolute;
		inset: 0;
		overflow: hidden;
	}
	.final-cta-orb {
		position: absolute;
		border-radius: 50%;
		filter: blur(120px);
	}
	.final-cta-orb--1 {
		width: 500px;
		height: 500px;
		background: radial-gradient(circle, rgba(0, 212, 255, 0.1), transparent);
		top: -100px;
		left: 20%;
		animation: orbFloat1 15s ease-in-out infinite;
	}
	.final-cta-orb--2 {
		width: 400px;
		height: 400px;
		background: radial-gradient(circle, rgba(255, 200, 55, 0.08), transparent);
		bottom: -100px;
		right: 20%;
		animation: orbFloat2 18s ease-in-out infinite;
	}

	.final-cta-content {
		position: relative;
		z-index: 2;
		text-align: center;
		opacity: 0;
		transform: translateY(30px);
		transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
	}
	.final-cta-content.revealed {
		opacity: 1;
		transform: translateY(0);
	}

	.final-cta-title {
		font-size: clamp(32px, 5vw, 52px);
		font-weight: 850;
		color: white;
		margin: 0 0 20px;
		letter-spacing: -0.02em;
		min-height: 1.3em;
	}
	.cta-cursor {
		color: var(--fv-cyan);
		animation: blink 0.8s ease-in-out infinite;
		font-weight: 300;
	}
	.final-cta-subtitle {
		font-size: 18px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0 0 40px;
		max-width: 600px;
		margin-left: auto;
		margin-right: auto;
	}
	.final-cta-btn {
		display: inline-flex;
		align-items: center;
		gap: 10px;
		padding: 18px 40px;
		border-radius: 16px;
		font-weight: 700;
		font-size: 17px;
		color: #1a1a2e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		text-decoration: none;
		transition: box-shadow 0.3s ease;
		will-change: transform;
	}
	.final-cta-btn:hover {
		box-shadow: 0 8px 50px rgba(255, 200, 55, 0.4), 0 0 0 1px rgba(255, 200, 55, 0.1);
	}

	/* ============================================================ */
	/* FOOTER */
	/* ============================================================ */
	.footer {
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		padding: 64px 24px 32px;
	}
	.footer-inner {
		max-width: 1200px;
		margin: 0 auto;
	}
	.footer-grid {
		display: grid;
		grid-template-columns: 2fr 1fr 1fr 1fr;
		gap: 48px;
		margin-bottom: 48px;
	}
	.footer-brand {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}
	.footer-logo {
		display: flex;
		align-items: center;
		gap: 10px;
		font-weight: 800;
		font-size: 18px;
		color: white;
	}
	.footer-logo-icon {
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 10px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
	}
	.footer-desc {
		font-size: 14px;
		color: var(--fv-smoke);
		line-height: 1.6;
		margin: 0;
		max-width: 300px;
	}
	.footer-socials {
		display: flex;
		gap: 12px;
	}
	.footer-social {
		width: 36px;
		height: 36px;
		display: flex;
		align-items: center;
		justify-content: center;
		border-radius: 10px;
		background: rgba(255, 255, 255, 0.05);
		border: 1px solid rgba(255, 255, 255, 0.08);
		color: var(--fv-smoke);
		text-decoration: none;
		transition: all 0.2s ease;
	}
	.footer-social:hover {
		background: rgba(255, 255, 255, 0.1);
		color: white;
	}

	.footer-col {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.footer-col h4 {
		font-size: 13px;
		font-weight: 700;
		color: white;
		text-transform: uppercase;
		letter-spacing: 1px;
		margin: 0 0 4px;
	}
	.footer-col a {
		font-size: 14px;
		color: var(--fv-smoke);
		text-decoration: none;
		transition: color 0.2s ease;
	}
	.footer-col a:hover {
		color: var(--fv-silver);
	}

	.footer-bottom {
		display: flex;
		align-items: center;
		justify-content: space-between;
		padding-top: 24px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
	}
	.footer-bottom p {
		font-size: 13px;
		color: var(--fv-ash);
		margin: 0;
	}
	.footer-badges {
		display: flex;
		gap: 12px;
	}
	.footer-badges span {
		font-size: 11px;
		padding: 4px 12px;
		border-radius: 6px;
		background: rgba(255, 255, 255, 0.04);
		color: var(--fv-smoke);
		font-weight: 600;
	}

	/* ============================================================ */
	/* RESPONSIVE */
	/* ============================================================ */
	@media (max-width: 1024px) {
		.bento-grid {
			grid-template-columns: repeat(2, 1fr);
		}
		.bento-card--large {
			grid-column: span 2;
			grid-row: span 1;
		}
		.bento-card--medium {
			grid-column: span 1;
		}
	}

	@media (max-width: 768px) {
		.hero {
			padding: 100px 20px 60px;
			min-height: auto;
		}
		.hero-title {
			font-size: 36px;
		}

		.stats-inner {
			flex-direction: column;
			gap: 20px;
			padding: 24px;
		}
		.stat-divider {
			width: 40px;
			height: 1px;
		}

		.bento-grid {
			grid-template-columns: 1fr;
		}
		.bento-card--large,
		.bento-card--medium {
			grid-column: span 1;
			grid-row: span 1;
		}

		.security-grid {
			grid-template-columns: 1fr;
		}
		.steps-grid {
			grid-template-columns: 1fr;
		}
		.step-connector {
			display: none;
		}

		.pricing-grid {
			grid-template-columns: 1fr;
		}

		.testimonials-grid {
			grid-template-columns: 1fr;
		}

		.comparison-table {
			font-size: 12px;
		}

		.footer-grid {
			grid-template-columns: 1fr 1fr;
			gap: 32px;
		}
		.footer-brand {
			grid-column: span 2;
		}
		.footer-bottom {
			flex-direction: column;
			gap: 16px;
			text-align: center;
		}

		.hero-scroll-indicator {
			display: none;
		}
		.demo-card {
			width: 100%;
		}
	}

	@media (max-width: 480px) {
		.hero-ctas {
			flex-direction: column;
			align-items: center;
		}
		.hero-cta-primary,
		.hero-cta-ghost {
			width: 100%;
			justify-content: center;
		}
		.hero-trust {
			flex-direction: column;
			gap: 8px;
		}
		.hero-trust-sep {
			display: none;
		}
		.footer-grid {
			grid-template-columns: 1fr;
		}
		.footer-brand {
			grid-column: span 1;
		}
	}
</style>
