<section id="pricing" class="relative py-32 px-6">
	<div class="max-w-4xl mx-auto">
		<div class="text-center mb-16">
			<span class="inline-block px-4 py-1.5 rounded-full bg-[var(--fv-gold)]/10 text-[var(--fv-gold)] text-xs font-bold uppercase tracking-wider mb-4">Tarifs</span>
			<h2 class="text-4xl sm:text-5xl font-extrabold text-white mb-4">Simple et transparent.</h2>
			<p class="text-lg text-[var(--fv-mist)]">14 jours d'essai gratuit. Sans carte bancaire.</p>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-3xl mx-auto">
			<!-- Free Plan -->
			<div class="fv-glass p-8">
				<div class="mb-6">
					<h3 class="text-xl font-bold text-white mb-1">Gratuit</h3>
					<p class="text-sm text-[var(--fv-smoke)]">Pour commencer en sécurité</p>
				</div>
				<div class="mb-8">
					<span class="text-4xl font-extrabold text-white">0€</span>
					<span class="text-[var(--fv-smoke)]">/mois</span>
				</div>
				<ul class="space-y-3 mb-8">
					{#each freeFeatures as f}
						<li class="flex items-center gap-3 text-sm text-[var(--fv-mist)]">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
							{f}
						</li>
					{/each}
				</ul>
				<a href="/register" class="fv-btn fv-btn-ghost w-full">Créer un compte</a>
			</div>

			<!-- Pro Plan -->
			<div class="fv-glass p-8 border-[var(--fv-gold)]/30 relative overflow-hidden fv-glow-gold">
				<!-- Popular badge -->
				<div class="absolute top-0 right-0">
					<div class="bg-gradient-to-r from-[var(--fv-gold)] to-[var(--fv-gold-light)] text-[#1a1a2e] text-[10px] font-extrabold uppercase tracking-wider px-4 py-1.5 rounded-bl-xl">
						Populaire
					</div>
				</div>

				<div class="mb-6">
					<h3 class="text-xl font-bold text-white mb-1 flex items-center gap-2">
						Pro
						<span class="px-2 py-0.5 rounded-full bg-[var(--fv-gold)]/15 text-[var(--fv-gold)] text-[10px] font-bold">👑</span>
					</h3>
					<p class="text-sm text-[var(--fv-smoke)]">Sécurité maximale</p>
				</div>
				<div class="mb-2">
					<span class="text-4xl font-extrabold text-white">4,99€</span>
					<span class="text-[var(--fv-smoke)]">/mois</span>
				</div>
				<p class="text-xs text-[var(--fv-smoke)] mb-8">ou 41,99€/an <span class="text-[var(--fv-gold)] font-bold">(économise 30%)</span></p>
				<ul class="space-y-3 mb-8">
					{#each proFeatures as f}
						<li class="flex items-center gap-3 text-sm text-[var(--fv-mist)]">
							<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="3"><polyline points="20 6 9 17 4 12"/></svg>
							{f}
						</li>
					{/each}
				</ul>
				<a href="/register" class="fv-btn fv-btn-gold w-full">Essai gratuit 14 jours</a>
			</div>
		</div>
	</div>
</section>

<script lang="ts">
	const freeFeatures = [
		'5 comptes maximum',
		'Chiffrement AES-256',
		'Synchronisation cloud',
		'Codes TOTP intégrés',
		'Générateur de mots de passe',
		'AutoFill iOS natif'
	];

	const proFeatures = [
		'Comptes illimités',
		'Tout du plan gratuit',
		'Surveillance Dark Web',
		'Emails masqués illimités',
		'Partage sécurisé',
		'Support prioritaire',
		'Catégories avancées'
	];
</script>
