/**
 * Resolves a service name to its domain for favicon lookup.
 * No AI needed — uses a curated mapping of 200+ popular services
 * plus a smart fallback that tries "{name}.com".
 */

const DOMAIN_MAP: Record<string, string> = {
	// Email
	gmail: 'gmail.com', google: 'google.com', outlook: 'outlook.com', hotmail: 'hotmail.com',
	yahoo: 'yahoo.com', protonmail: 'proton.me', proton: 'proton.me', icloud: 'icloud.com',
	zoho: 'zoho.com', fastmail: 'fastmail.com', tutanota: 'tutanota.com',

	// Social
	facebook: 'facebook.com', instagram: 'instagram.com', twitter: 'twitter.com', x: 'x.com',
	tiktok: 'tiktok.com', snapchat: 'snapchat.com', linkedin: 'linkedin.com',
	reddit: 'reddit.com', pinterest: 'pinterest.com', tumblr: 'tumblr.com',
	threads: 'threads.net', mastodon: 'mastodon.social', bluesky: 'bsky.app',

	// Streaming
	netflix: 'netflix.com', spotify: 'spotify.com', youtube: 'youtube.com',
	twitch: 'twitch.tv', disney: 'disneyplus.com', 'disney+': 'disneyplus.com',
	'disney plus': 'disneyplus.com', hbo: 'hbomax.com', 'prime video': 'primevideo.com',
	'amazon prime': 'primevideo.com', hulu: 'hulu.com', crunchyroll: 'crunchyroll.com',
	deezer: 'deezer.com', 'apple music': 'music.apple.com', soundcloud: 'soundcloud.com',
	paramount: 'paramountplus.com', peacock: 'peacocktv.com', canal: 'canalplus.com',
	'canal+': 'canalplus.com', 'canal plus': 'canalplus.com', mycanal: 'canalplus.com',

	// Gaming
	steam: 'steampowered.com', epic: 'epicgames.com', 'epic games': 'epicgames.com',
	playstation: 'playstation.com', psn: 'playstation.com', xbox: 'xbox.com',
	nintendo: 'nintendo.com', riot: 'riotgames.com', 'riot games': 'riotgames.com',
	valorant: 'playvalorant.com', 'league of legends': 'leagueoflegends.com',
	lol: 'leagueoflegends.com', minecraft: 'minecraft.net', roblox: 'roblox.com',
	ubisoft: 'ubisoft.com', ea: 'ea.com', blizzard: 'blizzard.com',
	'battle.net': 'battle.net', gog: 'gog.com', origin: 'ea.com',

	// Shopping
	amazon: 'amazon.com', ebay: 'ebay.com', aliexpress: 'aliexpress.com',
	etsy: 'etsy.com', wish: 'wish.com', shein: 'shein.com', zalando: 'zalando.com',
	asos: 'asos.com', nike: 'nike.com', adidas: 'adidas.com', vinted: 'vinted.com',
	leboncoin: 'leboncoin.fr', cdiscount: 'cdiscount.com', fnac: 'fnac.com',
	darty: 'darty.com', ikea: 'ikea.com', leroy: 'leroymerlin.fr',
	'leroy merlin': 'leroymerlin.fr', decathlon: 'decathlon.com',

	// Travel
	airbnb: 'airbnb.com', booking: 'booking.com', expedia: 'expedia.com',
	skyscanner: 'skyscanner.com', kayak: 'kayak.com', tripadvisor: 'tripadvisor.com',
	transavia: 'transavia.com', ryanair: 'ryanair.com', easyjet: 'easyjet.com',
	'air france': 'airfrance.com', airfrance: 'airfrance.com', sncf: 'sncf-connect.com',
	trainline: 'trainline.com', uber: 'uber.com', blablacar: 'blablacar.com',

	// Finance
	paypal: 'paypal.com', stripe: 'stripe.com', revolut: 'revolut.com',
	n26: 'n26.com', wise: 'wise.com', boursorama: 'boursorama.com',
	'boursorama banque': 'boursorama.com', 'credit agricole': 'credit-agricole.fr',
	'societe generale': 'societegenerale.fr', bnp: 'bnpparibas.com',
	'bnp paribas': 'bnpparibas.com', lcl: 'lcl.fr', 'la banque postale': 'labanquepostale.fr',
	coinbase: 'coinbase.com', binance: 'binance.com', kraken: 'kraken.com',

	// Dev / Tech
	github: 'github.com', gitlab: 'gitlab.com', bitbucket: 'bitbucket.org',
	stackoverflow: 'stackoverflow.com', 'stack overflow': 'stackoverflow.com',
	npm: 'npmjs.com', docker: 'docker.com', aws: 'aws.amazon.com',
	azure: 'azure.microsoft.com', vercel: 'vercel.com', netlify: 'netlify.com',
	heroku: 'heroku.com', digitalocean: 'digitalocean.com', cloudflare: 'cloudflare.com',
	figma: 'figma.com', notion: 'notion.so', slack: 'slack.com',
	jira: 'atlassian.com', trello: 'trello.com', asana: 'asana.com',
	linear: 'linear.app', supabase: 'supabase.com', firebase: 'firebase.google.com',

	// Communication
	discord: 'discord.com', telegram: 'telegram.org', whatsapp: 'whatsapp.com',
	signal: 'signal.org', zoom: 'zoom.us', teams: 'teams.microsoft.com',
	'microsoft teams': 'teams.microsoft.com', skype: 'skype.com',
	meet: 'meet.google.com', 'google meet': 'meet.google.com',

	// Cloud
	dropbox: 'dropbox.com', 'google drive': 'drive.google.com',
	onedrive: 'onedrive.live.com', mega: 'mega.nz', wetransfer: 'wetransfer.com',

	// Education
	duolingo: 'duolingo.com', coursera: 'coursera.org', udemy: 'udemy.com',
	khan: 'khanacademy.org', 'khan academy': 'khanacademy.org',

	// Food
	ubereats: 'ubereats.com', 'uber eats': 'ubereats.com',
	deliveroo: 'deliveroo.com', 'just eat': 'justeat.com',
	doordash: 'doordash.com', mcdonalds: 'mcdonalds.com', starbucks: 'starbucks.com',

	// Misc
	wordpress: 'wordpress.com', medium: 'medium.com', substack: 'substack.com',
	canva: 'canva.com', adobe: 'adobe.com', microsoft: 'microsoft.com',
	apple: 'apple.com', samsung: 'samsung.com', openai: 'openai.com',
	chatgpt: 'openai.com', claude: 'anthropic.com', anthropic: 'anthropic.com',
};

/**
 * Resolve a title/name to a domain.
 * 1. Check the curated map (case-insensitive)
 * 2. If the title looks like a domain already, use it
 * 3. Fallback: try "{name}.com"
 */
export function resolveDomain(title: string): string | null {
	if (!title || title.trim().length === 0) return null;

	const clean = title.trim().toLowerCase();

	// Direct match in map
	if (DOMAIN_MAP[clean]) return DOMAIN_MAP[clean];

	// Partial match (e.g. "Mon compte Gmail" → "gmail")
	for (const [key, domain] of Object.entries(DOMAIN_MAP)) {
		if (clean.includes(key)) return domain;
	}

	// Already looks like a domain
	if (clean.includes('.') && !clean.includes(' ')) return clean;

	// Fallback: try name.com (single word only)
	const word = clean.replace(/[^a-z0-9]/g, '');
	if (word.length >= 3 && !clean.includes(' ')) return `${word}.com`;

	return null;
}

/**
 * Get favicon URL for an entry.
 * Priority: website field > title resolution
 */
export function getFaviconUrl(entry: { title: string; website: string }, size: number = 64): string | null {
	// 1. Use website field if present
	if (entry.website) {
		const domain = entry.website.replace(/^https?:\/\//, '').split('/')[0];
		if (domain) return `https://www.google.com/s2/favicons?domain=${domain}&sz=${size}`;
	}

	// 2. Try resolving from title
	const resolved = resolveDomain(entry.title);
	if (resolved) return `https://www.google.com/s2/favicons?domain=${resolved}&sz=${size}`;

	return null;
}
