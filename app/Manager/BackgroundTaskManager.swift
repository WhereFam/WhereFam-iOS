// app/Manager/BackgroundTaskManager.swift
import BackgroundTasks
import CoreLocation

@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private static let taskID = "com.wherefam.locationburst"
    private init() {}

    func registerTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskID, using: nil) { [weak self] task in
            self?.handleBurstTask(task as! BGProcessingTask)
        }
    }

    func scheduleBurstIfNeeded() {
        let req = BGProcessingTaskRequest(identifier: Self.taskID)
        req.requiresNetworkConnectivity = true
        req.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(req)
    }

    func handleSignificantLocationChange(_ location: CLLocation, rpc: RPCViewModel) async {
        await burst(location: location, rpc: rpc)
    }

    private func handleBurstTask(_ task: BGProcessingTask) {
        scheduleBurstIfNeeded()
        task.expirationHandler = { task.setTaskCompleted(success: false) }
        guard let loc = LocationManager.shared.userLocation,
              let rpc = AppEnvironment.shared.rpc else {
            task.setTaskCompleted(success: false); return
        }
        Task { @MainActor in
            await self.burst(location: loc, rpc: rpc)
            task.setTaskCompleted(success: true)
        }
    }

    private func burst(location: CLLocation, rpc: RPCViewModel) async {
        guard rpc.isReady, !rpc.publicKey.isEmpty else { return }
        let payload: [String: Any] = [
            "id":              rpc.publicKey,
            "name":            UserDefaults.standard.string(forKey: "userName") ?? "",
            "latitude":        location.coordinate.latitude,
            "longitude":       location.coordinate.longitude,
            "altitude":        location.altitude,
            "speed":           max(location.speed, 0),
            "timestamp":       Date().timeIntervalSince1970 * 1000,
            "batteryLevel":    BatteryManager.shared.level,
            "batteryCharging": BatteryManager.shared.isCharging
        ]
        await rpc.send(.backgroundLocationBurst, data: payload)
        let deadline = Date().addingTimeInterval(20)
        while !rpc.lastBurstComplete && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        rpc.lastBurstComplete = false
    }
}