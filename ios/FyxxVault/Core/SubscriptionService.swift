import StoreKit
import Foundation

// MARK: - FyxxVault Subscription Service (StoreKit 2)

@MainActor
final class SubscriptionService: ObservableObject {
    @Published var isProUser: Bool = false
    @Published var currentSubscriptionID: String? = nil
    @Published var availableProducts: [Product] = []
    @Published var purchaseInProgress: Bool = false
    @Published var errorMessage: String? = nil

    static let proMonthlyID = "com.fyxx.fyxxvault.pro.monthly"
    static let proYearlyID = "com.fyxx.fyxxvault.pro.yearly"

    private static let proProductIDs: Set<String> = [proMonthlyID, proYearlyID]
    private static let entitlementCacheKey = "fyxxvault.subscription.isProCached"

    private var transactionListener: Task<Void, Never>? = nil

    init() {
        // Load cached entitlement for instant UI (will be verified async)
        isProUser = UserDefaults.standard.bool(forKey: Self.entitlementCacheKey)

        // Start listening for transaction updates
        transactionListener = listenForTransactions()

        // Check current entitlements and load products
        Task {
            await checkEntitlements()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: Self.proProductIDs)
            availableProducts = products.sorted { ($0.subscription?.subscriptionPeriod.unit.rawValue ?? 0) < ($1.subscription?.subscriptionPeriod.unit.rawValue ?? 0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if Self.proProductIDs.contains(transaction.productID) {
                hasActiveSubscription = true
                break
            }
        }

        isProUser = hasActiveSubscription
        cacheEntitlementStatus(hasActiveSubscription)

        // Also update current subscription status
        await updateSubscriptionStatus()
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        purchaseInProgress = true
        errorMessage = nil

        defer { purchaseInProgress = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                errorMessage = "Transaction verification failed."
                return
            }
            await transaction.finish()
            await checkEntitlements()

        case .userCancelled:
            break

        case .pending:
            // Transaction requires approval (e.g. Ask to Buy)
            break

        @unknown default:
            break
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        purchaseInProgress = true
        errorMessage = nil

        defer { purchaseInProgress = false }

        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.checkEntitlements()
            }
        }
    }

    // MARK: - Subscription Status

    private func updateSubscriptionStatus() async {
        guard let product = availableProducts.first(where: { $0.subscription != nil }) ?? (try? await Product.products(for: Self.proProductIDs)).flatMap({ $0.first }) else { return }

        guard let subscription = product.subscription else { return }

        do {
            let statuses = try await subscription.status
            let activeStatus = statuses.first { status in
                guard case .verified(let renewalInfo) = status.renewalInfo,
                      case .verified(_) = status.transaction else { return false }
                return Self.proProductIDs.contains(renewalInfo.currentProductID)
            }
            if case .verified(let renewalInfo) = activeStatus?.renewalInfo {
                currentSubscriptionID = renewalInfo.currentProductID
            } else {
                currentSubscriptionID = nil
            }
        } catch {
            // Subscription status unavailable
        }
    }

    // MARK: - Cache

    private func cacheEntitlementStatus(_ isPro: Bool) {
        UserDefaults.standard.set(isPro, forKey: Self.entitlementCacheKey)
    }

    // MARK: - Helpers

    var monthlyProduct: Product? {
        availableProducts.first { $0.id == Self.proMonthlyID }
    }

    var yearlyProduct: Product? {
        availableProducts.first { $0.id == Self.proYearlyID }
    }
}
