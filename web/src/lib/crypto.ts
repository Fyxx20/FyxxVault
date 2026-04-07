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

	// Rejection sampling to avoid modulo bias
	const maxValid = 256 - (256 % charset.length);
	const result: string[] = [];
	while (result.length < length) {
		const array = crypto.getRandomValues(new Uint8Array(length - result.length + 16));
		for (const byte of array) {
			if (byte < maxValid && result.length < length) {
				result.push(charset[byte % charset.length]);
			}
		}
	}
	return result.join('');
}

/**
 * Generate a random passphrase (random words separated by a separator).
 */
export function generatePassphrase(
	wordCount: number = 5,
	separator: string = '-',
	capitalize: boolean = true
): string {
	// 1024 words = 10 bits of entropy per word (5 words = 50 bits, 6 words = 60 bits)
	const words = [
		'abacus','abbey','absorb','access','accord','acorn','acre','admit','adopt','advent',
		'aerial','agenda','agent','agile','alarm','album','alert','alien','align','alloy',
		'alpha','amber','anchor','angel','anvil','apple','arctic','arena','arrow','atlas',
		'audio','aurora','avid','axiom','azure','badge','baker','bamboo','banjo','baron',
		'basin','beach','beacon','bench','berry','blade','blanket','blaze','blend','bliss',
		'bloom','board','bonus','booth','brave','breeze','brick','bride','brief','brisk',
		'broad','brook','brush','buddy','build','bundle','burst','cabin','cable','cactus',
		'camel','campus','candy','canyon','cargo','carpet','cedar','census','chain','chalk',
		'chapel','charm','chase','cherry','chief','cider','circus','civic','claim','clash',
		'clay','cliff','climb','clock','cloud','clown','coach','coast','cobra','cocoa',
		'comet','copper','coral','cotton','couch','crane','crash','cream','crest','crisp',
		'cross','crown','cruise','cubic','curve','cycle','dagger','dance','dawn','debate',
		'debug','decal','decoy','delta','demon','dense','depot','derby','desert','detail',
		'device','dew','dialog','digit','dingo','disco','diver','dizzy','dock','dodge',
		'domain','donor','donut','dove','draft','dragon','drain','drape','dream','drift',
		'drone','drums','dusk','dwarf','eagle','earth','ebony','echo','eclipse','edge',
		'editor','effort','elder','elite','elm','ember','emery','emoji','empire','empty',
		'enamel','endow','energy','enjoy','entry','epoch','equal','equip','erode','essay',
		'estate','ethic','evade','event','exact','exile','export','extra','fable','fabric',
		'facet','factor','fairy','faith','falcon','fame','fancy','fawn','feast','fennel',
		'ferry','fiber','field','figment','filter','final','fiscal','flair','flame','flash',
		'flask','fleet','flint','flora','fluid','flute','focal','foggy','font','forest',
		'forge','format','forum','fossil','found','frame','fresh','frost','frozen','fruit',
		'fuels','funds','fungi','fused','gadget','galaxy','gamer','gamma','garage','garden',
		'garlic','gauge','gazer','gecko','geek','ghost','giant','giddy','ginger','gizmo',
		'glade','gleam','glide','globe','glory','gnome','goblet','golden','gospel','grace',
		'grain','grape','grasp','gravel','green','greet','grief','grind','groove','grove',
		'growl','guard','guess','guide','guild','guitar','gummy','gusto','habit','hammer',
		'harbor','haste','haven','hazel','heart','helix','helmet','hemp','heron','hiker',
		'hitch','hobby','hollow','holly','honey','honor','horizon','hover','human','humid',
		'humor','hunter','husky','hyena','icing','ideal','igloo','image','impact','impel',
		'import','incite','index','indoor','infant','influx','inject','inner','input','insect',
		'intent','invest','ionic','irony','island','ivory','jacket','jaguar','jasper','jazzy',
		'jersey','jewel','jigsaw','joker','jolly','jostle','jounce','judge','juice','jumble',
		'jumbo','jungle','junior','justice','kayak','kebab','kennel','kernel','kettle','kidney',
		'kindle','kiosk','kitten','knack','kneel','knobs','kodiak','kraft','kudos','label',
		'ladder','lager','lagoon','lance','laptop','latch','launch','layer','layout','leafy',
		'legend','lemon','lesson','level','lever','light','lilac','linden','linen','lions',
		'liquid','listen','llama','lobby','local','locket','lodge','logic','lotus','lumber',
		'lunar','lyric','macaw','macro','magnet','magic','major','mammal','mango','manor',
		'mantis','maple','marble','march','margin','marsh','mascot','mason','master','matrix',
		'meadow','medal','medium','melon','memoir','mental','mentor','merge','merit','metal',
		'method','micro','middle','might','mimic','mingle','minor','mirth','mirror','mixer',
		'mocha','model','modern','module','money','month','moose','moral','mosaic','motion',
		'mouse','movie','muffin','murmur','muscle','museum','music','mutual','mystic','nacho',
		'naive','napkin','narrow','native','nebula','nerve','nestle','nexus','nimble','noble',
		'nomad','normal','north','notary','notion','novel','number','nurse','nutmeg','nuzzle',
		'object','obtain','ocean','offset','olive','omega','onion','onset','opaque','opera',
		'option','oracle','orbit','orchid','organ','origin','osprey','otter','outer','output',
		'outfit','outlaw','oven','oxide','oyster','ozone','paddle','palace','panda','panel',
		'pantry','papaya','parade','parcel','parrot','paste','pastry','patch','patio','patrol',
		'pause','peach','peanut','pearl','pebble','pencil','penny','pepper','perch','permit',
		'person','phase','photo','phrase','piano','picnic','pigeon','pigment','pillow','pilot',
		'pinch','pixel','pizza','place','plaid','plane','planet','plant','plasma','plaza',
		'pledge','pliers','pluck','plumb','plume','plunge','plush','pocket','point','poison',
		'polar','polite','polka','ponder','poppy','porch','portal','poser','poster','potion',
		'powder','power','praise','prefix','press','pretty','price','prince','prism','prison',
		'prize','probe','profit','prompt','proof','proper','prune','public','puddle','pulse',
		'pumpkin','pupil','purple','purse','puzzle','pygmy','python','quail','qualm','quark',
		'queen','query','quest','quick','quiet','quiver','quota','rabbit','racket','radar',
		'radish','radio','raft','rally','ramen','ramp','ranch','random','range','rapid',
		'raven','react','reader','realm','reason','recap','record','reef','reform','region',
		'reign','reject','relate','relay','relief','relish','remix','remote','renew','rental',
		'repeal','reply','report','rescue','result','retail','retire','reveal','revolt','rhyme',
		'ribbon','rider','ridge','rifle','rigid','rinse','ripple','risky','ritual','river',
		'roast','robin','robot','rocket','rocky','rogue','roller','roman','roost','roster',
		'rotate','rough','round','royal','rugby','ruler','rumba','rumble','runway','rural',
		'sable','saddle','safari','safety','saint','salad','salmon','salon','salsa','sample',
		'sandal','sandy','satin','sauce','sauna','scale','scenic','school','scope','scout',
		'screen','script','sculpt','season','secret','sector','sedan','senate','sense','sequel',
		'serial','serum','settle','setup','seven','shadow','shark','sheep','shelf','shell',
		'shield','shift','shine','shirt','shock','shower','shrub','shuttle','siege','sigma',
		'signal','silly','silver','simple','since','siren','sister','sixth','sixty','sketch',
		'skate','skill','skull','slate','sleek','slice','slide','slope','smart','smile',
		'smoke','snack','snake','socket','solar','solid','solve','sonic','south','space',
		'spark','spawn','spear','speech','speed','spice','spider','spine','spiral','splash',
		'spoke','sport','spray','spring','squad','stable','stack','staff','stage','stain',
		'stake','stalk','stamp','stand','staple','stark','start','stash','state','stave',
		'steak','steam','steel','steep','steer','stems','stern','stick','still','stock',
		'stole','stone','stood','store','storm','story','stove','strap','straw','stray',
		'stream','stride','strike','string','strip','stroke','stuck','studio','study','stuff',
		'stump','style','submit','subtle','suffix','sugar','suite','sultan','summit','sunny',
		'super','supply','surge','survey','swamp','swarm','sweet','swept','swift','symbol',
		'sword','syntax','syrup','system','table','tackle','talent','tally','tango','target',
		'tarot','taste','tavern','temple','tempo','tenant','tender','tennis','theory','theta',
		'thorn','thread','thrill','throne','thumb','ticket','tidal','tiger','timber','timer',
		'tissue','toast','toggle','token','tomato','topic','torch','torque','total','toward',
		'tower','toxin','trace','track','trade','trail','train','trait','travel','treaty',
		'treat','trend','tribal','trick','triple','trophy','tropic','trout','truant','truly',
		'trunk','trust','tumble','tulip','tunic','tunnel','turban','turtle','twelve','typing',
		'ultra','umbra','unable','uncle','under','union','unique','unite','unity','until',
		'update','upper','uptown','urban','urgent','usher','useful','usual','utmost','utile',
		'utter','vacuum','valid','valley','value','valve','vandal','vapor','vault','vector',
		'velvet','vendor','venture','verbal','verify','verse','vessel','viable','victim','vigor',
		'vinyl','viola','violet','viper','virtue','virus','vision','visit','visor','visual',
		'vital','vivid','vocal','vodka','voice','volume','voter','vowel','voyage','vulture',
		'wacky','waffle','wagon','waist','wallet','walnut','walrus','waltz','wander','wanted',
		'warmth','washer','watch','water','waver','wealth','weapon','weary','weasel','wheat',
		'while','whirl','whole','wicked','widen','width','wield','winter','wisdom','witch',
		'wizard','wonder','worker','world','worthy','worth','wound','wrist','xerox','yacht',
		'yearn','yellow','yield','yogurt','youth','zealot','zebra','zenith','zephyr','zesty',
		'zigzag','zinc','zipper','zippy','zombie','zones','zoning','zoomed',
		'alchemy','basalt','cobalt','damask','fenwick','gopher'
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
