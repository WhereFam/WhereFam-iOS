// app/Core/Home/View/ShareIDView.swift
// Shows your permanent public key QR — for manual sharing
// The invite-based pairing QR is in PeopleView > AddPersonSheet
import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareIDView: View {
    @EnvironmentObject var rpc: RPCViewModel
    @State private var qrImage: UIImage?
    @State private var copied  = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if let qr = qrImage {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable().scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemFill))
                        .frame(width: 200, height: 200)
                        .overlay(ProgressView())
                }

                VStack(spacing: 6) {
                    Text("Your permanent WhereFam ID")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("For one-tap adding, use the invite QR in People → +")
                        .font(.caption).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                // Key display
                if !rpc.publicKey.isEmpty {
                    HStack(spacing: 8) {
                        Text(rpc.publicKey)
                            .font(.caption.monospaced())
                            .lineLimit(1).truncationMode(.middle)
                            .padding(10)
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            UIPasteboard.general.string = rpc.publicKey
                            copied = true
                            Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.clipboard")
                                .foregroundStyle(.blue)
                                .padding(10)
                                .background(Color(.secondarySystemFill))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
            }
            .navigationTitle("Your ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let qr = qrImage {
                        let img = Image(uiImage: qr)
                        ShareLink(item: img, preview: SharePreview("My WhereFam ID", image: img)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !rpc.publicKey.isEmpty { generateQR() }
            else { Task { await rpc.send(.requestPublicKey) } }
        }
        .onChange(of: rpc.publicKey) { _, _ in generateQR() }
    }

    private func generateQR() {
        guard !rpc.publicKey.isEmpty else { return }
        // Encode as wherefam://add?id=<key> — permanent ID deep link
        guard let data = "wherefam://add?id=\(rpc.publicKey)".data(using: .utf8) else { return }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M",  forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return }
        qrImage = UIImage(cgImage: cg)
    }
}

#Preview {
    ShareIDView()
        .environmentObject(RPCViewModel())
}
