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
            .navigationTitle(String(localized: "masked.email.nav.title"))
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "vault.action.close")) { dismiss() }.foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
            .sheet(isPresented: $showCreateSheet) { createAliasSheet }
            .confirmationDialog(String(localized: "masked.email.delete.alias.title"), isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ), titleVisibility: .visible) {
                Button(String(localized: "vault.action.delete"), role: .destructive) {
                    if let alias = showDeleteConfirm {
                        Task { await maskedEmailService.deleteAlias(id: alias.id) }
                    }
                    showDeleteConfirm = nil
                }
                Button(String(localized: "vault.action.cancel"), role: .cancel) { showDeleteConfirm = nil }
            } message: {
                Text(String(localized: "masked.email.delete.alias.message"))
            }
        }
    }

    // MARK: - Setup View

    private var setupView: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(FVColor.cyan)

            Text(String(localized: "masked.email.title"))
                .font(FVFont.heading(22))
                .foregroundStyle(.white)

            Text(String(localized: "masked.email.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "masked.email.setup.title")).font(FVFont.title(16)).foregroundStyle(.white)
                Text(String(localized: "masked.email.setup.step1"))
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
                Text(String(localized: "masked.email.setup.step2"))
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
                Text(String(localized: "masked.email.setup.step3"))
                    .font(.system(size: 13, design: .rounded)).foregroundStyle(FVColor.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FVTextField(title: String(localized: "masked.email.api.key"), text: $apiToken, secure: true)

            FVButton(title: String(localized: "masked.email.connect")) {
                guard !apiToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                maskedEmailService.configure(apiToken: apiToken.trimmingCharacters(in: .whitespacesAndNewlines))
                apiToken = ""
                Task { await maskedEmailService.fetchAliases() }
            }

            HStack(spacing: 8) {
                FVTag(text: String(localized: "masked.email.tag.free"), color: FVColor.success)
                FVTag(text: String(localized: "masked.email.tag.included"), color: FVColor.cyan)
            }
        }
        .fvGlass()
    }

    // MARK: - Configured View

    private var configuredView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "masked.email.title"))
                        .font(FVFont.heading(22))
                        .foregroundStyle(.white)
                    Text(String(format: NSLocalizedString("masked.email.active.count %lld", comment: ""), maskedEmailService.aliases.count))
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
                FVEmptyState(icon: "envelope.badge.shield.half.filled", title: String(localized: "masked.email.empty.title"), subtitle: String(localized: "masked.email.empty.subtitle"))
            }

            ForEach(maskedEmailService.aliases) { alias in
                aliasCard(alias)
            }

            Button(String(localized: "masked.email.disconnect")) {
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

                Text(alias.isActive ? String(localized: "masked.email.status.active") : String(localized: "masked.email.status.disabled"))
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
                Text(String(localized: "masked.email.new.alias"))
                    .font(FVFont.heading(20))
                    .foregroundStyle(.white)

                FVTextField(title: String(localized: "masked.email.alias.description"), text: $newAliasDescription)

                FVButton(title: maskedEmailService.isLoading ? String(localized: "masked.email.creating") : String(localized: "masked.email.create.alias")) {
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
                    Button(String(localized: "vault.action.cancel")) { showCreateSheet = false }.foregroundStyle(FVColor.cyan)
                }
            }
        }
        .presentationDetents([.height(250)])
    }
}
