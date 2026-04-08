// app/Core/Home/View/ShareIDView.swift
import SwiftUI
import CoreImage.CIFilterBuiltins

struct ShareIDView: View {
    @EnvironmentObject var rpc: RPCViewModel
    @State private var qrImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Group {
                    if let qr = qrImage {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable().scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemFill))
                            .frame(width: 200, height: 200)
                            .overlay(
                                rpc.publicKey.isEmpty
                                ? AnyView(ProgressView())
                                : AnyView(EmptyView())
                            )
                    }
                }
                
                HStack {
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                    Text("or copy ID").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 8)
                    Rectangle().fill(Color(.separator)).frame(height: 0.5)
                }.padding(.horizontal, 32)
                
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
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                                .foregroundStyle(.blue)
                                .padding(10)
                                .background(Color(.secondarySystemFill))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Copy ID")
                    }
                    .padding(.horizontal, 24)
                } else {
                    Text("Connecting…")
                        .font(.caption).foregroundStyle(.secondary)
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
            // If we already have the key just generate the QR
            if !rpc.publicKey.isEmpty {
                generateQR()
            } else {
                // Request it from the JS side — response comes via publicKeyResponse
                Task { await rpc.send(.requestPublicKey) }
            }
        }
        .onChange(of: rpc.publicKey) { _, _ in generateQR() }
    }
    
    private func generateQR() {
        guard !rpc.publicKey.isEmpty else { return }
        let b64url = rpc.publicKey
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        guard let data = "wherefam://add?id=\(b64url)".data(using: .utf8) else { return }
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
