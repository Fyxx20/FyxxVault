import SwiftUI

struct SecurityDashboardView: View {
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var breachMonitor: BreachMonitorService
    var onRecommendationTap: (VaultQuickAction) -> Void
    @State private var editingEntry: VaultEntry?
    @State private var statsAppeared = false

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
                    Text(String(localized: "security.title"))
                        .font(FVFont.display(28))
                        .foregroundStyle(.white)
                    Text(String(localized: "security.subtitle"))
                        .font(FVFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(FVColor.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Security Score Card
                VStack(spacing: 12) {
                    Text(String(localized: "security.score.label"))
                        .font(FVFont.caption(10))
                        .kerning(2)
                        .foregroundStyle(FVColor.smoke)

                    FVSecurityGauge(score: audit.score, size: 180)

                    Text(String(localized: "security.score.label"))
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .fvGlow(scoreColor(audit.score))

                // Stat pills with stagger animation
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FVStatPill(icon: "exclamationmark.triangle", title: String(localized: "security.stat.weak"), value: "\(audit.weakCount)", color: FVColor.danger)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: statsAppeared)

                    FVStatPill(icon: "arrow.triangle.2.circlepath", title: String(localized: "security.stat.reused"), value: "\(audit.reusedCount)", color: FVColor.warning)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: statsAppeared)

                    FVStatPill(icon: "shield.slash", title: String(localized: "security.stat.no.mfa"), value: "\(audit.withoutMFACount)", color: FVColor.violet)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: statsAppeared)

                    FVStatPill(icon: "clock.badge.exclamationmark", title: String(localized: "security.stat.expired"), value: "\(audit.expiredCount)", color: FVColor.rose)
                        .opacity(statsAppeared ? 1 : 0)
                        .offset(y: statsAppeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: statsAppeared)
                }
                .onAppear { statsAppeared = true }

                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "lightbulb", title: String(localized: "security.section.recommendations"))
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { _, item in
                        Button {
                            guard let action = item.action else { return }
                            fvHaptic(.light)
                            onRecommendationTap(action)
                        } label: {
                            HStack(spacing: 10) {
                                // Severity icon
                                Image(systemName: item.severityIcon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(item.severityColor)
                                    .frame(width: 24, height: 24)

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
                    FVSectionHeader(icon: "clock.arrow.circlepath", title: String(localized: "security.section.expirations"))
                    if expiringEntries.isEmpty {
                        Text(String(localized: "security.expirations.none"))
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
                                        Text(days < 0 ? String(format: NSLocalizedString("security.expired.since %lld", comment: ""), abs(days)) : String(format: NSLocalizedString("security.expires.in %lld", comment: ""), days))
                                            .font(FVFont.caption(11))
                                            .foregroundStyle(days < 0 ? FVColor.danger : FVColor.warning)
                                    }
                                }
                                Spacer(minLength: 10)
                                Button(String(localized: "security.action.change")) { editingEntry = entry }
                                    .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
                            }
                        }
                    }
                }
                .fvGlass()

                // MARK: Dark Web Monitoring
                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "network.badge.shield.half.filled", title: String(localized: "security.section.darkweb"))

                    if breachMonitor.isScanning {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(FVColor.cyan)
                                Text(String(format: NSLocalizedString("security.darkweb.scanning %lld", comment: ""), Int(breachMonitor.scanProgress * 100)))
                                    .font(FVFont.body(13))
                                    .foregroundStyle(FVColor.mist)
                            }
                            ProgressView(value: breachMonitor.scanProgress, total: 1.0)
                                .tint(FVColor.cyan)
                        }
                    } else {
                        if let lastDate = breachMonitor.lastScanDate {
                            Text(String(format: NSLocalizedString("security.darkweb.last.scan %@", comment: ""), lastDate.formatted(.relative(presentation: .named))))
                                .font(FVFont.caption(11))
                                .foregroundStyle(FVColor.smoke)
                        }

                        if breachMonitor.totalBreached > 0 {
                            Label(String(format: NSLocalizedString("security.darkweb.breached %lld", comment: ""), breachMonitor.totalBreached), systemImage: "exclamationmark.triangle.fill")
                                .font(FVFont.body(13))
                                .foregroundStyle(FVColor.danger)
                        } else if breachMonitor.lastScanDate != nil {
                            Label(String(localized: "security.darkweb.no.breach"), systemImage: "checkmark.circle.fill")
                                .font(FVFont.body(13))
                                .foregroundStyle(FVColor.success)
                        }

                        Button {
                            fvHaptic(.light)
                            Task {
                                await breachMonitor.scanAll(entries: vaultStore.entries)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                Text(String(localized: "security.darkweb.scan.now"))
                            }
                            .font(FVFont.body(13))
                            .foregroundStyle(FVColor.cyan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(FVColor.cyan.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(FVColor.cyan.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    // List of breached entries
                    if !breachMonitor.isScanning && breachMonitor.totalBreached > 0 {
                        let breached = vaultStore.entries.filter { (breachMonitor.breachCount(for: $0.id) ?? 0) > 0 }
                        ForEach(breached.prefix(10), id: \.id) { entry in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title)
                                        .font(FVFont.title(15))
                                        .foregroundStyle(.white)
                                    if let count = breachMonitor.breachCount(for: entry.id) {
                                        Text(String(format: NSLocalizedString("security.darkweb.appeared.in %lld", comment: ""), count))
                                            .font(FVFont.caption(11))
                                            .foregroundStyle(FVColor.danger)
                                    }
                                }
                                Spacer(minLength: 10)
                                Button(String(localized: "security.action.change")) { editingEntry = entry }
                                    .buttonStyle(FVSettingsButton(tint: FVColor.danger))
                            }
                        }
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
        let severity: Severity

        enum Severity { case critical, warning, ok }

        var severityIcon: String {
            switch severity {
            case .critical: return "exclamationmark.circle.fill"
            case .warning:  return "exclamationmark.triangle.fill"
            case .ok:       return "checkmark.circle.fill"
            }
        }

        var severityColor: Color {
            switch severity {
            case .critical: return FVColor.danger
            case .warning:  return FVColor.warning
            case .ok:       return FVColor.success
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0..<40:  return FVColor.danger
        case 40..<70: return FVColor.warning
        case 70..<85: return FVColor.warning
        default:      return FVColor.success
        }
    }

    private func actionableRecommendations(_ audit: SecurityAudit) -> [SecurityRecommendation] {
        var items: [SecurityRecommendation] = []
        if audit.weakCount > 0 {
            items.append(.init(text: String(format: NSLocalizedString("security.rec.weak %lld", comment: ""), audit.weakCount), action: .weakPasswords, severity: .critical))
        }
        if audit.reusedCount > 0 {
            items.append(.init(text: String(format: NSLocalizedString("security.rec.reused %lld", comment: ""), audit.reusedCount), action: .reusedPasswords, severity: .critical))
        }
        if audit.withoutMFACount > 0 {
            items.append(.init(text: String(format: NSLocalizedString("security.rec.mfa %lld", comment: ""), audit.withoutMFACount), action: .missingMFA, severity: .warning))
        }
        if audit.expiredCount > 0 {
            items.append(.init(text: String(format: NSLocalizedString("security.rec.expired %lld", comment: ""), audit.expiredCount), action: .expiredPasswords, severity: .warning))
        }
        if items.isEmpty {
            items.append(.init(text: String(localized: "security.rec.excellent"), action: nil, severity: .ok))
        }
        return items
    }
}
