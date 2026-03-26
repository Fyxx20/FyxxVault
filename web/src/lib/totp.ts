/**
 * TOTP (Time-Based One-Time Password) generator using Web Crypto API.
 * RFC 6238 compliant.
 */

/**
 * Decode a Base32-encoded string to Uint8Array.
 */
function base32Decode(encoded: string): Uint8Array {
	const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
	const cleaned = encoded.replace(/[\s=-]/g, '').toUpperCase();

	let bits = '';
	for (const char of cleaned) {
		const idx = alphabet.indexOf(char);
		if (idx === -1) continue;
		bits += idx.toString(2).padStart(5, '0');
	}

	const bytes = new Uint8Array(Math.floor(bits.length / 8));
	for (let i = 0; i < bytes.length; i++) {
		bytes[i] = parseInt(bits.substring(i * 8, i * 8 + 8), 2);
	}
	return bytes;
}

/**
 * Generate HMAC-SHA1 using Web Crypto API.
 */
async function hmacSha1(key: Uint8Array, message: Uint8Array): Promise<Uint8Array> {
	const cryptoKey = await crypto.subtle.importKey(
		'raw',
		key,
		{ name: 'HMAC', hash: 'SHA-1' },
		false,
		['sign']
	);
	const signature = await crypto.subtle.sign('HMAC', cryptoKey, message);
	return new Uint8Array(signature);
}

/**
 * Convert a number to an 8-byte big-endian Uint8Array.
 */
function numberToBytes(num: number): Uint8Array {
	const bytes = new Uint8Array(8);
	let temp = num;
	for (let i = 7; i >= 0; i--) {
		bytes[i] = temp & 0xff;
		temp = Math.floor(temp / 256);
	}
	return bytes;
}

/**
 * Generate a TOTP code from a Base32 secret.
 * @param secret - Base32-encoded secret key
 * @param period - Time step in seconds (default 30)
 * @param digits - Number of digits in the code (default 6)
 * @returns The TOTP code as a zero-padded string
 */
export async function generateTOTP(
	secret: string,
	period: number = 30,
	digits: number = 6
): Promise<string> {
	const key = base32Decode(secret);
	const time = Math.floor(Date.now() / 1000 / period);
	const timeBytes = numberToBytes(time);

	const hmac = await hmacSha1(key, timeBytes);

	// Dynamic truncation
	const offset = hmac[hmac.length - 1] & 0x0f;
	const binary =
		((hmac[offset] & 0x7f) << 24) |
		((hmac[offset + 1] & 0xff) << 16) |
		((hmac[offset + 2] & 0xff) << 8) |
		(hmac[offset + 3] & 0xff);

	const otp = binary % Math.pow(10, digits);
	return otp.toString().padStart(digits, '0');
}

/**
 * Get the remaining seconds in the current TOTP period.
 */
export function getTOTPRemaining(period: number = 30): number {
	return period - (Math.floor(Date.now() / 1000) % period);
}
