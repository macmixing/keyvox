import Foundation
import StoreKit

struct StoreUnlockProduct: Equatable {
    let id: String
    let displayName: String
    let displayPrice: String
}

protocol StoreUnlockStore {
    func loadUnlockProduct(productID: String) async throws -> StoreUnlockProduct?
    func isUnlocked(productID: String) async throws -> Bool
    func purchase(productID: String) async throws -> Bool
    func restore(productID: String) async throws -> Bool
}

struct AppStoreUnlockStore: StoreUnlockStore {
    func loadUnlockProduct(productID: String) async throws -> StoreUnlockProduct? {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            return nil
        }

        return StoreUnlockProduct(
            id: product.id,
            displayName: product.displayName,
            displayPrice: product.displayPrice
        )
    }

    func isUnlocked(productID: String) async throws -> Bool {
        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.productID == productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            return true
        }

        return false
    }

    func purchase(productID: String) async throws -> Bool {
        let products = try await Product.products(for: [productID])
        guard let product = products.first(where: { $0.id == productID }) else {
            return false
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verificationResult):
            guard case .verified(let transaction) = verificationResult else {
                return false
            }
            await transaction.finish()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore(productID: String) async throws -> Bool {
        try await AppStore.sync()
        return try await isUnlocked(productID: productID)
    }
}
