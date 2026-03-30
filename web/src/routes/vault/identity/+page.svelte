<script lang="ts">
	import { onMount } from 'svelte';

	// ── Types ──────────────────────────────────────────────────────────────────
	interface Identity {
		firstName: string;
		lastName: string;
		gender: 'M' | 'F';
		dob: string;
		age: number;
		email: string;
		phone: string;
		address: string;
		city: string;
		postalCode: string;
		country: string;
	}

	interface VirtualCard {
		type: 'Visa' | 'Mastercard';
		number: string;
		numberFormatted: string;
		expiry: string;
		cvv: string;
		holder: string;
	}

	// ── Data pools ─────────────────────────────────────────────────────────────
	const firstNamesMale = [
		'Lucas', 'Hugo', 'Nathan', 'Théo', 'Mathis', 'Tom', 'Baptiste', 'Maxime',
		'Antoine', 'Romain', 'Nicolas', 'Julien', 'Pierre', 'Alexandre', 'Thomas',
		'Gabriel', 'Louis', 'Arthur', 'Léo', 'Quentin', 'Alexis', 'Clément',
		'Florian', 'Kévin', 'Adrien', 'Yann', 'Ethan', 'Axel', 'Raphaël', 'Luca'
	];

	const firstNamesFemale = [
		'Emma', 'Léa', 'Chloé', 'Sarah', 'Manon', 'Lucie', 'Camille', 'Inès',
		'Jade', 'Julie', 'Pauline', 'Marie', 'Laura', 'Clara', 'Alice', 'Anaïs',
		'Océane', 'Mathilde', 'Zoé', 'Clémence', 'Elisa', 'Noémie', 'Charlotte',
		'Margot', 'Eva', 'Lola', 'Nina', 'Mia', 'Ambre', 'Justine'
	];

	const lastNames = [
		'Martin', 'Bernard', 'Thomas', 'Petit', 'Robert', 'Richard', 'Durand',
		'Dupont', 'Lambert', 'Fontaine', 'Rousseau', 'Vincent', 'Muller', 'Lefebvre',
		'Faure', 'Andre', 'Mercier', 'Blanc', 'Guerin', 'Boyer', 'Garnier', 'Chevalier',
		'Francois', 'Legrand', 'Gauthier', 'Garcia', 'Perrin', 'Robin', 'Clement', 'Morin'
	];

	const streets = [
		'Rue de la Paix', 'Avenue des Fleurs', 'Boulevard Haussmann', 'Rue du Commerce',
		'Avenue de la République', 'Rue Lafayette', 'Boulevard Voltaire', 'Rue de Rivoli',
		'Avenue Victor Hugo', 'Rue du Faubourg Saint-Antoine', 'Boulevard de la Liberté',
		'Rue Jean Jaurès', 'Avenue de la Gare', 'Rue des Lilas', 'Allée des Acacias',
		'Chemin du Moulin', 'Impasse des Roses', 'Voie Romaine', 'Rue du Général de Gaulle',
		'Passage des Artisans'
	];

	const cities = [
		{ name: 'Paris', cp: '75001' }, { name: 'Lyon', cp: '69001' },
		{ name: 'Marseille', cp: '13001' }, { name: 'Toulouse', cp: '31000' },
		{ name: 'Nice', cp: '06000' }, { name: 'Nantes', cp: '44000' },
		{ name: 'Strasbourg', cp: '67000' }, { name: 'Montpellier', cp: '34000' },
		{ name: 'Bordeaux', cp: '33000' }, { name: 'Lille', cp: '59000' },
		{ name: 'Rennes', cp: '35000' }, { name: 'Reims', cp: '51100' },
		{ name: 'Grenoble', cp: '38000' }, { name: 'Dijon', cp: '21000' },
		{ name: 'Angers', cp: '49000' }, { name: 'Brest', cp: '29200' },
		{ name: 'Nîmes', cp: '30000' }, { name: 'Rouen', cp: '76000' },
		{ name: 'Caen', cp: '14000' }, { name: 'Tours', cp: '37000' }
	];

	const emailDomains = [
		'gmail.com', 'yahoo.fr', 'hotmail.fr', 'outlook.fr', 'orange.fr',
		'free.fr', 'sfr.fr', 'laposte.net', 'wanadoo.fr', 'protonmail.com'
	];

	// ── Helpers ────────────────────────────────────────────────────────────────
	function rand<T>(arr: T[]): T {
		return arr[Math.floor(Math.random() * arr.length)];
	}

	function randInt(min: number, max: number): number {
		return Math.floor(Math.random() * (max - min + 1)) + min;
	}

	function luhnCheckDigit(digits: number[]): number {
		let sum = 0;
		for (let i = digits.length - 1; i >= 0; i--) {
			let d = digits[digits.length - 1 - i];
			if (i % 2 === 0) {
				d *= 2;
				if (d > 9) d -= 9;
			}
			sum += d;
		}
		return (10 - (sum % 10)) % 10;
	}

	function generateCardNumber(prefix: number[]): string {
		const digits = [...prefix];
		while (digits.length < 15) digits.push(randInt(0, 9));
		digits.push(luhnCheckDigit(digits));
		return digits.join('');
	}

	function formatCardNumber(n: string): string {
		return n.replace(/(.{4})/g, '$1 ').trim();
	}

	// ── Generators ─────────────────────────────────────────────────────────────
	function generateIdentity(): Identity {
		const gender: 'M' | 'F' = Math.random() > 0.5 ? 'M' : 'F';
		const firstName = gender === 'M' ? rand(firstNamesMale) : rand(firstNamesFemale);
		const lastName = rand(lastNames);
		const age = randInt(18, 65);
		const birthYear = new Date().getFullYear() - age;
		const birthMonth = String(randInt(1, 12)).padStart(2, '0');
		const birthDay = String(randInt(1, 28)).padStart(2, '0');
		const city = rand(cities);
		const streetNumber = randInt(1, 120);
		const street = rand(streets);

		const emailPrefix = `${firstName.toLowerCase().replace(/[^a-z]/g, '')}.${lastName.toLowerCase().replace(/[^a-z]/g, '')}${randInt(10, 99)}`;
		const phone = `0${randInt(6, 7)}${Array.from({ length: 8 }, () => randInt(0, 9)).join('')}`;

		return {
			firstName,
			lastName,
			gender,
			dob: `${birthDay}/${birthMonth}/${birthYear}`,
			age,
			email: `${emailPrefix}@${rand(emailDomains)}`,
			phone: phone.replace(/(\d{2})(?=\d)/g, '$1 ').trim(),
			address: `${streetNumber} ${street}`,
			city: city.name,
			postalCode: city.cp,
			country: 'France'
		};
	}

	function generateCard(identity: Identity): VirtualCard {
		const type: 'Visa' | 'Mastercard' = Math.random() > 0.5 ? 'Visa' : 'Mastercard';
		const prefix = type === 'Visa' ? [4] : [5, randInt(1, 5)];
		const number = generateCardNumber(prefix);
		const expMonth = String(randInt(1, 12)).padStart(2, '0');
		const expYear = String(new Date().getFullYear() + randInt(1, 5)).slice(-2);
		const cvv = String(randInt(100, 999));

		return {
			type,
			number,
			numberFormatted: formatCardNumber(number),
			expiry: `${expMonth}/${expYear}`,
			cvv,
			holder: `${identity.firstName.toUpperCase()} ${identity.lastName.toUpperCase()}`
		};
	}

	// ── State ──────────────────────────────────────────────────────────────────
	let identity = $state<Identity | null>(null);
	let card = $state<VirtualCard | null>(null);
	let copiedField = $state<string | null>(null);
	let showCvv = $state(false);
	let flipped = $state(false);

	function regenerate() {
		const id = generateIdentity();
		identity = id;
		card = generateCard(id);
		showCvv = false;
		flipped = false;
	}

	async function copy(value: string, field: string) {
		await navigator.clipboard.writeText(value);
		copiedField = field;
		setTimeout(() => { copiedField = null; }, 1500);
	}

	onMount(() => regenerate());
</script>

<div class="min-h-screen bg-[var(--fv-abyss)] p-4 md:p-6 lg:p-8">
	<!-- Header -->
	<div class="flex items-center justify-between mb-6">
		<div>
			<h1 class="text-xl font-extrabold text-white">Identité fictive</h1>
			<p class="text-xs text-[var(--fv-ash)] mt-0.5">Génère une identité et une carte pour protéger tes vraies données</p>
		</div>
		<button
			onclick={regenerate}
			class="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#10b981]/10 border border-[#10b981]/20 text-[#10b981] text-sm font-semibold hover:bg-[#10b981]/20 transition-all"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<path d="M1 4v6h6"/><path d="M23 20v-6h-6"/>
				<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4-4.64 4.36A9 9 0 0 1 3.51 15"/>
			</svg>
			Régénérer
		</button>
	</div>

	{#if identity && card}
	<div class="grid grid-cols-1 xl:grid-cols-2 gap-5">

		<!-- ── Identité ─────────────────────────────────────────────────────── -->
		<div class="fv-glass rounded-2xl p-5">
			<div class="flex items-center gap-3 mb-5">
				<div class="w-10 h-10 rounded-xl bg-[#10b981]/15 flex items-center justify-center">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2">
						<rect x="2" y="5" width="20" height="14" rx="2"/>
						<circle cx="8" cy="12" r="2"/>
						<path d="M14 9h4M14 12h4M14 15h2"/>
					</svg>
				</div>
				<div>
					<h2 class="text-sm font-bold text-white">Identité</h2>
					<p class="text-[10px] text-[var(--fv-ash)]">Données fictives — aucun vrai individu</p>
				</div>
			</div>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
				{#each [
					{ label: 'Prénom', value: identity.firstName, field: 'firstName' },
					{ label: 'Nom', value: identity.lastName, field: 'lastName' },
					{ label: 'Date de naissance', value: `${identity.dob} (${identity.age} ans)`, field: 'dob' },
					{ label: 'Email fictif', value: identity.email, field: 'email' },
					{ label: 'Téléphone', value: identity.phone, field: 'phone' },
					{ label: 'Adresse', value: identity.address, field: 'address' },
					{ label: 'Ville', value: identity.city, field: 'city' },
					{ label: 'Code postal', value: identity.postalCode, field: 'cp' },
					{ label: 'Pays', value: identity.country, field: 'country' }
				] as item}
					<button
						onclick={() => copy(item.value, item.field)}
						class="group flex flex-col gap-1 p-3 rounded-xl bg-white/[0.03] border border-white/[0.06] hover:bg-white/[0.07] hover:border-[#10b981]/30 transition-all text-left w-full"
					>
						<span class="text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wide">{item.label}</span>
						<div class="flex items-center justify-between gap-2">
							<span class="text-sm text-white font-medium truncate">{item.value}</span>
							{#if copiedField === item.field}
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.5" class="shrink-0"><polyline points="20 6 9 17 4 12"/></svg>
							{:else}
								<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="shrink-0 text-[var(--fv-ash)] opacity-0 group-hover:opacity-100 transition-opacity">
									<rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>
								</svg>
							{/if}
						</div>
					</button>
				{/each}
			</div>
		</div>

		<!-- ── Carte virtuelle ───────────────────────────────────────────────── -->
		<div class="fv-glass rounded-2xl p-5">
			<div class="flex items-center gap-3 mb-5">
				<div class="w-10 h-10 rounded-xl bg-[var(--fv-violet)]/15 flex items-center justify-center">
					<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet)" stroke-width="2">
						<rect x="1" y="4" width="22" height="16" rx="2"/>
						<line x1="1" y1="10" x2="23" y2="10"/>
					</svg>
				</div>
				<div>
					<h2 class="text-sm font-bold text-white">Carte virtuelle</h2>
					<p class="text-[10px] text-[var(--fv-ash)]">Valide algorithmiquement — vérification de format uniquement</p>
				</div>
			</div>

			<!-- Card visual -->
			<div class="relative h-48 mb-5 cursor-pointer" onclick={() => flipped = !flipped} style="perspective: 1000px;">
				<div class="absolute inset-0 transition-transform duration-500" style="transform-style: preserve-3d; transform: {flipped ? 'rotateY(180deg)' : 'rotateY(0deg)'};">

					<!-- Front -->
					<div class="absolute inset-0 rounded-2xl overflow-hidden" style="backface-visibility: hidden;">
						<div class="w-full h-full p-5 flex flex-col justify-between relative"
							style="background: {card.type === 'Visa' ? 'linear-gradient(135deg, #1a1a3e 0%, #2d1b69 50%, #1e3a8a 100%)' : 'linear-gradient(135deg, #1a1a2e 0%, #6b21a8 50%, #7c3aed 100%)'};">
							<!-- Decorative circles -->
							<div class="absolute top-0 right-0 w-40 h-40 rounded-full opacity-10" style="background: radial-gradient(circle, white, transparent); transform: translate(30%, -30%);"></div>
							<div class="absolute bottom-0 left-0 w-32 h-32 rounded-full opacity-10" style="background: radial-gradient(circle, white, transparent); transform: translate(-30%, 30%);"></div>

							<div class="flex items-start justify-between relative z-10">
								<!-- Chip -->
								<div class="w-10 h-7 rounded-md bg-gradient-to-br from-yellow-300 to-yellow-500 flex items-center justify-center">
									<div class="grid grid-cols-2 gap-px w-6 h-5">
										{#each Array(4) as _}
											<div class="rounded-[1px] bg-yellow-600/40"></div>
										{/each}
									</div>
								</div>
								<!-- Brand -->
								<span class="text-white font-black text-lg tracking-wider" style="text-shadow: 0 1px 4px rgba(0,0,0,0.5);">{card.type}</span>
							</div>

							<div class="relative z-10">
								<p class="text-white font-mono text-lg tracking-widest mb-3" style="text-shadow: 0 1px 6px rgba(0,0,0,0.4);">{card.numberFormatted}</p>
								<div class="flex items-end justify-between">
									<div>
										<p class="text-white/50 text-[9px] uppercase tracking-widest mb-0.5">Titulaire</p>
										<p class="text-white font-semibold text-sm tracking-wider">{card.holder}</p>
									</div>
									<div class="text-right">
										<p class="text-white/50 text-[9px] uppercase tracking-widest mb-0.5">Expire</p>
										<p class="text-white font-semibold text-sm">{card.expiry}</p>
									</div>
								</div>
							</div>
						</div>
					</div>

					<!-- Back -->
					<div class="absolute inset-0 rounded-2xl overflow-hidden" style="backface-visibility: hidden; transform: rotateY(180deg);">
						<div class="w-full h-full flex flex-col justify-center"
							style="background: {card.type === 'Visa' ? 'linear-gradient(135deg, #1a1a3e 0%, #2d1b69 50%, #1e3a8a 100%)' : 'linear-gradient(135deg, #1a1a2e 0%, #6b21a8 50%, #7c3aed 100%)'};">
							<div class="w-full h-10 bg-black/60 mb-4"></div>
							<div class="px-5 flex items-center justify-end gap-3">
								<div class="flex-1 h-8 rounded bg-white/10"></div>
								<div class="bg-white rounded px-3 py-1.5">
									<p class="text-gray-800 font-mono font-bold text-sm tracking-widest">{card.cvv}</p>
								</div>
							</div>
							<p class="text-center text-white/30 text-[9px] mt-4 px-5">CVV — Retournez la carte pour voir</p>
						</div>
					</div>
				</div>
			</div>
			<p class="text-center text-[10px] text-[var(--fv-ash)] mb-5">Cliquez sur la carte pour voir le CVV</p>

			<!-- Card fields copy -->
			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
				{#each [
					{ label: 'Numéro de carte', value: card.number, display: card.numberFormatted, field: 'cardNum' },
					{ label: 'Date d\'expiration', value: card.expiry, display: card.expiry, field: 'cardExp' },
					{ label: 'CVV', value: card.cvv, display: showCvv ? card.cvv : '•••', field: 'cardCvv' },
					{ label: 'Titulaire', value: card.holder, display: card.holder, field: 'cardHolder' }
				] as item}
					<div class="flex items-center gap-2 p-3 rounded-xl bg-white/[0.03] border border-white/[0.06]">
						<div class="flex-1 min-w-0">
							<p class="text-[10px] font-semibold text-[var(--fv-ash)] uppercase tracking-wide">{item.label}</p>
							<p class="text-sm text-white font-mono mt-0.5 truncate">
								{#if item.field === 'cardCvv'}
									{showCvv ? item.value : '•••'}
								{:else}
									{item.display}
								{/if}
							</p>
						</div>
						{#if item.field === 'cardCvv'}
							<button onclick={() => showCvv = !showCvv} class="p-1.5 rounded-lg hover:bg-white/10 text-[var(--fv-ash)] transition-colors">
								{#if showCvv}
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
								{:else}
									<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>
								{/if}
							</button>
						{/if}
						<button onclick={() => copy(item.value, item.field)} class="p-1.5 rounded-lg hover:bg-white/10 transition-colors">
							{#if copiedField === item.field}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2.5"><polyline points="20 6 9 17 4 12"/></svg>
							{:else}
								<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="text-[var(--fv-ash)]"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
							{/if}
						</button>
					</div>
				{/each}
			</div>

			<!-- Warning -->
			<div class="mt-4 p-3 rounded-xl bg-amber-500/8 border border-amber-500/20 flex items-start gap-2.5">
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2" class="shrink-0 mt-0.5">
					<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
					<line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>
				</svg>
				<p class="text-[10px] text-amber-400/80 leading-relaxed">
					Numéro valide selon l'algorithme de Luhn (vérification de format). <strong>Aucun paiement réel possible.</strong> Usage : formulaires qui vérifient uniquement le format.
				</p>
			</div>
		</div>
	</div>
	{/if}
</div>
