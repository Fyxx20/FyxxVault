<script lang="ts">
	import { onMount } from 'svelte';
	let mounted = $state(false);
	onMount(() => { mounted = true; });
</script>

<svelte:head>
	<title>Politique de confidentialite - FyxxVault</title>
	<meta name="description" content="Politique de confidentialite de FyxxVault. Decouvrez comment nous protegeons vos donnees avec notre architecture zero-knowledge." />
</svelte:head>

<div class="legal-page" class:visible={mounted}>
	<div class="legal-container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Retour a l'accueil
		</a>

		<h1 class="legal-title">Politique de <span class="fv-gradient-text">confidentialite</span></h1>
		<p class="legal-date">Derniere mise a jour : Mars 2026</p>

		<div class="legal-content">
			<section class="legal-section">
				<h2>1. Introduction</h2>
				<p>FyxxVault (ci-apres "nous", "notre" ou "le Service"), edite par Marius Harea sous la marque Fyxx, s'engage a proteger la vie privee de ses utilisateurs. La presente politique de confidentialite decrit les donnees personnelles que nous collectons, comment nous les utilisons, et les droits dont vous disposez concernant vos informations.</p>
				<p>FyxxVault est un gestionnaire de mots de passe base sur une <strong>architecture zero-knowledge</strong>. Cela signifie que nous ne pouvons techniquement pas acceder au contenu de votre coffre-fort, meme si nous le voulions.</p>
			</section>

			<section class="legal-section">
				<h2>2. Responsable du traitement</h2>
				<div class="fv-glass legal-card">
					<p><strong>Marius Harea</strong></p>
					<p>Editeur de FyxxVault (marque Fyxx)</p>
					<p>Localisation : France</p>
					<p>Contact : <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
				</div>
			</section>

			<section class="legal-section">
				<h2>3. Donnees collectees</h2>
				<h3>3.1 Donnees de compte</h3>
				<ul>
					<li><strong>Adresse e-mail</strong> : utilisee pour l'authentification et la communication relative au service.</li>
					<li><strong>Mot de passe maitre (hashe)</strong> : votre mot de passe maitre n'est jamais stocke en clair. Seul un hash derive (via PBKDF2 avec sel unique) est conserve pour la verification.</li>
					<li><strong>Date de creation du compte</strong> et <strong>date de derniere connexion</strong>.</li>
				</ul>

				<h3>3.2 Donnees du coffre-fort (chiffrees)</h3>
				<ul>
					<li>Identifiants (noms d'utilisateur, mots de passe)</li>
					<li>Notes securisees</li>
					<li>Codes TOTP (2FA)</li>
					<li>Informations de cartes bancaires</li>
					<li>Donnees d'identite</li>
				</ul>
				<div class="legal-highlight">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
					<p><strong>Architecture zero-knowledge :</strong> toutes les donnees du coffre-fort sont chiffrees cote client avec AES-256-GCM avant d'etre envoyees a nos serveurs. La cle de chiffrement est derivee de votre mot de passe maitre et n'est jamais transmise. <strong>Nous ne pouvons pas lire, acceder ou dechiffrer le contenu de votre coffre.</strong></p>
				</div>

				<h3>3.3 Donnees techniques</h3>
				<ul>
					<li>Adresse IP (logs serveur, conserves 30 jours maximum)</li>
					<li>Type de navigateur et systeme d'exploitation (pour la compatibilite)</li>
					<li>Donnees d'utilisation anonymisees (nombre d'entrees, statistiques de securite generales)</li>
				</ul>

				<h3>3.4 Donnees de paiement</h3>
				<p>Les paiements sont traites par <strong>Stripe</strong>. Nous ne stockons jamais vos numeros de carte bancaire. Stripe nous transmet uniquement un identifiant de transaction et le statut du paiement. Consultez la <a href="https://stripe.com/fr/privacy" target="_blank" rel="noopener">politique de confidentialite de Stripe</a>.</p>
			</section>

			<section class="legal-section">
				<h2>4. Utilisation des donnees</h2>
				<p>Nous utilisons vos donnees uniquement pour :</p>
				<ul>
					<li>Fournir et maintenir le service FyxxVault</li>
					<li>Authentifier votre acces au compte</li>
					<li>Synchroniser votre coffre-fort chiffre entre vos appareils</li>
					<li>Gerer votre abonnement et la facturation</li>
					<li>Vous envoyer des communications essentielles (securite, mise a jour du service)</li>
					<li>Ameliorer le service (donnees anonymisees uniquement)</li>
				</ul>
				<p>Nous ne vendons <strong>jamais</strong> vos donnees personnelles. Nous n'utilisons <strong>aucune</strong> donnee a des fins publicitaires.</p>
			</section>

			<section class="legal-section">
				<h2>5. Base legale du traitement</h2>
				<ul>
					<li><strong>Execution du contrat</strong> (Art. 6(1)(b) RGPD) : pour fournir le service auquel vous avez souscrit.</li>
					<li><strong>Interet legitime</strong> (Art. 6(1)(f) RGPD) : pour assurer la securite et l'amelioration du service.</li>
					<li><strong>Consentement</strong> (Art. 6(1)(a) RGPD) : pour les communications marketing optionnelles.</li>
					<li><strong>Obligation legale</strong> (Art. 6(1)(c) RGPD) : pour repondre aux obligations legales et fiscales.</li>
				</ul>
			</section>

			<section class="legal-section">
				<h2>6. Hebergement et sous-traitants</h2>
				<div class="legal-table-wrapper">
					<table class="legal-table">
						<thead>
							<tr>
								<th>Prestataire</th>
								<th>Fonction</th>
								<th>Localisation</th>
							</tr>
						</thead>
						<tbody>
							<tr>
								<td>Supabase</td>
								<td>Base de donnees, authentification</td>
								<td>Union europeenne (EU)</td>
							</tr>
							<tr>
								<td>Netlify</td>
								<td>Hebergement du site web</td>
								<td>Etats-Unis (clauses contractuelles types)</td>
							</tr>
							<tr>
								<td>Stripe</td>
								<td>Traitement des paiements</td>
								<td>Etats-Unis / EU (certifie Privacy Shield)</td>
							</tr>
							<tr>
								<td>addy.io</td>
								<td>Generation d'emails masques (optionnel)</td>
								<td>Union europeenne</td>
							</tr>
							<tr>
								<td>HIBP (Have I Been Pwned)</td>
								<td>Verification de fuites de donnees</td>
								<td>Australie</td>
							</tr>
						</tbody>
					</table>
				</div>
				<p>Tous nos sous-traitants sont lies par des accords de traitement des donnees conformes au RGPD. Les donnees hebergees sur Supabase sont situees dans l'Union europeenne.</p>
			</section>

			<section class="legal-section">
				<h2>7. Cookies et traceurs</h2>
				<p>FyxxVault utilise un nombre minimal de cookies :</p>
				<ul>
					<li><strong>Cookie de session</strong> : necessaire au fonctionnement de l'authentification. Strictement essentiel.</li>
					<li><strong>Preferences utilisateur</strong> : theme, langue (stockage local).</li>
				</ul>
				<div class="legal-highlight">
					<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
					<p><strong>Aucun cookie de tracking, aucun cookie publicitaire, aucun outil d'analyse tiers (Google Analytics, etc.)</strong>. Votre navigation sur FyxxVault n'est pas tracee.</p>
				</div>
			</section>

			<section class="legal-section">
				<h2>8. Duree de conservation</h2>
				<ul>
					<li><strong>Donnees de compte</strong> : conservees pendant toute la duree de votre compte, puis supprimees dans un delai de 30 jours apres la suppression du compte.</li>
					<li><strong>Donnees du coffre-fort</strong> : supprimees immediatement lors de la suppression du compte.</li>
					<li><strong>Logs serveur</strong> : conserves 30 jours maximum.</li>
					<li><strong>Donnees de facturation</strong> : conservees selon les obligations legales (10 ans pour les obligations comptables francaises).</li>
				</ul>
			</section>

			<section class="legal-section">
				<h2>9. Partage avec des tiers</h2>
				<p>Nous ne partageons vos donnees personnelles qu'avec les prestataires mentionnes en section 6, et uniquement dans la mesure necessaire au fonctionnement du service :</p>
				<ul>
					<li><strong>Stripe</strong> : votre email et les informations de paiement pour le traitement des transactions.</li>
					<li><strong>addy.io</strong> : uniquement si vous activez la fonctionnalite d'emails masques (aucune donnee du coffre n'est partagee).</li>
					<li><strong>HIBP</strong> : verification anonymisee par k-anonymity (seuls les 5 premiers caracteres du hash SHA-1 sont envoyes, jamais le mot de passe).</li>
				</ul>
				<p>Nous ne vendons, ne louons et ne communiquons jamais vos donnees a des fins commerciales ou publicitaires.</p>
			</section>

			<section class="legal-section">
				<h2>10. Vos droits (RGPD)</h2>
				<p>Conformement au Reglement General sur la Protection des Donnees (RGPD), vous disposez des droits suivants :</p>
				<ul>
					<li><strong>Droit d'acces</strong> (Art. 15) : obtenir une copie de vos donnees personnelles.</li>
					<li><strong>Droit de rectification</strong> (Art. 16) : corriger vos donnees inexactes ou incompletes.</li>
					<li><strong>Droit a l'effacement</strong> (Art. 17) : demander la suppression de vos donnees.</li>
					<li><strong>Droit a la portabilite</strong> (Art. 20) : recevoir vos donnees dans un format structure et lisible par machine.</li>
					<li><strong>Droit d'opposition</strong> (Art. 21) : vous opposer au traitement de vos donnees.</li>
					<li><strong>Droit a la limitation</strong> (Art. 18) : limiter le traitement de vos donnees.</li>
				</ul>
				<p>Pour exercer vos droits, contactez-nous a <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a>. Nous repondrons dans un delai de 30 jours.</p>
				<p>Vous pouvez egalement introduire une reclamation aupres de la <strong>CNIL</strong> (Commission Nationale de l'Informatique et des Libertes) : <a href="https://www.cnil.fr" target="_blank" rel="noopener">www.cnil.fr</a>.</p>
			</section>

			<section class="legal-section">
				<h2>11. Securite des donnees</h2>
				<ul>
					<li>Chiffrement AES-256-GCM pour toutes les donnees du coffre</li>
					<li>Derivation de cle via PBKDF2 avec sel unique par utilisateur</li>
					<li>Transport securise via TLS 1.3</li>
					<li>Architecture zero-knowledge : la cle de chiffrement ne quitte jamais votre appareil</li>
					<li>Hashage des mots de passe maitre cote serveur via bcrypt</li>
					<li>Politique de securite stricte sur l'infrastructure (Supabase RLS)</li>
				</ul>
			</section>

			<section class="legal-section">
				<h2>12. Transferts internationaux</h2>
				<p>Les donnees de votre coffre-fort sont hebergees dans l'Union europeenne via Supabase. Certains prestataires (Netlify, Stripe) peuvent traiter des donnees aux Etats-Unis, sous le couvert de clauses contractuelles types approuvees par la Commission europeenne, garantissant un niveau de protection adequat.</p>
			</section>

			<section class="legal-section">
				<h2>13. Modifications de cette politique</h2>
				<p>Nous pouvons mettre a jour cette politique de confidentialite. En cas de modification substantielle, nous vous en informerons par email ou par notification dans l'application. La date de derniere mise a jour est indiquee en haut de cette page.</p>
			</section>

			<section class="legal-section">
				<h2>14. Contact</h2>
				<div class="fv-glass legal-card">
					<p>Pour toute question relative a cette politique ou a vos donnees personnelles :</p>
					<p><strong>Email :</strong> <a href="mailto:contact@fyxxvault.com">contact@fyxxvault.com</a></p>
					<p><strong>Responsable du traitement :</strong> Marius Harea</p>
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

	.legal-highlight {
		display: flex;
		gap: 14px;
		padding: 16px 20px;
		background: rgba(0, 212, 255, 0.06);
		border: 1px solid rgba(0, 212, 255, 0.15);
		border-radius: 12px;
		margin: 16px 0;
		align-items: flex-start;
	}
	.legal-highlight svg {
		flex-shrink: 0;
		margin-top: 2px;
	}
	.legal-highlight p {
		margin: 0;
		font-size: 14px;
	}

	.legal-table-wrapper {
		overflow-x: auto;
		margin: 16px 0;
		border-radius: 12px;
		border: 1px solid rgba(255,255,255,0.08);
	}

	.legal-table {
		width: 100%;
		border-collapse: collapse;
		font-size: 14px;
	}
	.legal-table th {
		background: rgba(255,255,255,0.05);
		color: var(--fv-silver);
		font-weight: 600;
		padding: 12px 16px;
		text-align: left;
		border-bottom: 1px solid rgba(255,255,255,0.08);
	}
	.legal-table td {
		padding: 12px 16px;
		color: var(--fv-mist);
		border-bottom: 1px solid rgba(255,255,255,0.04);
	}
	.legal-table tr:last-child td {
		border-bottom: none;
	}

	@media (max-width: 640px) {
		.legal-page {
			padding: 24px 16px 60px;
		}
		.legal-highlight {
			flex-direction: column;
			gap: 8px;
		}
	}
</style>
