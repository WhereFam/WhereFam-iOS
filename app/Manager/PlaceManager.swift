// app/Manager/PlaceManager.swift
import CoreLocation
import UserNotifications

extension Notification.Name {
    static let placeEventOccurred = Notification.Name("placeEventOccurred")
}

@MainActor
final class PlaceManager: NSObject, ObservableObject {
    static let shared = PlaceManager()

    @Published var activePlaces: [Place] = []

    private let manager = CLLocationManager()
    private override init() { super.init(); manager.delegate = self }

    func syncRegions() {
        activePlaces = (try? fetchAllPlaces()) ?? []
        let ids = Set(activePlaces.map(\.id))
        manager.monitoredRegions
            .filter { !ids.contains($0.identifier) }
            .forEach { manager.stopMonitoring(for: $0) }
        let monitored = Set(manager.monitoredRegions.map(\.identifier))
        activePlaces.filter { !monitored.contains($0.id) }
            .forEach { manager.startMonitoring(for: $0.region) }
    }

    func addPlace(_ place: Place) throws {
        try savePlace(place)
        manager.startMonitoring(for: place.region)
        activePlaces.append(place)
    }

    func removePlace(_ place: Place) throws {
        try deletePlace(id: place.id)
        manager.stopMonitoring(for: place.region)
        activePlaces.removeAll { $0.id == place.id }
    }

    private func notify(title: String, id: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.sound = .default
        Task {
            try? await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: id, content: c, trigger: nil))
        }
    }
}

extension PlaceManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            guard let place = self.activePlaces.first(where: { $0.id == region.identifier }) else { return }
            self.notify(title: "\(place.emoji) Arrived at \(place.name)", id: "arrive-\(place.id)")
            NotificationCenter.default.post(name: .placeEventOccurred, object: nil,
                userInfo: ["event": "arrived", "placeName": place.name, "emoji": place.emoji])
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            guard let place = self.activePlaces.first(where: { $0.id == region.identifier }) else { return }
            self.notify(title: "\(place.emoji) Left \(place.name)", id: "leave-\(place.id)")
            NotificationCenter.default.post(name: .placeEventOccurred, object: nil,
                userInfo: ["event": "left", "placeName": place.name, "emoji": place.emoji])
        }
    }
}
