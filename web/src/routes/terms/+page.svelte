<script lang="ts">
	import { onMount } from 'svelte';
	let mounted = $state(false);
	onMount(() => { mounted = true; });
</script>

<svelte:head>
	<title>Conditions Generales de Vente - FyxxVault</title>
	<meta name="description" content="Conditions Generales de Vente de FyxxVault. Abonnement, paiement, retractation et conditions d'utilisation." />
</svelte:head>

<div class="legal-page" class:visible={mounted}>
	<div class="legal-container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Retour a l'accueil
		</a>

		<h1 class="legal-title">Conditions Generales <span class="fv-gradient-text">de Vente</span></h1>
		<p class="legal-date">Derniere mise a jour : Mars 2026</p>

		<div class="legal-content">
			<section class="legal-section">
				<h2>1. Objet</h2>
				<p>Les presentes Conditions Generales de Vente (ci-apres "CGV") ont pour objet de definir les modalites et conditions dans lesquelles FyxxVault, edite par Marius Harea sous la marque Fyxx (ci-apres "l'Editeur"), fournit son service de gestion de mots de passe a l'utilisateur (ci-apres "l'Utilisateur" ou "vous").</p>
				<p>Toute inscription ou utilisation du service implique l'acceptation sans reserve des presentes CGV.</p>
			</section>

			<section class="legal-section">
				<h2>2. Description du service</h2>
				<p>FyxxVault est un gestionnaire de mots de passe securise proposant :</p>
				<ul>
					<li>Le stockage chiffre d'identifiants, mots de passe, notes et codes 2FA</li>
					<li>La synchronisation chiffree entre appareils</li>
					<li>Le remplissage automatique (AutoFill) sur iOS et navigateurs</li>
					<li>La generation de mots de passe forts</li>
					<li>La surveillance de fuites de donnees (HIBP)</li>
					<li>La generation d'emails masques (via addy.io)</li>
				</ul>
				<p>Le service est accessible via l'application iOS et l'application web a l'adresse <a href="https://fyxxvault.com">fyxxvault.com</a>.</p>
			</section>

			<section class="legal-section">
				<h2>3. Inscription et compte</h2>
				<p>Pour utiliser FyxxVault, l'Utilisateur doit creer un compte en fournissant :</p>
				<ul>
					<li>Une adresse e-mail valide</li>
					<li>Un mot de passe maitre</li>
				</ul>
				<p>L'Utilisateur est seul responsable de la confidentialite de son mot de passe maitre. <strong>FyxxVault ne peut en aucun cas recuperer ou reinitialiser le mot de passe maitre</strong> en raison de l'architecture zero-knowledge. La perte du mot de passe maitre entraine la perte definitive de l'acces aux donnees chiffrees.</p>
				<p>L'Utilisateur s'engage a fournir des informations exactes et a ne pas creer de compte a des fins frauduleuses.</p>
			</section>

			<section class="legal-section">
				<h2>4. Offres et tarifs</h2>

				<h3>4.1 Offre Gratuite</h3>
				<p>L'offre gratuite permet l'utilisation des fonctionnalites de base de FyxxVault sans engagement ni limite de duree.</p>

				<h3>4.2 Offre Pro</h3>
				<div class="fv-glass legal-card">
					<div class="pricing-grid">
						<div class="pricing-item">
							<span class="pricing-label">Abonnement mensuel</span>
							<span class="pricing-value">4,99 EUR / mois</span>
						</div>
						<div class="pricing-item">
							<span class="pricing-label">Abonnement annuel</span>
							<span class="pricing-value">41,99 EUR / an</span>
							<span class="pricing-note">soit environ 3,50 EUR/mois — economisez 30%</span>
						</div>
					</div>
				</div>
				<p>L'offre Pro inclut l'ensemble des fonctionnalites avancees : TOTP integre, emails masques, surveillance de fuites, stockage illimite, et priorite de support.</p>

				<h3>4.3 Essai gratuit</h3>
				<p>Un <strong>essai gratuit de 14 jours</strong> de l'offre Pro est propose a tout nouvel utilisateur. A l'issue de la periode d'essai, l'abonnement est automatiquement active sauf si l'Utilisateur l'annule avant la fin de la periode d'essai.</p>
				<p>Les tarifs sont exprimes en euros (EUR), toutes taxes comprises (TTC). L'Editeur se reserve le droit de modifier les tarifs a tout moment. Les modifications tarifaires prennent effet au renouvellement suivant, avec notification prealable de 30 jours minimum.</p>
			</section>

			<section class="legal-section">
				<h2>5. Tarification</h2>
				<p>FyxxVault self-hosted est entierement gratuit et open source. Aucun paiement n'est requis.</p>
			</section>

			<section class="legal-section">
				<h2>6. Droit de retractation</h2>
				<p>Conformement aux articles L. 221-18 et suivants du Code de la consommation, l'Utilisateur dispose d'un droit de retractation de <strong>14 jours</strong> a compter de la souscription de l'abonnement.</p>
				<p>Pour exercer ce droit, l'Utilisateur peut :</p>
				<ul>
					<li>Envoyer un email a <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></li>
					<li>Utiliser la fonction d'annulation dans les parametres de son compte</li>
				</ul>
				<p>En cas d'exercice du droit de retractation, le remboursement est effectue dans un delai de 14 jours via le meme moyen de paiement.</p>
				<p><strong>Exception :</strong> conformement a l'article L. 221-28 du Code de la consommation, le droit de retractation ne peut etre exerce si le service a ete pleinement execute avant la fin du delai de retractation et que l'execution a commence avec l'accord prealable de l'Utilisateur et la reconnaissance de la perte de son droit de retractation.</p>
			</section>

			<section class="legal-section">
				<h2>7. Duree et resiliation</h2>
				<h3>7.1 Duree</h3>
				<p>L'abonnement est conclu pour la duree choisie (mensuelle ou annuelle) et se renouvelle automatiquement par tacite reconduction.</p>

				<h3>7.2 Resiliation par l'Utilisateur</h3>
				<p>L'Utilisateur peut resilier son abonnement a tout moment depuis les parametres de son compte ou en contactant <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a>. La resiliation prend effet a la fin de la periode en cours. L'Utilisateur conserve l'acces aux fonctionnalites Pro jusqu'a la fin de la periode payee.</p>

				<h3>7.3 Resiliation par l'Editeur</h3>
				<p>L'Editeur se reserve le droit de suspendre ou resilier le compte d'un Utilisateur en cas de :</p>
				<ul>
					<li>Violation des presentes CGV</li>
					<li>Utilisation frauduleuse ou abusive du service</li>
					<li>Non-paiement apres relances</li>
				</ul>

				<h3>7.4 Consequences de la resiliation</h3>
				<p>Apres resiliation, l'Utilisateur conserve l'acces aux fonctionnalites de l'offre gratuite. Les donnees chiffrees restent accessibles. L'Utilisateur peut exporter ses donnees ou supprimer definitivement son compte.</p>
			</section>

			<section class="legal-section">
				<h2>8. Limitation de responsabilite</h2>
				<p>L'Editeur met en oeuvre tous les moyens raisonnables pour assurer la disponibilite et la securite du service. Toutefois :</p>
				<ul>
					<li>Le service est fourni "en l'etat". L'Editeur ne garantit pas une disponibilite ininterrompue.</li>
					<li>L'Editeur ne saurait etre tenu responsable de la perte de donnees resultant de la perte du mot de passe maitre par l'Utilisateur.</li>
					<li>L'Editeur ne saurait etre tenu responsable des dommages indirects (perte de profits, perte de donnees, etc.).</li>
					<li>La responsabilite de l'Editeur est limitee au montant des sommes effectivement versees par l'Utilisateur au cours des 12 derniers mois.</li>
				</ul>
			</section>

			<section class="legal-section">
				<h2>9. Propriete intellectuelle</h2>
				<p>L'ensemble des elements constituant le service FyxxVault (logiciel, design, textes, logos, marques) est la propriete exclusive de l'Editeur ou de ses concedants de licence.</p>
				<p>L'Utilisateur beneficie d'un droit d'utilisation personnel, non exclusif et non cessible, limite a l'utilisation du service conformement aux presentes CGV. Toute reproduction, modification, distribution ou exploitation non autorisee est strictement interdite.</p>
				<p>Les donnees stockees par l'Utilisateur dans son coffre-fort restent la propriete exclusive de l'Utilisateur.</p>
			</section>

			<section class="legal-section">
				<h2>10. Donnees personnelles</h2>
				<p>Le traitement des donnees personnelles est regi par notre <a href="/privacy">Politique de confidentialite</a>, qui fait partie integrante des presentes CGV.</p>
			</section>

			<section class="legal-section">
				<h2>11. Modification des CGV</h2>
				<p>L'Editeur se reserve le droit de modifier les presentes CGV a tout moment. Les modifications seront notifiees a l'Utilisateur par email ou notification dans l'application au moins 30 jours avant leur entree en vigueur.</p>
				<p>La poursuite de l'utilisation du service apres l'entree en vigueur des nouvelles CGV vaut acceptation de celles-ci. En cas de desaccord, l'Utilisateur peut resilier son abonnement avant l'entree en vigueur des modifications.</p>
			</section>

			<section class="legal-section">
				<h2>12. Force majeure</h2>
				<p>L'Editeur ne saurait etre tenu responsable de l'inexecution de ses obligations en cas de force majeure, telle que definie par l'article 1218 du Code civil, notamment en cas de catastrophe naturelle, pandemie, guerre, greve, panne d'infrastructure internet ou decisions gouvernementales.</p>
			</section>

			<section class="legal-section">
				<h2>13. Loi applicable et juridiction</h2>
				<p>Les presentes CGV sont soumises au <strong>droit francais</strong>.</p>
				<p>En cas de litige, les parties s'engagent a rechercher une solution amiable. A defaut d'accord amiable dans un delai de 30 jours, le litige sera soumis aux tribunaux competents de France.</p>
				<p>Conformement aux dispositions du Code de la consommation, l'Utilisateur peut recourir a un service de mediation de la consommation. Le mediateur competent est accessible via la plateforme europeenne de reglement des litiges en ligne : <a href="https://ec.europa.eu/consumers/odr" target="_blank" rel="noopener">https://ec.europa.eu/consumers/odr</a>.</p>
			</section>

			<section class="legal-section">
				<h2>14. Contact</h2>
				<div class="fv-glass legal-card">
					<p>Pour toute question relative aux presentes CGV :</p>
					<p><strong>Email :</strong> <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
					<p><strong>Editeur :</strong> Marius Harea (Fyxx)</p>
					<p><strong>Site web :</strong> <a href="https://fyxxvault.com">fyxxvault.com</a></p>
				</div>
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

	.legal-section ul {
		color: var(--fv-mist);
		line-height: 1.7;
		padding-left: 20px;
		margin: 0 0 12px;
		font-size: 15px;
	}

	.legal-section li {
		margin-bottom: 8px;
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
	.legal-card p {
		margin: 0 0 6px;
	}
	.legal-card p:last-child {
		margin: 0;
	}

	.pricing-grid {
		display: flex;
		flex-direction: column;
		gap: 16px;
	}

	.pricing-item {
		display: flex;
		flex-direction: column;
		gap: 2px;
	}

	.pricing-label {
		color: var(--fv-smoke);
		font-size: 13px;
		font-weight: 500;
		text-transform: uppercase;
		letter-spacing: 0.5px;
	}

	.pricing-value {
		color: white;
		font-size: 20px;
		font-weight: 700;
	}

	.pricing-note {
		color: var(--fv-success);
		font-size: 13px;
		font-weight: 500;
	}

	@media (max-width: 640px) {
		.legal-page {
			padding: 24px 16px 60px;
		}
	}
</style>
