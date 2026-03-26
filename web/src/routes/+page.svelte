<script lang="ts">
	import Hero from '$lib/components/landing/Hero.svelte';
	import Features from '$lib/components/landing/Features.svelte';
	import Security from '$lib/components/landing/Security.svelte';
	import Pricing from '$lib/components/landing/Pricing.svelte';
	import Footer from '$lib/components/landing/Footer.svelte';
	import Navbar from '$lib/components/landing/Navbar.svelte';
</script>

<svelte:head>
	<title>FyxxVault — Ton coffre-fort numérique</title>
</svelte:head>

<div class="min-h-screen bg-[var(--fv-abyss)]">
	<Navbar />
	<Hero />
	<Features />
	<Security />
	<Pricing />
	<Footer />
</div>
