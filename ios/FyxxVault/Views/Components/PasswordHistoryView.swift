import SwiftUI

struct PasswordHistoryView: View {
    let history: [PasswordVersion]
    let currentPassword: String
    @Environment(\.dismiss) private var dismiss
    @State private var revealedIDs: Set<UUID> = []

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if history.isEmpty {
                        FVEmptyState(
                            icon: "clock.arrow.circlepath",
                            title: String(localized: "history.empty.title"),
                            subtitle: String(localized: "history.empty.subtitle")
                        )
                    } else {
                        ForEach(Array(history.enumerated()), id: \.element.id) { index, version in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if index == 0 {
                                        FVTag(text: String(localized: "history.current"), color: FVColor.success)
                                    } else {
                                        FVTag(text: String(localized: "history.previous"), color: FVColor.mist)
                                    }
                                    Spacer()
                                    Text(dateFormatter.string(from: version.createdAt))
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundStyle(FVColor.mist.opacity(0.7))
                                }

                                HStack {
                                    if revealedIDs.contains(version.id) {
                                        Text(version.password)
                                            .font(.custom("Menlo", size: 13))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .lineLimit(1)
                                    } else {
                                        Text(String(repeating: "\u{2022}", count: min(version.password.count, 16)))
                                            .font(.custom("Menlo", size: 13))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Spacer()

                                    Button {
                                        if revealedIDs.contains(version.id) {
                                            revealedIDs.remove(version.id)
                                        } else {
                                            revealedIDs.insert(version.id)
                                        }
                                    } label: {
                                        Image(systemName: revealedIDs.contains(version.id) ? "eye.slash" : "eye")
                                            .font(.system(size: 12))
                                            .foregroundStyle(FVColor.silver)
                                    }

                                    Button {
                                        ClipboardService.copy(version.password)
                                        fvHaptic(.success)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 12))
                                            .foregroundStyle(FVColor.cyan)
                                    }
                                }

                                // Strength indicator
                                PasswordStrengthView(password: version.password)
                            }
                            .fvGlass()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .navigationTitle(String(localized: "history.nav.title"))
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
}
