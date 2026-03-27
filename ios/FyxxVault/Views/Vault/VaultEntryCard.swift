import SwiftUI

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

    // MARK: - Computed Properties

    private var strength: PasswordStrength {
        PasswordToolkit.strength(for: entry.password)
    }

    private var strengthColor: Color {
        switch strength {
        case .faible:    return FVColor.danger
        case .moyen:     return FVColor.warning
        case .fort:      return FVColor.success
        case .excellent: return FVColor.cyan
        }
    }

    private var strengthFraction: CGFloat {
        switch strength {
        case .faible:    return 0.25
        case .moyen:     return 0.50
        case .fort:      return 0.75
        case .excellent: return 1.00
        }
    }

    private var categoryAccent: Color {
        entry.category.iconColor
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Swipe reveal backgrounds ──────────────────────────────────────
            swipeBackground

            // ── Main card ────────────────────────────────────────────────────
            cardBody
                .offset(x: swipeOffset)
                .gesture(swipeDragGesture)
        }
        .scaleEffect(isPressed ? 0.975 : 1.0)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isPressed)
        .pressEvents {
            isPressed = true
        } onRelease: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) { isPressed = false }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapCard?() }
        .contextMenu { contextMenuItems }
        .onAppear {
            revealPassword = !hidePasswordsByDefault
            showMFACode   = !hideMFACodeByDefault
        }
    }

    // MARK: - Card Body

    @ViewBuilder
    private var cardBody: some View {
        ZStack(alignment: .topLeading) {
            // Multi-layer glass background
            cardBackground

            // Colored left accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [categoryAccent, categoryAccent.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 14)
                Spacer()
            }

            // Top accent line (category-colored thin bar at top edge)
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [categoryAccent.opacity(0.8), categoryAccent.opacity(0.0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Spacer()
            }

            // Main content
            VStack(alignment: .leading, spacing: compact ? 10 : 13) {
                topRow
                divider
                passwordRow
                expirationRow
                notesRow
                mfaRow
                strengthBarRow
            }
            .padding(.leading, 18)
            .padding(.trailing, 16)
            .padding(.vertical, 16)

            // Copy success overlay
            if showCopyOverlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(FVColor.success.opacity(0.12))
                    .overlay(
                        VStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(FVColor.success)
                            Text(String(localized: "vault.card.copied"))
                                .font(FVFont.caption(12))
                                .foregroundStyle(FVColor.success)
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: showCopyOverlay)
        // Selection ring
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? LinearGradient(colors: [FVColor.cyan, FVColor.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                    lineWidth: isSelected ? 2.5 : 0
                )
        )
        // Selection mode checkmark badge
        .overlay(alignment: .topTrailing) {
            if selectionMode {
                ZStack {
                    Circle()
                        .fill(isSelected ? FVColor.cyan : Color.white.opacity(0.12))
                        .frame(width: 22, height: 22)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : FVColor.smoke)
                }
                .padding(12)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectionMode)
            }
        }
    }

    // MARK: - Card Background

    @ViewBuilder
    private var cardBackground: some View {
        ZStack {
            // Base ultra-thin material
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.35))

            // Deep abyss layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FVColor.obsidian.opacity(0.92),
                            FVColor.void_.opacity(0.85),
                            FVColor.abyss.opacity(0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Glass sheen layer
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.07), Color.white.opacity(0.01)],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )

            // Category color inner glow (bottom)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [categoryAccent.opacity(0.07), .clear],
                        center: .bottomLeading,
                        startRadius: 10,
                        endRadius: 200
                    )
                )

            // Border
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            categoryAccent.opacity(0.10),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: FVColor.cyan.opacity(0.10), radius: 18, x: 0, y: 6)
        .shadow(color: FVColor.violet.opacity(0.08), radius: 24, x: 0, y: 10)
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }

    // MARK: - Top Row

    @ViewBuilder
    private var topRow: some View {
        HStack(alignment: .top, spacing: 13) {
            categoryIcon
            titleBlock
            Spacer(minLength: 4)
            rightActions
        }
    }

    // MARK: - Category Icon (52×52 premium rounded square)

    @ViewBuilder
    private var categoryIcon: some View {
        ZStack {
            // Strong gradient fill
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            categoryAccent.opacity(0.50),
                            FVColor.violet.opacity(0.40),
                            categoryAccent.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Inner glow ring
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.28),
                            categoryAccent.opacity(0.35),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )

            // Specular highlight at top
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            // Icon or initial letter
            if entry.category == .login && faviconImage == nil {
                Text(String(entry.title.prefix(1)).uppercased())
                    .font(FVFont.label(18))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: categoryAccent.opacity(0.6), radius: 6, x: 0, y: 0)
            }

            // Favicon overlay (replaces everything above)
            if let img = faviconImage {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .frame(width: 52, height: 52)
        .task(id: entry.website) {
            guard !entry.website.isEmpty else { return }
            faviconImage = await FaviconCache.shared.loadFavicon(for: entry.website)
        }
    }

    // MARK: - Title Block

    @ViewBuilder
    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title line
            HStack(spacing: 7) {
                Text(entry.title)
                    .font(FVFont.heading(compact ? 15 : 17))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                // Strength pulsing dot
                FVPulsingDot(color: strengthColor, size: 6)

                // Favorite star
                if entry.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(FVColor.gold)
                        .shadow(color: FVColor.gold.opacity(0.6), radius: 4)
                        .scaleEffect(favBounce ? 1.4 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.4), value: favBounce)
                        .onAppear {
                            favBounce = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { favBounce = false }
                        }
                }

                // Expiry badges
                if entry.isExpired {
                    badgePill(
                        text: String(localized: "vault.card.expired"),
                        icon: "clock.badge.exclamationmark.fill",
                        color: FVColor.danger
                    )
                } else if entry.isExpiringSoon {
                    badgePill(
                        text: String(localized: "vault.card.expiring.soon"),
                        icon: "clock.fill",
                        color: FVColor.warning
                    )
                }

                // Breach badge
                if let breachCount, breachCount > 0 {
                    badgePill(
                        text: String(format: NSLocalizedString("vault.card.breached %lld", comment: ""), breachCount),
                        icon: "exclamationmark.triangle.fill",
                        color: FVColor.danger
                    )
                }
            }

            // Username row with inline copy pill
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(FVColor.smoke)
                Text(entry.username)
                    .font(FVFont.body(compact ? 12 : 13))
                    .foregroundStyle(FVColor.mist)
                    .lineLimit(1)

                Button {
                    ClipboardService.copy(entry.username)
                    fvHaptic(.light)
                    didCopyUsername = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { didCopyUsername = false }
                } label: {
                    Image(systemName: didCopyUsername ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(didCopyUsername ? FVColor.success : FVColor.smoke)
                        .frame(width: 20, height: 20)
                        .background(
                            Capsule()
                                .fill(didCopyUsername ? FVColor.success.opacity(0.15) : Color.white.opacity(0.07))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    didCopyUsername ? FVColor.success.opacity(0.4) : Color.white.opacity(0.10),
                                    lineWidth: 0.8
                                )
                        )
                }
                .animation(.easeInOut(duration: 0.18), value: didCopyUsername)
            }

            // Website
            if !entry.website.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "globe")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(FVColor.cyan.opacity(0.7))
                    Text(entry.website)
                        .font(FVFont.caption(compact ? 10 : 11))
                        .foregroundStyle(FVColor.cyan)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Right Actions

    @ViewBuilder
    private var rightActions: some View {
        VStack(alignment: .trailing, spacing: 8) {
            // Relative time label in pill
            Text(entry.lastModifiedAt.formatted(.relative(presentation: .named)))
                .font(FVFont.caption(9))
                .foregroundStyle(FVColor.smoke)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.7))

            // Action pill buttons
            HStack(spacing: 5) {
                if let onEdit {
                    actionPillButton(
                        icon: "pencil",
                        color: FVColor.silver,
                        tint: Color.white.opacity(0.08)
                    ) { onEdit() }
                }
                if let onDelete {
                    actionPillButton(
                        icon: "trash",
                        color: FVColor.danger,
                        tint: FVColor.danger.opacity(0.10)
                    ) { onDelete() }
                }
            }
        }
    }

    // MARK: - Divider

    @ViewBuilder
    private var divider: some View {
        LinearGradient(
            colors: [
                categoryAccent.opacity(0.02),
                categoryAccent.opacity(0.18),
                Color.white.opacity(0.06),
                categoryAccent.opacity(0.02)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    // MARK: - Password Row

    @ViewBuilder
    private var passwordRow: some View {
        HStack(spacing: 10) {
            // Password text on a tinted background
            Text(revealPassword
                    ? entry.password
                    : String(repeating: "\u{2022}", count: min(max(entry.password.count, 8), 20)))
                .font(revealPassword
                    ? FVFont.mono(compact ? 12 : 13)
                    : .system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(revealPassword ? FVColor.silver : FVColor.smoke.opacity(0.8))
                .lineLimit(1)
                .privacySensitive()
                .animation(.easeInOut(duration: 0.18), value: revealPassword)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    strengthColor.opacity(0.07),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(strengthColor.opacity(0.18), lineWidth: 0.8)
                )

            // Copy pill button (gradient border)
            Button {
                ClipboardService.copy(entry.password)
                onCopyPassword?()
                fvHaptic(.success)
                didCopyPassword = true
                showCopyOverlay  = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8)  { showCopyOverlay  = false }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { didCopyPassword = false }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: didCopyPassword ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                    Text(didCopyPassword
                            ? String(localized: "vault.card.copied")
                            : String(localized: "vault.card.copy"))
                        .font(FVFont.caption(10))
                }
                .foregroundStyle(didCopyPassword ? FVColor.success : FVColor.silver)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(didCopyPassword
                              ? FVColor.success.opacity(0.12)
                              : Color.white.opacity(0.07))
                )
                .overlay(
                    Capsule().strokeBorder(
                        didCopyPassword
                            ? FVColor.success.opacity(0.50)
                            : LinearGradient(
                                colors: [FVColor.cyan.opacity(0.45), FVColor.violet.opacity(0.30)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              ).opacity(1),
                        lineWidth: 1
                    )
                )
            }
            .animation(.easeInOut(duration: 0.18), value: didCopyPassword)

            // Reveal toggle pill
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { revealPassword.toggle() }
                fvHaptic(.light)
            } label: {
                Image(systemName: revealPassword ? "eye.slash.fill" : "eye.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(revealPassword ? FVColor.cyan : FVColor.smoke)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(revealPassword
                                  ? FVColor.cyan.opacity(0.12)
                                  : Color.white.opacity(0.07))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                revealPassword
                                    ? FVColor.cyan.opacity(0.35)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
            }
        }
    }

    // MARK: - Expiration Row

    @ViewBuilder
    private var expirationRow: some View {
        if entry.expirationPolicy != .none, let days = entry.daysUntilExpiration {
            let isExpired = days < 0
            let isWarning = !isExpired && days < 14
            let rowColor: Color = isExpired ? FVColor.danger : (isWarning ? FVColor.warning : FVColor.smoke)
            HStack(spacing: 6) {
                Image(systemName: isExpired ? "clock.badge.xmark.fill" : "clock.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(rowColor)
                Text(isExpired
                        ? String(format: NSLocalizedString("vault.card.password.expired.since %lld", comment: ""), abs(days))
                        : String(format: NSLocalizedString("vault.card.password.expires.in %lld %@", comment: ""), days, entry.expirationPolicy.label))
                    .font(FVFont.caption(10))
                    .foregroundStyle(rowColor)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(rowColor.opacity(0.10))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(rowColor.opacity(0.25), lineWidth: 0.8))
        }
    }

    // MARK: - Notes Row

    @ViewBuilder
    private var notesRow: some View {
        if !entry.notes.isEmpty {
            Text(entry.notes)
                .font(FVFont.body(compact ? 11 : 12))
                .foregroundStyle(FVColor.smoke)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.7)
                )
        }
    }

    // MARK: - MFA Row

    @ViewBuilder
    private var mfaRow: some View {
        if entry.mfaEnabled && entry.mfaType == .totp {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    FVPulsingDot(color: FVColor.cyan, size: 5)
                    Button(showMFACode
                            ? String(localized: "vault.card.mfa.hide")
                            : String(localized: "vault.card.mfa.show")) {
                        showMFACode.toggle()
                        fvHaptic(.light)
                    }
                    .font(FVFont.body(11))
                    .foregroundStyle(FVColor.cyan)

                    Spacer()

                    // MFA badge
                    Text("2FA")
                        .font(FVFont.label(9))
                        .foregroundStyle(FVColor.cyan)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FVColor.cyan.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.30), lineWidth: 0.8))
                }

                if showMFACode {
                    TOTPCodePanel(secretInput: entry.mfaSecret, accentMode: accentMode, onCopy: onCopyMFA)
                }
            }
        }
    }

    // MARK: - Strength Bar Row

    @ViewBuilder
    private var strengthBarRow: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 3)

                // Fill
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [strengthColor.opacity(0.9), strengthColor.opacity(0.55)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * strengthFraction, height: 3)
                    .shadow(color: strengthColor.opacity(0.6), radius: 3, x: 0, y: 0)
                    .animation(.easeInOut(duration: 0.45), value: strengthFraction)
            }
        }
        .frame(height: 3)
    }

    // MARK: - Swipe Background

    @ViewBuilder
    private var swipeBackground: some View {
        if swipeOffset > 0 {
            // Copy action — cyan
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [FVColor.cyan, FVColor.cyan.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                HStack {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(String(localized: "vault.card.copy"))
                            .font(FVFont.caption(10))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.leading, 28)
                    Spacer()
                }
            }
        } else if swipeOffset < 0 {
            // Delete action — red
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [FVColor.danger.opacity(0.75), FVColor.danger],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                        Text(String(localized: "vault.action.delete"))
                            .font(FVFont.caption(10))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.trailing, 28)
                }
            }
        }
    }

    // MARK: - Swipe Drag Gesture

    private var swipeDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let t = value.translation.width
                swipeOffset = t > 0 ? min(t, 110) : max(t, -110)
            }
            .onEnded { value in
                let threshold: CGFloat = 62
                if value.translation.width > threshold {
                    fvHaptic(.success)
                    ClipboardService.copy(entry.password)
                    onCopyPassword?()
                    showCopyOverlay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { showCopyOverlay = false }
                } else if value.translation.width < -threshold {
                    fvHaptic(.medium)
                    onDelete?()
                }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                    swipeOffset = 0
                }
            }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuItems: some View {
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

    // MARK: - Helper Views

    @ViewBuilder
    private func badgePill(text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 0.8))
    }

    @ViewBuilder
    private func actionPillButton(icon: String, color: Color, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(color.opacity(0.25), lineWidth: 0.8)
                )
        }
    }
}
