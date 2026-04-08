// app/Manager/LocationManager.swift
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentPlaceName: String?

    weak var rpc: RPCViewModel?

    private let manager  = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastBroadcast: CLLocation?
    private var lastGeocode: CLLocation?
    private var continuations: [UUID: AsyncStream<CLLocation>.Continuation] = [:]

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = kCLDistanceFilterNone  // accept all updates in simulator
        manager.activityType    = .other
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestPermission() {
        print("[Location] requesting permission, status: \(manager.authorizationStatus.rawValue)")
        switch manager.authorizationStatus {
        case .notDetermined:        manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:  startUpdating(); manager.requestAlwaysAuthorization()
        case .authorizedAlways:     startFull()
        default:
            print("[Location] permission denied or restricted")
        }
    }

    func locationUpdates() -> AsyncStream<CLLocation> {
        let id = UUID()
        return AsyncStream { continuation in
            Task { @MainActor [weak self] in
                self?.continuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func startUpdating() {
        manager.startUpdatingLocation()
    }

    private func startFull() {
        manager.allowsBackgroundLocationUpdates = true
        manager.startMonitoringSignificantLocationChanges()
        manager.startUpdatingLocation()
    }

    private func broadcast(_ location: CLLocation) {
        // Relaxed accuracy for simulator (simulator often returns -1 or large values)
        guard location.horizontalAccuracy < 500 else {
            print("[Location] rejected — poor accuracy: \(location.horizontalAccuracy)")
            return
        }
        lastBroadcast = location
        userLocation  = location
        continuations.values.forEach { $0.yield(location) }
        maybeGeocode(location)
    }

    private func maybeGeocode(_ loc: CLLocation) {
        if let last = lastGeocode, loc.distance(from: last) < 100 { return }
        lastGeocode = loc
        geocoder.reverseGeocodeLocation(loc) { [weak self] marks, _ in
            let label = [marks?.first?.name, marks?.first?.locality]
                .compactMap { $0 }.joined(separator: ", ")
            Task { @MainActor [weak self] in self?.currentPlaceName = label.isEmpty ? nil : label }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways:    self.startFull()
            case .authorizedWhenInUse: self.startUpdating(); manager.requestAlwaysAuthorization()
            case .denied, .restricted: manager.stopUpdatingLocation()
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.broadcast(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return }
        print("[Location] error: \(error.localizedDescription)")
    }
}
