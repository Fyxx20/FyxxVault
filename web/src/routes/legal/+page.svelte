<script lang="ts">
	import { onMount } from 'svelte';
	let mounted = $state(false);
	onMount(() => { mounted = true; });
</script>

<svelte:head>
	<title>Mentions legales - FyxxVault</title>
	<meta name="description" content="Mentions legales de FyxxVault. Editeur, hebergement, responsable de publication et informations CNIL/RGPD." />
</svelte:head>

<div class="legal-page" class:visible={mounted}>
	<div class="legal-container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Retour a l'accueil
		</a>

		<h1 class="legal-title">Mentions <span class="fv-gradient-text">legales</span></h1>
		<p class="legal-date">Derniere mise a jour : Mars 2026</p>

		<div class="legal-content">
			<section class="legal-section">
				<h2>1. Editeur du site</h2>
				<div class="fv-glass legal-card">
					<p><strong>Nom du service :</strong> FyxxVault</p>
					<p><strong>Marque :</strong> Fyxx</p>
					<p><strong>Editeur :</strong> Marius Harea</p>
					<p><strong>Statut :</strong> Entrepreneur individuel</p>
					<p><strong>Pays :</strong> France</p>
					<p><strong>Email :</strong> <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
					<p><strong>Site web :</strong> <a href="https://fyxxvault.com">https://fyxxvault.com</a></p>
				</div>
			</section>

			<section class="legal-section">
				<h2>2. Responsable de publication</h2>
				<p><strong>Marius Harea</strong></p>
				<p>Contact : <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
			</section>

			<section class="legal-section">
				<h2>3. Hebergement</h2>
				<div class="hosting-grid">
					<div class="fv-glass legal-card">
						<h3>Site web</h3>
						<p><strong>Netlify, Inc.</strong></p>
						<p>512 2nd Street, Suite 200</p>
						<p>San Francisco, CA 94107, USA</p>
						<p><a href="https://www.netlify.com" target="_blank" rel="noopener">www.netlify.com</a></p>
					</div>
					<div class="fv-glass legal-card">
						<h3>Base de donnees et authentification</h3>
						<p><strong>SQLite (self-hosted)</strong></p>
						<p>Stockage local sur votre serveur</p>
						<p>Aucun tiers implique</p>
					</div>
				</div>
			</section>

			<section class="legal-section">
				<h2>4. Propriete intellectuelle</h2>
				<p>L'ensemble du contenu du site fyxxvault.com, incluant sans limitation les textes, graphismes, images, logos, icones, logiciels, et la structure generale du site, est la propriete exclusive de Marius Harea (marque Fyxx) ou fait l'objet d'une autorisation d'utilisation.</p>
				<p>Toute representation, reproduction, adaptation, traduction et/ou diffusion, integrale ou partielle, du contenu du site, par quelque procede que ce soit, est strictement interdite sans autorisation prealable et ecrite de l'editeur.</p>
				<p>La marque FyxxVault, le logo et les elements graphiques associes sont proteges au titre de la propriete intellectuelle. Toute utilisation non autorisee constitue une contrefacon sanctionnee par les articles L. 335-2 et suivants du Code de la propriete intellectuelle.</p>
			</section>

			<section class="legal-section">
				<h2>5. Protection des donnees personnelles</h2>
				<p>Conformement au <strong>Reglement General sur la Protection des Donnees (RGPD)</strong> n 2016/679 du 27 avril 2016 et a la <strong>loi Informatique et Libertes</strong> n 78-17 du 6 janvier 1978 modifiee, l'utilisateur dispose de droits sur ses donnees personnelles.</p>

				<div class="fv-glass legal-card">
					<h3>Responsable du traitement</h3>
					<p><strong>Marius Harea</strong></p>
					<p>Email : <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
				</div>

				<p>FyxxVault met en oeuvre une architecture <strong>zero-knowledge</strong> : les donnees du coffre-fort sont chiffrees cote client et ne sont pas accessibles par l'editeur.</p>

				<p>Pour en savoir plus sur le traitement de vos donnees personnelles, consultez notre <a href="/privacy">Politique de confidentialite</a>.</p>

				<h3>Autorite de controle</h3>
				<p>Vous pouvez adresser une reclamation a la CNIL :</p>
				<div class="fv-glass legal-card">
					<p><strong>Commission Nationale de l'Informatique et des Libertes (CNIL)</strong></p>
					<p>3 Place de Fontenoy - TSA 80715</p>
					<p>75334 Paris Cedex 07</p>
					<p><a href="https://www.cnil.fr" target="_blank" rel="noopener">www.cnil.fr</a></p>
				</div>
			</section>

			<section class="legal-section">
				<h2>6. Cookies</h2>
				<p>Le site fyxxvault.com utilise uniquement des cookies strictement necessaires au fonctionnement du service (cookies de session d'authentification). Aucun cookie de tracking ou publicitaire n'est utilise.</p>
				<p>Pour plus d'informations, consultez la section dediee dans notre <a href="/privacy">Politique de confidentialite</a>.</p>
			</section>

			<section class="legal-section">
				<h2>7. Conditions d'utilisation</h2>
				<p>L'utilisation du service FyxxVault est soumise a nos <a href="/terms">Conditions Generales de Vente</a>.</p>
			</section>

			<section class="legal-section">
				<h2>8. Litiges</h2>
				<p>Les presentes mentions legales sont soumises au droit francais. En cas de litige, et apres tentative de resolution amiable, les tribunaux francais seront seuls competents.</p>
				<p>Plateforme europeenne de resolution des litiges en ligne : <a href="https://ec.europa.eu/consumers/odr" target="_blank" rel="noopener">https://ec.europa.eu/consumers/odr</a></p>
			</section>
		</div>
	</div>
</div>

<style>
	.legal-page {
		min-height: 100vh;
		background: var(--fv-abyss);
		padding: 40px 20px 80px;
		opacity: 0;
		transform: translateY(12px);
		transition: opacity 0.5s ease, transform 0.5s ease;
	}
	.legal-page.visible {
		opacity: 1;
		transform: translateY(0);
	}

	.legal-container {
		max-width: 800px;
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

	.legal-title {
		font-size: clamp(28px, 5vw, 42px);
		font-weight: 800;
		color: white;
		margin: 0 0 8px;
		line-height: 1.2;
	}

	.legal-date {
		color: var(--fv-smoke);
		font-size: 14px;
		margin: 0 0 48px;
	}

	.legal-content {
		display: flex;
		flex-direction: column;
		gap: 40px;
	}

	.legal-section h2 {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 16px;
		padding-bottom: 8px;
		border-bottom: 1px solid rgba(255,255,255,0.08);
	}

	.legal-section h3 {
		font-size: 16px;
		font-weight: 600;
		color: var(--fv-cyan-light);
		margin: 20px 0 10px;
	}

	.legal-section p {
		color: var(--fv-mist);
		line-height: 1.7;
		margin: 0 0 12px;
		font-size: 15px;
	}

	.legal-section a {
		color: var(--fv-cyan);
		text-decoration: none;
		transition: color 0.2s ease;
	}
	.legal-section a:hover {
		color: var(--fv-cyan-light);
		text-decoration: underline;
	}

	.legal-section strong {
		color: var(--fv-silver);
	}

	.legal-card {
		padding: 20px 24px;
		margin: 12px 0;
	}
	.legal-card h3 {
		margin: 0 0 10px;
	}
	.legal-card p {
		margin: 0 0 6px;
	}
	.legal-card p:last-child {
		margin: 0;
	}

	.hosting-grid {
		display: grid;
		grid-template-columns: 1fr 1fr;
		gap: 16px;
		margin: 12px 0;
	}

	@media (max-width: 640px) {
		.legal-page {
			padding: 24px 16px 60px;
		}
		.hosting-grid {
			grid-template-columns: 1fr;
		}
	}
</style>
