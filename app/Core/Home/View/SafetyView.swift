// app/Core/Home/View/SafetyView.swift
import SwiftUI

struct SafetyView: View {
    @EnvironmentObject var safety: SafetyManager

    var body: some View {
        List {
            Section {
                sosSection
            } header: {
                Text("Emergency")
            } footer: {
                Text("Sends your live location to every person in your WhereFam circle over an encrypted peer-to-peer connection.")
            }

            Section("Crash detection") {
                HStack(spacing: 12) {
                    Image(systemName: "car.side.and.exclamationmark")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Powered by Apple SafetyKit")
                            .font(.body.weight(.medium))
                        Text("Automatically alerts your circle if a severe crash is detected on iPhone 14 or later.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if let date = safety.lastCrashDate {
                    LabeledContent("Last detected") {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder private var sosSection: some View {
        switch safety.sosState {
        case .idle:
            Button(role: .destructive) {
                safety.triggerManualSOS()
            } label: {
                Label("Send SOS to Circle", systemImage: "sos")
                    .font(.headline)
            }

        case .countdown(let secs):
            VStack(spacing: 12) {
                Text("Sending SOS in \(secs)s…")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.red)
                Button("Cancel") { safety.cancelSOS() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

        case .active:
            Label("SOS sent to your circle", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)

        case .cancelled:
            Label("SOS cancelled", systemImage: "xmark.circle")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SafetyView()
        .environmentObject(SafetyManager.shared)
}
