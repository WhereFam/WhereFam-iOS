// app/Core/Home/View/SimpleMapView.swift
import MapLibre
import SwiftUI
import CoreLocation
import SQLiteData

struct SimpleMapView: View {
    @FetchAll(Person.all) var people
    @State private var selectedPerson: Person?
    @State private var showDetail     = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapLibreView(people: people, selectedPerson: $selectedPerson)
                .ignoresSafeArea()

            if let person = selectedPerson {
                PersonBottomCard(
                    person:     person,
                    showDetail: $showDetail,
                    onDismiss:  { withAnimation(.spring()) { selectedPerson = nil } }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 90)
            }
        }
        .navigationDestination(isPresented: $showDetail) {
            if let person = selectedPerson {
                PersonDetailView(person: person)
            }
        }
        .animation(.spring(response: 0.35), value: selectedPerson?.id)
    }
}

// MARK: - MapLibre wrapper

struct MapLibreView: UIViewRepresentable {
    let people: [Person]
    @Binding var selectedPerson: Person?

    func makeCoordinator() -> Coordinator { Coordinator(selectedPerson: $selectedPerson) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(
            frame: .zero,
            styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty")
        )
        map.delegate            = context.coordinator
        map.showsUserLocation   = true
        map.compassViewPosition = .topLeft
        map.logoView.isHidden   = true
        context.coordinator.mapView = map

        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleMapTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.sync(people, on: map)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, MLNMapViewDelegate, UIGestureRecognizerDelegate {

        @Binding var selectedPerson: Person?
        weak var mapView: MLNMapView?
        private var centred = false

        init(selectedPerson: Binding<Person?>) { _selectedPerson = selectedPerson }

        // Allow our tap to fire alongside map's own gestures
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let map = mapView else { return }
            let point        = gesture.location(in: map)
            let hitAnnotation = map.subviews.contains { $0 is MLNAnnotationView && $0.frame.contains(point) }
            if !hitAnnotation { withAnimation(.spring()) { selectedPerson = nil } }
        }

        func sync(_ people: [Person], on map: MLNMapView) {
            let live    = people.filter { $0.latitude != nil && $0.longitude != nil }
            let liveIDs = Set(live.map(\.id))
            let existing = (map.annotations ?? []).compactMap { $0 as? PersonPin }
            map.removeAnnotations(existing.filter { !liveIDs.contains($0.personID) })
            let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.personID, $0) })
            for p in live {
                guard let lat = p.latitude, let lon = p.longitude else { continue }
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                if let pin = byID[p.id] {
                    pin.coordinate = coord
                    pin.person     = p
                    (map.view(for: pin) as? PersonPinView)?.update(p)
                } else {
                    let pin = PersonPin()
                    pin.personID   = p.id
                    pin.coordinate = coord
                    pin.person     = p
                    map.addAnnotation(pin)
                }
            }
        }

        func mapView(_ map: MLNMapView, didUpdate loc: MLNUserLocation?) {
            guard !centred, let l = loc?.location else { return }
            map.setCenter(l.coordinate, zoomLevel: 14, animated: true)
            centred = true
        }

        func mapView(_ map: MLNMapView, didSelect annotation: MLNAnnotation) {
            guard let pin = annotation as? PersonPin, let person = pin.person else { return }
            map.deselectAnnotation(annotation, animated: false)
            map.setCenter(annotation.coordinate, zoomLevel: 15, animated: true)
            withAnimation(.spring()) { selectedPerson = person }
        }

        func mapView(_ map: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let pin = annotation as? PersonPin, let person = pin.person else { return nil }
            let reuseID = "pin-\(person.id)"
            if let v = map.dequeueReusableAnnotationView(withIdentifier: reuseID) as? PersonPinView {
                v.update(person); return v
            }
            let v = PersonPinView(reuseIdentifier: reuseID)
            v.update(person)
            v.centerOffset = CGVector(dx: 0, dy: -34)
            return v
        }
    }
}

// MARK: - Pin model

final class PersonPin: MLNPointAnnotation {
    var personID: String = ""
    var person:   Person?
}

// MARK: - Pin view

final class PersonPinView: MLNAnnotationView {
    private var host: UIHostingController<PinSwiftUI>!
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        host = UIHostingController(rootView: PinSwiftUI(person: nil))
        host.view.backgroundColor = .clear
        addSubview(host.view)
        frame         = CGRect(origin: .zero, size: CGSize(width: 60, height: 70))
        host.view.frame = bounds
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }
    func update(_ person: Person) { host.rootView = PinSwiftUI(person: person) }
}

struct PinSwiftUI: View {
    let person: Person?
    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(.white).frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                avatarView.frame(width: 44, height: 44).clipShape(Circle())
                if person?.isOnline == true {
                    Circle().fill(.green).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 15, y: -15)
                }
                if person?.isDriving == true {
                    Image(systemName: "car.fill")
                        .font(.system(size: 9)).foregroundStyle(.white)
                        .padding(3).background(.orange).clipShape(Capsule())
                        .offset(x: -15, y: -15)
                }
            }
            if let name = person?.name {
                Text(name)
                    .font(.system(size: 10, weight: .semibold)).lineLimit(1)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.ultraThinMaterial).clipShape(Capsule())
            }
        }
    }

    @ViewBuilder private var avatarView: some View {
        if let data = person?.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(Color.blue.opacity(0.12))
                .overlay(Text(person?.initials ?? "?")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(.blue))
        }
    }
}

// MARK: - Bottom person card

struct PersonBottomCard: View {
    let person:     Person
    @Binding var showDetail: Bool
    let onDismiss:  () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemFill))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            HStack(spacing: 14) {
                Group {
                    if let data = person.avatarData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Circle().fill(Color.blue.opacity(0.12))
                            .overlay(Text(person.initials)
                                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.blue))
                    }
                }
                .frame(width: 52, height: 52).clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name ?? "Unknown").font(.headline)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(person.isOnline ? Color.green : Color(.systemFill))
                            .frame(width: 7, height: 7)
                        Text(person.lastSeenText).font(.caption).foregroundStyle(.secondary)
                        if person.isDriving { Text("· Driving").font(.caption).foregroundStyle(.orange) }
                    }
                    HStack(spacing: 12) {
                        if let level = person.batteryLevel {
                            Label("\(Int(level * 100))%",
                                  systemImage: person.batteryCharging == true ? "battery.100.bolt" : "battery.50")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if let speed = person.speedKmh, speed > 2 {
                            Label(String(format: "%.0f km/h", speed), systemImage: "speedometer")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                    }
                }
                Spacer()
                Button { showDetail = true } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 28)).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, y: -4)
        .padding(.horizontal, 12)
        .onTapGesture { showDetail = true }
        .gesture(DragGesture(minimumDistance: 20)
            .onEnded { v in if v.translation.height > 40 { onDismiss() } })
    }
}
