<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { getAuthState, initAuth } from '$lib/stores/auth.svelte';

	let checking = $state(true);

	onMount(async () => {
		await initAuth();
		const auth = getAuthState();

		// If already unlocked, go straight to vault
		if (auth.isUnlocked) {
			goto('/vault', { replaceState: true });
			return;
		}

		// If authenticated (has session), go to unlock
		if (auth.isAuthenticated) {
			goto('/vault/unlock', { replaceState: true });
			return;
		}

		// Check if any user exists
		try {
			const res = await fetch('/api/status');
			const data = await res.json();

			if (data.hasUser) {
				// User exists but no session — go to unlock
				goto('/vault/unlock', { replaceState: true });
			} else {
				// No user — first time setup
				goto('/setup', { replaceState: true });
			}
		} catch {
			// Fallback to setup
			goto('/setup', { replaceState: true });
		}
	});
</script>

<svelte:head>
	<title>FyxxVault</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)] flex items-center justify-center">
	<div class="text-center">
		<div class="w-14 h-14 rounded-2xl bg-gradient-to-br from-[var(--fv-cyan)] to-[var(--fv-violet)] flex items-center justify-center mx-auto mb-4" style="box-shadow: 0 0 30px rgba(0, 212, 255, 0.25);">
			<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2">
				<rect x="3" y="11" width="18" height="11" rx="2"/>
				<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
			</svg>
		</div>
		<div class="w-8 h-8 border-2 border-[var(--fv-cyan)]/30 border-t-[var(--fv-cyan)] rounded-full animate-spin mx-auto"></div>
	</div>
</div>
