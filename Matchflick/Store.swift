import Foundation
import StoreKit

/// StoreKit 2 — auto-renewable monthly subscription (`minder_pro_monthly`).
/// Pro is NEVER persisted as truth: it is derived live from `Transaction.currentEntitlements`,
/// granted only on a `.verified`, unexpired, unrevoked transaction.
@MainActor
final class Store: ObservableObject {
    static let productID = "minder_pro_monthly"

    @Published private(set) var isPro = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false

    private var updatesTask: Task<Void, Never>?

    /// DEBUG/sim only — lets us verify the Pro UI without a sandbox account. Off in Release.
    private var debugForcePro: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["MATCHFLICK_FORCE_PRO"] == "1"
        #else
        return false
        #endif
    }

    init() {
        updatesTask = listenForTransactions()
        Task {
            #if DEBUG
            // MATCHFLICK_NO_SK skips the product fetch so headless screenshot runs (no StoreKit config /
            // no App Store account) don't trigger the system "Sign in to Apple Account" prompt.
            if ProcessInfo.processInfo.environment["MATCHFLICK_NO_SK"] != "1" { await loadProduct() }
            #else
            await loadProduct()
            #endif
            await refreshEntitlements()
        }
    }

    deinit { updatesTask?.cancel() }

    var displayPrice: String { product?.displayPrice ?? "$2.99" }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Store.productID])
            self.product = products.first
        } catch {
            self.product = nil
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Store.productID, transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled || debugForcePro
    }

    /// Returns true only when a verified purchase has been granted.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
    }
}
