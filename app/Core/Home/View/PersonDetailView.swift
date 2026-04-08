// app/Core/Home/View/PersonDetailView.swift
import SwiftUI
import SQLiteData

struct PersonDetailView: View {
    let person: Person

    // Fetch all history and filter on appear — avoids "self not available" error
    // Uses @FetchAll with .all() then updates the query once view is live
    @FetchAll(LocationHistory.all) var history

    private var personHistory: [LocationHistory] {
        history.filter { $0.personId == person.id }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    avatarView.frame(width: 64, height: 64).clipShape(Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name ?? "Unknown").font(.title2.weight(.semibold))
                        HStack(spacing: 6) {
                            Circle()
                                .fill(person.isOnline ? Color.green : Color(.systemFill))
                                .frame(width: 8, height: 8)
                            Text(person.lastSeenText)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Live status") {
                if let lat = person.latitude, let lon = person.longitude {
                    LabeledContent("Location") {
                        Text(String(format: "%.5f, %.5f", lat, lon))
                            .font(.caption.monospaced()).foregroundStyle(.secondary)
                    }
                }
                if let speed = person.speedKmh {
                    LabeledContent("Speed", value: String(format: "%.0f km/h", speed))
                }
                if let alt = person.altitude {
                    LabeledContent("Altitude", value: String(format: "%.0f m", alt))
                }
                if let level = person.batteryLevel {
                    LabeledContent("Battery") {
                        HStack(spacing: 4) {
                            Text("\(Int(level * 100))%")
                            if person.batteryCharging == true {
                                Image(systemName: "bolt.fill").foregroundStyle(.green)
                            }
                        }
                    }
                }
            }

            if !personHistory.isEmpty {
                Section("Timeline — last 7 days") {
                    ForEach(personHistory) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            if let place = entry.placeName {
                                Label(place, systemImage: "mappin.fill")
                            } else {
                                Text(String(format: "%.4f, %.4f", entry.latitude, entry.longitude))
                                    .font(.caption.monospaced())
                            }
                            Text(entry.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } else {
                Section {
                    Text("No history yet.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(person.name ?? "Person")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var avatarView: some View {
        if let data = person.avatarData, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(Color.blue.opacity(0.12))
                .overlay(Text(person.initials)
                    .font(.system(size: 22, weight: .semibold)).foregroundStyle(.blue))
        }
    }
}
