<script lang="ts">
	import { onMount } from 'svelte';

	let mounted = $state(false);
	let openItem = $state<string | null>(null);

	onMount(() => { mounted = true; });

	function toggle(id: string) {
		openItem = openItem === id ? null : id;
	}

	interface FaqItem {
		id: string;
		question: string;
		answer: string;
	}

	interface FaqCategory {
		title: string;
		icon: string;
		color: string;
		items: FaqItem[];
	}

	const categories: FaqCategory[] = [
		{
			title: 'General',
			icon: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
			color: 'var(--fv-cyan)',
			items: [
				{
					id: 'gen-1',
					question: "Qu'est-ce que FyxxVault ?",
					answer: "FyxxVault est un gestionnaire de mots de passe securise avec une architecture zero-knowledge. Il vous permet de stocker, generer et remplir automatiquement vos mots de passe, codes 2FA, notes securisees et informations sensibles. Toutes vos donnees sont chiffrees avec AES-256-GCM avant de quitter votre appareil — meme nous ne pouvons pas les lire."
				},
				{
					id: 'gen-2',
					question: "FyxxVault est-il gratuit ?",
					answer: "Oui, FyxxVault propose une offre gratuite qui inclut les fonctionnalites essentielles : stockage de mots de passe, generateur, et AutoFill. L'offre Pro (4,99 EUR/mois ou 41,99 EUR/an) ajoute les codes TOTP integres, les emails masques, la surveillance de fuites, et le stockage illimite. Un essai gratuit de 14 jours est offert pour tester l'offre Pro."
				},
				{
					id: 'gen-3',
					question: "Sur quelles plateformes est disponible FyxxVault ?",
					answer: "FyxxVault est actuellement disponible sur iOS (iPhone et iPad) avec AutoFill natif, et sur le web via n'importe quel navigateur moderne a l'adresse fyxxvault.com. Des applications Android et des extensions navigateur sont prevues pour les prochaines versions."
				}
			]
		},
		{
			title: 'Securite',
			icon: 'M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z',
			color: 'var(--fv-success)',
			items: [
				{
					id: 'sec-1',
					question: "Comment mes donnees sont-elles protegees ?",
					answer: "Vos donnees sont protegees par un chiffrement AES-256-GCM, le meme standard utilise par les gouvernements et les armees. La cle de chiffrement est derivee de votre mot de passe maitre via PBKDF2 avec un sel unique. Le chiffrement et le dechiffrement se font exclusivement sur votre appareil — les donnees ne transitent sur le reseau que sous forme chiffree."
				},
				{
					id: 'sec-2',
					question: "Qu'est-ce que le zero-knowledge ?",
					answer: "Le zero-knowledge (connaissance nulle) signifie que FyxxVault est concu de sorte que nous n'avons aucune connaissance du contenu de votre coffre-fort. Votre mot de passe maitre n'est jamais envoye a nos serveurs, et la cle de chiffrement ne quitte jamais votre appareil. Meme en cas de demande judiciaire, nous ne pourrions pas fournir le contenu de votre coffre car nous n'avons techniquement aucun moyen d'y acceder."
				},
				{
					id: 'sec-3',
					question: "Que se passe-t-il si FyxxVault est pirate ?",
					answer: "Grace a l'architecture zero-knowledge, meme si nos serveurs etaient compromis, les attaquants n'obtiendraient que des donnees chiffrees inutilisables. Sans votre mot de passe maitre (qui n'est jamais stocke sur nos serveurs), il est mathematiquement impossible de dechiffrer vos donnees. C'est l'avantage fondamental du chiffrement de bout en bout."
				},
				{
					id: 'sec-4',
					question: "Pouvez-vous acceder a mes mots de passe ?",
					answer: "Non, absolument pas. C'est le principe meme du zero-knowledge. Votre mot de passe maitre et votre cle de chiffrement ne quittent jamais votre appareil. Les donnees stockees sur nos serveurs sont chiffrees et nous ne disposons d'aucun moyen pour les dechiffrer. C'est une garantie architecturale, pas une simple promesse."
				}
			]
		},
		{
			title: 'Compte',
			icon: 'M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2M12 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
			color: 'var(--fv-violet)',
			items: [
				{
					id: 'acc-1',
					question: "Comment creer un compte ?",
					answer: "Rendez-vous sur fyxxvault.com/register ou telechargez l'application iOS. Entrez votre adresse email et choisissez un mot de passe maitre fort (nous recommandons au moins 12 caracteres avec une combinaison de lettres, chiffres et symboles). C'est tout — votre coffre-fort est pret en quelques secondes."
				},
				{
					id: 'acc-2',
					question: "J'ai oublie mon mot de passe maitre, que faire ?",
					answer: "En raison de l'architecture zero-knowledge, nous ne pouvons malheureusement pas reinitialiser votre mot de passe maitre. C'est le prix de la securite maximale : personne, meme nous, ne peut acceder a vos donnees sans ce mot de passe. C'est pourquoi nous insistons pour que vous le memorisiez bien ou que vous le notiez dans un lieu sur et physique. Si vous avez perdu votre mot de passe maitre, vous devrez creer un nouveau compte."
				},
				{
					id: 'acc-3',
					question: "Comment supprimer mon compte ?",
					answer: "Vous pouvez supprimer votre compte depuis les parametres de l'application ou en contactant contact@fyxxvault.com. La suppression est definitive : toutes vos donnees chiffrees seront supprimees de nos serveurs sous 30 jours. Nous vous recommandons d'exporter vos donnees avant de proceder a la suppression."
				},
				{
					id: 'acc-4',
					question: "Comment exporter mes donnees ?",
					answer: "Dans l'application, allez dans Parametres puis Exporter. Vous pouvez exporter vos donnees au format CSV ou JSON chiffre. L'export CSV est en clair (pratique pour migrer vers un autre service), tandis que l'export JSON conserve le chiffrement. C'est votre droit a la portabilite garanti par le RGPD."
				}
			]
		},
		{
			title: 'Abonnement',
			icon: 'M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z M7 7h.01',
			color: 'var(--fv-gold)',
			items: [
				{
					id: 'sub-1',
					question: "Quelle est la difference entre Gratuit et Pro ?",
					answer: "L'offre Gratuite inclut le stockage de mots de passe, le generateur, l'AutoFill et la synchronisation entre appareils. L'offre Pro ajoute : les codes TOTP (2FA) integres, la generation d'emails masques via addy.io, la surveillance automatique de fuites de donnees (HIBP), le stockage illimite d'entrees, le mode panique, et le support prioritaire."
				},
				{
					id: 'sub-2',
					question: "Comment annuler mon abonnement ?",
					answer: "Vous pouvez annuler votre abonnement a tout moment depuis les parametres de votre compte, section Abonnement. L'annulation prend effet a la fin de la periode en cours — vous conservez l'acces aux fonctionnalites Pro jusqu'a la fin de la periode payee. Vous pouvez aussi contacter contact@fyxxvault.com."
				},
				{
					id: 'sub-3',
					question: "Quels moyens de paiement acceptez-vous ?",
					answer: "Les paiements sont traites par Stripe, une plateforme de paiement securisee. Nous acceptons les cartes Visa, Mastercard, American Express, et les autres moyens de paiement pris en charge par Stripe selon votre pays. Vos informations bancaires ne sont jamais stockees sur nos serveurs."
				}
			]
		},
		{
			title: 'Technique',
			icon: 'M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z',
			color: 'var(--fv-rose)',
			items: [
				{
					id: 'tech-1',
					question: "Comment fonctionne l'AutoFill sur iOS ?",
					answer: "FyxxVault utilise l'extension AutoFill Credential Provider d'Apple. Apres l'installation, activez FyxxVault dans Reglages > Mots de passe > Options de mots de passe > Remplissage automatique. Ensuite, lorsque vous vous connectez a un site ou une app, iOS proposera automatiquement les identifiants correspondants stockes dans votre coffre FyxxVault."
				},
				{
					id: 'tech-2',
					question: "Comment importer depuis 1Password ou Bitwarden ?",
					answer: "Exportez d'abord vos donnees depuis votre gestionnaire actuel au format CSV. Puis dans FyxxVault, allez dans Parametres > Importer et selectionnez votre fichier CSV. FyxxVault detecte automatiquement le format (1Password, Bitwarden, LastPass, Chrome, Safari, etc.) et importe vos identifiants. Pensez a supprimer le fichier CSV apres l'import."
				},
				{
					id: 'tech-3',
					question: "Qu'est-ce que le mode panique ?",
					answer: "Le mode panique (fonctionnalite Pro) permet de verrouiller instantanement votre coffre-fort et de deconnecter toutes les sessions actives en un seul geste. Utile si vous pensez que votre compte est compromis, si vous avez laisse une session ouverte sur un appareil non securise, ou en situation de contrainte. Activable depuis l'application d'un simple tap."
				}
			]
		}
	];
</script>

<svelte:head>
	<title>FAQ - FyxxVault</title>
	<meta name="description" content="Questions frequentes sur FyxxVault : securite, fonctionnalites, abonnement, et support technique." />
</svelte:head>

<div class="faq-page" class:visible={mounted}>
	<div class="faq-container">
		<a href="/" class="back-link">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
			Retour a l'accueil
		</a>

		<h1 class="faq-title">Questions <span class="fv-gradient-text">frequentes</span></h1>
		<p class="faq-subtitle">Trouvez rapidement les reponses a vos questions sur FyxxVault.</p>

		<div class="faq-categories">
			{#each categories as category}
				<div class="faq-category">
					<div class="faq-category-header">
						<div class="faq-category-icon" style="--icon-color: {category.color}">
							<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="{category.icon}"/></svg>
						</div>
						<h2>{category.title}</h2>
					</div>

					<div class="faq-items">
						{#each category.items as item}
							<div class="faq-item" class:open={openItem === item.id}>
								<button class="faq-question" onclick={() => toggle(item.id)} aria-expanded={openItem === item.id}>
									<span>{item.question}</span>
									<svg class="faq-chevron" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"/></svg>
								</button>
								<div class="faq-answer-wrapper">
									<div class="faq-answer">
										<p>{item.answer}</p>
									</div>
								</div>
							</div>
						{/each}
					</div>
				</div>
			{/each}
		</div>

		<div class="faq-cta fv-glass">
			<h3>Vous n'avez pas trouve votre reponse ?</h3>
			<p>Notre equipe est la pour vous aider.</p>
			<a href="mailto:contact@fyxxvault.com" class="fv-btn fv-btn-primary">
				Contactez-nous
			</a>
		</div>
	</div>
</div>

<style>
	.faq-page {
		min-height: 100vh;
		background: var(--fv-abyss);
		padding: 40px 20px 80px;
		opacity: 0;
		transform: translateY(12px);
		transition: opacity 0.5s ease, transform 0.5s ease;
	}
	.faq-page.visible {
		opacity: 1;
		transform: translateY(0);
	}

	.faq-container {
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

	.faq-title {
		font-size: clamp(28px, 5vw, 42px);
		font-weight: 800;
		color: white;
		margin: 0 0 12px;
		line-height: 1.2;
	}

	.faq-subtitle {
		color: var(--fv-smoke);
		font-size: 16px;
		margin: 0 0 48px;
		line-height: 1.5;
	}

	.faq-categories {
		display: flex;
		flex-direction: column;
		gap: 40px;
	}

	.faq-category-header {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-bottom: 16px;
	}

	.faq-category-icon {
		width: 40px;
		height: 40px;
		border-radius: 12px;
		background: color-mix(in srgb, var(--icon-color) 12%, transparent);
		display: flex;
		align-items: center;
		justify-content: center;
		color: var(--icon-color);
		flex-shrink: 0;
	}

	.faq-category-header h2 {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0;
	}

	.faq-items {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.faq-item {
		border-radius: 12px;
		background: rgba(255,255,255,0.03);
		border: 1px solid rgba(255,255,255,0.06);
		overflow: hidden;
		transition: border-color 0.2s ease, background 0.2s ease;
	}
	.faq-item:hover {
		border-color: rgba(255,255,255,0.1);
		background: rgba(255,255,255,0.04);
	}
	.faq-item.open {
		border-color: rgba(0, 212, 255, 0.15);
		background: rgba(0, 212, 255, 0.03);
	}

	.faq-question {
		width: 100%;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
		padding: 16px 20px;
		background: none;
		border: none;
		cursor: pointer;
		text-align: left;
		color: var(--fv-silver);
		font-size: 15px;
		font-weight: 600;
		font-family: inherit;
		line-height: 1.4;
		transition: color 0.2s ease;
	}
	.faq-question:hover {
		color: white;
	}

	.faq-chevron {
		flex-shrink: 0;
		color: var(--fv-smoke);
		transition: transform 0.3s ease, color 0.2s ease;
	}
	.faq-item.open .faq-chevron {
		transform: rotate(180deg);
		color: var(--fv-cyan);
	}

	.faq-answer-wrapper {
		display: grid;
		grid-template-rows: 0fr;
		transition: grid-template-rows 0.3s ease;
	}
	.faq-item.open .faq-answer-wrapper {
		grid-template-rows: 1fr;
	}

	.faq-answer {
		overflow: hidden;
	}

	.faq-answer p {
		padding: 0 20px 16px;
		margin: 0;
		color: var(--fv-mist);
		font-size: 14px;
		line-height: 1.7;
	}

	.faq-cta {
		margin-top: 60px;
		padding: 40px;
		text-align: center;
	}
	.faq-cta h3 {
		font-size: 20px;
		font-weight: 700;
		color: white;
		margin: 0 0 8px;
	}
	.faq-cta p {
		color: var(--fv-smoke);
		margin: 0 0 24px;
		font-size: 15px;
	}

	@media (max-width: 640px) {
		.faq-page {
			padding: 24px 16px 60px;
		}
		.faq-cta {
			padding: 28px 20px;
		}
	}
</style>
