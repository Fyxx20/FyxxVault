import SwiftUI

// MARK: - Support Chat Widget (floating overlay)

struct SupportChatOverlay: View {
    @ObservedObject var supportService: SupportService
    var userEmail: String

    @State private var isExpanded = false
    @State private var chatPhase: ChatPhase = .home // home, list, chat
    @State private var messageText = ""
    @State private var newSubject = ""
    @State private var showNewTicket = false

    enum ChatPhase { case home, list, chat }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.clear

            if isExpanded {
                chatPanel
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity)
                    ))
            }

            // Floating button
            floatingButton
        }
        .padding(.trailing, 16)
        .padding(.bottom, 88) // above tab bar
    }

    // MARK: - Floating Button

    private var floatingButton: some View {
        Button {
            fvHaptic(.medium)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isExpanded.toggle()
                if isExpanded && supportService.isAuthenticated {
                    Task { await supportService.fetchTickets() }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(FVGradient.cyanToViolet)
                    .frame(width: 54, height: 54)
                    .shadow(color: FVColor.cyan.opacity(0.4), radius: 12, y: 4)

                Image(systemName: isExpanded ? "xmark" : "message.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)

                if !isExpanded && supportService.unreadAdminMessages > 0 {
                    Circle()
                        .fill(FVColor.danger)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("\(supportService.unreadAdminMessages)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        )
                        .offset(x: 18, y: -18)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Panel

    private var chatPanel: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader

            Divider().background(FVColor.cardBorder)

            // Content
            Group {
                switch chatPhase {
                case .home: homeView
                case .list: ticketListView
                case .chat: chatView
                }
            }
        }
        .frame(width: 320, height: 460)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(FVColor.obsidian)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.2))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(FVColor.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 24, y: 12)
    }

    private var panelHeader: some View {
        HStack(spacing: 10) {
            if chatPhase != .home {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if chatPhase == .chat {
                            chatPhase = .list
                            supportService.stopPolling()
                        } else {
                            chatPhase = .home
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(FVColor.cyan)
                        .font(.system(size: 15, weight: .semibold))
                }
            }

            // Avatar
            ZStack {
                Circle()
                    .fill(FVGradient.cyanToViolet)
                    .frame(width: 32, height: 32)
                Text("FV")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Support FyxxVault")
                    .font(FVFont.title(13))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    Circle().fill(FVColor.success).frame(width: 6, height: 6)
                    Text("En ligne").font(FVFont.caption(10)).foregroundStyle(FVColor.success)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Home View

    private var homeView: some View {
        VStack(spacing: 14) {
            // Welcome
            VStack(spacing: 8) {
                Text("Bonjour 👋")
                    .font(FVFont.heading(18))
                    .foregroundStyle(.white)
                Text("Comment pouvons-nous vous aider ?")
                    .font(FVFont.body(13))
                    .foregroundStyle(FVColor.mist)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)

            // Quick topics
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    quickTopic("Synchronisation", icon: "icloud.fill")
                    quickTopic("Facturation", icon: "creditcard.fill")
                }
                HStack(spacing: 8) {
                    quickTopic("Import données", icon: "square.and.arrow.down.fill")
                    quickTopic("Sécurité", icon: "lock.shield.fill")
                }
            }
            .padding(.horizontal, 14)

            Spacer()

            // CTA buttons
            VStack(spacing: 8) {
                Button {
                    withAnimation { chatPhase = .list }
                    if supportService.isAuthenticated {
                        Task { await supportService.fetchTickets() }
                    }
                } label: {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                        Text("Mes conversations")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(FVFont.body(13))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    showNewTicket = true
                } label: {
                    HStack {
                        Image(systemName: "plus.message.fill")
                        Text("Nouveau message")
                        Spacer()
                    }
                    .font(FVFont.body(13))
                    .foregroundStyle(FVColor.abyss)
                    .padding(12)
                    .background(FVGradient.cyanToViolet)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
        .sheet(isPresented: $showNewTicket) { newTicketSheet }
    }

    private func quickTopic(_ title: String, icon: String) -> some View {
        Button {
            newSubject = title
            showNewTicket = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(FVColor.cyan)
                    .frame(width: 16)
                Text(title)
                    .font(FVFont.caption(11))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ticket List

    private var ticketListView: some View {
        ScrollView {
            VStack(spacing: 8) {
                if supportService.tickets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray").font(.system(size: 32)).foregroundStyle(FVColor.smoke)
                        Text("Aucune conversation").font(FVFont.body(14)).foregroundStyle(FVColor.mist)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(supportService.tickets) { ticket in
                        ticketRow(ticket)
                    }
                }
            }
            .padding(14)
        }
        .overlay(alignment: .bottom) {
            Button {
                showNewTicket = true
            } label: {
                Label("Nouveau message", systemImage: "plus")
                    .font(FVFont.body(13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(FVGradient.cyanToViolet)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)
            .background(
                LinearGradient(colors: [FVColor.obsidian.opacity(0), FVColor.obsidian], startPoint: .top, endPoint: .bottom)
                    .frame(height: 60)
            )
        }
        .sheet(isPresented: $showNewTicket) { newTicketSheet }
    }

    private func ticketRow(_ ticket: SupportTicket) -> some View {
        Button {
            supportService.currentTicket = ticket
            Task {
                await supportService.fetchMessages(ticketId: ticket.id)
                supportService.startPolling(ticketId: ticket.id)
            }
            withAnimation { chatPhase = .chat }
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor(ticket.status))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ticket.subject)
                        .font(FVFont.title(13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(statusLabel(ticket.status))
                        .font(FVFont.caption(11))
                        .foregroundStyle(statusColor(ticket.status))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(FVColor.smoke)
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            if let ticket = supportService.currentTicket {
                // Status badge
                HStack {
                    Text(ticket.subject)
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist)
                        .lineLimit(1)
                    Spacer()
                    Text(statusLabel(ticket.status))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(statusColor(ticket.status))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor(ticket.status).opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(supportService.messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: supportService.messages.count) { _, _ in
                        if let last = supportService.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                // Resolved banner
                if ticket.status == "resolved" || ticket.status == "closed" {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(FVColor.success)
                        Text("Ce ticket a été résolu").font(FVFont.caption(12)).foregroundStyle(FVColor.success)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(FVColor.success.opacity(0.1))
                } else {
                    // Input
                    HStack(spacing: 8) {
                        TextField("Votre message...", text: $messageText, axis: .vertical)
                            .font(FVFont.body(13))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .padding(10)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            messageText = ""
                            Task {
                                await supportService.sendMessage(
                                    ticketId: ticket.id,
                                    content: text,
                                    userEmail: userEmail
                                )
                            }
                        } label: {
                            Image(systemName: supportService.isSending ? "ellipsis" : "arrow.up.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(messageText.isEmpty ? FVColor.smoke : FVColor.cyan)
                        }
                        .buttonStyle(.plain)
                        .disabled(messageText.isEmpty || supportService.isSending)
                    }
                    .padding(10)
                    .background(FVColor.obsidian)
                }
            }
        }
    }

    private func messageBubble(_ msg: SupportMessage) -> some View {
        let isUser = msg.senderType == "user"
        let isAI = msg.senderType == "ai"

        return HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if !isUser {
                    Text(isAI ? "FyxxBot" : "Support")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isAI ? FVColor.violet : FVColor.gold)
                }

                Text(msg.content)
                    .font(FVFont.body(13))
                    .foregroundStyle(isUser ? .white : FVColor.silver)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        isUser
                            ? AnyView(FVGradient.cyanToViolet)
                            : AnyView(Color.white.opacity(0.08))
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14,
                            style: .continuous
                        )
                    )
            }

            if !isUser { Spacer(minLength: 40) }
        }
    }

    // MARK: - New Ticket Sheet

    private var newTicketSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "message.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(FVColor.cyan)

                Text("Nouveau message")
                    .font(FVFont.heading(18))
                    .foregroundStyle(.white)

                FVTextField(title: "Sujet", text: $newSubject)

                FVTextField(title: "Votre message", text: $messageText)

                FVButton(title: supportService.isSending ? "Envoi..." : "Envoyer") {
                    let subject = newSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                    let message = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !subject.isEmpty, !message.isEmpty else { return }
                    Task {
                        let tid = await supportService.createTicketFromArray(
                            subject: subject,
                            firstMessage: message,
                            userEmail: userEmail
                        )
                        if tid != nil {
                            newSubject = ""
                            messageText = ""
                            showNewTicket = false
                            if let ticket = supportService.currentTicket {
                                await supportService.fetchMessages(ticketId: ticket.id)
                                supportService.startPolling(ticketId: ticket.id)
                            }
                            withAnimation { chatPhase = .chat }
                        }
                    }
                }
            }
            .padding(24)
            .background(FVAnimatedBackground())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { showNewTicket = false }
                        .foregroundStyle(FVColor.cyan)
                }
            }
        }
        .presentationDetents([.height(400)])
    }

    // MARK: - Helpers

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "open": return FVColor.cyan
        case "waiting": return FVColor.warning
        case "resolved": return FVColor.success
        case "closed": return FVColor.smoke
        default: return FVColor.mist
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "open": return "Ouvert"
        case "waiting": return "En attente"
        case "resolved": return "Résolu"
        case "closed": return "Fermé"
        default: return status
        }
    }
}
