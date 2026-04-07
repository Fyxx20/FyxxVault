<section id="features" class="relative py-32 px-6">
	<div class="max-w-6xl mx-auto">
		<div class="text-center mb-20">
			<span class="inline-block px-4 py-1.5 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs font-bold uppercase tracking-wider mb-4">Fonctionnalités</span>
			<h2 class="text-4xl sm:text-5xl font-extrabold text-white mb-4">Tout ce qu'il te faut.</h2>
			<p class="text-lg text-[var(--fv-mist)] max-w-xl mx-auto">Plus qu'un gestionnaire de mots de passe — un hub de sécurité complet.</p>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
			{#each features as f}
				<div class="fv-glass p-7 hover:border-white/15 transition-all duration-300 group hover:-translate-y-1">
					<div class="w-12 h-12 rounded-2xl flex items-center justify-center mb-5" style="background: {f.color}15;">
						<span class="text-2xl">{f.emoji}</span>
					</div>
					<h3 class="text-lg font-bold text-white mb-2 group-hover:text-[var(--fv-cyan)] transition-colors">{f.title}</h3>
					<p class="text-sm text-[var(--fv-smoke)] leading-relaxed">{f.description}</p>
					{#if f.badge}
						<span class="inline-block mt-4 px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider" style="background: {f.color}15; color: {f.color};">{f.badge}</span>
					{/if}
				</div>
			{/each}
		</div>
	</div>
</section>

<script lang="ts">
	const features = [
		{
			emoji: '🔐', title: 'Coffre chiffré AES-256',
			description: 'Tes mots de passe sont chiffrés localement avant tout transfert. Même nous, on ne peut pas les lire.',
			color: 'var(--fv-cyan)', badge: 'Zero-Knowledge'
		},
		{
			emoji: '🔑', title: 'Authentification 2FA/TOTP',
			description: 'Codes TOTP intégrés pour chaque compte. Plus besoin d\'une app séparée.',
			color: 'var(--fv-violet)', badge: null
		},
		{
			emoji: '☁️', title: 'Sync multi-appareils',
			description: 'Accède à ton coffre sur iPhone, iPad et navigateur. Sync chiffrée de bout en bout.',
			color: 'var(--fv-success)', badge: 'E2E Encrypted'
		},
		{
			emoji: '🌐', title: 'Surveillance Dark Web',
			description: 'Scan automatique HIBP. Tu es alerté si un de tes mots de passe apparaît dans une fuite.',
			color: 'var(--fv-danger)', badge: 'Pro'
		},
		{
			emoji: '📧', title: 'Emails masqués',
			description: 'Crée des alias email uniques pour chaque service. Protège ta vraie adresse.',
			color: 'var(--fv-rose)', badge: 'Pro'
		},
		{
			emoji: '🔗', title: 'Partage sécurisé',
			description: 'Partage un mot de passe via un lien chiffré éphémère avec expiration automatique.',
			color: 'var(--fv-gold)', badge: 'Pro'
		},
		{
			emoji: '📱', title: 'AutoFill natif',
			description: 'Remplissage automatique dans Safari et toutes tes apps iOS. Un tap et c\'est fait.',
			color: 'var(--fv-cyan)', badge: null
		},
		{
			emoji: '🚨', title: 'Mode Panique',
			description: 'Un mot de passe d\'urgence efface tout instantanément. Protection ultime en cas de menace.',
			color: 'var(--fv-danger)', badge: null
		},
		{
			emoji: '📊', title: 'Dashboard sécurité',
			description: 'Score de sécurité en temps réel, mots de passe faibles, réutilisés ou expirés en un coup d\'œil.',
			color: 'var(--fv-violet)', badge: null
		}
	];
</script>
