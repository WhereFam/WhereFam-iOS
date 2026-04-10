// app/Core/Home/View/PersonDetailView.swift
import SwiftUI
import MapLibre
import CoreLocation
import SQLiteData

struct PersonDetailView: View {
    let person: Person
    @FetchAll(LocationHistory.all) var allHistory
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var showRemoveAlert = false

    private var history: [LocationHistory] {
        allHistory
            .filter { $0.personId == person.id }
            .sorted { $0.recordedAt > $1.recordedAt }
            .prefix(50)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {

                // MARK: Mini map
                if let lat = person.latitude, let lon = person.longitude {
                    PersonMapView(
                        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                        person: person
                    )
                    .frame(height: 220)
                    .ignoresSafeArea(edges: .horizontal)
                } else {
                    ZStack {
                        Color(.secondarySystemFill)
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 32)).foregroundStyle(.secondary)
                            Text("Location unavailable")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 180)
                }

                // MARK: Header card
                VStack(spacing: 0) {
                    // Avatar + name overlapping the map
                    HStack(spacing: 14) {
                        avatarView
                            .frame(width: 72, height: 72)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
                            .shadow(radius: 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name ?? "Unknown")
                                .font(.title2.weight(.bold))
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(person.isOnline ? Color.green : Color(.systemFill))
                                    .frame(width: 8, height: 8)
                                Text(person.lastSeenText)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, -36)
                    .padding(.bottom, 16)

                    // MARK: Status cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 12) {
                        StatusCard(
                            icon: "speedometer",
                            color: person.isDriving ? .orange : .blue,
                            title: "Speed",
                            value: person.speedKmh.map { String(format: "%.0f km/h", $0) } ?? "—"
                        )
                        StatusCard(
                            icon: person.batteryCharging == true ? "battery.100.bolt" : batteryIcon,
                            color: batteryColor,
                            title: "Battery",
                            value: person.batteryLevel.map { "\(Int($0 * 100))%" } ?? "—"
                        )
                        StatusCard(
                            icon: "arrow.up.and.down",
                            color: .teal,
                            title: "Altitude",
                            value: person.altitude.map { String(format: "%.0f m", $0) } ?? "—"
                        )
                        StatusCard(
                            icon: "clock",
                            color: .purple,
                            title: "Last seen",
                            value: person.lastSeenText
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)

                    Divider()

                    // MARK: Timeline
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Timeline")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 12)

                        if history.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 32)).foregroundStyle(.secondary)
                                    Text("No history yet")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 32)
                        } else {
                            ForEach(Array(history.enumerated()), id: \.element.id) { idx, entry in
                                TimelineRow(entry: entry, isLast: idx == history.count - 1)
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(person.name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showRemoveAlert = true
                } label: {
                    Image(systemName: "person.badge.minus")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Remove \(person.name ?? "this person")?", isPresented: $showRemoveAlert) {
            Button("Remove", role: .destructive) {
                Task { await coordinator.removePeer(id: person.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will no longer see your location and you won't see theirs.")
        }
        .ignoresSafeArea(edges: .top)
    }

    private var batteryIcon: String {
        guard let l = person.batteryLevel else { return "battery.0" }
        switch l {
        case ..<0.25: return "battery.25"
        case ..<0.50: return "battery.50"
        case ..<0.75: return "battery.75"
        default:      return "battery.100"
        }
    }

    private var batteryColor: Color {
        guard let l = person.batteryLevel else { return .secondary }
        if person.batteryCharging == true { return .green }
        return l < 0.2 ? .red : .green
    }

    @ViewBuilder private var avatarView: some View {
        if let data = person.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(Color.blue.opacity(0.15))
                .overlay(Text(person.initials)
                    .font(.system(size: 24, weight: .bold)).foregroundStyle(.blue))
        }
    }
}

// MARK: - Status card

struct StatusCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(value)
                .font(.system(size: 17, weight: .semibold))
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Timeline row

struct TimelineRow: View {
    let entry: LocationHistory
    let isLast: Bool
    @State private var placeName: String?
    @State private var isGeocoding = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Line + dot
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemFill))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 3) {
                // Place name or loading
                if let name = entry.placeName ?? placeName {
                    Label(name, systemImage: "mappin.fill")
                        .font(.subheadline.weight(.medium))
                } else if isGeocoding {
                    Text("Locating…")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Unknown location")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(entry.recordedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption).foregroundStyle(.tertiary)
                    Text(entry.recordedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                    if let speed = entry.speed, speed > 4.2 {
                        Text("· \(String(format: "%.0f km/h", speed * 3.6))")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            .padding(.bottom, isLast ? 20 : 16)
        }
        .padding(.horizontal, 20)
        .task {
            guard entry.placeName == nil && placeName == nil else { return }
            isGeocoding = true
            placeName   = await geocode(entry.latitude, entry.longitude)
            isGeocoding = false
        }
    }

    private var dotColor: Color {
        if let speed = entry.speed, speed > 4.2 { return .orange }
        return .blue
    }

    private func geocode(_ lat: Double, _ lon: Double) async -> String? {
        await withCheckedContinuation { cont in
            let loc = CLLocation(latitude: lat, longitude: lon)
            CLGeocoder().reverseGeocodeLocation(loc) { marks, _ in
                let name = marks?.first.flatMap {
                    [$0.name, $0.locality].compactMap { $0 }.first
                }
                cont.resume(returning: name)
            }
        }
    }
}

// MARK: - Mini map (read-only, centered on person)

struct PersonMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let person: Person

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero,
                             styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty"))
        map.delegate          = context.coordinator
        map.isScrollEnabled   = false
        map.isZoomEnabled     = false
        map.isRotateEnabled   = false
        map.isPitchEnabled    = false
        map.showsUserLocation = false
        map.compassViewMargins = CGPoint(x: 0, y: -100) // hide compass
        map.setCenter(coordinate, zoomLevel: 15, animated: false)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        map.setCenter(coordinate, zoomLevel: 15, animated: true)

        // Update or add pin
        if let existing = map.annotations?.first(where: { $0.title == "person" }) {
            map.removeAnnotation(existing)
        }
        let pin = MLNPointAnnotation()
        pin.coordinate = coordinate
        pin.title      = "person"
        map.addAnnotation(pin)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        func mapView(_ map: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            nil // use default red pin
        }
    }
}
