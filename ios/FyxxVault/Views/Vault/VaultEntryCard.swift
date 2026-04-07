import SwiftUI

// MARK: - VaultEntryCard

struct VaultEntryCard: View {
    let entry: VaultEntry
    var onDelete: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onCopyPassword: (() -> Void)? = nil
    var onCopyMFA: (() -> Void)? = nil
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var onTapCard: (() -> Void)? = nil
    var compact: Bool = false
    var accentMode: Int = 0
    var breachCount: Int? = nil

    @State private var isExpanded = false
    @State private var revealPassword = false
    @State private var didCopyPassword = false
    @State private var showMFACode = true
    @State private var isPressed = false
    @State private var showCopyOverlay = false
    @State private var swipeOffset: CGFloat = 0
    @State private var favBounce = false
    @State private var didCopyUsername = false
    @State private var faviconImage: UIImage? = nil

    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    private var strengthColor: Color {
        switch PasswordToolkit.strength(for: entry.password) {
        case .faible:    return FVColor.danger
        case .moyen:     return FVColor.warning
        case .fort:      return FVColor.success
        case .excellent: return FVColor.cyan
        }
    }

    private var strengthFraction: CGFloat {
        switch PasswordToolkit.strength(for: entry.password) {
        case .faible:    return 0.25
        case .moyen:     return 0.50
        case .fort:      return 0.75
        case .excellent: return 1.00
        }
    }

    var body: some View {
        ZStack {
            swipeReveal
            mainCard
                .offset(x: swipeOffset)
                .gesture(swipeGesture)
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
        .contextMenu { menuItems }
        .onAppear {
            revealPassword = !hidePasswordsByDefault
            showMFACode = !hideMFACodeByDefault
        }
    }

    private func handleTap() {
        if selectionMode {
            onTapCard?()
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                isExpanded.toggle()
            }
            fvHaptic(.light)
        }
    }
}

// MARK: - Main Card

private extension VaultEntryCard {

    var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            collapsedRow
            expandedSection
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(cardBorder)
        .overlay(selectionOverlay)
        .overlay(alignment: .topTrailing) { selectionBadge }
        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }

    var cardBg: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.04))
    }

    var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
    }
}

// MARK: - Collapsed Row

private extension VaultEntryCard {

    var collapsedRow: some View {
        HStack(spacing: 10) {
            faviconBox

            titleArea
                .layoutPriority(1)

            Spacer(minLength: 2)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    strengthDot
                    chevronIcon
                }
                timeLabel
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    var faviconBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(entry.category.iconColor.opacity(0.12))
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            faviconContent
        }
        .frame(width: 44, height: 44)
        .task(id: entry.website) {
            guard !entry.website.isEmpty else { return }
            faviconImage = await FaviconCache.shared.loadFavicon(for: entry.website)
        }
    }

    @ViewBuilder
    var faviconContent: some View {
        if let img = faviconImage {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if entry.category == .login {
            Text(String(entry.title.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(entry.category.iconColor)
        } else {
            Image(systemName: entry.category.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(entry.category.iconColor.opacity(0.7))
        }
    }

    var titleArea: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleRow
            subtitleText
        }
    }

    var titleRow: some View {
        HStack(spacing: 6) {
            Text(entry.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            if entry.mfaEnabled { mfaTag }
            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(FVColor.gold)
            }
            if let bc = breachCount, bc > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(FVColor.danger)
            }
        }
    }

    var mfaTag: some View {
        Text("2FA")
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(FVColor.cyan)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(FVColor.cyan.opacity(0.10))
            .clipShape(Capsule())
    }

    @ViewBuilder
    var subtitleText: some View {
        let sub = !entry.username.isEmpty ? entry.username : entry.website
        if !sub.isEmpty {
            Text(sub)
                .font(.system(size: 13))
                .foregroundStyle(FVColor.smoke)
                .lineLimit(1)
        }
    }

    var strengthDot: some View {
        Circle()
            .fill(strengthColor)
            .frame(width: 8, height: 8)
    }

    var timeLabel: some View {
        Text(entry.lastModifiedAt.formatted(.relative(presentation: .named)))
            .font(.system(size: 11))
            .foregroundStyle(FVColor.smoke)
            .lineLimit(1)
    }

    var chevronIcon: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(FVColor.ash)
    }
}

// MARK: - Expanded Section

private extension VaultEntryCard {

    @ViewBuilder
    var expandedSection: some View {
        if isExpanded {
            VStack(alignment: .leading, spacing: 0) {
                dividerLine
                expandedContent
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            passwordSection
            websiteSection
            mfaSection
            notesSection
            strengthBar
            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }
}

// MARK: - Password Section

private extension VaultEntryCard {

    var passwordSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("MOT DE PASSE")
            HStack(spacing: 10) {
                Text(revealPassword
                     ? entry.password
                     : String(repeating: "•", count: min(max(entry.password.count, 8), 20)))
                    .font(revealPassword
                           ? .system(size: 13, weight: .medium, design: .monospaced)
                           : .system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(revealPassword ? FVColor.silver : FVColor.smoke)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .privacySensitive()
                    .animation(.easeInOut(duration: 0.15), value: revealPassword)

                copyButton
                eyeButton
            }
        }
    }

    var copyButton: some View {
        Button {
            ClipboardService.copy(entry.password)
            onCopyPassword?()
            fvHaptic(.success)
            didCopyPassword = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyPassword = false }
        } label: {
            Image(systemName: didCopyPassword ? "checkmark" : "doc.on.doc")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(didCopyPassword ? FVColor.success : FVColor.smoke)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: didCopyPassword)
    }

    var eyeButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { revealPassword.toggle() }
            fvHaptic(.light)
        } label: {
            Image(systemName: revealPassword ? "eye.slash" : "eye")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(revealPassword ? FVColor.cyan : FVColor.smoke)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Website Section

private extension VaultEntryCard {

    @ViewBuilder
    var websiteSection: some View {
        if !entry.website.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("SITE WEB")
                Text(entry.website)
                    .font(.system(size: 13))
                    .foregroundStyle(FVColor.cyan)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - MFA Section

private extension VaultEntryCard {

    @ViewBuilder
    var mfaSection: some View {
        if entry.mfaEnabled && !entry.mfaSecret.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("CODE 2FA")
                TOTPCodePanel(secretInput: entry.mfaSecret, accentMode: accentMode, onCopy: onCopyMFA)
            }
        }
    }
}

// MARK: - Notes Section

private extension VaultEntryCard {

    @ViewBuilder
    var notesSection: some View {
        if !entry.notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("NOTES")
                Text(entry.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(FVColor.smoke)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Strength Bar

private extension VaultEntryCard {

    var strengthBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionLabel("ROBUSTESSE")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(strengthColor)
                        .frame(width: geo.size.width * strengthFraction, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Action Buttons

private extension VaultEntryCard {

    var actionButtons: some View {
        HStack(spacing: 10) {
            if let onEdit {
                ghostBtn(label: "Modifier", icon: "pencil", color: FVColor.silver) { onEdit() }
            }
            if let onDelete {
                ghostBtn(label: "Supprimer", icon: "trash", color: FVColor.danger) { onDelete() }
            }
        }
    }

    func ghostBtn(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .medium))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private extension VaultEntryCard {

    func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .tracking(1.5)
            .foregroundStyle(FVColor.smoke)
    }
}

// MARK: - Selection

private extension VaultEntryCard {

    var selectionOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                isSelected
                    ? LinearGradient(colors: [FVColor.cyan, FVColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                lineWidth: isSelected ? 2 : 0
            )
    }

    @ViewBuilder
    var selectionBadge: some View {
        if selectionMode {
            ZStack {
                Circle().fill(isSelected ? FVColor.cyan : Color.white.opacity(0.12)).frame(width: 22, height: 22)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : FVColor.smoke)
            }
            .padding(10)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Swipe

private extension VaultEntryCard {

    @ViewBuilder
    var swipeReveal: some View {
        if swipeOffset > 0 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FVColor.cyan)
                .overlay(alignment: .leading) {
                    Label("Copier", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.leading, 20)
                }
        } else if swipeOffset < 0 {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(FVColor.danger)
                .overlay(alignment: .trailing) {
                    Label("Supprimer", systemImage: "trash.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.trailing, 20)
                }
        }
    }

    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { v in
                swipeOffset = v.translation.width > 0 ? min(v.translation.width, 100) : max(v.translation.width, -100)
            }
            .onEnded { v in
                if v.translation.width > 60 {
                    fvHaptic(.success)
                    ClipboardService.copy(entry.password)
                    onCopyPassword?()
                } else if v.translation.width < -60 {
                    fvHaptic(.medium)
                    onDelete?()
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { swipeOffset = 0 }
            }
    }
}

// MARK: - Context Menu

private extension VaultEntryCard {

    @ViewBuilder
    var menuItems: some View {
        Button {
            ClipboardService.copy(entry.password)
            onCopyPassword?()
            fvHaptic(.success)
        } label: {
            Label(String(localized: "vault.card.copy"), systemImage: "doc.on.doc")
        }
        Button {
            ClipboardService.copy(entry.username)
            fvHaptic(.light)
        } label: {
            Label(String(localized: "vault.field.username"), systemImage: "person")
        }
        if let onEdit {
            Button { onEdit() } label: {
                Label(String(localized: "vault.action.edit"), systemImage: "pencil")
            }
        }
        if let onDelete {
            Button(role: .destructive) { onDelete() } label: {
                Label(String(localized: "vault.action.delete"), systemImage: "trash")
            }
        }
    }
}
