// app/Manager/StoreKitManager.swift
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    private static let tipID = "com.wherefam.tip"

    @Published var products: [Product] = []
    @Published var hasTipped: Bool = false

    private var listenerTask: Task<Void, Never>?

    private init() {
        listenerTask = Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await MainActor.run { self.hasTipped = true }
                }
            }
        }
        Task { await loadProducts(); await refreshEntitlements() }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: [Self.tipID])) ?? []
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let v) = result, case .verified(let tx) = v {
            await tx.finish(); hasTipped = true
        }
    }

    func refreshEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.tipID, tx.revocationDate == nil {
                hasTipped = true; return
            }
        }
    }
}