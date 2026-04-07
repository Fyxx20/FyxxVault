const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const MAX_ENTRIES = 10000;
let lastCleanup = Date.now();
const CLEANUP_INTERVAL = 60000;

function cleanup() {
	const now = Date.now();
	if (now - lastCleanup < CLEANUP_INTERVAL) return;
	lastCleanup = now;

	for (const [key, entry] of rateLimitMap) {
		if (now > entry.resetAt) {
			rateLimitMap.delete(key);
		}
	}
}

export function checkRateLimit(key: string, maxRequests: number = 60, windowMs: number = 60000): boolean {
	cleanup();

	// Prevent memory exhaustion from too many unique keys
	if (rateLimitMap.size >= MAX_ENTRIES && !rateLimitMap.has(key)) {
		return false;
	}

	const now = Date.now();
	const entry = rateLimitMap.get(key);

	if (!entry || now > entry.resetAt) {
		rateLimitMap.set(key, { count: 1, resetAt: now + windowMs });
		return true;
	}

	if (entry.count >= maxRequests) {
		return false;
	}

	entry.count++;
	return true;
}
