// app/Models/Person.swift
import Foundation
import SQLiteData

@Table("person")
struct Person: Identifiable, Equatable, Sendable, Codable {
    let id: String
    var name: String?
    var avatarData: Data?
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var speed: Double?
    var batteryLevel: Float?
    var batteryCharging: Bool?
    var lastSeen: Date?
    var addedAt: Date

    var isOnline: Bool {
        guard let lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 35
    }
    var isDriving: Bool { (speed ?? 0) > 4.2 }
    var speedKmh: Double? { speed.map { $0 * 3.6 } }
    var lastSeenText: String {
        guard let lastSeen else { return "Never" }
        if isOnline { return "Online now" }
        let d = Date().timeIntervalSince(lastSeen)
        if d < 60    { return "Just now" }
        if d < 3600  { return "\(Int(d/60))m ago" }
        if d < 86400 { return "\(Int(d/3600))h ago" }
        return "\(Int(d/86400))d ago"
    }
    var initials: String {
        guard let name, !name.isEmpty else { return "?" }
        return name.split(separator: " ").prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined().uppercased()
    }
}
