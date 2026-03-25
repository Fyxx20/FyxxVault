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
    @AppStorage("fyxxvault.hide.passwords.default") private var hidePasswordsByDefault = true
    @AppStorage("fyxxvault.hide.mfa.default") private var hideMFACodeByDefault = false
    @AppStorage("fyxxvault.haptics.enabled") private var hapticsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 7 : 10) {
            HStack {
                HStack(spacing: 10) {
                    Circle()
                        .fill(
                            LinearGradient(colors: [entry.category.iconColor.opacity(0.9), FVColor.violet.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 34, height: 34)
                        .overlay {
                            if entry.category == .login {
                                Text(String(entry.title.prefix(1)).uppercased())
                                    .font(FVFont.label(14))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: entry.category.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }

                    VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.title).font(FVFont.title(compact ? 16 : 18)).foregroundStyle(.white)
                        if entry.isFavorite { Image(systemName: "star.fill").font(.system(size: 12)).foregroundStyle(.yellow.opacity(0.9)) }
                        if entry.isExpired {
                            Label(String(localized: "vault.card.expired"), systemImage: "clock.badge.exclamationmark.fill")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(FVColor.danger)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.red.opacity(0.15)).clipShape(Capsule())
                        } else if entry.isExpiringSoon {
                            Label(String(localized: "vault.card.expiring.soon"), systemImage: "clock.fill")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(.orange)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(.orange.opacity(0.15)).clipShape(Capsule())
                        }
                        if let breachCount, breachCount > 0 {
                            Label(String(localized: "vault.card.breached \(breachCount)"), systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 10, weight: .bold)).foregroundStyle(FVColor.danger)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(FVColor.danger.opacity(0.15)).clipShape(Capsule())
                        }
                    }
                    if !entry.website.isEmpty {
                        Text(entry.website)
                            .font(FVFont.caption(compact ? 11 : 12))
                            .foregroundStyle(FVColor.cyan)
                            .lineLimit(1)
                    }
                }
                }
                Spacer()
                if let onEdit {
                    Button { onEdit() } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                if let onDelete {
                    Button { onDelete() } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(FVColor.danger.opacity(0.9))
                            .frame(width: 28, height: 28)
                            .background(FVColor.danger.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
            }

            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)

            Text(entry.username).font(FVFont.body(14)).foregroundStyle(.white.opacity(0.8))

            HStack(spacing: 8) {
                Text(revealPassword ? entry.password : String(repeating: "•", count: max(entry.password.count, 8)))
                    .font(.custom("Menlo", size: 13)).foregroundStyle(.white.opacity(0.95)).lineLimit(1)
                    .privacySensitive()
                Spacer()
                Button {
                    ClipboardService.copy(entry.password); onCopyPassword?()
                    fvHaptic(.light)
                    didCopyPassword = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { didCopyPassword = false }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: didCopyPassword ? "checkmark.circle.fill" : "doc.on.doc")
                        Text(didCopyPassword ? String(localized: "vault.card.copied") : String(localized: "vault.card.copy"))
                    }
                    .font(FVFont.caption(11))
                    .foregroundStyle(didCopyPassword ? FVColor.cyan : FVColor.silver)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                }
                Button(revealPassword ? String(localized: "vault.card.hide") : String(localized: "vault.card.reveal")) { revealPassword.toggle() }
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.silver)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
            }

            if entry.expirationPolicy != .none, let days = entry.daysUntilExpiration {
                Text(days < 0 ? String(localized: "vault.card.password.expired.since \(abs(days))") : String(localized: "vault.card.password.expires.in \(days) \(entry.expirationPolicy.label)"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(days < 0 ? .red : (days < 14 ? .orange : .white.opacity(0.55)))
            }

            if !entry.notes.isEmpty { Text(entry.notes).font(FVFont.body(13)).foregroundStyle(.white.opacity(0.67)) }

            if entry.mfaEnabled && entry.mfaType == .totp {
                Button(showMFACode ? String(localized: "vault.card.mfa.hide") : String(localized: "vault.card.mfa.show")) { showMFACode.toggle(); fvHaptic(.light) }
                    .font(FVFont.body(12)).foregroundStyle(FVColor.cyan)
                if showMFACode { TOTPCodePanel(secretInput: entry.mfaSecret, accentMode: accentMode, onCopy: onCopyMFA) }
            }
        }
        .fvGlass()
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? FVColor.cyan : .clear, lineWidth: 2))
        .overlay(alignment: .topTrailing) {
            if selectionMode { Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").foregroundStyle(isSelected ? FVColor.cyan : .white.opacity(0.5)).padding(10) }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTapCard?() }
        .onAppear { revealPassword = !hidePasswordsByDefault; showMFACode = !hideMFACodeByDefault }
    }
}
