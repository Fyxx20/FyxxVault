import SwiftUI
import StoreKit

// MARK: - FyxxVault Pro Paywall

struct PaywallView: View {
    @ObservedObject var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: PlanType = .yearly
    @State private var appeared = false
    @State private var shimmerOffset: CGFloat = -300
    @State private var purchaseError: String? = nil

    enum PlanType: String {
        case monthly, yearly
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background
            FVAnimatedBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Spacer for close button
                    Color.clear.frame(height: 20)

                    headerSection
                    featuresSection
                    pricingSection
                    ctaSection
                    footerSection

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)

            // Close button
            closeButton
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
        .alert("Error", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            fvHaptic(.light)
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(FVColor.smoke)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .padding(.top, 16)
        .padding(.trailing, 24)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(FVColor.gold.opacity(0.12))
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(FVColor.gold.opacity(0.06))
                    .frame(width: 110, height: 110)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FVColor.gold, FVColor.goldLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(appeared ? 1 : 0.5)
            .opacity(appeared ? 1 : 0)

            // Title with gold gradient
            Text(String(localized: "paywall.title"))
                .font(FVFont.display(28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FVColor.gold, FVColor.goldLight, FVColor.gold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)

            Text(String(localized: "paywall.subtitle"))
                .font(FVFont.body(15))
                .foregroundStyle(FVColor.mist.opacity(0.8))
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
        }
        .padding(.top, 10)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "cloud.fill", text: String(localized: "paywall.feature.cloud"), color: FVColor.cyan)
            featureRow(icon: "envelope.badge.shield.half.filled", text: String(localized: "paywall.feature.masked"), color: FVColor.violet)
            featureRow(icon: "eye.trianglebadge.exclamationmark", text: String(localized: "paywall.feature.darkweb"), color: FVColor.rose)
            featureRow(icon: "person.2.fill", text: String(localized: "paywall.feature.sharing"), color: FVColor.success)
            featureRow(icon: "headset.circle.fill", text: String(localized: "paywall.feature.support"), color: FVColor.gold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fvGlass()
        .fvSectionBorder(FVColor.gold)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func featureRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(FVFont.body(14))
                .foregroundStyle(FVColor.silver)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(FVColor.success)
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(spacing: 12) {
            // Monthly plan
            planCard(
                type: .monthly,
                title: String(localized: "paywall.monthly"),
                price: subscriptionService.monthlyProduct?.displayPrice ?? "$2.99",
                period: String(localized: "paywall.monthly.price"),
                badge: nil
            )

            // Yearly plan
            planCard(
                type: .yearly,
                title: String(localized: "paywall.yearly"),
                price: subscriptionService.yearlyProduct?.displayPrice ?? "$24.99",
                period: String(localized: "paywall.yearly.price"),
                badge: String(localized: "paywall.yearly.save")
            )
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    private func planCard(type: PlanType, title: String, price: String, period: String, badge: String?) -> some View {
        let isSelected = selectedPlan == type

        return Button {
            fvHaptic(.light)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = type
            }
        } label: {
            HStack(spacing: 14) {
                // Radio indicator
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? FVColor.cyan : FVColor.ash, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(FVColor.cyan)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(FVFont.title(16))
                            .foregroundStyle(.white)

                        if let badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(FVColor.abyss)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(FVGradient.goldShimmer)
                                .clipShape(Capsule())
                        }
                    }

                    Text(period)
                        .font(FVFont.caption(12))
                        .foregroundStyle(FVColor.mist)
                }

                Spacer()

                Text(price)
                    .font(FVFont.heading(18))
                    .foregroundStyle(isSelected ? FVColor.cyan : FVColor.silver)
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isSelected ? FVColor.cyan.opacity(0.04) : Color.clear)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? FVColor.cyan.opacity(0.5) : Color.white.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: isSelected ? FVColor.cyan.opacity(0.15) : .clear, radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Purchase button
            Button {
                fvHaptic(.medium)
                Task {
                    await performPurchase()
                }
            } label: {
                HStack(spacing: 8) {
                    if subscriptionService.purchaseInProgress {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(FVColor.abyss)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                        Text(String(localized: "paywall.cta"))
                            .font(FVFont.label(16))
                    }
                }
                .foregroundStyle(FVColor.abyss)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(FVGradient.goldShimmer)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    // Shimmer
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.2), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerOffset)
                        .mask(RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(FVColor.goldLight.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: FVColor.gold.opacity(0.3), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(subscriptionService.purchaseInProgress)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)

            // Restore purchases
            Button {
                fvHaptic(.light)
                Task {
                    await subscriptionService.restorePurchases()
                    if subscriptionService.isProUser {
                        dismiss()
                    }
                }
            } label: {
                Text(String(localized: "paywall.restore"))
                    .font(FVFont.body(13))
                    .foregroundStyle(FVColor.cyan.opacity(0.8))
            }
            .disabled(subscriptionService.purchaseInProgress)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 20) {
            Button {
                // Open Terms of Service URL
                if let url = URL(string: "https://fyxxvault.com/terms") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(String(localized: "paywall.terms"))
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.smoke)
            }

            Circle()
                .fill(FVColor.ash)
                .frame(width: 3, height: 3)

            Button {
                // Open Privacy Policy URL
                if let url = URL(string: "https://fyxxvault.com/privacy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(String(localized: "paywall.privacy"))
                    .font(FVFont.caption(11))
                    .foregroundStyle(FVColor.smoke)
            }
        }
    }

    // MARK: - Purchase Logic

    private func performPurchase() async {
        let product: Product? = selectedPlan == .monthly
            ? subscriptionService.monthlyProduct
            : subscriptionService.yearlyProduct

        guard let product else {
            purchaseError = "Product not available."
            return
        }

        do {
            try await subscriptionService.purchase(product)
            if subscriptionService.isProUser {
                dismiss()
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }
}
