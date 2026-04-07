<script lang="ts">
	import { t } from '$lib/i18n.svelte';
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

	interface CountryData {
		flag: string;
		label: string;
		maleNames: string[];
		femaleNames: string[];
		lastNames: string[];
		streets: string[];
		cities: { name: string; cp: string }[];
		emailDomains: string[];
		phoneGen: () => string;
	}

	// ── Country data pools ─────────────────────────────────────────────────────
	const countries: Record<string, CountryData> = {
		FR: {
			flag: '🇫🇷', label: 'France',
			maleNames: ['Lucas', 'Hugo', 'Nathan', 'Théo', 'Mathis', 'Tom', 'Baptiste', 'Maxime', 'Antoine', 'Romain', 'Nicolas', 'Julien', 'Pierre', 'Alexandre', 'Thomas', 'Gabriel', 'Louis', 'Arthur', 'Léo', 'Quentin'],
			femaleNames: ['Emma', 'Léa', 'Chloé', 'Sarah', 'Manon', 'Lucie', 'Camille', 'Inès', 'Jade', 'Julie', 'Pauline', 'Marie', 'Laura', 'Clara', 'Alice', 'Anaïs', 'Océane', 'Mathilde', 'Zoé', 'Charlotte'],
			lastNames: ['Martin', 'Bernard', 'Thomas', 'Petit', 'Robert', 'Richard', 'Durand', 'Dupont', 'Lambert', 'Fontaine', 'Rousseau', 'Vincent', 'Muller', 'Lefebvre', 'Faure', 'Mercier', 'Blanc', 'Guerin', 'Boyer', 'Garnier'],
			streets: ['Rue de la Paix', 'Avenue des Fleurs', 'Boulevard Haussmann', 'Rue du Commerce', 'Avenue de la République', 'Rue Lafayette', 'Boulevard Voltaire', 'Rue de Rivoli', 'Avenue Victor Hugo', 'Boulevard de la Liberté', 'Rue Jean Jaurès', 'Rue des Lilas', 'Allée des Acacias', 'Chemin du Moulin', 'Rue du Général de Gaulle'],
			cities: [
				{ name: 'Paris', cp: '75001' }, { name: 'Lyon', cp: '69001' }, { name: 'Marseille', cp: '13001' },
				{ name: 'Toulouse', cp: '31000' }, { name: 'Nice', cp: '06000' }, { name: 'Nantes', cp: '44000' },
				{ name: 'Strasbourg', cp: '67000' }, { name: 'Montpellier', cp: '34000' }, { name: 'Bordeaux', cp: '33000' },
				{ name: 'Lille', cp: '59000' }, { name: 'Rennes', cp: '35000' }, { name: 'Grenoble', cp: '38000' }
			],
			emailDomains: ['gmail.com', 'yahoo.fr', 'hotmail.fr', 'outlook.fr', 'orange.fr', 'free.fr', 'laposte.net', 'protonmail.com'],
			phoneGen: () => `0${randInt(6, 7)}${Array.from({ length: 8 }, () => randInt(0, 9)).join('')}`.replace(/(\d{2})(?=\d)/g, '$1 ').trim()
		},
		US: {
			flag: '🇺🇸', label: 'United States',
			maleNames: ['James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Christopher', 'Daniel', 'Matthew', 'Anthony', 'Andrew', 'Joshua', 'Ethan', 'Alexander', 'Ryan', 'Nathan', 'Tyler'],
			femaleNames: ['Mary', 'Patricia', 'Jennifer', 'Linda', 'Elizabeth', 'Barbara', 'Susan', 'Jessica', 'Sarah', 'Karen', 'Emily', 'Olivia', 'Emma', 'Ava', 'Sophia', 'Isabella', 'Mia', 'Charlotte', 'Amelia', 'Harper'],
			lastNames: ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Wilson', 'Anderson', 'Thomas', 'Taylor', 'Moore', 'Jackson', 'Martin', 'Lee'],
			streets: ['Main St', 'Oak Ave', 'Maple Dr', 'Cedar Ln', 'Elm St', 'Pine Rd', 'Washington Blvd', 'Park Ave', 'Lake Dr', 'Sunset Blvd', 'Highland Ave', 'River Rd', 'Forest Ln', 'Meadow Dr', 'Spring St'],
			cities: [
				{ name: 'New York', cp: '10001' }, { name: 'Los Angeles', cp: '90001' }, { name: 'Chicago', cp: '60601' },
				{ name: 'Houston', cp: '77001' }, { name: 'Phoenix', cp: '85001' }, { name: 'Philadelphia', cp: '19101' },
				{ name: 'San Antonio', cp: '78201' }, { name: 'San Diego', cp: '92101' }, { name: 'Dallas', cp: '75201' },
				{ name: 'Austin', cp: '78701' }, { name: 'Seattle', cp: '98101' }, { name: 'Denver', cp: '80201' }
			],
			emailDomains: ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'aol.com', 'icloud.com', 'protonmail.com', 'mail.com'],
			phoneGen: () => { const area = randInt(200, 999); const p1 = randInt(200, 999); const p2 = randInt(1000, 9999); return `(${area}) ${p1}-${p2}`; }
		},
		GB: {
			flag: '🇬🇧', label: 'United Kingdom',
			maleNames: ['Oliver', 'George', 'Harry', 'Jack', 'Noah', 'Charlie', 'Leo', 'Jacob', 'Freddie', 'Alfie', 'Oscar', 'Thomas', 'James', 'William', 'Henry', 'Arthur', 'Archie', 'Edward', 'Samuel', 'Joseph'],
			femaleNames: ['Olivia', 'Amelia', 'Isla', 'Ava', 'Emily', 'Sophia', 'Grace', 'Mia', 'Poppy', 'Ella', 'Lily', 'Evie', 'Hannah', 'Ruby', 'Freya', 'Phoebe', 'Daisy', 'Sophie', 'Isabella', 'Florence'],
			lastNames: ['Smith', 'Jones', 'Williams', 'Taylor', 'Brown', 'Davies', 'Evans', 'Wilson', 'Thomas', 'Roberts', 'Johnson', 'Lewis', 'Walker', 'Robinson', 'Wood', 'Thompson', 'White', 'Watson', 'Jackson', 'Wright'],
			streets: ['High Street', 'Station Road', 'Church Lane', 'Park Avenue', 'Victoria Road', 'Queen Street', 'King Street', 'Mill Lane', 'The Green', 'Manor Road', 'Chapel Lane', 'Bridge Street', 'Market Square', 'School Lane', 'New Road'],
			cities: [
				{ name: 'London', cp: 'EC1A 1BB' }, { name: 'Manchester', cp: 'M1 1AE' }, { name: 'Birmingham', cp: 'B1 1AA' },
				{ name: 'Leeds', cp: 'LS1 1BA' }, { name: 'Liverpool', cp: 'L1 0AA' }, { name: 'Bristol', cp: 'BS1 1AA' },
				{ name: 'Edinburgh', cp: 'EH1 1AA' }, { name: 'Glasgow', cp: 'G1 1AA' }, { name: 'Cardiff', cp: 'CF10 1AA' },
				{ name: 'Cambridge', cp: 'CB1 1AA' }, { name: 'Oxford', cp: 'OX1 1AA' }, { name: 'Brighton', cp: 'BN1 1AA' }
			],
			emailDomains: ['gmail.com', 'yahoo.co.uk', 'hotmail.co.uk', 'outlook.com', 'btinternet.com', 'sky.com', 'protonmail.com', 'icloud.com'],
			phoneGen: () => `07${randInt(400, 999)} ${randInt(100, 999)} ${randInt(100, 999)}`
		},
		DE: {
			flag: '🇩🇪', label: 'Deutschland',
			maleNames: ['Lukas', 'Leon', 'Maximilian', 'Paul', 'Felix', 'Jonas', 'Tim', 'Niklas', 'Jan', 'Finn', 'Noah', 'Elias', 'Moritz', 'Alexander', 'Julian', 'Tobias', 'Sebastian', 'David', 'Philipp', 'Fabian'],
			femaleNames: ['Emma', 'Mia', 'Hannah', 'Sofia', 'Anna', 'Lena', 'Emilia', 'Marie', 'Lea', 'Clara', 'Lina', 'Ella', 'Amelie', 'Johanna', 'Luisa', 'Laura', 'Katharina', 'Sarah', 'Julia', 'Lisa'],
			lastNames: ['Müller', 'Schmidt', 'Schneider', 'Fischer', 'Weber', 'Meyer', 'Wagner', 'Becker', 'Schulz', 'Hoffmann', 'Koch', 'Richter', 'Wolf', 'Schröder', 'Neumann', 'Schwarz', 'Braun', 'Zimmermann', 'Krüger', 'Hartmann'],
			streets: ['Hauptstraße', 'Bahnhofstraße', 'Kirchstraße', 'Gartenstraße', 'Schulstraße', 'Berliner Straße', 'Dorfstraße', 'Waldstraße', 'Bergstraße', 'Lindenstraße', 'Friedrichstraße', 'Rosenweg', 'Parkstraße', 'Marktplatz', 'Am Rathaus'],
			cities: [
				{ name: 'Berlin', cp: '10115' }, { name: 'München', cp: '80331' }, { name: 'Hamburg', cp: '20095' },
				{ name: 'Köln', cp: '50667' }, { name: 'Frankfurt', cp: '60311' }, { name: 'Stuttgart', cp: '70173' },
				{ name: 'Düsseldorf', cp: '40213' }, { name: 'Leipzig', cp: '04109' }, { name: 'Dresden', cp: '01067' },
				{ name: 'Hannover', cp: '30159' }, { name: 'Nürnberg', cp: '90402' }, { name: 'Bremen', cp: '28195' }
			],
			emailDomains: ['gmail.com', 'web.de', 'gmx.de', 'yahoo.de', 'outlook.de', 't-online.de', 'posteo.de', 'protonmail.com'],
			phoneGen: () => `0${randInt(151, 179)} ${randInt(1000000, 9999999)}`
		},
		ES: {
			flag: '🇪🇸', label: 'España',
			maleNames: ['Hugo', 'Martín', 'Lucas', 'Daniel', 'Pablo', 'Alejandro', 'Álvaro', 'Adrián', 'David', 'Diego', 'Mario', 'Carlos', 'Sergio', 'Marcos', 'Jorge', 'Iker', 'Javier', 'Ángel', 'Miguel', 'Antonio'],
			femaleNames: ['Lucía', 'Sofía', 'Martina', 'María', 'Paula', 'Daniela', 'Valeria', 'Alba', 'Emma', 'Julia', 'Carla', 'Sara', 'Noa', 'Carmen', 'Irene', 'Claudia', 'Elena', 'Laura', 'Marta', 'Ana'],
			lastNames: ['García', 'Rodríguez', 'Martínez', 'López', 'González', 'Hernández', 'Pérez', 'Sánchez', 'Ramírez', 'Torres', 'Flores', 'Rivera', 'Gómez', 'Díaz', 'Reyes', 'Moreno', 'Jiménez', 'Ruiz', 'Álvarez', 'Romero'],
			streets: ['Calle Mayor', 'Avenida de la Constitución', 'Calle Real', 'Paseo de la Castellana', 'Calle del Sol', 'Avenida de la Libertad', 'Calle Nueva', 'Calle San Juan', 'Paseo del Prado', 'Calle de la Iglesia', 'Rambla de Catalunya', 'Calle Gran Vía', 'Calle de Alcalá', 'Avenida de Andalucía', 'Calle del Carmen'],
			cities: [
				{ name: 'Madrid', cp: '28001' }, { name: 'Barcelona', cp: '08001' }, { name: 'Valencia', cp: '46001' },
				{ name: 'Sevilla', cp: '41001' }, { name: 'Zaragoza', cp: '50001' }, { name: 'Málaga', cp: '29001' },
				{ name: 'Bilbao', cp: '48001' }, { name: 'Granada', cp: '18001' }, { name: 'Alicante', cp: '03001' },
				{ name: 'Salamanca', cp: '37001' }, { name: 'Toledo', cp: '45001' }, { name: 'Córdoba', cp: '14001' }
			],
			emailDomains: ['gmail.com', 'yahoo.es', 'hotmail.es', 'outlook.es', 'telefonica.net', 'protonmail.com'],
			phoneGen: () => `6${randInt(10, 99)} ${randInt(100, 999)} ${randInt(100, 999)}`
		},
		IT: {
			flag: '🇮🇹', label: 'Italia',
			maleNames: ['Leonardo', 'Francesco', 'Alessandro', 'Lorenzo', 'Mattia', 'Andrea', 'Gabriele', 'Riccardo', 'Tommaso', 'Edoardo', 'Federico', 'Marco', 'Luca', 'Giuseppe', 'Giovanni', 'Antonio', 'Davide', 'Simone', 'Nicola', 'Stefano'],
			femaleNames: ['Sofia', 'Giulia', 'Aurora', 'Alice', 'Ginevra', 'Emma', 'Giorgia', 'Greta', 'Beatrice', 'Anna', 'Chiara', 'Sara', 'Martina', 'Francesca', 'Valentina', 'Elisa', 'Alessia', 'Camilla', 'Elena', 'Federica'],
			lastNames: ['Rossi', 'Russo', 'Ferrari', 'Esposito', 'Bianchi', 'Romano', 'Colombo', 'Ricci', 'Marino', 'Greco', 'Bruno', 'Gallo', 'Conti', 'De Luca', 'Mancini', 'Costa', 'Giordano', 'Rizzo', 'Lombardi', 'Moretti'],
			streets: ['Via Roma', 'Via Garibaldi', 'Via Dante', 'Via Mazzini', 'Corso Italia', 'Via Nazionale', 'Via Verdi', 'Via Leonardo da Vinci', 'Via San Marco', 'Piazza del Duomo', 'Via Cavour', 'Via della Repubblica', 'Via Marconi', 'Viale Europa', 'Via Leopardi'],
			cities: [
				{ name: 'Roma', cp: '00100' }, { name: 'Milano', cp: '20100' }, { name: 'Napoli', cp: '80100' },
				{ name: 'Torino', cp: '10100' }, { name: 'Firenze', cp: '50100' }, { name: 'Bologna', cp: '40100' },
				{ name: 'Venezia', cp: '30100' }, { name: 'Genova', cp: '16100' }, { name: 'Palermo', cp: '90100' },
				{ name: 'Verona', cp: '37100' }, { name: 'Pisa', cp: '56100' }, { name: 'Siena', cp: '53100' }
			],
			emailDomains: ['gmail.com', 'yahoo.it', 'hotmail.it', 'outlook.it', 'libero.it', 'virgilio.it', 'tiscali.it', 'protonmail.com'],
			phoneGen: () => `3${randInt(20, 99)} ${randInt(100, 999)} ${randInt(1000, 9999)}`
		},
		BE: {
			flag: '🇧🇪', label: 'Belgique',
			maleNames: ['Noah', 'Lucas', 'Louis', 'Liam', 'Adam', 'Victor', 'Arthur', 'Jules', 'Mohamed', 'Nathan', 'Hugo', 'Mathis', 'Théo', 'Raphaël', 'Gabriel', 'Léo', 'Maxime', 'Thomas', 'Antoine', 'Ethan'],
			femaleNames: ['Emma', 'Louise', 'Olivia', 'Alice', 'Léa', 'Juliette', 'Clara', 'Mia', 'Lina', 'Chloé', 'Charlotte', 'Elena', 'Camille', 'Jade', 'Zoé', 'Lucie', 'Manon', 'Sarah', 'Marie', 'Nora'],
			lastNames: ['Peeters', 'Janssen', 'Maes', 'Jacobs', 'Willems', 'Claes', 'Goossens', 'Wouters', 'De Smedt', 'Dubois', 'Lambert', 'Dupont', 'Martin', 'Leclercq', 'Simon', 'Laurent', 'Leroy', 'Renard', 'Mertens', 'Hermans'],
			streets: ['Rue de la Station', 'Grand Place', 'Avenue Louise', 'Rue du Marché', 'Chaussée de Waterloo', 'Rue Royale', 'Avenue de Tervuren', 'Rue de Namur', 'Boulevard Anspach', 'Rue Haute', 'Kerkstraat', 'Steenweg', 'Marktplein', 'Stationsstraat', 'Dorpsstraat'],
			cities: [
				{ name: 'Bruxelles', cp: '1000' }, { name: 'Anvers', cp: '2000' }, { name: 'Gand', cp: '9000' },
				{ name: 'Liège', cp: '4000' }, { name: 'Bruges', cp: '8000' }, { name: 'Namur', cp: '5000' },
				{ name: 'Charleroi', cp: '6000' }, { name: 'Mons', cp: '7000' }, { name: 'Louvain', cp: '3000' },
				{ name: 'Tournai', cp: '7500' }, { name: 'Arlon', cp: '6700' }, { name: 'Hasselt', cp: '3500' }
			],
			emailDomains: ['gmail.com', 'yahoo.be', 'hotmail.be', 'outlook.be', 'skynet.be', 'telenet.be', 'proximus.be', 'protonmail.com'],
			phoneGen: () => `04${randInt(60, 99)} ${randInt(10, 99)} ${randInt(10, 99)} ${randInt(10, 99)}`
		},
		CA: {
			flag: '🇨🇦', label: 'Canada',
			maleNames: ['Liam', 'Noah', 'Oliver', 'William', 'Elijah', 'James', 'Benjamin', 'Lucas', 'Henry', 'Alexander', 'Ethan', 'Jacob', 'Michael', 'Daniel', 'Logan', 'Jackson', 'Sebastian', 'Jack', 'Owen', 'Samuel'],
			femaleNames: ['Olivia', 'Emma', 'Charlotte', 'Amelia', 'Sophia', 'Isabella', 'Ava', 'Mia', 'Evelyn', 'Luna', 'Harper', 'Ella', 'Elizabeth', 'Sofia', 'Emily', 'Avery', 'Chloe', 'Scarlett', 'Penelope', 'Layla'],
			lastNames: ['Smith', 'Brown', 'Tremblay', 'Martin', 'Roy', 'Wilson', 'MacDonald', 'Gagnon', 'Johnson', 'Taylor', 'Côté', 'Campbell', 'Anderson', 'Leblanc', 'Lee', 'Jones', 'Williams', 'Miller', 'Gauthier', 'Bouchard'],
			streets: ['Rue Principale', 'Main Street', 'King Street', 'Queen Street', 'Rue Saint-Jean', 'Maple Avenue', 'Boulevard Laurier', 'Cedar Drive', 'Rue Notre-Dame', 'Park Road', 'Chemin du Lac', 'Wellington Street', 'Rue Sainte-Catherine', 'Elm Street', 'Boulevard René-Lévesque'],
			cities: [
				{ name: 'Toronto', cp: 'M5A 1A1' }, { name: 'Montréal', cp: 'H2X 1Y4' }, { name: 'Vancouver', cp: 'V6B 1A1' },
				{ name: 'Calgary', cp: 'T2P 1A1' }, { name: 'Ottawa', cp: 'K1A 0A1' }, { name: 'Edmonton', cp: 'T5J 0A1' },
				{ name: 'Québec', cp: 'G1R 1A1' }, { name: 'Winnipeg', cp: 'R3C 0A1' }, { name: 'Halifax', cp: 'B3H 1A1' },
				{ name: 'Victoria', cp: 'V8W 1A1' }, { name: 'Sherbrooke', cp: 'J1H 1A1' }, { name: 'Gatineau', cp: 'J8X 1A1' }
			],
			emailDomains: ['gmail.com', 'yahoo.ca', 'hotmail.ca', 'outlook.com', 'rogers.com', 'bell.net', 'shaw.ca', 'protonmail.com'],
			phoneGen: () => { const area = rand(['416', '514', '604', '403', '613', '780', '418', '204', '902', '250']); return `(${area}) ${randInt(200, 999)}-${randInt(1000, 9999)}`; }
		},
		CH: {
			flag: '🇨🇭', label: 'Suisse',
			maleNames: ['Noah', 'Liam', 'Matteo', 'Luca', 'Elias', 'Gabriel', 'Leon', 'Louis', 'David', 'Samuel', 'Ben', 'Julian', 'Finn', 'Tim', 'Alexander', 'Jan', 'Nico', 'Leandro', 'Rafael', 'Aaron'],
			femaleNames: ['Mia', 'Emma', 'Elena', 'Lina', 'Emilia', 'Lea', 'Anna', 'Lara', 'Laura', 'Alina', 'Sara', 'Sofia', 'Julia', 'Nina', 'Lena', 'Lia', 'Nora', 'Amelie', 'Jana', 'Chiara'],
			lastNames: ['Müller', 'Meier', 'Schmid', 'Keller', 'Weber', 'Huber', 'Schneider', 'Meyer', 'Steiner', 'Fischer', 'Gerber', 'Brunner', 'Baumann', 'Frei', 'Zimmermann', 'Moser', 'Widmer', 'Wyss', 'Graf', 'Roth'],
			streets: ['Bahnhofstrasse', 'Hauptstrasse', 'Dorfstrasse', 'Kirchgasse', 'Rue de la Gare', 'Seestrasse', 'Schulstrasse', 'Bergstrasse', 'Rue du Lac', 'Chemin des Vignes', 'Avenue de la Paix', 'Route de Genève', 'Marktgasse', 'Via San Gottardo', 'Piazza Grande'],
			cities: [
				{ name: 'Zürich', cp: '8001' }, { name: 'Genève', cp: '1200' }, { name: 'Bern', cp: '3000' },
				{ name: 'Basel', cp: '4000' }, { name: 'Lausanne', cp: '1000' }, { name: 'Luzern', cp: '6000' },
				{ name: 'St. Gallen', cp: '9000' }, { name: 'Biel', cp: '2500' }, { name: 'Lugano', cp: '6900' },
				{ name: 'Fribourg', cp: '1700' }, { name: 'Neuchâtel', cp: '2000' }, { name: 'Winterthur', cp: '8400' }
			],
			emailDomains: ['gmail.com', 'bluewin.ch', 'sunrise.ch', 'gmx.ch', 'outlook.com', 'protonmail.com', 'hispeed.ch', 'icloud.com'],
			phoneGen: () => `07${randInt(6, 9)} ${randInt(100, 999)} ${randInt(10, 99)} ${randInt(10, 99)}`
		},
		JP: {
			flag: '🇯🇵', label: '日本 (Japan)',
			maleNames: ['Haruto', 'Yuto', 'Sota', 'Riku', 'Hinata', 'Kaito', 'Sora', 'Ren', 'Minato', 'Asahi', 'Yuki', 'Takumi', 'Hayato', 'Ryota', 'Kota', 'Daiki', 'Shota', 'Kenji', 'Naoki', 'Akira'],
			femaleNames: ['Himari', 'Hina', 'Yua', 'Sakura', 'Ichika', 'Akari', 'Sara', 'Yui', 'Rin', 'Mei', 'Mio', 'Riko', 'Koharu', 'Aoi', 'Hana', 'Yuna', 'Miyu', 'Kokona', 'Saki', 'Ema'],
			lastNames: ['Sato', 'Suzuki', 'Takahashi', 'Tanaka', 'Watanabe', 'Ito', 'Yamamoto', 'Nakamura', 'Kobayashi', 'Kato', 'Yoshida', 'Yamada', 'Sasaki', 'Yamaguchi', 'Matsumoto', 'Inoue', 'Kimura', 'Shimizu', 'Hayashi', 'Saito'],
			streets: ['Chuo-dori', 'Meiji-dori', 'Yasukuni-dori', 'Sotobori-dori', 'Omotesando', 'Aoyama-dori', 'Shinjuku-dori', 'Kasuga-dori', 'Harumi-dori', 'Gaien-nishi-dori', 'Koen-dori', 'Tamagawa-dori', 'Kannana-dori', 'Meguro-dori', 'Takeshita-dori'],
			cities: [
				{ name: 'Tokyo', cp: '100-0001' }, { name: 'Osaka', cp: '530-0001' }, { name: 'Kyoto', cp: '600-8001' },
				{ name: 'Yokohama', cp: '220-0001' }, { name: 'Nagoya', cp: '450-0001' }, { name: 'Sapporo', cp: '060-0001' },
				{ name: 'Fukuoka', cp: '810-0001' }, { name: 'Kobe', cp: '650-0001' }, { name: 'Sendai', cp: '980-0001' },
				{ name: 'Hiroshima', cp: '730-0001' }, { name: 'Nara', cp: '630-8001' }, { name: 'Kamakura', cp: '248-0001' }
			],
			emailDomains: ['gmail.com', 'yahoo.co.jp', 'outlook.jp', 'docomo.ne.jp', 'softbank.ne.jp', 'icloud.com', 'protonmail.com', 'nifty.com'],
			phoneGen: () => `0${randInt(70, 90)}-${randInt(1000, 9999)}-${randInt(1000, 9999)}`
		},
		BR: {
			flag: '🇧🇷', label: 'Brasil',
			maleNames: ['Miguel', 'Arthur', 'Gael', 'Théo', 'Heitor', 'Ravi', 'Davi', 'Bernardo', 'Samuel', 'Gabriel', 'Pedro', 'Lorenzo', 'Benjamin', 'Matheus', 'Lucas', 'Nicolas', 'Joaquim', 'Rafael', 'Henrique', 'Gustavo'],
			femaleNames: ['Helena', 'Alice', 'Laura', 'Maria', 'Valentina', 'Heloísa', 'Sophia', 'Cecília', 'Isabella', 'Manuela', 'Julia', 'Luísa', 'Liz', 'Eloá', 'Lívia', 'Lorena', 'Clara', 'Beatriz', 'Mariana', 'Rafaela'],
			lastNames: ['Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa'],
			streets: ['Rua das Flores', 'Avenida Brasil', 'Rua São Paulo', 'Avenida Paulista', 'Rua da Liberdade', 'Rua XV de Novembro', 'Avenida Atlântica', 'Rua do Comércio', 'Avenida Rio Branco', 'Rua Sete de Setembro', 'Rua Augusta', 'Avenida Copacabana', 'Rua da Consolação', 'Alameda Santos', 'Rua Oscar Freire'],
			cities: [
				{ name: 'São Paulo', cp: '01000-000' }, { name: 'Rio de Janeiro', cp: '20000-000' }, { name: 'Brasília', cp: '70000-000' },
				{ name: 'Salvador', cp: '40000-000' }, { name: 'Fortaleza', cp: '60000-000' }, { name: 'Belo Horizonte', cp: '30000-000' },
				{ name: 'Curitiba', cp: '80000-000' }, { name: 'Recife', cp: '50000-000' }, { name: 'Porto Alegre', cp: '90000-000' },
				{ name: 'Florianópolis', cp: '88000-000' }, { name: 'Manaus', cp: '69000-000' }, { name: 'Campinas', cp: '13000-000' }
			],
			emailDomains: ['gmail.com', 'yahoo.com.br', 'hotmail.com', 'outlook.com.br', 'uol.com.br', 'bol.com.br', 'terra.com.br', 'protonmail.com'],
			phoneGen: () => { const ddd = rand(['11', '21', '31', '41', '51', '61', '71', '81', '85', '92']); return `(${ddd}) 9${randInt(1000, 9999)}-${randInt(1000, 9999)}`; }
		}
	};

	const countryKeys = Object.keys(countries);

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
	function generateIdentity(code: string): Identity {
		const c = countries[code];
		const gender: 'M' | 'F' = Math.random() > 0.5 ? 'M' : 'F';
		const firstName = gender === 'M' ? rand(c.maleNames) : rand(c.femaleNames);
		const lastName = rand(c.lastNames);
		const age = randInt(18, 65);
		const birthYear = new Date().getFullYear() - age;
		const birthMonth = String(randInt(1, 12)).padStart(2, '0');
		const birthDay = String(randInt(1, 28)).padStart(2, '0');
		const city = rand(c.cities);
		const streetNumber = randInt(1, 120);
		const street = rand(c.streets);

		const emailPrefix = `${firstName.toLowerCase().replace(/[^a-z]/g, '')}.${lastName.toLowerCase().replace(/[^a-z]/g, '')}${randInt(10, 99)}`;

		return {
			firstName,
			lastName,
			gender,
			dob: `${birthDay}/${birthMonth}/${birthYear}`,
			age,
			email: `${emailPrefix}@${rand(c.emailDomains)}`,
			phone: c.phoneGen(),
			address: `${streetNumber} ${street}`,
			city: city.name,
			postalCode: city.cp,
			country: c.label
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
	let selectedCountry = $state('FR');
	let identity = $state<Identity | null>(null);
	let card = $state<VirtualCard | null>(null);
	let copiedField = $state<string | null>(null);
	let showCvv = $state(false);
	let flipped = $state(false);

	function regenerate() {
		const id = generateIdentity(selectedCountry);
		identity = id;
		card = generateCard(id);
		showCvv = false;
		flipped = false;
	}

	function selectCountry(code: string) {
		selectedCountry = code;
		regenerate();
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
	<div class="flex flex-col sm:flex-row sm:items-center justify-between gap-4 mb-6">
		<div>
			<h1 class="text-xl font-extrabold text-white">{t('identity.title')}</h1>
			<p class="text-xs text-[var(--fv-ash)] mt-0.5">{t('identity.description')}</p>
		</div>
		<button
			onclick={regenerate}
			class="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#10b981]/10 border border-[#10b981]/20 text-[#10b981] text-sm font-semibold hover:bg-[#10b981]/20 transition-all shrink-0"
		>
			<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
				<path d="M1 4v6h6"/><path d="M23 20v-6h-6"/>
				<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4-4.64 4.36A9 9 0 0 1 3.51 15"/>
			</svg>
			{t('identity.regenerate')}
		</button>
	</div>

	<!-- Country selector -->
	<div class="relative mb-6 w-full max-w-xs">
		<select
			class="country-select"
			value={selectedCountry}
			onchange={(e) => selectCountry((e.target as HTMLSelectElement).value)}
		>
			{#each countryKeys as code}
				<option value={code}>{countries[code].flag}  {countries[code].label}</option>
			{/each}
		</select>
		<div class="country-select-arrow">
			<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
				<polyline points="6 9 12 15 18 9"/>
			</svg>
		</div>
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
					<h2 class="text-sm font-bold text-white">{t('identity.section_identity')}</h2>
					<p class="text-[10px] text-[var(--fv-ash)]">{t('identity.fictional')}</p>
				</div>
			</div>

			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
				{#each [
					{ label: t('identity.first_name'), value: identity.firstName, field: 'firstName' },
					{ label: t('identity.last_name'), value: identity.lastName, field: 'lastName' },
					{ label: t('identity.dob'), value: `${identity.dob} (${identity.age} ans)`, field: 'dob' },
					{ label: t('identity.fake_email'), value: identity.email, field: 'email' },
					{ label: t('identity.phone'), value: identity.phone, field: 'phone' },
					{ label: t('identity.address'), value: identity.address, field: 'address' },
					{ label: t('identity.city'), value: identity.city, field: 'city' },
					{ label: t('identity.postal_code'), value: identity.postalCode, field: 'cp' },
					{ label: t('identity.country'), value: identity.country, field: 'country' }
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
					<h2 class="text-sm font-bold text-white">{t('identity.virtual_card')}</h2>
					<p class="text-[10px] text-[var(--fv-ash)]">{t('identity.card_note')}</p>
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
										<p class="text-white/50 text-[9px] uppercase tracking-widest mb-0.5">{t('identity.cardholder')}</p>
										<p class="text-white font-semibold text-sm tracking-wider">{card.holder}</p>
									</div>
									<div class="text-right">
										<p class="text-white/50 text-[9px] uppercase tracking-widest mb-0.5">{t('identity.expiry')}</p>
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
							<p class="text-center text-white/30 text-[9px] mt-4 px-5">{t('identity.cvv_back')}</p>
						</div>
					</div>
				</div>
			</div>
			<p class="text-center text-[10px] text-[var(--fv-ash)] mb-5">{t('identity.flip_card')}</p>

			<!-- Card fields copy -->
			<div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
				{#each [
					{ label: t('identity.card_number'), value: card.number, display: card.numberFormatted, field: 'cardNum' },
					{ label: t('identity.card_expiry'), value: card.expiry, display: card.expiry, field: 'cardExp' },
					{ label: t('identity.cvv'), value: card.cvv, display: showCvv ? card.cvv : '•••', field: 'cardCvv' },
					{ label: t('identity.cardholder'), value: card.holder, display: card.holder, field: 'cardHolder' }
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
					{@html t('identity.luhn_warning')}
				</p>
			</div>
		</div>
	</div>
	{/if}
</div>

<style>
	.country-select {
		appearance: none;
		-webkit-appearance: none;
		width: 100%;
		padding: 12px 44px 12px 16px;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 14px;
		color: #f1f5f9;
		font-size: 14px;
		font-weight: 600;
		font-family: inherit;
		cursor: pointer;
		outline: none;
		transition: all 0.2s ease;
	}

	.country-select:hover {
		background: rgba(255, 255, 255, 0.07);
		border-color: rgba(255, 255, 255, 0.15);
	}

	.country-select:focus {
		border-color: rgba(16, 185, 129, 0.5);
		box-shadow: 0 0 0 3px rgba(16, 185, 129, 0.1);
	}

	.country-select option {
		background: #0f172a;
		color: #f1f5f9;
		padding: 10px;
		font-size: 14px;
	}

	.country-select-arrow {
		position: absolute;
		right: 14px;
		top: 50%;
		transform: translateY(-50%);
		color: #64748b;
		pointer-events: none;
		transition: color 0.15s;
	}

	.country-select:focus + .country-select-arrow {
		color: #10b981;
	}
</style>
