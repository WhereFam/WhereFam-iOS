// app/Core/Home/View/PeopleView.swift
import SwiftUI
import SQLiteData
import CoreImage.CIFilterBuiltins

struct PeopleView: View {
    @EnvironmentObject var rpc:         RPCViewModel
    @EnvironmentObject var coordinator: AppCoordinator

    @FetchAll(Person.order(by: \.name)) var people: [Person]

    @State private var showAdd      = false
    @State private var showInviteQR = false
    @State private var inviteQR:   UIImage?
    @State private var scanInput   = ""

    var body: some View {
        Group {
            if people.isEmpty {
                ContentUnavailableView(
                    "No people yet",
                    systemImage: "person.2",
                    description: Text("Tap + to invite a family member.")
                )
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
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "person.badge.plus") }
            }
        }
        // Add sheet — two options: generate invite QR or paste their invite
        .sheet(isPresented: $showAdd) {
            AddPersonSheet(rpc: rpc)
        }
        .onChange(of: rpc.pairingComplete) { _, complete in
            if complete { showAdd = false; rpc.pairingComplete = false }
        }
    }
}

// MARK: - Add person sheet

struct AddPersonSheet: View {
    let rpc: RPCViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .generate
    @State private var scanText  = ""
    @State private var inviteQR: UIImage?
    @State private var generating = false

    enum Mode: String, CaseIterable {
        case generate = "Show my invite"
        case scan     = "Enter their invite"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if mode == .generate {
                    generatePane
                } else {
                    scanPane
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Add Family Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if mode == .generate { Task { await generateInvite() } }
        }
        .onChange(of: mode) { _, m in
            if m == .generate && inviteQR == nil { Task { await generateInvite() } }
        }
    }

    @ViewBuilder private var generatePane: some View {
        VStack(spacing: 16) {
            if generating {
                ProgressView("Generating invite…")
            } else if let qr = inviteQR {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable().scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("They scan this with WhereFam to join your circle")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Text("Invite expires once used")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private var scanPane: some View {
        VStack(spacing: 16) {
            TextField("Paste their invite code", text: $scanText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)

            Button("Join") {
                guard !scanText.isEmpty else { return }
                Task {
                    await rpc.send(.joinWithInvite, data: ["invite": scanText.trimmingCharacters(in: .whitespaces)])
                    dismiss()
                }
            }
            .disabled(scanText.isEmpty)
            .buttonStyle(.borderedProminent)
        }
    }

    private func generateInvite() async {
        generating = true
        await rpc.send(.createInvite)
        // Wait for inviteCode to arrive via IPC
        var waited = 0
        while rpc.inviteCode.isEmpty && waited < 50 {
            try? await Task.sleep(for: .milliseconds(200))
            waited += 1
        }
        generating = false
        if !rpc.inviteCode.isEmpty { inviteQR = makeQR(rpc.inviteCode) }
    }

    private func makeQR(_ string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M",  forKey: "inputCorrectionLevel")
        guard let out = filter.outputImage else { return nil }
        let scaled = out.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Person row (unchanged)

struct PersonRowView: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            avatarView.frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name ?? "Unknown").font(.body.weight(.medium))
                HStack(spacing: 5) {
                    Circle()
                        .fill(person.isOnline ? Color.green : Color(.systemFill))
                        .frame(width: 7, height: 7)
                    Text(person.lastSeenText).font(.caption).foregroundStyle(.secondary)
                    if person.isDriving { Text("· Driving").font(.caption).foregroundStyle(.orange) }
                }
            }
            Spacer()
            if let level = person.batteryLevel { batteryView(level: level, charging: person.batteryCharging ?? false) }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var avatarView: some View {
        if let data = person.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(Color.blue.opacity(0.12))
                .overlay(Text(person.initials).font(.system(size: 15, weight: .semibold)).foregroundStyle(.blue))
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
