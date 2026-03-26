<script lang="ts">
	import '../app.css';
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { fade } from 'svelte/transition';
	let { children } = $props();

	let showLoader = $state(false);
	let loaderDone = $state(false);
	let cursorX = $state(0);
	let cursorY = $state(0);
	let ringX = $state(0);
	let ringY = $state(0);
	let cursorVisible = $state(false);
	let cursorHover = $state(false);
	let cursorCta = $state(false);
	let isDesktop = $state(false);

	onMount(() => {
		if ('serviceWorker' in navigator) {
			navigator.serviceWorker.register('/sw.js').catch(() => {});
		}

		// Page loader - only on first visit
		if (!sessionStorage.getItem('fv-loaded')) {
			showLoader = true;
			sessionStorage.setItem('fv-loaded', '1');
			setTimeout(() => {
				loaderDone = true;
				setTimeout(() => showLoader = false, 500);
			}, 1500);
		}

		// Custom cursor - desktop only
		const isTouchDevice = 'ontouchstart' in window || navigator.maxTouchPoints > 0;
		if (!isTouchDevice && window.matchMedia('(hover: hover)').matches) {
			isDesktop = true;
			let rafId: number;

			const onMouseMove = (e: MouseEvent) => {
				cursorX = e.clientX;
				cursorY = e.clientY;
				if (!cursorVisible) cursorVisible = true;
			};

			// Smooth ring follow
			const followRing = () => {
				ringX += (cursorX - ringX) * 0.15;
				ringY += (cursorY - ringY) * 0.15;
				rafId = requestAnimationFrame(followRing);
			};

			document.addEventListener('mousemove', onMouseMove);
			document.addEventListener('mouseleave', () => cursorVisible = false);
			document.addEventListener('mouseenter', () => cursorVisible = true);
			rafId = requestAnimationFrame(followRing);

			// Hover detection for interactive elements
			const onMouseOver = (e: MouseEvent) => {
				const target = e.target as HTMLElement;
				const interactive = target.closest('a, button, input, textarea, select, [role="button"], .magnetic-btn');
				const cta = target.closest('.fv-btn-gold, .fv-btn-primary, .hero-cta-primary, .pricing-card-cta--gold');
				cursorCta = !!cta;
				cursorHover = !!interactive && !cta;
			};
			document.addEventListener('mouseover', onMouseOver);

			return () => {
				document.removeEventListener('mousemove', onMouseMove);
				document.removeEventListener('mouseover', onMouseOver);
				cancelAnimationFrame(rafId);
			};
		}
	});
</script>

<!-- Page Loader -->
{#if showLoader}
	<div class="page-loader" class:loader-done={loaderDone}>
		<svg class="page-loader-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
			<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
			<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
			<circle cx="12" cy="16" r="1"/>
		</svg>
		<div class="page-loader-bar-track">
			<div class="page-loader-bar"></div>
		</div>
	</div>
{/if}

<!-- Custom cursor removed -->

<!-- Page content with route transition -->
{#key $page.url.pathname}
	<div class="page-transition-wrapper" in:fade={{ duration: 250, delay: 100 }} out:fade={{ duration: 150 }}>
		{@render children()}
	</div>
{/key}
