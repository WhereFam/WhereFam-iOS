// app/Core/Home/View/StoreKitPaywallView.swift
import SwiftUI
import StoreKit

struct StoreKitPaywallView: View {
    @EnvironmentObject var store: StoreKitManager
    @State private var purchasing = false
    @State private var errorMsg: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.pink)

                VStack(spacing: 8) {
                    Text("Support WhereFam")
                        .font(.title2.weight(.semibold))
                    Text("WhereFam is free, private, and open-source. A one-time tip keeps it that way.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                if store.hasTipped {
                    Label("Thank you so much! ❤️", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green).font(.headline)
                } else if store.products.isEmpty {
                    ProgressView()
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.products) { product in
                            Button { Task { await buy(product) } } label: {
                                HStack {
                                    Text(product.displayName).font(.headline)
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.pink.opacity(0.1))
                                .foregroundStyle(.pink)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(purchasing)
                        }
                    }
                    .padding(.horizontal)
                }

                if let err = errorMsg {
                    Text(err).font(.caption).foregroundStyle(.red)
                }

                Spacer()

                Button("Restore Purchases") {
                    Task { try? await AppStore.sync(); await store.refreshEntitlements() }
                }
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.bottom)
            }
            .navigationTitle("Support App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func buy(_ product: Product) async {
        purchasing = true; errorMsg = nil
        do { try await store.purchase(product) }
        catch { errorMsg = "Purchase failed. Please try again." }
        purchasing = false
    }
}