// app/Core/Home/View/SimpleMapView.swift
import MapLibre
import SwiftUI
import CoreLocation
import SQLiteData

struct SimpleMapView: UIViewRepresentable {
    @FetchAll(Person.all) var people

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(
            frame: .zero,
            styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty")
        )
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.compassViewPosition = .topLeft
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {
        context.coordinator.sync(people, on: map)
    }

    final class Coordinator: NSObject, MLNMapViewDelegate {
        private var centred = false

        func sync(_ people: [Person], on map: MLNMapView) {
            let live    = people.filter { $0.latitude != nil && $0.longitude != nil }
            let liveIDs = Set(live.map(\.id))
            let existing = (map.annotations ?? []).compactMap { $0 as? PersonPin }

            map.removeAnnotations(existing.filter { !liveIDs.contains($0.personID) })

            let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.personID, $0) })
            for p in live {
                guard let lat = p.latitude, let lon = p.longitude else { continue }
                let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                if let pin = byID[p.id] { pin.coordinate = coord; pin.person = p }
                else {
                    let pin = PersonPin()
                    pin.personID = p.id
                    pin.coordinate = coord
                    pin.person = p
                    map.addAnnotation(pin)
                }
            }
        }

        func mapView(_ map: MLNMapView, didUpdate loc: MLNUserLocation?) {
            guard !centred, let l = loc?.location else { return }
            map.setCenter(l.coordinate, zoomLevel: 14, animated: true)
            centred = true
        }

        func mapView(_ map: MLNMapView, viewFor annotation: MLNAnnotation) -> MLNAnnotationView? {
            guard let pin = annotation as? PersonPin, let person = pin.person else { return nil }
            let reuseID = "pin-\(person.id)"
            if let v = map.dequeueReusableAnnotationView(withIdentifier: reuseID) as? PersonPinView {
                v.update(person); return v
            }
            let v = PersonPinView(reuseIdentifier: reuseID)
            v.update(person)
            v.centerOffset = CGVector(dx: 0, dy: -30)
            return v
        }
    }
}

// MARK: - Annotation model + view

final class PersonPin: MLNPointAnnotation {
    var personID: String = ""
    var person: Person?
}

final class PersonPinView: MLNAnnotationView {
    private var host: UIHostingController<PinSwiftUI>!
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        host = UIHostingController(rootView: PinSwiftUI(person: nil))
        host.view.backgroundColor = .clear
        addSubview(host.view)
        frame = CGRect(origin: .zero, size: CGSize(width: 60, height: 68))
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
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                avatarView.frame(width: 44, height: 44).clipShape(Circle())
                if person?.isOnline == true {
                    Circle().fill(.green).frame(width: 11, height: 11)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        .offset(x: 15, y: -15)
                }
                if person?.isDriving == true {
                    Image(systemName: "car.fill").font(.system(size: 9)).foregroundStyle(.white)
                        .padding(3).background(.orange).clipShape(Capsule())
                        .offset(x: -15, y: -15)
                }
            }
            if let name = person?.name {
                Text(name).font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.thinMaterial).clipShape(Capsule())
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
