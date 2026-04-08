// app/Core/Home/View/PeopleView.swift
import SwiftUI
import SQLiteData
import CoreImage.CIFilterBuiltins
import AVFoundation

struct PeopleView: View {
    @EnvironmentObject var rpc:         RPCViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @FetchAll(Person.order(by: \.name)) var people: [Person]

    @State private var showMyInvite  = false  // + button → show my QR
    @State private var showScanner   = false  // scan icon → scan theirs

    var body: some View {
        Group {
            if people.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2").font(.system(size: 52)).foregroundStyle(.secondary)
                    Text("No people yet").font(.title3.weight(.semibold))
                    Text("Tap + to get your invite code and share it with family.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    Button("Get my invite code") { showMyInvite = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                List {
                    ForEach(people) { person in
                        NavigationLink(destination: PersonDetailView(person: person)) {
                            PersonRowView(person: person)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            Task { await coordinator.removePeer(id: people[i].id) }
                        }
                    }
                }
            }
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Left — scan their QR
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20))
                }
            }
            // Right — show my invite
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMyInvite = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // My invite sheet
        .sheet(isPresented: $showMyInvite) {
            MyInviteSheet(rpc: rpc)
        }
        // Scanner sheet
        .sheet(isPresented: $showScanner) {
            ScannerSheet(rpc: rpc, dismiss: { showScanner = false })
        }
        // Deep link from system camera scan
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkAddPeer)) { note in
            guard let code = note.userInfo?["peerID"] as? String else { return }
            Task { await rpc.send(.joinWithInvite, data: ["invite": code]) }
        }
        .onChange(of: rpc.pairingComplete) { _, done in
            if done { showMyInvite = false; showScanner = false; rpc.pairingComplete = false }
        }
    }
}

// MARK: - My invite sheet (shown when + is tapped)

struct MyInviteSheet: View {
    @ObservedObject var rpc: RPCViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode = ""
    @State private var qrImage:   UIImage?
    @State private var generating = false
    @State private var copied     = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                // QR code
                Group {
                    if generating {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemFill))
                            .frame(width: 220, height: 220)
                            .overlay(ProgressView())
                    } else if let qr = qrImage {
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable().scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: .black.opacity(0.08), radius: 8)
                    }
                }

                VStack(spacing: 6) {
                    Text("Share this with family")
                        .font(.headline)
                    Text("They scan it in WhereFam, or you can copy the code below and send it via iMessage.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 24)
                }

                // Actions
                if !inviteCode.isEmpty {
                    Button {
                        UIPasteboard.general.string = "wherefam://invite?code=\(inviteCode)"
                        copied = true
                        Task { try? await Task.sleep(for: .seconds(2)); copied = false }
                    } label: {
                        Label(copied ? "Copied!" : "Copy invite link",
                              systemImage: copied ? "checkmark" : "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 24)

                    Button {
                        Task { await generate() }
                    } label: {
                        Label("Generate new invite", systemImage: "arrow.clockwise")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .navigationTitle("Your Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !inviteCode.isEmpty {
                        let url = "wherefam://invite?code=\(inviteCode)"
                        ShareLink(item: url,
                                  subject: Text("Join me on WhereFam"),
                                  message: Text("Tap to join my WhereFam family circle: \(url)")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .task { await generate() }
        .onChange(of: rpc.inviteCode) { _, code in
            guard !code.isEmpty else { return }
            inviteCode     = code
            qrImage        = makeQR(code)
            generating     = false
            rpc.inviteCode = ""
        }
    }

    private func generate() async {
        generating = true
        inviteCode = ""
        qrImage    = nil
        await rpc.send(.createInvite)
        for _ in 0..<50 {
            try? await Task.sleep(for: .milliseconds(200))
            if !rpc.inviteCode.isEmpty { return }
        }
        generating = false
    }

    private func makeQR(_ code: String) -> UIImage? {
        // Encode as deep link so iOS camera opens WhereFam automatically
        guard let data = "wherefam://invite?code=\(code)".data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M",  forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Scanner sheet (shown when scan icon tapped)

struct ScannerSheet: View {
    @ObservedObject var rpc: RPCViewModel
    let dismiss: () -> Void
    @State private var scanned = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                QRScannerView { code in
                    guard !scanned else { return }
                    scanned = true
                    Task {
                        await rpc.send(.joinWithInvite, data: ["invite": code])
                        dismiss()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .frame(height: 320)

                Text("Scan their invite QR code")
                    .font(.subheadline).foregroundStyle(.secondary)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Scan Invite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - QR Scanner

class PreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

struct QRScannerView: UIViewRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIView(context: Context) -> PreviewView {
        let view    = PreviewView()
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input  = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return view }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.previewLayer = preview
        view.layer.addSublayer(preview)
        context.coordinator.session = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScan: (String) -> Void
        var session: AVCaptureSession?
        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj    = objects.first as? AVMetadataMachineReadableCodeObject,
                  let string = obj.stringValue else { return }
            session?.stopRunning()

            // Extract invite code from wherefam://invite?code=<hex> or use raw string
            let code: String
            if let url        = URL(string: string),
               url.scheme     == "wherefam",
               url.host       == "invite",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let item       = components.queryItems?.first(where: { $0.name == "code" }),
               let value      = item.value {
                code = value
            } else {
                code = string
            }
            onScan(code)
        }
    }
}

// MARK: - Person row

struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            avatarView.frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name ?? String(person.id.prefix(12)))
                    .font(.body.weight(.medium))
                HStack(spacing: 5) {
                    Circle()
                        .fill(person.isOnline ? Color.green : Color(.systemFill))
                        .frame(width: 7, height: 7)
                    Text(person.lastSeenText).font(.caption).foregroundStyle(.secondary)
                    if person.isDriving { Text("· Driving").font(.caption).foregroundStyle(.orange) }
                }
            }
            Spacer()
            if let level = person.batteryLevel {
                batteryView(level: level, charging: person.batteryCharging ?? false)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var avatarView: some View {
        if let data = person.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(Color.blue.opacity(0.12))
                .overlay(Text(person.initials)
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.blue))
        }
    }

    private func batteryView(level: Float, charging: Bool) -> some View {
        HStack(spacing: 2) {
            Image(systemName: charging ? "battery.100.bolt" : batteryIcon(level))
                .foregroundStyle(level < 0.2 && !charging ? .red : .secondary)
            Text("\(Int(level * 100))%").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func batteryIcon(_ l: Float) -> String {
        switch l {
        case ..<0.25: return "battery.25"
        case ..<0.50: return "battery.50"
        case ..<0.75: return "battery.75"
        default:      return "battery.100"
        }
    }
}

#Preview {
    PeopleView()
        .environmentObject(RPCViewModel())
        .environmentObject(AppCoordinator())
}
