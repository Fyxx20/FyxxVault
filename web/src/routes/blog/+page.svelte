<script lang="ts">
	import { onMount } from 'svelte';

	let mounted = $state(false);
	onMount(() => { mounted = true; });

	const articles = [
		{
			slug: 'fyxxvault-vs-1password-vs-bitwarden',
			title: 'FyxxVault vs 1Password vs Bitwarden (2026)',
			excerpt: "An honest comparison of three password managers. Encryption, pricing, features, privacy — we break it all down to help you find the right fit.",
			date: '30 March 2026',
			readTime: '10 min',
			category: 'Comparison',
			categoryColor: 'var(--fv-cyan)',
			live: true,
		},
		{
			slug: 'pourquoi-fyxxvault-plus-sur',
			title: 'Pourquoi FyxxVault est plus sur que votre gestionnaire actuel',
			excerpt: "Architecture zero-knowledge, chiffrement AES-256-GCM, derivation de cle PBKDF2... Decouvrez pourquoi FyxxVault offre un niveau de securite superieur a la majorite des gestionnaires de mots de passe du marche.",
			date: '20 mars 2026',
			readTime: '6 min',
			category: 'Securite',
			categoryColor: 'var(--fv-success)',
			live: false,
		},
		{
			slug: '5-erreurs-mots-de-passe',
			title: '5 erreurs que tout le monde fait avec ses mots de passe',
			excerpt: "Reutiliser le meme mot de passe, utiliser des informations personnelles, ne pas activer le 2FA... Voici les erreurs les plus courantes et comment les eviter pour proteger vos comptes en ligne.",
			date: '14 mars 2026',
			readTime: '4 min',
			category: 'Conseils',
			categoryColor: 'var(--fv-gold)',
			live: false,
		},
		{
			slug: 'zero-knowledge-comment-ca-marche',
			title: 'Zero-knowledge : comment ca marche ?',
			excerpt: "Le zero-knowledge est au coeur de la securite de FyxxVault. Mais que signifie vraiment ce concept ? Explication technique accessible pour comprendre pourquoi meme nous ne pouvons pas lire vos donnees.",
			date: '7 mars 2026',
			readTime: '8 min',
			category: 'Technologie',
			categoryColor: 'var(--fv-violet)',
			live: false,
		},
	];
</script>

<svelte:head>
	<title>Blog - FyxxVault</title>
	<meta name="description" content="Blog FyxxVault : articles sur la securite, les mots de passe, le chiffrement et la protection de vos donnees en ligne." />
</svelte:head>

<div class="blog-page" class:visible={mounted}>
	<div class="blog-container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Retour a l'accueil
		</a>

		<h1 class="blog-title">Le <span class="fv-gradient-text">Blog</span></h1>
		<p class="blog-subtitle">Actualites, conseils de securite et guides techniques pour proteger votre vie numerique.</p>

		<div class="blog-grid">
			{#each articles as article, i}
				{#if article.live}
					<a href="/blog/{article.slug}" class="blog-card-link">
						<article class="blog-card fv-glass" style="animation-delay: {i * 100}ms">
							<div class="blog-card-header">
								<span class="blog-category" style="--cat-color: {article.categoryColor}">{article.category}</span>
								<span class="blog-badge blog-badge-live">New</span>
							</div>
							<h2 class="blog-card-title">{article.title}</h2>
							<p class="blog-card-excerpt">{article.excerpt}</p>
							<div class="blog-card-meta">
								<div class="blog-meta-left">
									<span class="blog-date">
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
										{article.date}
									</span>
									<span class="blog-read-time">
										<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
										{article.readTime}
									</span>
								</div>
								<span class="blog-read-link">Read &rarr;</span>
							</div>
						</article>
					</a>
				{:else}
					<article class="blog-card fv-glass" style="animation-delay: {i * 100}ms">
						<div class="blog-card-header">
							<span class="blog-category" style="--cat-color: {article.categoryColor}">{article.category}</span>
							<span class="blog-badge">Bientot</span>
						</div>
						<h2 class="blog-card-title">{article.title}</h2>
						<p class="blog-card-excerpt">{article.excerpt}</p>
						<div class="blog-card-meta">
							<div class="blog-meta-left">
								<span class="blog-date">
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
									{article.date}
								</span>
								<span class="blog-read-time">
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
									{article.readTime}
								</span>
							</div>
						</div>
					</article>
				{/if}
			{/each}
		</div>

		<div class="blog-newsletter fv-glass">
			<div class="blog-newsletter-content">
				<svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
				<h3>Restez informe</h3>
				<p>De nouveaux articles arrivent bientot. Suivez-nous pour ne rien manquer sur la securite et la protection de vos donnees.</p>
				<a href="mailto:contact@fyxxvault.com" class="fv-btn fv-btn-ghost">
					Nous contacter
				</a>
			</div>
		</div>
	</div>
</div>

<style>
	.blog-page {
		min-height: 100vh;
		background: var(--fv-abyss);
		padding: 40px 20px 80px;
		opacity: 0;
		transform: translateY(12px);
		transition: opacity 0.5s ease, transform 0.5s ease;
	}
	.blog-page.visible {
		opacity: 1;
		transform: translateY(0);
	}

	.blog-container {
		max-width: 900px;
		margin: 0 auto;
	}

	.back-link {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		color: var(--fv-smoke);
		text-decoration: none;
		font-size: 14px;
		font-weight: 500;
		margin-bottom: 40px;
		transition: color 0.2s ease;
	}
	.back-link:hover {
		color: var(--fv-cyan);
	}

	.blog-title {
		font-size: clamp(28px, 5vw, 42px);
		font-weight: 800;
		color: white;
		margin: 0 0 12px;
		line-height: 1.2;
	}

	.blog-subtitle {
		color: var(--fv-smoke);
		font-size: 16px;
		margin: 0 0 48px;
		line-height: 1.5;
		max-width: 600px;
	}

	.blog-grid {
		display: flex;
		flex-direction: column;
		gap: 20px;
	}

	.blog-card {
		padding: 28px;
		transition: transform 0.2s ease, border-color 0.2s ease;
		animation: fv-fade-in-up 0.5s ease both;
	}
	.blog-card:hover {
		transform: translateY(-2px);
		border-color: rgba(255,255,255,0.14);
	}

	@keyframes fv-fade-in-up {
		from { opacity: 0; transform: translateY(12px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.blog-card-header {
		display: flex;
		align-items: center;
		gap: 10px;
		margin-bottom: 16px;
	}

	.blog-category {
		display: inline-block;
		padding: 4px 12px;
		border-radius: 20px;
		font-size: 12px;
		font-weight: 600;
		color: var(--cat-color);
		background: color-mix(in srgb, var(--cat-color) 12%, transparent);
		letter-spacing: 0.3px;
	}

	.blog-badge {
		display: inline-block;
		padding: 4px 10px;
		border-radius: 20px;
		font-size: 11px;
		font-weight: 700;
		color: var(--fv-gold);
		background: rgba(255, 200, 55, 0.1);
		border: 1px solid rgba(255, 200, 55, 0.2);
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.blog-card-title {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 10px;
		line-height: 1.3;
	}

	.blog-card-excerpt {
		color: var(--fv-mist);
		font-size: 14px;
		line-height: 1.7;
		margin: 0 0 20px;
	}

	.blog-card-meta {
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.blog-meta-left {
		display: flex;
		align-items: center;
		gap: 16px;
	}

	.blog-date,
	.blog-read-time {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		color: var(--fv-smoke);
		font-size: 13px;
	}

	.blog-newsletter {
		margin-top: 60px;
		padding: 40px;
	}

	.blog-newsletter-content {
		display: flex;
		flex-direction: column;
		align-items: center;
		text-align: center;
		gap: 8px;
	}
	.blog-newsletter-content h3 {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 8px 0 0;
	}
	.blog-newsletter-content p {
		color: var(--fv-smoke);
		font-size: 15px;
		max-width: 480px;
		margin: 0 0 16px;
		line-height: 1.5;
	}

	.blog-card-link {
		text-decoration: none;
		display: block;
	}
	.blog-card-link .blog-card:hover {
		border-color: rgba(0, 212, 255, 0.3);
	}

	.blog-badge-live {
		color: var(--fv-cyan) !important;
		background: rgba(0, 212, 255, 0.1) !important;
		border: 1px solid rgba(0, 212, 255, 0.2) !important;
	}

	.blog-read-link {
		color: var(--fv-cyan);
		font-size: 14px;
		font-weight: 600;
		transition: opacity 0.2s;
	}
	.blog-card-link:hover .blog-read-link {
		opacity: 0.8;
	}

	@media (max-width: 640px) {
		.blog-page {
			padding: 24px 16px 60px;
		}
		.blog-card {
			padding: 20px;
		}
		.blog-newsletter {
			padding: 28px 20px;
		}
	}
</style>
