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
    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    private var strength: PasswordStrength {
        PasswordToolkit.strength(for: entry.password)
    }

    private var strengthColor: Color {
        switch strength {
        case .faible: return .red
        case .moyen: return .orange
        case .fort: return .green
        case .excellent: return .cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 11) {
            // MARK: - Top Row: Icon + Title + Actions
            HStack(spacing: 10) {
                // Category icon in gradient rounded square
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [entry.category.iconColor.opacity(0.35), FVColor.violet.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [entry.category.iconColor.opacity(0.4), FVColor.violet.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay {
                        if entry.category == .login {
                            Text(String(entry.title.prefix(1)).uppercased())
                                .font(FVFont.label(15))
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: entry.category.iconName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                VStack(alignment: .leading, spacing: 3) {
                    // Title row with strength dot and favorite star
                    HStack(spacing: 6) {
                        Text(entry.title)
                            .font(FVFont.title(compact ? 15 : 16))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        FVPulsingDot(color: strengthColor, size: 6)

                        if entry.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.yellow.opacity(0.9))
                                .scaleEffect(favBounce ? 1.35 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: favBounce)
                                .onAppear {
                                    favBounce = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { favBounce = false }
                                }
                        }

                        if entry.isExpired {
                            Label(String(localized: "vault.card.expired"), systemImage: "clock.badge.exclamationmark.fill")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(FVColor.danger)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.red.opacity(0.15)).clipShape(Capsule())
                        } else if entry.isExpiringSoon {
                            Label(String(localized: "vault.card.expiring.soon"), systemImage: "clock.fill")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(.orange)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.orange.opacity(0.15)).clipShape(Capsule())
                        }

                        if let breachCount, breachCount > 0 {
                            Label(String(format: NSLocalizedString("vault.card.breached %lld", comment: ""), breachCount), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .bold)).foregroundStyle(FVColor.danger)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(FVColor.danger.opacity(0.15)).clipShape(Capsule())
                        }
                    }

                    // Username with copy button
                    HStack(spacing: 4) {
                        Text(entry.username)
                            .font(FVFont.body(compact ? 12 : 13))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Button {
                            ClipboardService.copy(entry.username)
                            fvHaptic(.light)
                            didCopyUsername = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { didCopyUsername = false }
                        } label: {
                            Image(systemName: didCopyUsername ? "checkmark.circle.fill" : "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundStyle(didCopyUsername ? FVColor.success : FVColor.smoke)
                        }
                    }

                    // Website in cyan
                    if !entry.website.isEmpty {
                        Text(entry.website)
                            .font(FVFont.caption(compact ? 10 : 12))
                            .foregroundStyle(FVColor.cyan)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                // Right side: relative time + actions
                VStack(alignment: .trailing, spacing: 6) {
                    Text(entry.lastModifiedAt.formatted(.relative(presentation: .named)))
                        .font(FVFont.caption(9))
                        .foregroundStyle(FVColor.smoke)

                    HStack(spacing: 4) {
                        if let onEdit {
                            Button { onEdit() } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(width: 26, height: 26)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                        if let onDelete {
                            Button { onDelete() } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(FVColor.danger.opacity(0.8))
                                    .frame(width: 26, height: 26)
                                    .background(FVColor.danger.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }

            // MARK: - Gradient Separator
            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.white.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)

            // MARK: - Password Row
            HStack(spacing: 8) {
                Text(revealPassword ? entry.password : String(repeating: "\u{2022}", count: max(entry.password.count, 8)))
                    .font(.custom("Menlo", size: 13))
                    .foregroundStyle(.white.opacity(revealPassword ? 0.95 : 0.5))
                    .lineLimit(1)
                    .privacySensitive()
                    .animation(.easeInOut(duration: 0.2), value: revealPassword)
                Spacer()

                // Copy button with green flash
                Button {
                    ClipboardService.copy(entry.password); onCopyPassword?()
                    fvHaptic(.success)
                    didCopyPassword = true
                    showCopyOverlay = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showCopyOverlay = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyPassword = false }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: didCopyPassword ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 10))
                        Text(didCopyPassword ? String(localized: "vault.card.copied") : String(localized: "vault.card.copy"))
                            .font(FVFont.caption(10))
                    }
                    .foregroundStyle(didCopyPassword ? FVColor.success : FVColor.silver)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(didCopyPassword ? FVColor.success.opacity(0.1) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(didCopyPassword ? FVColor.success.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1))
                }

                // Reveal toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { revealPassword.toggle() }
                    fvHaptic(.light)
                } label: {
                    Image(systemName: revealPassword ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(FVColor.silver)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }

            // MARK: - Expiration Info
            if entry.expirationPolicy != .none, let days = entry.daysUntilExpiration {
                Text(days < 0 ? String(format: NSLocalizedString("vault.card.password.expired.since %lld", comment: ""), abs(days)) : String(format: NSLocalizedString("vault.card.password.expires.in %lld %@", comment: ""), days, entry.expirationPolicy.label))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(days < 0 ? .red : (days < 14 ? .orange : .white.opacity(0.55)))
            }

            // MARK: - Notes
            if !entry.notes.isEmpty {
                Text(entry.notes)
                    .font(FVFont.body(12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }

            // MARK: - MFA Section
            if entry.mfaEnabled && entry.mfaType == .totp {
                HStack(spacing: 6) {
                    FVPulsingDot(color: FVColor.cyan, size: 5)
                    Button(showMFACode ? String(localized: "vault.card.mfa.hide") : String(localized: "vault.card.mfa.show")) {
                        showMFACode.toggle()
                        fvHaptic(.light)
                    }
                    .font(FVFont.body(11))
                    .foregroundStyle(FVColor.cyan)
                }
                if showMFACode {
                    TOTPCodePanel(secretInput: entry.mfaSecret, accentMode: accentMode, onCopy: onCopyMFA)
                }
            }
        }
        .fvGlass()
        // Copy success overlay (green flash)
        .overlay {
            if showCopyOverlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(FVColor.success.opacity(0.1))
                    .overlay(
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(FVColor.success)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showCopyOverlay)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? FVColor.cyan : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if selectionMode { Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundStyle(isSelected ? FVColor.cyan : .white.opacity(0.5)).padding(10) }
        }
        // Swipe actions
        .background(
            Group {
                if swipeOffset > 0 {
                    HStack {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.leading, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FVColor.cyan.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else if swipeOffset < 0 {
                    HStack {
                        Spacer()
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(FVColor.danger.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        )
        .offset(x: swipeOffset)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let translation = value.translation.width
                    swipeOffset = translation > 0 ? min(translation, 100) : max(translation, -100)
                }
                .onEnded { value in
                    let threshold: CGFloat = 60
                    if value.translation.width > threshold {
                        fvHaptic(.success)
                        ClipboardService.copy(entry.password)
                        onCopyPassword?()
                        showCopyOverlay = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showCopyOverlay = false }
                    } else if value.translation.width < -threshold {
                        fvHaptic(.medium)
                        onDelete?()
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        swipeOffset = 0
                    }
                }
        )
        // Press scale with spring bounce back
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isPressed)
        .pressEvents {
            isPressed = true
        } onRelease: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { isPressed = false }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapCard?() }
        .contextMenu {
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
        .onAppear { revealPassword = !hidePasswordsByDefault; showMFACode = !hideMFACodeByDefault }
    }
}
