import type { VaultEntry } from './types';

const PBKDF2_ROUNDS_DEFAULT = 210_000;
const AES_KEY_BITS = 256;
const IV_LENGTH = 12;

/**
 * Safely access getSubtle(), throwing a clear error if unavailable.
 */
function getSubtle(): SubtleCrypto {
	if (typeof globalThis.crypto?.subtle === 'undefined') {
		throw new Error('Web Crypto API non disponible. Utilise HTTPS ou localhost.');
	}
	return globalThis.crypto.subtle;
}

/**
 * Derive a Key-Encryption Key (KEK) from the master password using PBKDF2.
 * The KEK is used to wrap/unwrap the Vault Encryption Key (VEK).
 */
export async function deriveKEK(
	masterPassword: string,
	salt: Uint8Array,
	rounds: number = PBKDF2_ROUNDS_DEFAULT
): Promise<CryptoKey> {
	const enc = new TextEncoder();
	const keyMaterial = await getSubtle().importKey(
		'raw',
		enc.encode(masterPassword),
		'PBKDF2',
		false,
		['deriveKey']
	);

	return getSubtle().deriveKey(
		{
			name: 'PBKDF2',
			salt,
			iterations: rounds,
			hash: 'SHA-256'
		},
		keyMaterial,
		{ name: 'AES-GCM', length: AES_KEY_BITS },
		false,
		['encrypt', 'decrypt']
	);
}

/**
 * Generate a random 32-byte Vault Encryption Key (VEK).
 */
export function generateVEK(): Uint8Array {
	return crypto.getRandomValues(new Uint8Array(32));
}

/**
 * Generate a random salt for PBKDF2.
 */
export function generateSalt(): Uint8Array {
	return crypto.getRandomValues(new Uint8Array(32));
}

/**
 * Wrap (encrypt) the VEK with the KEK using AES-GCM.
 * Output format: [12-byte IV][ciphertext+tag]
 */
export async function wrapVEK(vek: Uint8Array, kek: CryptoKey): Promise<Uint8Array> {
	const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
	const ciphertext = await getSubtle().encrypt(
		{ name: 'AES-GCM', iv },
		kek,
		vek
	);

	const result = new Uint8Array(IV_LENGTH + ciphertext.byteLength);
	result.set(iv, 0);
	result.set(new Uint8Array(ciphertext), IV_LENGTH);
	return result;
}

/**
 * Unwrap (decrypt) the VEK with the KEK using AES-GCM.
 * Input format: [12-byte IV][ciphertext+tag]
 */
export async function unwrapVEK(wrapped: Uint8Array, kek: CryptoKey): Promise<Uint8Array> {
	const iv = wrapped.slice(0, IV_LENGTH);
	const ciphertext = wrapped.slice(IV_LENGTH);

	const plaintext = await getSubtle().decrypt(
		{ name: 'AES-GCM', iv },
		kek,
		ciphertext
	);

	return new Uint8Array(plaintext);
}

/**
 * Import raw VEK bytes as a CryptoKey for AES-GCM.
 */
async function importVEKKey(vek: Uint8Array): Promise<CryptoKey> {
	return getSubtle().importKey(
		'raw',
		vek,
		{ name: 'AES-GCM', length: AES_KEY_BITS },
		false,
		['encrypt', 'decrypt']
	);
}

/**
 * Encrypt a vault entry with the VEK using AES-GCM.
 * Output format: [12-byte IV][ciphertext+tag]
 */
export async function encryptEntry(entry: VaultEntry, vek: Uint8Array): Promise<Uint8Array> {
	const enc = new TextEncoder();
	const plaintext = enc.encode(JSON.stringify(entry));
	const iv = crypto.getRandomValues(new Uint8Array(IV_LENGTH));
	const key = await importVEKKey(vek);

	const ciphertext = await getSubtle().encrypt(
		{ name: 'AES-GCM', iv },
		key,
		plaintext
	);

	const result = new Uint8Array(IV_LENGTH + ciphertext.byteLength);
	result.set(iv, 0);
	result.set(new Uint8Array(ciphertext), IV_LENGTH);
	return result;
}

/**
 * Decrypt a vault entry blob with the VEK using AES-GCM.
 * Input format: [12-byte IV][ciphertext+tag]
 */
export async function decryptEntry(blob: Uint8Array, vek: Uint8Array): Promise<VaultEntry> {
	const iv = blob.slice(0, IV_LENGTH);
	const ciphertext = blob.slice(IV_LENGTH);
	const key = await importVEKKey(vek);

	const plaintext = await getSubtle().decrypt(
		{ name: 'AES-GCM', iv },
		key,
		ciphertext
	);

	const dec = new TextDecoder();
	return JSON.parse(dec.decode(plaintext)) as VaultEntry;
}

/**
 * Evaluate password strength on a 0–100 scale.
 */
export function passwordStrength(password: string): { score: number; label: string; color: string } {
	if (!password) return { score: 0, label: 'Aucun', color: 'var(--fv-ash)' };

	let score = 0;

	// Length scoring
	if (password.length >= 8) score += 15;
	if (password.length >= 12) score += 15;
	if (password.length >= 16) score += 10;
	if (password.length >= 20) score += 10;

	// Character variety
	if (/[a-z]/.test(password)) score += 10;
	if (/[A-Z]/.test(password)) score += 10;
	if (/[0-9]/.test(password)) score += 10;
	if (/[^a-zA-Z0-9]/.test(password)) score += 15;

	// Patterns (deductions)
	if (/(.)\1{2,}/.test(password)) score -= 10; // repeated chars
	if (/^[a-z]+$/i.test(password)) score -= 10; // only letters
	if (/^[0-9]+$/.test(password)) score -= 15; // only digits

	score = Math.max(0, Math.min(100, score));

	if (score < 30) return { score, label: 'Faible', color: 'var(--fv-danger)' };
	if (score < 60) return { score, label: 'Moyen', color: 'var(--fv-gold)' };
	if (score < 80) return { score, label: 'Fort', color: 'var(--fv-cyan)' };
	return { score, label: 'Excellent', color: 'var(--fv-success)' };
}

/**
 * Generate a random password.
 */
export function generatePassword(
	length: number = 20,
	options: {
		uppercase?: boolean;
		lowercase?: boolean;
		digits?: boolean;
		symbols?: boolean;
	} = {}
): string {
	const {
		uppercase = true,
		lowercase = true,
		digits = true,
		symbols = true
	} = options;

	let charset = '';
	if (lowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
	if (uppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
	if (digits) charset += '0123456789';
	if (symbols) charset += '!@#$%^&*()-_=+[]{}|;:,.<>?';

	if (!charset) charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

	const array = crypto.getRandomValues(new Uint8Array(length));
	return Array.from(array, (byte) => charset[byte % charset.length]).join('');
}

/**
 * Generate a random passphrase (random words separated by a separator).
 */
export function generatePassphrase(
	wordCount: number = 5,
	separator: string = '-',
	capitalize: boolean = true
): string {
	// Diceware-inspired word list (subset for client-side use)
	const words = [
		'abacus','abbey','absorb','access','accord','acorn','acre','admit','adopt','advent',
		'agenda','agent','agile','alarm','album','alert','alien','align','alloy','alpha',
		'amber','anchor','angel','anvil','apple','arctic','arena','arrow','atlas','audio',
		'aurora','avid','axiom','azure','badge','baker','banjo','baron','basin','beach',
		'beacon','bench','berry','blade','blaze','blend','bliss','bloom','board','bonus',
		'booth','brave','brick','bride','brief','brisk','broad','brook','brush','buddy',
		'build','burst','cabin','cable','camel','candy','cargo','cedar','chain','chalk',
		'charm','chase','chief','cider','civic','claim','clash','cliff','climb','cloud',
		'clown','coach','coast','cobra','cocoa','comet','coral','couch','crane','crash',
		'cream','crest','crisp','cross','crown','cubic','curve','cycle','dance','dawn',
		'debug','decal','decoy','delta','dense','depot','derby','dew','digit','dingo',
		'disco','diver','dizzy','dodge','donor','donut','dove','draft','drain','drape',
		'dream','drift','drone','drums','dusk','dwarf','eagle','earth','ebony','echo',
		'eclipse','edge','elder','elite','ember','emery','emoji','empty','enamel','endow',
		'enjoy','epoch','equal','equip','erode','essay','ethic','evade','event','exact',
		'exile','extra','fable','facet','fairy','faith','fame','fancy','fawn','feast',
		'fiber','field','figment','final','flair','flame','flash','fleet','flint','flora',
		'fluid','flute','focal','foggy','font','forge','forum','found','frame','fresh',
		'frost','fruit','fuels','funds','fungi','fused','gamer','gamma','gauge','gazer',
		'gecko','geek','ghost','giant','giddy','gizmo','glade','gleam','glide','globe',
		'glory','gnome','grace','grain','grape','grasp','gravel','green','greet','grief',
		'grind','groin','grove','growl','guard','guess','guide','guild','gummy','gusto',
		'habit','haste','haven','hazel','heart','helix','hemp','heron','hiker','hitch',
		'hobby','holly','honey','honor','hover','human','humid','humor','husky','hyena',
		'icing','ideal','igloo','image','impel','index','inner','input','ionic','irony',
		'ivory','jacket','jaguar','jazzy','jewel','joker','jolly','judge','juice','jumbo',
		'kayak','kebab','kiosk','knack','kneel','knobs','kraft','kudos','label','lager',
		'lance','latch','layer','leafy','lemon','level','lever','light','lilac','linen',
		'lions','llama','lobby','local','lodge','logic','lotus','lunar','lyric','macro',
		'magic','major','mango','manor','maple','march','marsh','mason','medal','melon',
		'merge','merit','metal','micro','might','mimic','minor','mirth','mixer','mocha',
		'model','money','month','moose','moral','mouse','movie','music','nacho','naive',
		'nerve','nexus','noble','north','novel','nurse','ocean','olive','omega','onset',
		'opera','orbit','organ','outer','oxide','ozone','panda','panel','paste','patch',
		'patio','pause','peach','pearl','penny','perch','phase','photo','piano','pilot',
		'pinch','pixel','pizza','place','plaid','plane','plant','plaza','pluck','plumb',
		'plume','plush','point','polar','polka','poppy','porch','poser','power','press',
		'price','prism','prize','probe','proof','prune','pulse','pupil','purse','pygmy',
		'quail','qualm','quark','queen','query','quest','quick','quiet','quota','radar',
		'radio','rally','ramen','ranch','range','rapid','raven','react','realm','recap',
		'reef','reign','relay','remix','renew','reply','rhyme','rider','ridge','rigid',
		'rinse','risky','river','roast','robin','robot','rocky','rogue','roman','roost',
		'royal','rugby','ruler','rumba','rural','sable','saint','salad','salon','salsa',
		'sandy','satin','sauce','sauna','scale','scene','scone','scope','scout','sedan',
		'sense','serum','setup','seven','shade','shark','sheep','shelf','shell','shift',
		'shine','shirt','shock','shown','shrub','siege','sigma','silly','since','siren',
		'sixth','sixty','skate','skill','skull','slate','sleek','slice','slide','slope',
		'smart','smile','smoke','snack','snake','solar','solid','solve','sonic','south',
		'space','spark','spawn','spear','speed','spice','spine','spoke','sport','spray',
		'squad','stack','staff','stage','stain','stake','stalk','stamp','stand','stark',
		'start','stash','state','stave','steak','steam','steel','steep','steer','stems',
		'stern','stick','still','stock','stole','stone','stood','store','storm','story',
		'stove','strap','straw','stray','strip','stuck','study','stuff','stump','style',
		'sugar','suite','sunny','super','surge','swamp','swarm','sweet','swept','swift',
		'sword','syrup','table','tally','tango','tarot','taste','tempo','theta','thorn',
		'thumb','tidal','tiger','timer','toast','token','topic','torch','total','tower',
		'trace','track','trade','trail','train','trait','treat','trend','trick','troop',
		'trout','truly','trump','trunk','trust','tulip','tunic','ultra','umbra','uncle',
		'under','union','unite','unity','until','upper','urban','usher','usual','utile',
		'utter','valid','value','valve','vapor','vault','verse','vigor','vinyl','viola',
		'viper','virus','visit','visor','vital','vivid','vocal','vodka','voice','voter',
		'vowel','wacky','wagon','waist','waltz','watch','water','waver','weary','wheat',
		'while','whirl','whole','widen','width','wield','witch','wizard','world','worth',
		'wound','wrist','yacht','yearn','yield','youth','zebra','zesty','zippy','zones'
	];

	const indices = crypto.getRandomValues(new Uint32Array(wordCount));
	const selected = Array.from(indices).map(i => {
		const word = words[i % words.length];
		return capitalize ? word.charAt(0).toUpperCase() + word.slice(1) : word;
	});

	return selected.join(separator);
}

/**
 * Convert Uint8Array to hex string (for debugging/display).
 */
export function bytesToHex(bytes: Uint8Array): string {
	return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Convert hex string to Uint8Array.
 */
export function hexToBytes(hex: string): Uint8Array {
	const bytes = new Uint8Array(hex.length / 2);
	for (let i = 0; i < hex.length; i += 2) {
		bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
	}
	return bytes;
}
