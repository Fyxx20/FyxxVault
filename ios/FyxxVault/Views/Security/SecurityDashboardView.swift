import SwiftUI

struct SecurityDashboardView: View {
    @ObservedObject var vaultStore: VaultStore
    var onRecommendationTap: (VaultQuickAction) -> Void
    @State private var editingEntry: VaultEntry?

    private var expiringEntries: [VaultEntry] {
        vaultStore.entries
            .filter { $0.isExpired || $0.isExpiringSoon }
            .sorted { ($0.daysUntilExpiration ?? .max) < ($1.daysUntilExpiration ?? .max) }
    }

    var body: some View {
        ScrollView {
            let audit = vaultStore.securityAudit
            let recommendations = actionableRecommendations(audit)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sécurité")
                        .font(FVFont.display(28))
                        .foregroundStyle(.white)
                    Text("ANALYSE EN TEMPS RÉEL")
                        .font(FVFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(FVColor.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    FVSecurityGauge(score: audit.score, size: 160)
                    Text("Score de sécurité global")
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .fvGlass()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FVStatPill(icon: "exclamationmark.triangle", title: "À renforcer", value: "\(audit.weakCount)", color: FVColor.danger)
                    FVStatPill(icon: "arrow.triangle.2.circlepath", title: "Réutilisés", value: "\(audit.reusedCount)", color: FVColor.warning)
                    FVStatPill(icon: "shield.slash", title: "Sans MFA", value: "\(audit.withoutMFACount)", color: FVColor.violet)
                    FVStatPill(icon: "clock.badge.exclamationmark", title: "Expirés", value: "\(audit.expiredCount)", color: FVColor.rose)
                }

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "lightbulb", title: "RECOMMANDATIONS")
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { _, item in
                        Button {
                            guard let action = item.action else { return }
                            fvHaptic(.light)
                            onRecommendationTap(action)
                        } label: {
                            HStack(spacing: 10) {
                                Text(item.text)
                                    .font(FVFont.body(13))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: item.action == nil ? "checkmark.circle.fill" : "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(item.action == nil ? FVColor.success : FVColor.cyan.opacity(0.85))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(item.action == nil)
                    }
                }
                .fvGlass()

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "clock.arrow.circlepath", title: "EXPIRATIONS")
                    if expiringEntries.isEmpty {
                        Text("Aucun mot de passe expiré actuellement.")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.mist.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(expiringEntries.prefix(6), id: \.id) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(FVFont.title(15))
                                        .foregroundStyle(.white)
                                    if let days = entry.daysUntilExpiration {
                                        Text(days < 0 ? "Expiré depuis \(abs(days)) jour(s)" : "Expire dans \(days) jour(s)")
                                            .font(FVFont.caption(11))
                                            .foregroundStyle(days < 0 ? FVColor.danger : FVColor.warning)
                                    }
                                }
                                Spacer(minLength: 10)
                                Button("Changer") { editingEntry = entry }
                                    .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
                            }
                        }
                    }
                }
                .fvGlass()

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "checkmark.shield", title: "ALERTES BREACH")
                    if audit.reusedCount > 0 {
                        Text("Des réutilisations sont détectées. Vérifie les mots de passe compromis dans l'édition de compte.")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.warning)
                    } else {
                        Label("Aucune fuite détectée", systemImage: "checkmark.circle.fill")
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.success)
                    }
                }
                .fvGlass()

                Color.clear.frame(height: 120)
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $editingEntry) { entry in
            EditVaultEntryView(vaultStore: vaultStore, entry: entry)
        }
    }

    private struct SecurityRecommendation {
        let text: String
        let action: VaultQuickAction?
    }

    private func actionableRecommendations(_ audit: SecurityAudit) -> [SecurityRecommendation] {
        var items: [SecurityRecommendation] = []
        if audit.weakCount > 0 {
            items.append(.init(text: "Renforce \(audit.weakCount) mot(s) de passe à améliorer.", action: .weakPasswords))
        }
        if audit.reusedCount > 0 {
            items.append(.init(text: "Évite la réutilisation (\(audit.reusedCount) entrée(s)).", action: .reusedPasswords))
        }
        if audit.withoutMFACount > 0 {
            items.append(.init(text: "Active le MFA sur \(audit.withoutMFACount) compte(s).", action: .missingMFA))
        }
        if audit.expiredCount > 0 {
            items.append(.init(text: "\(audit.expiredCount) mot(s) de passe expiré(s) à renouveler.", action: .expiredPasswords))
        }
        if items.isEmpty {
            items.append(.init(text: "Excellent niveau de sécurité.", action: nil))
        }
        return items
    }
}
