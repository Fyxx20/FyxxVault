// Self-destructing service worker.
// We intentionally disable runtime caching because it can serve stale HTML/CSS/JS.
self.addEventListener('install', () => {
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		(async () => {
			const keys = await caches.keys();
			await Promise.all(keys.filter((key) => key.startsWith('fyxxvault-')).map((key) => caches.delete(key)));
			await self.registration.unregister();
			await self.clients.claim();
		})()
	);
});
