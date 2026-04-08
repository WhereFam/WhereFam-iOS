// app/Core/Home/View/PlacesView.swift
import SwiftUI
import CoreLocation

// MARK: - Preset

private struct Preset {
    let name: String
    let emoji: String
    let symbol: String
    let color: Color
}

private let presets: [Preset] = [
    Preset(name: "Home",        emoji: "🏠", symbol: "house.fill",           color: .blue),
    Preset(name: "Work",        emoji: "🏢", symbol: "briefcase.fill",        color: .indigo),
    Preset(name: "School",      emoji: "🏫", symbol: "graduationcap.fill",    color: .purple),
    Preset(name: "Gym",         emoji: "💪", symbol: "dumbbell.fill",         color: .orange),
    Preset(name: "Hospital",    emoji: "🏥", symbol: "cross.fill",            color: .red),
    Preset(name: "Park",        emoji: "🌳", symbol: "leaf.fill",             color: .green),
    Preset(name: "Supermarket", emoji: "🛒", symbol: "cart.fill",             color: .teal),
    Preset(name: "Restaurant",  emoji: "🍜", symbol: "fork.knife",            color: .orange),
    Preset(name: "Church",      emoji: "🕌", symbol: "building.columns.fill", color: .gray),
    Preset(name: "Beach",       emoji: "🌊", symbol: "water.waves",           color: .cyan),
    Preset(name: "Airport",     emoji: "🛫", symbol: "airplane",              color: .blue),
    Preset(name: "Hotel",       emoji: "🏨", symbol: "bed.double.fill",       color: .mint),
]

// MARK: - Places list

struct PlacesView: View {
    @StateObject private var placeManager = PlaceManager.shared
    @State private var showAdd = false

    var body: some View {
        Group {
            if placeManager.activePlaces.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 52)).foregroundStyle(.secondary)
                    Text("No saved places")
                        .font(.title3.weight(.semibold))
                    Text("Save places like Home or School to get notified when you or your family arrive or leave.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    Button("Add a place") { showAdd = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                List {
                    ForEach(placeManager.activePlaces) { place in
                        PlaceRowView(place: place)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    try? placeManager.removePlace(place)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Places")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPlaceView { newPlace in
                try? placeManager.addPlace(newPlace)
            }
        }
        .onAppear { placeManager.syncRegions() }
    }
}

// MARK: - Row

struct PlaceRowView: View {
    let place: Place

    // Match symbol + color from preset, fall back to pin
    private var preset: Preset? { presets.first { $0.name == place.name } }
    private var symbol: String  { preset?.symbol ?? "mappin.fill" }
    private var color:  Color   { preset?.color  ?? .blue }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(place.name).font(.body.weight(.medium))
                HStack(spacing: 6) {
                    if place.notifyOnArrive {
                        Label("Arrive", systemImage: "arrow.down.circle.fill")
                            .font(.caption).foregroundStyle(.green)
                    }
                    if place.notifyOnLeave {
                        Label("Leave", systemImage: "arrow.up.circle.fill")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text("· \(radiusLabel(place.radiusMetres))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func radiusLabel(_ m: Double) -> String {
        m >= 1000 ? String(format: "%.1fkm", m / 1000) : "\(Int(m))m"
    }
}

// MARK: - Add place sheet

struct AddPlaceView: View {
    let onSave: (Place) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPreset: Preset? = presets[0]
    @State private var customName    = ""
    @State private var isCustom      = false
    @State private var useCurrentLoc  = true
    @State private var latString      = ""
    @State private var lonString      = ""
    @State private var pinnedCoord:   CLLocationCoordinate2D?
    @State private var showPinPicker  = false
    @State private var radius         = 150.0
    @State private var notifyArrive   = true
    @State private var notifyLeave    = true
    @State private var coordError: String?

    private var placeName: String {
        isCustom ? customName : (selectedPreset?.name ?? "")
    }
    private var placeEmoji: String {
        isCustom ? "📍" : (selectedPreset?.emoji ?? "📍")
    }
    private var coordinate: CLLocationCoordinate2D? {
        if useCurrentLoc { return LocationManager.shared.userLocation?.coordinate }
        if let p = pinnedCoord { return p }
        guard let lat = Double(latString), let lon = Double(lonString),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    private var canSave: Bool { !placeName.isEmpty && coordinate != nil }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Preset grid
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(presets, id: \.name) { p in
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedPreset?.name == p.name && !isCustom
                                              ? p.color.opacity(0.25)
                                              : Color(.secondarySystemFill))
                                        .frame(height: 56)
                                    Image(systemName: p.symbol)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(selectedPreset?.name == p.name && !isCustom
                                                         ? p.color : .secondary)
                                }
                                Text(p.name)
                                    .font(.caption2)
                                    .foregroundStyle(selectedPreset?.name == p.name && !isCustom
                                                     ? p.color : .secondary)
                                    .lineLimit(1)
                            }
                            .onTapGesture {
                                selectedPreset = p
                                isCustom       = false
                            }
                        }

                        // Custom option
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isCustom ? Color.blue.opacity(0.25) : Color(.secondarySystemFill))
                                    .frame(height: 56)
                                Image(systemName: "pencil")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(isCustom ? Color.blue : .secondary)
                            }
                            Text("Custom")
                                .font(.caption2)
                                .foregroundStyle(isCustom ? Color.blue : .secondary)
                        }
                        .onTapGesture { isCustom = true; selectedPreset = nil }
                    }
                    .padding(.vertical, 4)

                    if isCustom {
                        TextField("Place name", text: $customName)
                            .textInputAutocapitalization(.words)
                    }
                } header: {
                    Text("What kind of place?")
                }

                // MARK: Location
                Section {
                    Toggle("Use my current location", isOn: $useCurrentLoc)
                        .onChange(of: useCurrentLoc) { _, on in
                            if on { pinnedCoord = nil; latString = ""; lonString = "" }
                        }

                    if !useCurrentLoc {
                        // Drop pin on map
                        Button {
                            showPinPicker = true
                        } label: {
                            HStack {
                                Label("Drop pin on map", systemImage: "mappin.and.ellipse")
                                Spacer()
                                if let p = pinnedCoord {
                                    Text(String(format: "%.4f, %.4f", p.latitude, p.longitude))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .sheet(isPresented: $showPinPicker) {
                            CoordinatePickerView(coordinate: $pinnedCoord)
                        }

                        // Or enter manually
                        HStack {
                            Text("Latitude")
                            Spacer()
                            TextField("e.g. 37.7749", text: $latString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .onChange(of: latString) { _, _ in pinnedCoord = nil }
                        }
                        HStack {
                            Text("Longitude")
                            Spacer()
                            TextField("e.g. -122.4194", text: $lonString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 140)
                                .onChange(of: lonString) { _, _ in pinnedCoord = nil }
                        }
                        if let err = coordError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    } else if let loc = LocationManager.shared.userLocation {
                        HStack {
                            Text("Current location")
                            Spacer()
                            Text(String(format: "%.4f, %.4f",
                                        loc.coordinate.latitude,
                                        loc.coordinate.longitude))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Label("Location not available", systemImage: "location.slash")
                            .font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("Where is it?")
                } footer: {
                    if !useCurrentLoc {
                        Text("Drop a pin on the map or enter coordinates manually.")
                    }
                }

                // MARK: Alerts
                Section {
                    Toggle("When I arrive", isOn: $notifyArrive)
                    Toggle("When I leave",  isOn: $notifyLeave)
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Your WhereFam circle is also notified.")
                }

                // MARK: Radius
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Area size")
                            Spacer()
                            Text(radius >= 1000
                                 ? String(format: "%.1f km", radius / 1000)
                                 : "\(Int(radius)) m")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $radius, in: 50...1000, step: 25)
                    }
                } header: {
                    Text("Detection radius")
                } footer: {
                    Text("150m works well for most places.")
                }
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let coord = coordinate else {
                            coordError = "Invalid coordinates"
                            return
                        }
                        onSave(Place(
                            id:             UUID().uuidString,
                            name:           placeName,
                            emoji:          placeEmoji,
                            latitude:       coord.latitude,
                            longitude:      coord.longitude,
                            radiusMetres:   radius,
                            notifyOnArrive: notifyArrive,
                            notifyOnLeave:  notifyLeave,
                            createdAt:      Date()
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    PlacesView()
}
