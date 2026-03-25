import SwiftUI

struct ShareEntryView: View {
    let entry: VaultEntry
    @Environment(\.dismiss) private var dismiss

    @State private var expirationHours: Int = 1
    @State private var maxViews: Int = 1
    @State private var shareGenerated = false
    @State private var shareData = ""
    @State private var shareKey = ""
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if !shareGenerated {
                        configView
                    } else {
                        resultView
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle(String(localized: "share.nav.title"))
            .fvInlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) { dismiss() }
                        .foregroundStyle(FVColor.cyan)
                }
            }
            .background(FVAnimatedBackground())
        }
    }

    private var configView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.cyan)

            Text(String(localized: "share.title"))
                .font(FVFont.heading(20))
                .foregroundStyle(.white)

            Text(String(localized: "share.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            // Entry being shared
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: entry.category.iconName)
                        .foregroundStyle(entry.category.iconColor)
                    Text(entry.title)
                        .font(FVFont.title(16))
                        .foregroundStyle(.white)
                }
                Text(entry.username)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(FVColor.mist)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fvGlass()

            // Expiration
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "share.expiration"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Picker("", selection: $expirationHours) {
                    Text("1h").tag(1)
                    Text("6h").tag(6)
                    Text("24h").tag(24)
                    Text("72h").tag(72)
                }
                .pickerStyle(.segmented)
            }
            .fvGlass()

            // Max views
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "share.max.views"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Stepper("\(maxViews) vue(s)", value: $maxViews, in: 1...10)
                    .foregroundStyle(.white)
            }
            .fvGlass()

            HStack(spacing: 8) {
                FVTag(text: "AES-256-GCM", color: FVColor.success)
                FVTag(text: String(localized: "share.ephemeral"), color: FVColor.violet)
            }

            FVButton(title: String(localized: "share.generate")) {
                generateShare()
            }
        }
        .fvGlass()
    }

    private var resultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42))
                .foregroundStyle(FVColor.success)

            Text(String(localized: "share.generated.title"))
                .font(FVFont.heading(20))
                .foregroundStyle(.white)

            Text(String(localized: "share.generated.description"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)

            // Share data display
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "share.encrypted.data"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Text(shareData.prefix(60) + "...")
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fvGlass()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "share.decryption.key"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(FVColor.mist)
                Text(shareKey.prefix(40) + "...")
                    .font(.custom("Menlo", size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fvGlass()

            FVButton(title: copied ? String(localized: "share.copied") : String(localized: "share.copy.all")) {
                let fullShare = "FyxxVault Secure Share\n\nData: \(shareData)\nKey: \(shareKey)\n\nExpires in \(expirationHours)h, \(maxViews) view(s) max."
                #if canImport(UIKit)
                UIPasteboard.general.string = fullShare
                #endif
                copied = true
                fvHaptic(.success)
            }

            // Native share sheet
            ShareLink(item: "FyxxVault Secure Share\n\nData: \(shareData)\nKey: \(shareKey)") {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "share.via.system"))
                }
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.cyan)
                .padding(.vertical, 10)
            }

            Text(String(localized: "share.warning"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(FVColor.warning.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .fvGlass()
    }

    private func generateShare() {
        guard let result = SecureShareService.createShareLink(
            entry: entry,
            expiresIn: TimeInterval(expirationHours * 3600),
            maxViews: maxViews
        ) else { return }

        shareData = result.shareData
        shareKey = result.key
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            shareGenerated = true
        }
        fvHaptic(.success)
    }
}
