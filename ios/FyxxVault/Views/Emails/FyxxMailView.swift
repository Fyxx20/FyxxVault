import SwiftUI

// MARK: - FyxxMail Main View

struct FyxxMailView: View {
    @ObservedObject var mailService: FyxxMailService
    @ObservedObject var subscriptionService: SubscriptionService

    @State private var selectedTab = 0 // 0 = Inbox, 1 = Aliases
    @State private var selectedFolder = "inbox"
    @State private var selectedAlias: FyxxEmailAlias?
    @State private var showCreateAlias = false
    @State private var newAliasLabel = ""
    @State private var selectedEmail: FyxxEmail?

    var body: some View {
        VStack(spacing: 0) {
            // Custom header
            HStack {
                Text("Emails")
                    .font(FVFont.heading(20))
                    .foregroundStyle(.white)
                Spacer()
                if selectedTab == 1 {
                    Button {
                        if subscriptionService.isProUser || mailService.aliases.filter(\.isActive).count < 2 {
                            showCreateAlias = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(FVColor.cyan)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Segmented picker
            Picker("", selection: $selectedTab) {
                Text("Boîte de réception").tag(0)
                Text("Alias").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if selectedTab == 0 {
                inboxView
            } else {
                aliasesView
            }
        }
        .sheet(isPresented: $showCreateAlias) { createAliasSheet }
        .sheet(item: $selectedEmail) { email in
            EmailDetailView(email: email, mailService: mailService)
        }
        .task {
            if mailService.isAuthenticated {
                async let a: () = mailService.fetchAliases()
                async let b: () = mailService.fetchEmails(folder: selectedFolder)
                _ = await (a, b)
            }
        }
    }

    // MARK: - Inbox

    private var inboxView: some View {
        VStack(spacing: 0) {
            // Folder picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    folderChip("inbox", icon: "tray.fill", label: "Reçus")
                    folderChip("archive", icon: "archivebox.fill", label: "Archive")
                    folderChip("trash", icon: "trash.fill", label: "Corbeille")
                    folderChip("spam", icon: "xmark.octagon.fill", label: "Spam")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            if !mailService.isAuthenticated {
                notConnectedView
            } else if mailService.isLoading {
                Spacer()
                ProgressView().tint(FVColor.cyan)
                Spacer()
            } else if mailService.emails.isEmpty {
                Spacer()
                FVEmptyState(
                    icon: "tray",
                    title: "Aucun email",
                    subtitle: "Les emails reçus sur vos alias apparaîtront ici"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(mailService.emails) { email in
                            emailRow(email)
                                .onTapGesture {
                                    selectedEmail = email
                                    if !email.isRead {
                                        Task { await mailService.markAsRead(id: email.id) }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 120)
                }
            }

            if let error = mailService.error {
                Text(error)
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.danger)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .onChange(of: selectedFolder) { _, folder in
            mailService.updatePollingFolder(folder)
            Task { await mailService.fetchEmails(folder: folder) }
        }
    }

    private func folderChip(_ folder: String, icon: String, label: String) -> some View {
        Button {
            selectedFolder = folder
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(FVFont.caption(12))
            }
            .foregroundStyle(selectedFolder == folder ? FVColor.abyss : FVColor.silver)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(selectedFolder == folder ? FVColor.cyan : Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func emailRow(_ email: FyxxEmail) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(email.isRead ? Color.clear : FVColor.cyan)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(email.fromName.isEmpty ? email.fromAddress : email.fromName)
                        .font(FVFont.title(14))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(formatDate(email.receivedAt))
                        .font(FVFont.caption(11))
                        .foregroundStyle(FVColor.smoke)
                }
                Text(email.subject)
                    .font(FVFont.body(13))
                    .foregroundStyle(email.isRead ? FVColor.smoke : FVColor.silver)
                    .lineLimit(1)
                if !email.bodyText.isEmpty {
                    Text(email.bodyText)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(FVColor.ash)
                        .lineLimit(1)
                }
            }

            if email.isStarred {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(FVColor.gold)
            }
        }
        .padding(14)
        .background(email.isRead ? FVColor.cardBg : FVColor.cyan.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(email.isRead ? FVColor.cardBorder : FVColor.cyan.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button {
                Task { await mailService.toggleStarred(id: email.id) }
            } label: {
                Label(email.isStarred ? "Retirer favori" : "Favori", systemImage: email.isStarred ? "star.slash" : "star")
            }
            Button {
                Task { await mailService.moveToFolder(id: email.id, folder: "archive") }
            } label: {
                Label("Archiver", systemImage: "archivebox")
            }
            Button(role: .destructive) {
                Task { await mailService.moveToFolder(id: email.id, folder: "trash") }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Aliases

    private var aliasesView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !subscriptionService.isProUser {
                    proLockBanner
                }

                if !mailService.isAuthenticated {
                    notConnectedView
                } else if mailService.aliases.isEmpty && !mailService.isLoading {
                    FVEmptyState(
                        icon: "envelope.badge.shield.half.filled",
                        title: "Aucun alias",
                        subtitle: "Créez des alias @fyxxmail.com pour protéger votre vraie adresse"
                    )
                    .padding(.top, 20)
                } else {
                    ForEach(mailService.aliases) { alias in
                        aliasCard(alias)
                    }
                }

                if mailService.isLoading {
                    ProgressView().tint(FVColor.cyan)
                }

                if let error = mailService.error {
                    Text(error)
                        .font(FVFont.caption(11))
                        .foregroundStyle(FVColor.danger)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
            .padding(.bottom, 120)
        }
    }

    private var proLockBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .foregroundStyle(FVColor.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Fonctionnalité Pro")
                    .font(FVFont.title(14))
                    .foregroundStyle(.white)
                Text("2 alias actifs inclus avec FyxxVault Pro")
                    .font(FVFont.caption(12))
                    .foregroundStyle(FVColor.mist)
            }
            Spacer()
        }
        .padding(14)
        .background(FVColor.gold.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(FVColor.gold.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func aliasCard(_ alias: FyxxEmailAlias) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(alias.isActive ? FVColor.cyan : FVColor.smoke)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alias.address)
                        .font(FVFont.mono(13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !alias.label.isEmpty {
                        Text(alias.label)
                            .font(FVFont.caption(11))
                            .foregroundStyle(FVColor.mist)
                    }
                }
                Spacer()
                Button {
                    ClipboardService.copy(alias.address)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundStyle(FVColor.cyan)
                }
            }

            HStack {
                Toggle("", isOn: Binding(
                    get: { alias.isActive },
                    set: { v in Task { await mailService.toggleAlias(id: alias.id, active: v) } }
                ))
                .labelsHidden()
                .scaleEffect(0.85)
                Text(alias.isActive ? "Actif" : "Désactivé")
                    .font(FVFont.caption(11))
                    .foregroundStyle(alias.isActive ? FVColor.success : FVColor.smoke)
                Spacer()
                Button {
                    Task { await mailService.fetchEmails(aliasId: alias.id) }
                    selectedTab = 0
                } label: {
                    HStack(spacing: 4) {
                        Text("\(alias.emailsReceived) reçus")
                            .font(FVFont.caption(11))
                            .foregroundStyle(FVColor.mist)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(FVColor.smoke)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .fvGlass(cornerRadius: 16, padding: 14)
        .contextMenu {
            Button(role: .destructive) {
                Task { await mailService.deleteAlias(id: alias.id) }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    // MARK: - Not Connected

    private var notConnectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.slash")
                .font(.system(size: 40))
                .foregroundStyle(FVColor.smoke)
            Text("Connexion cloud requise")
                .font(FVFont.heading(16))
                .foregroundStyle(.white)
            Text("Connectez-vous au cloud dans les Réglages pour accéder à vos emails")
                .font(FVFont.caption(13))
                .foregroundStyle(FVColor.mist)
                .multilineTextAlignment(.center)
        }
        .padding(30)
    }

    // MARK: - Create Alias Sheet

    private var createAliasSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(FVColor.cyan)

                Text("Nouvel alias email")
                    .font(FVFont.heading(20))
                    .foregroundStyle(.white)

                Text("Votre alias @fyxxmail.com sera généré automatiquement")
                    .font(FVFont.caption(13))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)

                FVTextField(title: "Label (ex: Shopping, Newsletters...)", text: $newAliasLabel)

                FVButton(title: mailService.isLoading ? "Création..." : "Créer l'alias") {
                    let label = newAliasLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !label.isEmpty else { return }
                    Task {
                        let success = await mailService.createAlias(label: label)
                        if success {
                            newAliasLabel = ""
                            showCreateAlias = false
                        }
                    }
                }

                if let error = mailService.error {
                    Text(error)
                        .font(FVFont.caption(11))
                        .foregroundStyle(FVColor.danger)
                }

                if !subscriptionService.isProUser {
                    Text("Limite : 2 alias actifs (Pro)")
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.gold)
                }
            }
            .padding(24)
            .background(FVAnimatedBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showCreateAlias = false }
                        .foregroundStyle(FVColor.cyan)
                }
            }
        }
        .presentationDetents([.height(420)])
    }

    // MARK: - Helpers

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.doesRelativeDateFormatting = true
            df.dateStyle = .short
            df.timeStyle = .short
            return df.string(from: date)
        }
        return iso
    }
}

// MARK: - Email Detail View

struct EmailDetailView: View {
    var email: FyxxEmail
    @ObservedObject var mailService: FyxxMailService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(email.subject)
                            .font(FVFont.heading(18))
                            .foregroundStyle(.white)

                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundStyle(FVColor.cyan)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(email.fromName.isEmpty ? email.fromAddress : email.fromName)
                                    .font(FVFont.title(13))
                                    .foregroundStyle(.white)
                                if !email.fromName.isEmpty {
                                    Text(email.fromAddress)
                                        .font(FVFont.caption(11))
                                        .foregroundStyle(FVColor.mist)
                                }
                            }
                            Spacer()
                        }
                    }
                    .fvGlass()

                    // Body
                    Text(email.bodyText.isEmpty ? "(Contenu vide)" : email.bodyText)
                        .font(FVFont.body(14))
                        .foregroundStyle(FVColor.silver)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fvGlass()
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .background(FVAnimatedBackground())
            .navigationTitle("Email")
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(FVColor.cyan)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await mailService.toggleStarred(id: email.id) }
                    } label: {
                        Image(systemName: email.isStarred ? "star.fill" : "star")
                            .foregroundStyle(FVColor.gold)
                    }
                }
            }
        }
    }
}
