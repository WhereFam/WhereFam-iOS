// app/Models/LocationHistory.swift
import Foundation
import SQLiteData

@Table("locationHistory")
struct LocationHistory: Identifiable, Equatable, Sendable {
    let id: String
    var personId: String
    var latitude: Double
    var longitude: Double
    var speed: Double?
    var placeName: String?
    var recordedAt: Date
}
