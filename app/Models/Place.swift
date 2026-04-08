// app/Models/Place.swift
import Foundation
import SQLiteData
import CoreLocation

@Table("place")
struct Place: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var emoji: String
    var latitude: Double
    var longitude: Double
    var radiusMetres: Double
    var notifyOnArrive: Bool
    var notifyOnLeave: Bool
    var createdAt: Date

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var region: CLCircularRegion {
        let r = CLCircularRegion(center: coordinate, radius: radiusMetres, identifier: id)
        r.notifyOnEntry = notifyOnArrive
        r.notifyOnExit  = notifyOnLeave
        return r
    }
}
