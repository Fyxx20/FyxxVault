<section id="security" class="relative py-32 px-6">
	<div class="max-w-5xl mx-auto">
		<div class="text-center mb-16">
			<span class="inline-block px-4 py-1.5 rounded-full bg-[var(--fv-success)]/10 text-[var(--fv-success)] text-xs font-bold uppercase tracking-wider mb-4">Sécurité</span>
			<h2 class="text-4xl sm:text-5xl font-extrabold text-white mb-4">Conçu pour la paranoïa.</h2>
			<p class="text-lg text-[var(--fv-mist)] max-w-xl mx-auto">Chaque décision d'architecture est prise pour que personne — même nous — ne puisse accéder à tes données.</p>
		</div>

		<div class="grid grid-cols-1 md:grid-cols-2 gap-8">
			<!-- Zero Knowledge -->
			<div class="fv-glass p-8 fv-glow-cyan">
				<div class="flex items-start gap-4 mb-4">
					<div class="w-10 h-10 rounded-xl bg-[var(--fv-cyan)]/15 flex items-center justify-center shrink-0">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-cyan)" stroke-width="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
					</div>
					<div>
						<h3 class="text-lg font-bold text-white">Zero-Knowledge</h3>
						<p class="text-sm text-[var(--fv-smoke)] mt-1">Ton mot de passe maître ne quitte jamais ton appareil. La clé de chiffrement est dérivée localement via PBKDF2 avec 210,000 rounds.</p>
					</div>
				</div>
				<div class="flex flex-wrap gap-2 mt-4">
					<span class="px-3 py-1 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs font-semibold">PBKDF2-SHA256</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs font-semibold">210K rounds</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-cyan)]/10 text-[var(--fv-cyan)] text-xs font-semibold">32-byte key</span>
				</div>
			</div>

			<!-- E2E Encryption -->
			<div class="fv-glass p-8 fv-glow-violet">
				<div class="flex items-start gap-4 mb-4">
					<div class="w-10 h-10 rounded-xl bg-[var(--fv-violet)]/15 flex items-center justify-center shrink-0">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-violet)" stroke-width="2"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>
					</div>
					<div>
						<h3 class="text-lg font-bold text-white">Chiffrement AES-256-GCM</h3>
						<p class="text-sm text-[var(--fv-smoke)] mt-1">Chaque entrée est chiffrée individuellement avec une clé AES-256. L'intégrité est vérifiée par HMAC-SHA256.</p>
					</div>
				</div>
				<div class="flex flex-wrap gap-2 mt-4">
					<span class="px-3 py-1 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet)] text-xs font-semibold">AES-256-GCM</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet)] text-xs font-semibold">HMAC-SHA256</span>
					<span class="px-3 py-1 rounded-full bg-[var(--fv-violet)]/10 text-[var(--fv-violet)] text-xs font-semibold">Nonce unique</span>
				</div>
			</div>

			<!-- Key Wrapping -->
			<div class="fv-glass p-8">
				<div class="flex items-start gap-4">
					<div class="w-10 h-10 rounded-xl bg-[var(--fv-gold)]/15 flex items-center justify-center shrink-0">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-gold)" stroke-width="2"><circle cx="12" cy="12" r="3"/><path d="M12 1v6m0 6v6m11-7h-6m-6 0H1m15.5-6.5l-4.2 4.2m-2.6 2.6L5.5 18.5m13-1l-4.2-4.2m-2.6-2.6L5.5 5.5"/></svg>
					</div>
					<div>
						<h3 class="text-lg font-bold text-white">Key Wrapping Cloud</h3>
						<p class="text-sm text-[var(--fv-smoke)] mt-1">La clé de chiffrement du coffre (VEK) est enveloppée avec ta clé maître (KEK) avant d'être stockée. Le serveur ne voit que des blobs chiffrés.</p>
					</div>
				</div>
			</div>

			<!-- Open Architecture -->
			<div class="fv-glass p-8">
				<div class="flex items-start gap-4">
					<div class="w-10 h-10 rounded-xl bg-[var(--fv-success)]/15 flex items-center justify-center shrink-0">
						<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="var(--fv-success)" stroke-width="2"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="10"/></svg>
					</div>
					<div>
						<h3 class="text-lg font-bold text-white">Auditable & Transparent</h3>
						<p class="text-sm text-[var(--fv-smoke)] mt-1">Architecture documentée, SQLite WAL mode, rotation automatique des clés, permissions fichier 0600, chiffrement AES-256-GCM.</p>
					</div>
				</div>
			</div>
		</div>
	</div>
</section>
