/**
 * Check a password against the Have I Been Pwned database
 * using the k-anonymity API (only sends the first 5 chars of the SHA-1 hash).
 * Returns the number of times the password has appeared in data breaches (0 = safe).
 */
export async function checkPassword(password: string): Promise<number> {
	const encoder = new TextEncoder();
	const data = encoder.encode(password);
	const hashBuffer = await crypto.subtle.digest('SHA-1', data);
	const hashArray = Array.from(new Uint8Array(hashBuffer));
	const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('').toUpperCase();
	const prefix = hashHex.substring(0, 5);
	const suffix = hashHex.substring(5);

	const response = await fetch(`https://api.pwnedpasswords.com/range/${prefix}`);
	const text = await response.text();
	const lines = text.split('\n');

	for (const line of lines) {
		const [hash, count] = line.split(':');
		if (hash.trim() === suffix) return parseInt(count.trim());
	}
	return 0;
}

/**
 * Check multiple passwords in batch with progress callback.
 * Returns a map of entry IDs to breach counts.
 */
export async function checkPasswordsBatch(
	entries: { id: string; password: string }[],
	onProgress?: (checked: number, total: number) => void
): Promise<Map<string, number>> {
	const results = new Map<string, number>();
	const total = entries.length;
	let checked = 0;

	for (const entry of entries) {
		if (!entry.password) {
			checked++;
			onProgress?.(checked, total);
			continue;
		}

		try {
			const count = await checkPassword(entry.password);
			if (count > 0) {
				results.set(entry.id, count);
			}
		} catch (e) {
			console.error(`HIBP check failed for ${entry.id}:`, e);
		}

		checked++;
		onProgress?.(checked, total);

		// Rate limit: HIBP allows ~1 req/1.5s for free
		if (checked < total) {
			await new Promise(r => setTimeout(r, 200));
		}
	}

	return results;
}
