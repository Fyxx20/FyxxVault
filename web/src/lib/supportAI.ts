import { env } from '$env/dynamic/private';

const SYSTEM_PROMPT_FR = `Tu es FyxxBot, l'assistant IA du support FyxxVault, un gestionnaire de mots de passe premium disponible sur iOS et le web.

STYLE DE REPONSE :
- Reponds TOUJOURS en francais.
- Sois chaleureux, amical et tutoie l'utilisateur.
- Utilise des sauts de ligne pour aerer tes reponses.
- Utilise des emojis avec parcimonie (1-2 max par reponse).
- Structure tes reponses avec des listes numerotees si tu donnes des etapes.
- Sois concis mais complet.
- Si tu ne peux pas aider, dis clairement qu'un humain va prendre le relais.

FONCTIONNALITES DE FYXXVAULT :
- Chiffrement AES-256 avec architecture zero-knowledge (on ne voit jamais les donnees)
- Coffre-fort de mots de passe (illimite en Pro, limite en gratuit)
- Alias email avec adresses @fyxxmail.com pour la confidentialite
- Generateur d'identites fictives pour proteger ta vie privee en ligne
- Generateur de codes TOTP (authentification a deux facteurs)
- Surveillance du dark web pour alerter si tes identifiants fuitent
- Import/export CSV pour migrer depuis d'autres gestionnaires (1Password, Bitwarden, LastPass, etc.)
- Verrouillage automatique avec delai configurable et deverrouillage biometrique (Face ID, Touch ID)
- Synchronisation cloud chiffree entre appareils
- Generateur de mots de passe avec longueur et options personnalisables
- Notes securisees
- Remplissage automatique dans le navigateur

ABONNEMENTS :
- Gratuit : fonctionnalites de base du coffre avec nombre d'elements limite
- Pro : 4.99 EUR/mois — elements illimites, alias email, dark web monitoring, TOTP, support prioritaire

DEPANNAGE COURANT :
- Synchronisation : verifier la connexion internet, tirer vers le bas pour actualiser, se deconnecter/reconnecter
- Import : le CSV doit avoir les colonnes name, url, username, password, notes
- Verrouillage : configurable dans Parametres > Securite
- Abonnement : gere via App Store (iOS) ou Stripe (web)
- Suppression de compte : Parametres > Compte > Supprimer le compte
- Mot de passe oublie : lien "Mot de passe oublie" sur l'ecran de connexion

REGLES IMPORTANTES :
1. Ne jamais inventer de fonctionnalites qui n'existent pas.
2. Ne jamais demander le mot de passe maitre ou les cles de chiffrement.
3. Pour les problemes de facturation, conseiller de contacter le support pour un examen manuel.
4. Si le probleme est trop complexe, indiquer qu'un agent humain prendra le relais.`;

const SYSTEM_PROMPT_EN = `You are FyxxBot, the AI support assistant for FyxxVault, a premium password manager app available on iOS and the web.

RESPONSE STYLE:
- ALWAYS respond in English.
- Be warm, friendly and approachable.
- Use line breaks to space out your responses.
- Use emojis sparingly (1-2 max per response).
- Structure your responses with numbered lists when giving steps.
- Be concise but thorough.
- If you can't help, clearly state that a human agent will take over.

KEY FEATURES OF FYXXVAULT:
- AES-256 encryption with zero-knowledge architecture (we never see user data)
- Password vault with unlimited storage (Pro) or limited (Free)
- Email aliases with @fyxxmail.com addresses for privacy
- Identity generator for creating fake identities online
- TOTP two-factor authentication code generator
- Dark web monitoring to alert users if their credentials are leaked
- CSV import/export for migrating from other password managers (1Password, Bitwarden, LastPass, etc.)
- Auto-lock with configurable timeout and biometric unlock (Face ID, Touch ID)
- Cloud sync across devices via encrypted backend
- Password generator with customizable length and character options
- Secure notes
- Browser auto-fill support

PLANS:
- Free plan: basic vault features with limited items
- Pro plan: 4.99 EUR/month — unlimited items, email aliases, dark web monitoring, TOTP, priority support

COMMON TROUBLESHOOTING:
- Sync issues: check internet connection, pull-to-refresh, sign out and back in
- Import issues: CSV must have columns name, url, username, password, notes
- Auto-lock: configurable in Settings > Security
- Subscription: managed through Apple App Store or Stripe on web
- Account deletion: Settings > Account > Delete Account
- Password reset: use "Forgot Password" on login screen

IMPORTANT RULES:
1. Never make up features that don't exist.
2. Never ask for the user's master password or encryption keys.
3. For billing issues, advise contacting support for manual review.
4. If the issue is too complex, indicate that a human agent will follow up.`;

const FAQ_KEYWORDS: Record<string, { keywords: string[]; response_en: string; response_fr: string }> = {
	sync: {
		keywords: ['sync', 'synchronization', 'syncing', 'synchroniser', 'synchronisation', 'cloud'],
		response_en: '🔄 For sync issues, try these steps:\n\n1. Check your internet connection\n2. Pull down to refresh in the vault\n3. Sign out and sign back in\n\nIf the issue persists, a human agent will review your ticket.',
		response_fr: '🔄 Pour les problemes de synchronisation, essaie ces etapes :\n\n1. Verifie ta connexion internet\n2. Tire vers le bas pour actualiser le coffre\n3. Deconnecte-toi puis reconnecte-toi\n\nSi le probleme persiste, un agent humain prendra le relais.'
	},
	import: {
		keywords: ['import', 'csv', 'migrate', 'migration', 'importer', '1password', 'bitwarden', 'lastpass'],
		response_en: '📂 To import your passwords:\n\n1. Go to Settings > Import/Export > Import CSV\n2. Make sure your CSV has these columns: name, url, username, password, notes\n3. You can export from most password managers in CSV format\n\nNeed help with a specific format? Let me know!',
		response_fr: '📂 Pour importer tes mots de passe :\n\n1. Va dans Parametres > Import/Export > Importer CSV\n2. Ton CSV doit contenir les colonnes : name, url, username, password, notes\n3. Tu peux exporter depuis la plupart des gestionnaires au format CSV\n\nBesoin d\'aide avec un format specifique ? Dis-moi !'
	},
	subscription: {
		keywords: ['subscription', 'pro', 'plan', 'price', 'payment', 'billing', 'abonnement', 'prix', 'paiement', 'facturation', 'cancel', 'annuler'],
		response_en: '💳 FyxxVault Pro costs 4.99 EUR/month and includes:\n\n• Unlimited vault items\n• Email aliases (@fyxxmail.com)\n• Dark web monitoring\n• TOTP authenticator\n• Priority support\n\nYou can manage your subscription in Settings > Subscription.\n\nFor billing issues, a human agent will assist you.',
		response_fr: '💳 FyxxVault Pro coute 4.99 EUR/mois et inclut :\n\n• Elements illimites dans le coffre\n• Alias email (@fyxxmail.com)\n• Surveillance du dark web\n• Authentificateur TOTP\n• Support prioritaire\n\nTu peux gerer ton abonnement dans Parametres > Abonnement.\n\nPour les problemes de facturation, un agent humain va t\'aider.'
	},
	password: {
		keywords: ['password', 'master', 'forgot', 'reset', 'mot de passe', 'oublie', 'reinitialiser'],
		response_en: '🔑 To reset your password:\n\n1. Go to the login screen\n2. Click "Forgot Password"\n3. A reset email will be sent to your registered address\n\n⚠️ Important: Your master password cannot be recovered by us due to zero-knowledge encryption. If you forgot it, you\'ll need to create a new account.',
		response_fr: '🔑 Pour reinitialiser ton mot de passe :\n\n1. Va sur l\'ecran de connexion\n2. Clique sur "Mot de passe oublie"\n3. Un email de reinitialisation sera envoye a ton adresse\n\n⚠️ Important : ton mot de passe maitre ne peut pas etre recupere par nos soins (chiffrement zero-knowledge). Si tu l\'as oublie, il faudra creer un nouveau compte.'
	},
	security: {
		keywords: ['security', 'encryption', 'safe', 'secure', 'hack', 'breach', 'securite', 'chiffrement', 'pirate'],
		response_en: '🛡️ FyxxVault takes your security seriously:\n\n• AES-256 encryption (military-grade)\n• Zero-knowledge architecture\n• Your data is encrypted on your device before reaching our servers\n• We never have access to your master password\n\nYour vault is as secure as it gets!',
		response_fr: '🛡️ FyxxVault prend ta securite au serieux :\n\n• Chiffrement AES-256 (niveau militaire)\n• Architecture zero-knowledge\n• Tes donnees sont chiffrees sur ton appareil avant d\'etre envoyees\n• On n\'a jamais acces a ton mot de passe maitre\n\nTon coffre est ultra securise !'
	},
	alias: {
		keywords: ['alias', 'email', 'fyxxmail', 'mail', 'address'],
		response_en: '📧 Email aliases (@fyxxmail.com) are a Pro feature!\n\nHow it works:\n1. Create an alias in the Email section\n2. Emails sent to your alias are forwarded to your real inbox\n3. Your actual email stays private\n\nPerfect for signing up on sketchy websites without revealing your real email.',
		response_fr: '📧 Les alias email (@fyxxmail.com) sont une fonctionnalite Pro !\n\nComment ca marche :\n1. Cree un alias dans la section Email\n2. Les emails envoyes a ton alias sont rediriges vers ta vraie boite mail\n3. Ton vrai email reste prive\n\nParfait pour s\'inscrire sur des sites sans reveler ton vrai email.'
	},
	delete: {
		keywords: ['delete', 'account', 'supprimer', 'compte', 'remove', 'data'],
		response_en: '⚠️ To delete your account:\n\n1. Go to Settings > Account > Delete Account\n2. Confirm the deletion\n\nThis action is irreversible and will permanently delete all your vault data.\n\nMake sure to export your data first if needed!',
		response_fr: '⚠️ Pour supprimer ton compte :\n\n1. Va dans Parametres > Compte > Supprimer le compte\n2. Confirme la suppression\n\nCette action est irreversible et supprimera toutes tes donnees.\n\nPense a exporter tes donnees avant si besoin !'
	}
};

function fallbackResponse(message: string, lang: string): string {
	const lower = message.toLowerCase();

	for (const faq of Object.values(FAQ_KEYWORDS)) {
		if (faq.keywords.some(kw => lower.includes(kw))) {
			return lang === 'fr' ? faq.response_fr : faq.response_en;
		}
	}

	if (lang === 'fr') {
		return 'Merci pour ton message ! 👋\n\nJe n\'ai pas pu identifier precisement ton probleme. Un agent humain va examiner ton ticket et te repondre dans les plus brefs delais.\n\nEn attendant, n\'hesite pas a me donner plus de details !';
	}
	return 'Thanks for your message! 👋\n\nI wasn\'t able to identify your specific issue. A human agent will review your ticket and respond as soon as possible.\n\nIn the meantime, feel free to give me more details!';
}

export async function generateAIResponse(userMessage: string, lang: string = 'en'): Promise<string> {
	const openaiKey = env.OPENAI_API_KEY;
	const anthropicKey = env.ANTHROPIC_API_KEY;
	const systemPrompt = lang === 'fr' ? SYSTEM_PROMPT_FR : SYSTEM_PROMPT_EN;

	// Try OpenAI first, then Anthropic, then fallback
	if (openaiKey) {
		try {
			const res = await fetch('https://api.openai.com/v1/chat/completions', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Authorization': `Bearer ${openaiKey}`
				},
				body: JSON.stringify({
					model: 'gpt-4o-mini',
					max_tokens: 600,
					temperature: 0.7,
					messages: [
						{ role: 'system', content: systemPrompt },
						{ role: 'user', content: userMessage }
					]
				})
			});

			if (!res.ok) {
				console.error('OpenAI API error:', res.status, await res.text());
				return fallbackResponse(userMessage, lang);
			}

			const data = await res.json();
			const text = data?.choices?.[0]?.message?.content;
			if (typeof text === 'string' && text.length > 0) {
				return text;
			}
			return fallbackResponse(userMessage, lang);
		} catch (err) {
			console.error('OpenAI response failed:', err);
			return fallbackResponse(userMessage, lang);
		}
	}

	if (anthropicKey) {
		try {
			const res = await fetch('https://api.anthropic.com/v1/messages', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'x-api-key': anthropicKey,
					'anthropic-version': '2023-06-01'
				},
				body: JSON.stringify({
					model: 'claude-sonnet-4-20250514',
					max_tokens: 600,
					system: systemPrompt,
					messages: [{ role: 'user', content: userMessage }]
				})
			});

			if (!res.ok) {
				console.error('Anthropic API error:', res.status, await res.text());
				return fallbackResponse(userMessage, lang);
			}

			const data = await res.json();
			const text = data?.content?.[0]?.text;
			if (typeof text === 'string' && text.length > 0) {
				return text;
			}
			return fallbackResponse(userMessage, lang);
		} catch (err) {
			console.error('Anthropic response failed:', err);
			return fallbackResponse(userMessage, lang);
		}
	}

	return fallbackResponse(userMessage, lang);
}
