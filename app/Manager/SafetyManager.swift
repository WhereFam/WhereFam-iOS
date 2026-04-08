// app/Manager/SafetyManager.swift
// SafetyKit crash detection is disabled until the entitlement is granted.
// Request at: developer.apple.com/contact/request/safetykit
import UserNotifications
import UIKit

@MainActor
final class SafetyManager: NSObject, ObservableObject {
    static let shared = SafetyManager()

    enum SOSState: Equatable {
        case idle, countdown(secondsLeft: Int), active, cancelled
    }

    @Published var sosState: SOSState = .idle
    @Published var lastCrashDate: Date?

    var broadcastSOS: ((SOSPayload) async -> Void)?

    struct SOSPayload {
        let type: String
        let latitude: Double?
        let longitude: Double?
        let timestamp: Date
    }

    private var countdownTask: Task<Void, Never>?
    private override init() { super.init() }

    // No-op until SafetyKit entitlement is granted
    func start() {
        print("[Safety] SafetyKit entitlement not yet granted — crash detection disabled")
    }

    func triggerManualSOS() {
        guard sosState == .idle else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        sosState = .countdown(secondsLeft: 10)
        countdownTask = Task { [weak self] in
            for i in stride(from: 10, through: 1, by: -1) {
                guard let self, case .countdown = self.sosState else { return }
                self.sosState = .countdown(secondsLeft: i)
                try? await Task.sleep(for: .seconds(1))
            }
            await self?.fireSOS(type: "manual")
        }
    }

    func cancelSOS() {
        countdownTask?.cancel()
        sosState = .cancelled
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { self?.sosState = .idle }
        }
    }

    private func fireSOS(type: String) async {
        sosState = .active
        let loc = LocationManager.shared.userLocation
        let payload = SOSPayload(
            type: type,
            latitude: loc?.coordinate.latitude,
            longitude: loc?.coordinate.longitude,
            timestamp: Date()
        )
        await broadcastSOS?(payload)
        let c = UNMutableNotificationContent()
        c.title = type == "crash" ? "Crash detected" : "SOS sent"
        c.body  = "Your location was shared with your WhereFam circle."
        c.sound = .defaultCritical
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "sos-\(Date().timeIntervalSince1970)",
                                  content: c, trigger: nil))
    }
}
