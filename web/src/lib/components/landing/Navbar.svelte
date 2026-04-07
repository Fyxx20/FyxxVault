<script lang="ts">
	let scrolled = $state(false);
	let mobileOpen = $state(false);

	function handleScroll() {
		scrolled = window.scrollY > 20;
	}

	function closeMobile() {
		mobileOpen = false;
	}

	const links = [
		{ href: '#features', label: 'Fonctionnalites' },
		{ href: '#security', label: 'Securite' },
		{ href: '#pricing', label: 'Prix' },
	];
</script>

<svelte:window onscroll={handleScroll} />

<nav
	class="fv-navbar"
	class:fv-navbar--scrolled={scrolled}
>
	<div class="fv-navbar__inner">
		<!-- Logo -->
		<a href="/" class="fv-navbar__logo" onclick={closeMobile}>
			<div class="fv-navbar__logo-icon">
				<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
					<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/>
					<path d="M7 11V7a5 5 0 0 1 10 0v4"/>
				</svg>
			</div>
			<span class="fv-navbar__logo-text">FyxxVault</span>
		</a>

		<!-- Desktop links -->
		<div class="fv-navbar__links">
			{#each links as link}
				<a href={link.href} class="fv-navbar__link">{link.label}</a>
			{/each}
		</div>

		<!-- CTA -->
		<div class="fv-navbar__actions">
			<a href="/login" class="fv-navbar__login">Connexion</a>
			<a href="/register" class="fv-navbar__cta">
				Commencer
				<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="M5 12h14M12 5l7 7-7 7"/></svg>
			</a>
		</div>

		<!-- Mobile hamburger -->
		<button
			class="fv-navbar__hamburger"
			onclick={() => mobileOpen = !mobileOpen}
			aria-label="Menu"
		>
			<span class="fv-navbar__hamburger-line" class:fv-navbar__hamburger-line--open={mobileOpen}></span>
			<span class="fv-navbar__hamburger-line" class:fv-navbar__hamburger-line--open={mobileOpen}></span>
			<span class="fv-navbar__hamburger-line" class:fv-navbar__hamburger-line--open={mobileOpen}></span>
		</button>
	</div>

	<!-- Mobile menu -->
	{#if mobileOpen}
		<div class="fv-navbar__mobile">
			{#each links as link}
				<a href={link.href} class="fv-navbar__mobile-link" onclick={closeMobile}>{link.label}</a>
			{/each}
			<div class="fv-navbar__mobile-actions">
				<a href="/login" class="fv-navbar__mobile-login" onclick={closeMobile}>Connexion</a>
				<a href="/register" class="fv-navbar__mobile-cta" onclick={closeMobile}>Commencer gratuitement</a>
			</div>
		</div>
	{/if}
</nav>

<style>
	.fv-navbar {
		position: fixed;
		top: 0;
		left: 0;
		right: 0;
		z-index: 100;
		transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
		border-bottom: 1px solid transparent;
	}

	.fv-navbar--scrolled {
		background: rgba(10, 16, 30, 0.75);
		backdrop-filter: blur(24px) saturate(180%);
		-webkit-backdrop-filter: blur(24px) saturate(180%);
		border-bottom-color: rgba(255, 255, 255, 0.06);
		box-shadow: 0 1px 40px rgba(0, 0, 0, 0.3);
	}

	.fv-navbar__inner {
		max-width: 1200px;
		margin: 0 auto;
		padding: 16px 24px;
		display: flex;
		align-items: center;
		justify-content: space-between;
	}

	.fv-navbar__logo {
		display: flex;
		align-items: center;
		gap: 10px;
		text-decoration: none;
	}

	.fv-navbar__logo-icon {
		width: 36px;
		height: 36px;
		border-radius: 10px;
		background: linear-gradient(135deg, var(--fv-cyan), var(--fv-violet));
		display: flex;
		align-items: center;
		justify-content: center;
		box-shadow: 0 4px 16px rgba(0, 212, 255, 0.2);
	}

	.fv-navbar__logo-text {
		font-size: 18px;
		font-weight: 800;
		color: white;
		letter-spacing: -0.02em;
	}

	.fv-navbar__links {
		display: none;
		align-items: center;
		gap: 32px;
	}

	@media (min-width: 768px) {
		.fv-navbar__links { display: flex; }
	}

	.fv-navbar__link {
		font-size: 13px;
		font-weight: 500;
		color: var(--fv-smoke);
		text-decoration: none;
		transition: color 0.2s;
		letter-spacing: 0.01em;
	}

	.fv-navbar__link:hover {
		color: white;
	}

	.fv-navbar__actions {
		display: none;
		align-items: center;
		gap: 8px;
	}

	@media (min-width: 768px) {
		.fv-navbar__actions { display: flex; }
	}

	.fv-navbar__login {
		font-size: 13px;
		font-weight: 600;
		color: var(--fv-mist);
		text-decoration: none;
		padding: 8px 16px;
		border-radius: 10px;
		transition: all 0.2s;
	}

	.fv-navbar__login:hover {
		color: white;
		background: rgba(255, 255, 255, 0.06);
	}

	.fv-navbar__cta {
		display: inline-flex;
		align-items: center;
		gap: 6px;
		font-size: 13px;
		font-weight: 700;
		color: #0a101e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		padding: 9px 20px;
		border-radius: 10px;
		text-decoration: none;
		transition: all 0.25s cubic-bezier(0.16, 1, 0.3, 1);
		box-shadow: 0 2px 12px rgba(255, 200, 55, 0.25);
	}

	.fv-navbar__cta:hover {
		transform: translateY(-1px);
		box-shadow: 0 4px 20px rgba(255, 200, 55, 0.4);
	}

	/* Hamburger */
	.fv-navbar__hamburger {
		display: flex;
		flex-direction: column;
		gap: 5px;
		background: none;
		border: none;
		padding: 8px;
		cursor: pointer;
	}

	@media (min-width: 768px) {
		.fv-navbar__hamburger { display: none; }
	}

	.fv-navbar__hamburger-line {
		width: 20px;
		height: 2px;
		background: var(--fv-mist);
		border-radius: 2px;
		transition: all 0.3s;
	}

	.fv-navbar__hamburger-line--open:first-child {
		transform: rotate(45deg) translate(5px, 5px);
	}

	.fv-navbar__hamburger-line--open:nth-child(2) {
		opacity: 0;
	}

	.fv-navbar__hamburger-line--open:last-child {
		transform: rotate(-45deg) translate(5px, -5px);
	}

	/* Mobile menu */
	.fv-navbar__mobile {
		padding: 16px 24px 24px;
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(10, 16, 30, 0.95);
		backdrop-filter: blur(24px);
		-webkit-backdrop-filter: blur(24px);
		animation: fv-slideDown 0.3s cubic-bezier(0.16, 1, 0.3, 1);
	}

	@keyframes fv-slideDown {
		from { opacity: 0; transform: translateY(-8px); }
		to { opacity: 1; transform: translateY(0); }
	}

	.fv-navbar__mobile-link {
		display: block;
		padding: 12px 0;
		font-size: 15px;
		font-weight: 500;
		color: var(--fv-mist);
		text-decoration: none;
		border-bottom: 1px solid rgba(255, 255, 255, 0.04);
	}

	.fv-navbar__mobile-actions {
		display: flex;
		flex-direction: column;
		gap: 8px;
		margin-top: 16px;
	}

	.fv-navbar__mobile-login {
		display: block;
		text-align: center;
		padding: 12px;
		font-size: 14px;
		font-weight: 600;
		color: var(--fv-mist);
		text-decoration: none;
		border: 1px solid rgba(255, 255, 255, 0.1);
		border-radius: 12px;
	}

	.fv-navbar__mobile-cta {
		display: block;
		text-align: center;
		padding: 12px;
		font-size: 14px;
		font-weight: 700;
		color: #0a101e;
		background: linear-gradient(135deg, var(--fv-gold), var(--fv-gold-light));
		border-radius: 12px;
		text-decoration: none;
	}
</style>
