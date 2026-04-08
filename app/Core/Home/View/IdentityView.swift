// app/Core/Home/View/IdentityView.swift
import SwiftUI

struct IdentityView: View {
    @EnvironmentObject var rpc: RPCViewModel
    @State private var showKey     = false
    @State private var copySuccess = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Your WhereFam identity is a cryptographic keypair stored only on this device. Your public key is your permanent address — share it so family can find you.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }

                Section("Your public key") {
                    Text(rpc.publicKey)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)

                    Button {
                        UIPasteboard.general.string = rpc.publicKey
                        copySuccess = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copySuccess = false
                        }
                    } label: {
                        Label(
                            copySuccess ? "Copied!" : "Copy public key",
                            systemImage: copySuccess ? "checkmark" : "doc.on.clipboard"
                        )
                    }
                }

                Section("Privacy") {
                    Label("Your location never leaves your device unencrypted", systemImage: "lock.shield")
                    Label("Shared only with people you add", systemImage: "person.2.fill")
                    Label("No server ever sees your data", systemImage: "xmark.icloud")
                }
                .foregroundStyle(.secondary)
                .font(.subheadline)
            }
            .navigationTitle("Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
