/**
 * Secure sharing using Web Crypto API.
 * Generates an encrypted share link with expiration and max view limits.
 */

interface SharePayload {
	title: string;
	username?: string;
	password?: string;
	website?: string;
	notes?: string;
	[key: string]: any;
}

interface ShareOptions {
	expiresIn: '1h' | '6h' | '24h' | '72h';
	maxViews: number;
}

/**
 * Encrypt entry data for sharing. Returns a URL fragment with the key.
 * The key is only in the fragment (never sent to server).
 */
export async function createShareLink(
	payload: SharePayload,
	options: ShareOptions
): Promise<{ encryptedData: string; key: string; expiresAt: string }> {
	// Generate a random AES-256-GCM key
	const key = await crypto.subtle.generateKey(
		{ name: 'AES-GCM', length: 256 },
		true,
		['encrypt', 'decrypt']
	);

	// Export key as raw bytes
	const rawKey = new Uint8Array(await crypto.subtle.exportKey('raw', key));

	// Encode payload
	const encoder = new TextEncoder();
	const plaintext = encoder.encode(JSON.stringify({
		...payload,
		_maxViews: options.maxViews,
		_createdAt: new Date().toISOString()
	}));

	// Encrypt
	const iv = crypto.getRandomValues(new Uint8Array(12));
	const ciphertext = await crypto.subtle.encrypt(
		{ name: 'AES-GCM', iv },
		key,
		plaintext
	);

	// Combine IV + ciphertext
	const combined = new Uint8Array(iv.length + ciphertext.byteLength);
	combined.set(iv, 0);
	combined.set(new Uint8Array(ciphertext), iv.length);

	// Calculate expiration
	const expirationMap: Record<string, number> = {
		'1h': 3600000,
		'6h': 21600000,
		'24h': 86400000,
		'72h': 259200000
	};
	const expiresAt = new Date(Date.now() + expirationMap[options.expiresIn]).toISOString();

	// Convert to base64url
	const encryptedData = arrayToBase64Url(combined);
	const keyString = arrayToBase64Url(rawKey);

	return { encryptedData, key: keyString, expiresAt };
}

/**
 * Decrypt shared data using the key from the URL fragment.
 */
export async function decryptShareData(
	encryptedData: string,
	keyString: string
): Promise<SharePayload> {
	const combined = base64UrlToArray(encryptedData);
	const rawKey = base64UrlToArray(keyString);

	const key = await crypto.subtle.importKey(
		'raw',
		rawKey,
		{ name: 'AES-GCM', length: 256 },
		false,
		['decrypt']
	);

	const iv = combined.slice(0, 12);
	const ciphertext = combined.slice(12);

	const plaintext = await crypto.subtle.decrypt(
		{ name: 'AES-GCM', iv },
		key,
		ciphertext
	);

	const decoder = new TextDecoder();
	return JSON.parse(decoder.decode(plaintext));
}

function arrayToBase64Url(bytes: Uint8Array): string {
	let binary = '';
	for (const byte of bytes) {
		binary += String.fromCharCode(byte);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '');
}

function base64UrlToArray(str: string): Uint8Array {
	const padded = str.replace(/-/g, '+').replace(/_/g, '/');
	const binary = atob(padded);
	const bytes = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) {
		bytes[i] = binary.charCodeAt(i);
	}
	return bytes;
}
