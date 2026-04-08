// app/Manager/AppCoordinator.swift
import Foundation
import CoreLocation

@MainActor
final class AppCoordinator: ObservableObject {

    enum AppState { case idle, booting, ready, failed(String) }
    @Published var state: AppState = .idle

    private var rpc: RPCViewModel?

    func start(rpc: RPCViewModel) async {
        guard case .idle = state else { return }
        self.rpc = rpc
        state = .booting

        await rpc.send(.start, data: ["path": URL.documentsDirectory.path()])

        guard await waitForReady(rpc: rpc) else {
            state = .failed("Bare worker timed out")
            return
        }

        // Re-join saved peers on boot
        let saved = (try? fetchAllPeople()) ?? []
        for p in saved {
            await rpc.send(.joinPeer,       data: p.id)
            await rpc.send(.requestHistory, data: ["peerKey": p.id])
        }

        LocationManager.shared.rpc = rpc
        LocationManager.shared.requestPermission()
        startLocationStream(rpc: rpc)

        SafetyManager.shared.start()
        wireSafetyBroadcast(rpc: rpc)
        wirePlaceEventBroadcast(rpc: rpc)
        wireBatteryBroadcast(rpc: rpc)

        BackgroundTaskManager.shared.scheduleBurstIfNeeded()
        PlaceManager.shared.syncRegions()
        await syncProfile(rpc: rpc)

        state = .ready

        // Handle deep link invite that arrived during cold launch
        if let invite = AppEnvironment.shared.pendingInvite {
            AppEnvironment.shared.pendingInvite = nil
            await rpc.send(.joinWithInvite, data: ["invite": invite])
        }
    }

    private func waitForReady(rpc: RPCViewModel) async -> Bool {
        let deadline = Date().addingTimeInterval(15)
        while !rpc.isReady && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return rpc.isReady
    }

    private func startLocationStream(rpc: RPCViewModel) {
        Task { [weak self] in
            guard self != nil else { return }
            for await location in LocationManager.shared.locationUpdates() {
                guard rpc.isReady, !rpc.publicKey.isEmpty else { continue }
                var payload: [String: Any] = [
                    "id":              rpc.publicKey,
                    "name":            UserDefaults.standard.string(forKey: "userName") ?? "",
                    "latitude":        location.coordinate.latitude,
                    "longitude":       location.coordinate.longitude,
                    "altitude":        location.altitude,
                    "speed":           max(location.speed, 0),
                    "timestamp":       Date().timeIntervalSince1970 * 1000,
                    "batteryLevel":    Double(BatteryManager.shared.level),
                    "batteryCharging": BatteryManager.shared.isCharging
                ]
                if let b64 = UserDefaults.standard.string(forKey: "userAvatarBase64") {
                    payload["avatarData"] = b64
                }
                await rpc.send(.locationUpdate, data: payload)
            }
        }
    }

    private func wireSafetyBroadcast(rpc: RPCViewModel) {
        SafetyManager.shared.broadcastSOS = { p in
            await rpc.send(.sosAlert, data: [
                "id":        rpc.publicKey,
                "name":      UserDefaults.standard.string(forKey: "userName") ?? "",
                "type":      p.type,
                "latitude":  p.latitude as Any,
                "longitude": p.longitude as Any,
                "timestamp": p.timestamp.timeIntervalSince1970 * 1000
            ])
        }
    }

    private func wirePlaceEventBroadcast(rpc: RPCViewModel) {
        NotificationCenter.default.addObserver(
            forName: .placeEventOccurred, object: nil, queue: .main
        ) { note in
            guard let event     = note.userInfo?["event"]     as? String,
                  let placeName = note.userInfo?["placeName"] as? String,
                  let emoji     = note.userInfo?["emoji"]     as? String else { return }
            Task {
                await rpc.send(.placeEvent, data: [
                    "id":        rpc.publicKey,
                    "name":      UserDefaults.standard.string(forKey: "userName") ?? "",
                    "event":     event,
                    "placeName": placeName,
                    "emoji":     emoji,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ])
            }
        }
    }

    private func wireBatteryBroadcast(rpc: RPCViewModel) {
        NotificationCenter.default.addObserver(
            forName: .batteryBecameLow, object: nil, queue: .main
        ) { _ in
            Task {
                await rpc.send(.batteryUpdate, data: [
                    "id":              rpc.publicKey,
                    "name":            UserDefaults.standard.string(forKey: "userName") ?? "",
                    "batteryLevel":    Double(BatteryManager.shared.level),
                    "batteryCharging": BatteryManager.shared.isCharging
                ])
            }
        }
    }

    private func syncProfile(rpc: RPCViewModel) async {
        var data: [String: Any] = ["name": UserDefaults.standard.string(forKey: "userName") ?? ""]
        if let b64 = UserDefaults.standard.string(forKey: "userAvatarBase64") { data["avatarBase64"] = b64 }
        await rpc.send(.saveProfile, data: data)
    }

    // MARK: - Peer management

    func addPeer(id: String) async {
        let person = Person(id: id, addedAt: Date())
        try? savePerson(person)
        await rpc?.send(.joinPeer,       data: id)
        await rpc?.send(.requestHistory, data: ["peerKey": id])
    }

    func removePeer(id: String) async {
        try? deletePerson(id: id)
        await rpc?.send(.leavePeer, data: id)
    }
}
