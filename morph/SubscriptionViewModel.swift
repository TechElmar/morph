import SwiftUI
import StoreKit
import Combine

@MainActor
final class SubscriptionViewModel: ObservableObject {
    /// True StoreKit entitlement (a real/sandbox subscription is active).
    @Published private var storeKitPro: Bool = false
    /// Server-side comp: this account was granted Pro for free (profiles.is_pro).
    @Published private var isComped: Bool = false
    /// Pro access = a real subscription OR a comped account.
    var isPro: Bool { storeKitPro || isComped }

    @Published var isLoading: Bool = false
    @Published var isLoadingProducts: Bool = false
    @Published var productLoadFailed: Bool = false
    @Published var products: [Product] = []
    @Published var errorMessage: String?
    @Published var purchaseJustSucceeded: Bool = false

    static let monthlyProductID = "com.morph.pro.monthly"
    static let yearlyProductID  = "com.morph.pro.annual"
    static let allProductIDs: Set<String> = [monthlyProductID, yearlyProductID]

    private var transactionListener: Task<Void, Never>?

    init() {
        // Listen for transactions that arrive outside the purchase flow:
        // renewals, Ask to Buy approvals, purchases on other devices, refunds.
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Products

    func loadProducts() async {
        isLoadingProducts = true
        do {
            let loaded = try await Product.products(for: Self.allProductIDs)
            products = loaded.sorted { $0.price < $1.price }
            // An empty result is a failure too: wrong product IDs, products not
            // yet approved, or no StoreKit config when running from the sim.
            productLoadFailed = loaded.isEmpty
        } catch {
            products = []
            productLoadFailed = true
            print("StoreKit product load failed: \(error)")
        }
        isLoadingProducts = false
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyProductID } }
    var yearlyProduct: Product?  { products.first { $0.id == Self.yearlyProductID } }

    /// Percent saved on yearly vs 12 months of monthly, e.g. "Save 52%"
    var yearlySavings: String? {
        guard let m = monthlyProduct, let y = yearlyProduct else { return nil }
        let monthlyAnnual = m.price * 12
        guard monthlyAnnual > 0 else { return nil }
        let savings = (monthlyAnnual - y.price) / monthlyAnnual * 100
        let percent = NSDecimalNumber(decimal: savings).intValue
        return percent > 0 ? "Save \(percent)%" : nil
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    if storeKitPro {
                        purchaseJustSucceeded = true
                        Haptics.success()
                    }
                case .unverified:
                    errorMessage = "Purchase could not be verified."
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro {
                errorMessage = "No active subscription found."
            }
        } catch let error {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        storeKitPro = pro
    }

    // MARK: - Comp override (server-side free Pro)

    /// Reads profiles.is_pro for the signed-in account. Lets us grant Pro to
    /// specific accounts (App Review, friends) without an actual purchase.
    func refreshComped() async {
        guard let session = SupabaseClient.loadSession() else {
            isComped = false
            return
        }
        do {
            let (rows, _) = try await SupabaseClient.shared.select(
                path: "/profiles?id=eq.\(session.userID)&select=is_pro", session: session)
            isComped = (rows.first?["is_pro"] as? Bool) ?? false
        } catch {
            // Leave the current value on transient failure.
        }
    }
}
