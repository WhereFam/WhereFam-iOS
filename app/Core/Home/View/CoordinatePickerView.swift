// app/Core/Home/View/CoordinatePickerView.swift
import SwiftUI
import MapLibre
import CoreLocation

struct CoordinatePickerView: View {
    @Binding var coordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) private var dismiss

    @State private var pinCoord: CLLocationCoordinate2D = LocationManager.shared.userLocation?.coordinate
        ?? CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312)

    var body: some View {
        NavigationStack {
            ZStack {
                PinMapView(pinCoord: $pinCoord)
                    .ignoresSafeArea()

                // Fixed centre pin
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                        .shadow(radius: 4)
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                        .offset(y: -4)
                }
                .allowsHitTesting(false)

                // Coordinate badge
                VStack {
                    Spacer()
                    Text(String(format: "%.5f,  %.5f", pinCoord.latitude, pinCoord.longitude))
                        .font(.caption.monospaced())
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Drop Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirm") {
                        coordinate = pinCoord
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Map that tracks centre coordinate

struct PinMapView: UIViewRepresentable {
    @Binding var pinCoord: CLLocationCoordinate2D

    func makeCoordinator() -> Coordinator { Coordinator(pinCoord: $pinCoord) }

    func makeUIView(context: Context) -> MLNMapView {
        let map = MLNMapView(frame: .zero,
                             styleURL: URL(string: "https://tiles.openfreemap.org/styles/liberty"))
        map.delegate         = context.coordinator
        map.showsUserLocation = true
        map.compassViewPosition = .topLeft
        map.zoomLevel        = 15

        let center = LocationManager.shared.userLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0312)
        map.setCenter(center, animated: false)
        return map
    }

    func updateUIView(_ map: MLNMapView, context: Context) {}

    final class Coordinator: NSObject, MLNMapViewDelegate {
        @Binding var pinCoord: CLLocationCoordinate2D
        init(pinCoord: Binding<CLLocationCoordinate2D>) { _pinCoord = pinCoord }

        func mapView(_ map: MLNMapView, regionDidChangeAnimated animated: Bool) {
            pinCoord = map.centerCoordinate
        }
    }
}
