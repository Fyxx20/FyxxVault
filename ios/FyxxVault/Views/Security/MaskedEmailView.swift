import SwiftUI

struct MaskedEmailView: View {
    @ObservedObject var maskedEmailService: MaskedEmailService
    @Environment(\.dismiss) private var dismiss

    @State private var apiToken = ""
    @State private var newAliasDescription = ""
    @State private var showCreateSheet = false
    @State private var showDeleteConfirm: MaskedEmail?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !maskedEmailService.isConfigured {
                        setupView
                    } else {
                        configuredView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle("Emails Masqués")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
            .sheet(isPresented: $showCreateSheet) { createAliasSheet }
            .confirmationDialog("Supprimer cet alias ?", isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ), titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let alias = showDeleteConfirm {
                        Task { await maskedEmailService.deleteAlias(id: alias.id) }
                    }
                    showDeleteConfirm = nil
                }
                Button("Annuler", role: .cancel) { showDeleteConfirm = nil }
            } message: {
                Text("L'alias ne recevra plus d'emails.")
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(FVColor.cyan)

            Text("Emails Masqués")
                .font(FVFont.heading(22))
                .foregroundStyle(.white)

            Text("Génère des adresses email uniques pour chaque service. Si une fuite survient, seul l'alias est compromis — pas ton vrai email.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("Configuration").font(FVFont.title(16)).foregroundStyle(.white)
                Text("1. Crée un compte gratuit sur addy.io")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
                Text("2. Va dans Settings → API Keys → Generate")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
                Text("3. Colle ta clé API ci-dessous")
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FVTextField(title: "Clé API addy.io", text: $apiToken, secure: true)

            FVButton(title: "Connecter") {
                guard !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                maskedEmailService.configure(apiToken: apiToken.trimmingCharacters(in: .whitespacesAndNewlines))
                apiToken = ""
                Task { await maskedEmailService.fetchAliases() }
            }

            HStack(spacing: 8) {
                FVTag(text: "Gratuit", color: FVColor.success)
                FVTag(text: "20 alias inclus", color: FVColor.cyan)
            }
        }
        .fvGlass()
    }

    // MARK: - Configured View

    private var configuredView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Emails Masqués")
                        .font(FVFont.heading(22))
                        .foregroundStyle(.white)
                    Text("\(maskedEmailService.aliases.count) alias actif(s)")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(FVColor.mist)
                }
                Spacer()
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(FVColor.cyan)
                }
            }
            .fvGlass()

            if let error = maskedEmailService.error {
                Text(error)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fvGlass()
            }

            if maskedEmailService.isLoading {
                ProgressView()
                    .tint(FVColor.cyan)
            }

            if maskedEmailService.aliases.isEmpty && !maskedEmailService.isLoading {
                FVEmptyState(icon: "envelope.badge.shield.half.filled", title: "Aucun alias", subtitle: "Crée ton premier email masqué")
            }

            ForEach(maskedEmailService.aliases) { alias in
                aliasCard(alias)
            }

            Button("Déconnecter addy.io") {
                maskedEmailService.disconnect()
            }
            .buttonStyle(FVSettingsButton(tint: .red.opacity(0.8)))
        }
    }

    private func aliasCard(_ alias: MaskedEmail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(alias.isActive ? FVColor.cyan : FVColor.mist.opacity(0.5))
                Text(alias.email)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Button {
                    ClipboardService.copy(alias.email)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(FVColor.silver)
                }
            }

            if !alias.description.isEmpty {
                Text(alias.description)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(FVColor.mist.opacity(0.7))
            }

            HStack {
                Toggle("", isOn: Binding(
                    get: { alias.isActive },
                    set: { newValue in
                        Task { await maskedEmailService.toggleAlias(id: alias.id, active: newValue) }
                    }
                ))
                .labelsHidden()
                .scaleEffect(0.8)

                Text(alias.isActive ? "Actif" : "Désactivé")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(alias.isActive ? FVColor.success : FVColor.mist.opacity(0.5))

                Spacer()

                Button {
                    showDeleteConfirm = alias
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(FVColor.danger.opacity(0.7))
                }
            }
        }
        .fvGlass()
    }

    // MARK: - Create Sheet

    private var createAliasSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Nouvel alias")
                    .font(FVFont.heading(20))
                    .foregroundStyle(.white)

                FVTextField(title: "Description (ex: Netflix, Amazon...)", text: $newAliasDescription)

                FVButton(title: maskedEmailService.isLoading ? "Création..." : "Créer l'alias") {
                    let desc = newAliasDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !desc.isEmpty else { return }
                    Task {
                        if let _ = await maskedEmailService.createAlias(description: desc) {
                            newAliasDescription = ""
                            showCreateSheet = false
                        }
                    }
                }
            }
            .padding(20)
            .background(FVAnimatedBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showCreateSheet = false }.foregroundStyle(FVColor.cyan)
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}
