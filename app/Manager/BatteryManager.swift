// app/Manager/BatteryManager.swift
import UIKit

@MainActor
final class BatteryManager: ObservableObject {
    static let shared = BatteryManager()
    static let lowThreshold: Float = 0.20

    @Published var level: Float    = 1.0
    @Published var isCharging: Bool = false
    @Published var isLow: Bool     = false

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
            name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
            name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    @objc private func refresh() {
        let d        = UIDevice.current
        let wasLow   = isLow
        level        = d.batteryLevel < 0 ? 1.0 : d.batteryLevel
        isCharging   = d.batteryState == .charging || d.batteryState == .full
        isLow        = level <= Self.lowThreshold && !isCharging
        if isLow && !wasLow {
            NotificationCenter.default.post(name: .batteryBecameLow, object: nil)
        }
    }
}

extension Notification.Name {
    static let batteryBecameLow = Notification.Name("batteryBecameLow")
}