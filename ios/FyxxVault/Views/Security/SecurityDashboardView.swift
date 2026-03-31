import SwiftUI

// MARK: - Security Dashboard View

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

            VStack(spacing: 20) {
                SecurityHeaderView()

                SecurityScoreGaugeCard(score: audit.score)

                SecurityStatsGrid(
                    audit: audit,
                    appeared: statsAppeared
                )
                .onAppear { statsAppeared = true }

                SecurityRecommendationsCard(
                    recommendations: recommendations,
                    chevronAnimated: $chevronAnimated,
                    onRecommendationTap: onRecommendationTap
                )

                SecurityExpirationsCard(
                    entries: expiringEntries,
                    onEdit: { editingEntry = $0 }
                )

                SecurityDarkWebCard(
                    breachMonitor: breachMonitor,
                    subscriptionService: subscriptionService,
                    vaultStore: vaultStore,
                    showPaywall: $showPaywall,
                    onEdit: { editingEntry = $0 }
                )

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

    // MARK: - Recommendation Logic

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

// MARK: - Security Recommendation Model

struct SecurityRecommendation {
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

// MARK: - Glass Card Modifier

private struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

private extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Header

private struct SecurityHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "security.title"))
                .font(FVFont.heading(28))
                .foregroundStyle(.white)
            Text(String(localized: "security.subtitle"))
                .font(FVFont.body(13))
                .foregroundStyle(FVColor.smoke)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Score Gauge Card

private struct SecurityScoreGaugeCard: View {
    let score: Int

    var body: some View {
        VStack(spacing: 16) {
            ScoreLabel()
            SecurityCircularGauge(
                score: score,
                color: scoreColor(for: score),
                size: 170
            )
            ScoreDescriptionLabel(
                score: score,
                color: scoreColor(for: score)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard()
    }
}

// MARK: - Score Label (above gauge)

private struct ScoreLabel: View {
    var body: some View {
        Text(String(localized: "security.score.label"))
            .font(FVFont.caption(10))
            .kerning(2)
            .foregroundStyle(FVColor.smoke)
            .textCase(.uppercase)
    }
}

// MARK: - Score Description Label (below gauge)

private struct ScoreDescriptionLabel: View {
    let score: Int
    let color: Color

    private var label: String {
        switch score {
        case 80...:   return String(localized: "gauge.excellent")
        case 60..<80: return String(localized: "gauge.good")
        case 40..<60: return String(localized: "gauge.medium")
        default:      return String(localized: "gauge.weak")
        }
    }

    var body: some View {
        Text(label)
            .font(FVFont.body(14))
            .foregroundStyle(color)
    }
}

// MARK: - Score Color Helper

private func scoreColor(for score: Int) -> Color {
    switch score {
    case 80...:   return FVColor.success
    case 60..<80: return FVColor.cyan
    case 40..<60: return FVColor.warning
    default:      return FVColor.danger
    }
}

// MARK: - Circular Gauge

private struct SecurityCircularGauge: View {
    let score: Int
    let color: Color
    let size: CGFloat
    @State private var animatedScore: CGFloat = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            GaugeTrackRing(size: size)
            GaugeProgressRing(
                progress: animatedScore / 100,
                color: color,
                size: size
            )
            GaugeCenterNumber(
                value: Int(animatedScore),
                size: size
            )
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                animatedScore = CGFloat(score)
            }
        }
        .onChange(of: score) { _, newValue in
            withAnimation(.easeOut(duration: 0.6)) {
                animatedScore = CGFloat(newValue)
            }
        }
    }
}

// MARK: - Gauge Track Ring

private struct GaugeTrackRing: View {
    let size: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.06), lineWidth: 8)
            .frame(width: size, height: size)
    }
}

// MARK: - Gauge Progress Ring

private struct GaugeProgressRing: View {
    let progress: CGFloat
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                color,
                style: StrokeStyle(lineWidth: 8, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: size, height: size)
    }
}

// MARK: - Gauge Center Number

private struct GaugeCenterNumber: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        Text("\(value)")
            .font(FVFont.display(48))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
    }
}

// MARK: - Stats Grid (2x2)

private struct SecurityStatsGrid: View {
    let audit: SecurityAudit
    let appeared: Bool

    private static let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: Self.columns, spacing: 12) {
            StatGridItem(
                icon: "exclamationmark.triangle",
                title: String(localized: "security.stat.weak"),
                value: audit.weakCount,
                accentColor: FVColor.danger,
                appeared: appeared,
                delay: 0.1
            )
            StatGridItem(
                icon: "arrow.triangle.2.circlepath",
                title: String(localized: "security.stat.reused"),
                value: audit.reusedCount,
                accentColor: FVColor.warning,
                appeared: appeared,
                delay: 0.2
            )
            StatGridItem(
                icon: "shield.slash",
                title: String(localized: "security.stat.no.mfa"),
                value: audit.withoutMFACount,
                accentColor: FVColor.cyan,
                appeared: appeared,
                delay: 0.3
            )
            StatGridItem(
                icon: "clock.badge.exclamationmark",
                title: String(localized: "security.stat.expired"),
                value: audit.expiredCount,
                accentColor: FVColor.warning,
                appeared: appeared,
                delay: 0.4
            )
        }
    }
}

// MARK: - Stat Grid Item (animated wrapper)

private struct StatGridItem: View {
    let icon: String
    let title: String
    let value: Int
    let accentColor: Color
    let appeared: Bool
    let delay: Double

    var body: some View {
        SecurityStatCard(
            icon: icon,
            title: title,
            value: value,
            accentColor: accentColor
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8).delay(delay),
            value: appeared
        )
    }
}

// MARK: - Stat Card

private struct SecurityStatCard: View {
    let icon: String
    let title: String
    let value: Int
    let accentColor: Color
    @State private var animatedValue: Int = 0

    var body: some View {
        HStack(spacing: 0) {
            StatAccentBar(color: accentColor)
            StatContent(
                icon: icon,
                title: title,
                value: animatedValue,
                accentColor: accentColor
            )
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.trailing, 12)
        .glassCard(cornerRadius: 14)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                animatedValue = value
            }
        }
        .onChange(of: value) { _, newVal in
            withAnimation(.easeOut(duration: 0.4)) {
                animatedValue = newVal
            }
        }
    }
}

// MARK: - Stat Accent Bar

private struct StatAccentBar: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(color)
            .frame(width: 3, height: 40)
            .padding(.leading, 12)
    }
}

// MARK: - Stat Content

private struct StatContent: View {
    let icon: String
    let title: String
    let value: Int
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            StatIconRow(
                icon: icon,
                title: title,
                color: accentColor
            )
            Text("\(value)")
                .font(FVFont.heading(28))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.leading, 10)
    }
}

// MARK: - Stat Icon Row

private struct StatIconRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(FVFont.caption(10))
                .foregroundStyle(FVColor.smoke)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Recommendations Card

private struct SecurityRecommendationsCard: View {
    let recommendations: [SecurityRecommendation]
    @Binding var chevronAnimated: Set<Int>
    var onRecommendationTap: (VaultQuickAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FVSectionHeader(
                icon: "lightbulb",
                title: String(localized: "security.section.recommendations")
            )

            ForEach(Array(recommendations.enumerated()), id: \.offset) { idx, item in
                if idx > 0 {
                    RecommendationDivider()
                }
                SecurityRecommendationRow(
                    item: item,
                    index: idx,
                    isChevronAnimated: chevronAnimated.contains(idx),
                    onTap: {
                        guard let action = item.action else { return }
                        fvHaptic(.light)
                        _ = withAnimation(.spring(response: 0.3)) {
                            chevronAnimated.insert(idx)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            chevronAnimated.remove(idx)
                        }
                        onRecommendationTap(action)
                    }
                )
            }
        }
        .padding(20)
        .glassCard()
    }
}

// MARK: - Recommendation Divider

private struct RecommendationDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 4)
    }
}

// MARK: - Recommendation Row

private struct SecurityRecommendationRow: View {
    let item: SecurityRecommendation
    let index: Int
    let isChevronAnimated: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                SeverityDot(color: item.severityColor)
                RecommendationText(text: item.text)
                Spacer(minLength: 8)
                RecommendationTrailingIcon(
                    hasAction: item.action != nil,
                    color: item.action == nil ? FVColor.success : FVColor.smoke,
                    isAnimated: isChevronAnimated
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
    }
}

// MARK: - Severity Dot

private struct SeverityDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Recommendation Text

private struct RecommendationText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FVFont.body(13))
            .foregroundStyle(FVColor.silver)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Recommendation Trailing Icon

private struct RecommendationTrailingIcon: View {
    let hasAction: Bool
    let color: Color
    let isAnimated: Bool

    var body: some View {
        Image(systemName: hasAction ? "chevron.right" : "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .offset(x: isAnimated ? 4 : 0)
    }
}

// MARK: - Expirations Card

private struct SecurityExpirationsCard: View {
    let entries: [VaultEntry]
    var onEdit: (VaultEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FVSectionHeader(
                icon: "clock.arrow.circlepath",
                title: String(localized: "security.section.expirations")
            )

            if entries.isEmpty {
                ExpirationEmptyState()
            } else {
                ForEach(entries.prefix(6), id: \.id) { entry in
                    SecurityExpirationRow(
                        entry: entry,
                        onEdit: { onEdit(entry) }
                    )
                }
            }
        }
        .padding(20)
        .glassCard()
    }
}

// MARK: - Expiration Empty State

private struct ExpirationEmptyState: View {
    var body: some View {
        Text(String(localized: "security.expirations.none"))
            .font(FVFont.body(13))
            .foregroundStyle(FVColor.smoke)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Expiration Row

private struct SecurityExpirationRow: View {
    let entry: VaultEntry
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ExpirationEntryInfo(entry: entry)
            Spacer(minLength: 10)
            Button(String(localized: "security.action.change"), action: onEdit)
                .buttonStyle(FVSettingsButton(tint: FVColor.cyan))
        }
    }
}

// MARK: - Expiration Entry Info

private struct ExpirationEntryInfo: View {
    let entry: VaultEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title)
                .font(FVFont.title(15))
                .foregroundStyle(.white)
            if let days = entry.daysUntilExpiration {
                ExpirationDaysLabel(days: days)
            }
        }
    }
}

// MARK: - Expiration Days Label

private struct ExpirationDaysLabel: View {
    let days: Int

    var body: some View {
        Text(days < 0
             ? String(format: NSLocalizedString("security.expired.since %lld", comment: ""), abs(days))
             : String(format: NSLocalizedString("security.expires.in %lld", comment: ""), days))
            .font(FVFont.caption(11))
            .foregroundStyle(days < 0 ? FVColor.danger : FVColor.warning)
    }
}

// MARK: - Dark Web Monitoring Card

private struct SecurityDarkWebCard: View {
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var subscriptionService: SubscriptionService
    @ObservedObject var vaultStore: VaultStore
    @Binding var showPaywall: Bool
    var onEdit: (VaultEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DarkWebHeaderRow(isProUser: subscriptionService.isProUser)

            if !subscriptionService.isProUser {
                DarkWebLockedView(showPaywall: $showPaywall)
            } else if breachMonitor.isScanning {
                DarkWebScanningView(progress: breachMonitor.scanProgress)
            } else {
                DarkWebResultsView(
                    breachMonitor: breachMonitor,
                    vaultStore: vaultStore,
                    onEdit: onEdit
                )
            }
        }
        .padding(20)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(FVColor.violet.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Dark Web Header Row

private struct DarkWebHeaderRow: View {
    let isProUser: Bool

    var body: some View {
        HStack {
            FVSectionHeader(
                icon: "shield.checkerboard",
                title: String(localized: "security.section.darkweb")
            )
            Spacer()
            if !isProUser {
                FVProBadge()
            }
        }
    }
}

// MARK: - Dark Web Locked View

private struct DarkWebLockedView: View {
    @Binding var showPaywall: Bool

    var body: some View {
        VStack(spacing: 14) {
            DarkWebLockedIcon()
            DarkWebLockedDescription()
            DarkWebUnlockButton(showPaywall: $showPaywall)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Dark Web Locked Icon

private struct DarkWebLockedIcon: View {
    var body: some View {
        Image(systemName: "lock.shield.fill")
            .font(.system(size: 32))
            .foregroundStyle(FVColor.violet)
    }
}

// MARK: - Dark Web Locked Description

private struct DarkWebLockedDescription: View {
    var body: some View {
        Text("Analyse tes mots de passe contre les fuites du Dark Web")
            .font(FVFont.body(13))
            .foregroundStyle(FVColor.smoke)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Dark Web Unlock Button

private struct DarkWebUnlockButton: View {
    @Binding var showPaywall: Bool

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Debloquer avec Pro")
                    .font(FVFont.label(13))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(FVColor.gold)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dark Web Scanning View

private struct DarkWebScanningView: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DarkWebScanningStatus(progress: progress)
            ProgressView(value: progress, total: 1.0)
                .tint(FVColor.cyan)
        }
    }
}

// MARK: - Dark Web Scanning Status

private struct DarkWebScanningStatus: View {
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(FVColor.cyan)
            Text(String(format: NSLocalizedString("security.darkweb.scanning %lld", comment: ""), Int(progress * 100)))
                .font(FVFont.body(13))
                .foregroundStyle(FVColor.smoke)
        }
    }
}

// MARK: - Dark Web Results View

private struct DarkWebResultsView: View {
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var vaultStore: VaultStore
    var onEdit: (VaultEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DarkWebLastScanLabel(date: breachMonitor.lastScanDate)
            DarkWebBreachSummary(
                totalBreached: breachMonitor.totalBreached,
                hasScanned: breachMonitor.lastScanDate != nil
            )
            DarkWebScanButton(
                breachMonitor: breachMonitor,
                vaultStore: vaultStore
            )
            DarkWebBreachedList(
                breachMonitor: breachMonitor,
                vaultStore: vaultStore,
                onEdit: onEdit
            )
        }
    }
}

// MARK: - Dark Web Last Scan Label

private struct DarkWebLastScanLabel: View {
    let date: Date?

    var body: some View {
        if let lastDate = date {
            Text(String(format: NSLocalizedString("security.darkweb.last.scan %@", comment: ""), lastDate.formatted(.relative(presentation: .named))))
                .font(FVFont.caption(11))
                .foregroundStyle(FVColor.smoke)
        }
    }
}

// MARK: - Dark Web Breach Summary

private struct DarkWebBreachSummary: View {
    let totalBreached: Int
    let hasScanned: Bool

    var body: some View {
        if totalBreached > 0 {
            Label(
                String(format: NSLocalizedString("security.darkweb.breached %lld", comment: ""), totalBreached),
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(FVFont.body(13))
            .foregroundStyle(FVColor.danger)
        } else if hasScanned {
            Label(
                String(localized: "security.darkweb.no.breach"),
                systemImage: "checkmark.circle.fill"
            )
            .font(FVFont.body(13))
            .foregroundStyle(FVColor.success)
        }
    }
}

// MARK: - Dark Web Scan Button

private struct DarkWebScanButton: View {
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var vaultStore: VaultStore

    var body: some View {
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
            .background(FVColor.cyan.opacity(0.08))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(FVColor.cyan.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dark Web Breached List

private struct DarkWebBreachedList: View {
    @ObservedObject var breachMonitor: BreachMonitorService
    @ObservedObject var vaultStore: VaultStore
    var onEdit: (VaultEntry) -> Void

    var body: some View {
        if !breachMonitor.isScanning && breachMonitor.totalBreached > 0 {
            let breached = vaultStore.entries.filter {
                (breachMonitor.breachCount(for: $0.id) ?? 0) > 0
            }
            ForEach(breached.prefix(10), id: \.id) { entry in
                DarkWebBreachedRow(
                    entry: entry,
                    breachCount: breachMonitor.breachCount(for: entry.id),
                    onEdit: { onEdit(entry) }
                )
            }
        }
    }
}

// MARK: - Breached Entry Row

private struct DarkWebBreachedRow: View {
    let entry: VaultEntry
    let breachCount: Int?
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            BreachedEntryInfo(
                title: entry.title,
                breachCount: breachCount
            )
            Spacer(minLength: 10)
            Button(String(localized: "security.action.change"), action: onEdit)
                .buttonStyle(FVSettingsButton(tint: FVColor.danger))
        }
    }
}

// MARK: - Breached Entry Info

private struct BreachedEntryInfo: View {
    let title: String
    let breachCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FVFont.title(15))
                .foregroundStyle(.white)
            if let count = breachCount {
                Text(String(format: NSLocalizedString("security.darkweb.appeared.in %lld", comment: ""), count))
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.danger)
            }
        }
    }
}
