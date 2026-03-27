import SwiftUI

struct SecurityDashboardView: View {
    @ObservedObject var vaultStore: VaultStore
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var subscriptionService: SubscriptionService
    var onRecommendationTap: (VaultQuickAction) -> Void
    @State private var showPaywall = false
    @State private var editingEntry: VaultEntry?
    @State private var statsAppeared = false
    @State private var chevronAnimated: Set<Int> = []

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
                // MARK: - Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "security.title"))
                        .font(FVFont.display(28))
                        .fvAnimatedGradient()
                    Text(String(localized: "security.subtitle"))
                        .font(FVFont.caption(11))
                        .kerning(1.5)
                        .foregroundStyle(FVColor.smoke)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MARK: - Security Score Card (200pt gauge)
                VStack(spacing: 14) {
                    Text(String(localized: "security.score.label"))
                        .font(FVFont.caption(10))
                        .kerning(2)
                        .foregroundStyle(FVColor.smoke)

                    ZStack {
                        // Glow behind the ring
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [scoreColor(audit.score).opacity(0.15), .clear],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)

                        FVSecurityGauge(score: audit.score, size: 200)
                    }

                    Text(String(localized: "security.score.label"))
                        .font(FVFont.caption(12))
                        .fvAnimatedGradient(colors: [scoreColor(audit.score), FVColor.cyan, scoreColor(audit.score)])
                }
                .frame(maxWidth: .infinity)
                .fvGlow(scoreColor(audit.score))

                // MARK: - Bento Grid Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    FVBentoStatCard(
                        icon: "exclamationmark.triangle",
                        title: String(localized: "security.stat.weak"),
                        value: audit.weakCount,
                        color: FVColor.danger
                    )
                    .opacity(statsAppeared ? 1 : 0)
                    .offset(y: statsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: statsAppeared)

                    FVBentoStatCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: String(localized: "security.stat.reused"),
                        value: audit.reusedCount,
                        color: FVColor.warning
                    )
                    .opacity(statsAppeared ? 1 : 0)
                    .offset(y: statsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: statsAppeared)

                    FVBentoStatCard(
                        icon: "shield.slash",
                        title: String(localized: "security.stat.no.mfa"),
                        value: audit.withoutMFACount,
                        color: FVColor.violet
                    )
                    .opacity(statsAppeared ? 1 : 0)
                    .offset(y: statsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: statsAppeared)

                    FVBentoStatCard(
                        icon: "clock.badge.exclamationmark",
                        title: String(localized: "security.stat.expired"),
                        value: audit.expiredCount,
                        color: FVColor.rose
                    )
                    .opacity(statsAppeared ? 1 : 0)
                    .offset(y: statsAppeared ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4), value: statsAppeared)
                }
                .onAppear { statsAppeared = true }

                // MARK: - Recommendations
                VStack(alignment: .leading, spacing: 10) {
                    FVSectionHeader(icon: "lightbulb", title: String(localized: "security.section.recommendations"))
                    ForEach(Array(recommendations.enumerated()), id: \.offset) { idx, item in
                        Button {
                            guard let action = item.action else { return }
                            fvHaptic(.light)
                            _ = withAnimation(.spring(response: 0.3)) {
                                chevronAnimated.insert(idx)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                chevronAnimated.remove(idx)
                            }
                            onRecommendationTap(action)
                        } label: {
                            HStack(spacing: 10) {
                                // Severity icon in colored circle
                                ZStack {
                                    Circle()
                                        .fill(item.severityColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: item.severityIcon)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(item.severityColor)
                                }

                                Text(item.text)
                                    .font(FVFont.body(13))
                                    .foregroundStyle(.white.opacity(0.86))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: item.action == nil ? "checkmark.circle.fill" : "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(item.action == nil ? FVColor.success : FVColor.cyan.opacity(0.85))
                                    .offset(x: chevronAnimated.contains(idx) ? 4 : 0)
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
                .fvPremiumCard()

                // MARK: - Expirations
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
                    HStack {
                        FVSectionHeader(icon: "network.badge.shield.half.filled", title: String(localized: "security.section.darkweb"))
                        Spacer()
                        if !subscriptionService.isProUser {
                            FVProBadge()
                        }
                    }

                    if !subscriptionService.isProUser {
                        // Free users see a locked state
                        VStack(spacing: 12) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(FVColor.gold)
                            Text("Analyse tes mots de passe contre les fuites du Dark Web")
                                .font(FVFont.body(13))
                                .foregroundStyle(FVColor.mist)
                                .multilineTextAlignment(.center)
                            Button {
                                showPaywall = true
                            } label: {
                                Text("Passer à Pro")
                                    .font(FVFont.label(13))
                                    .foregroundStyle(FVColor.abyss)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(FVColor.gold)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    } else if breachMonitor.isScanning {
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscriptionService: subscriptionService)
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

// MARK: - Bento Stat Card

private struct FVBentoStatCard: View {
    let icon: String
    let title: String
    let value: Int
    var color: Color = FVColor.cyan
    @State private var animatedValue: Int = 0
    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 22, height: 22)
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(color)
                    }
                    Text(title)
                        .font(FVFont.caption(10))
                        .foregroundStyle(FVColor.smoke)
                }
                Text("\(animatedValue)")
                    .font(FVFont.heading(28))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.11), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: color.opacity(0.08), radius: 8, y: 4)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .pressEvents {
            isPressed = true
        } onRelease: {
            withAnimation(.spring(response: 0.3)) { isPressed = false }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newVal in
            withAnimation(.spring(response: 0.5)) { animatedValue = newVal }
        }
    }
}
