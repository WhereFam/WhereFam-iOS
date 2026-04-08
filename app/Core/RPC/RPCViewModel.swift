// app/Core/RPC/RPCViewModel.swift
import Foundation
import BareKit
import UserNotifications

enum RPCAction: String {
    case start                   = "start"
    case requestPublicKey        = "requestPublicKey"
    case joinPeer                = "joinPeer"
    case leavePeer               = "leavePeer"
    case locationUpdate          = "locationUpdate"
    case backgroundLocationBurst = "backgroundLocationBurst"
    case placeEvent              = "placeEvent"
    case sosAlert                = "sosAlert"
    case batteryUpdate           = "batteryUpdate"
    case requestHistory          = "requestHistory"
    case saveProfile             = "saveProfile"
    case createInvite            = "createInvite"
    case joinWithInvite          = "joinWithInvite"
}

@MainActor
final class RPCViewModel: ObservableObject {

    @Published var publicKey: String    = ""
    @Published var isReady: Bool        = false
    @Published var startupError: String?
    @Published var inviteCode: String   = ""
    @Published var pairingComplete: Bool = false

    var lastBurstComplete: Bool = false

    private(set) var ipc: IPC?
    private var ipcBuffer = ""

    func configure(with ipc: IPC?) {
        self.ipc = ipc
        AppEnvironment.shared.rpc = self
    }

    func readLoop() async {
        guard let ipc else { return }
        do {
            for try await chunk in ipc {
                guard let str = String(data: chunk, encoding: .utf8) else { continue }
                processChunk(str)
            }
        } catch { print("[RPC] read error: \(error)") }
    }

    func send(_ action: RPCAction, data: Any = [:]) async {
        guard let ipc else { return }
        do {
            let msg: [String: Any] = ["action": action.rawValue, "data": data]
            var raw = try JSONSerialization.data(withJSONObject: msg)
            raw.append(contentsOf: "\n".utf8)
            try await ipc.write(data: raw)
        } catch { print("[RPC] send error \(action.rawValue): \(error)") }
    }

    private func processChunk(_ chunk: String) {
        ipcBuffer.append(chunk)
        var lines = ipcBuffer.components(separatedBy: "\n")
        ipcBuffer = lines.removeLast()
        for line in lines {
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, let data = t.data(using: .utf8) else { continue }
            if let msg = try? JSONDecoder().decode(RPCMessage.self, from: data) { dispatch(msg) }
        }
    }

    private func dispatch(_ msg: RPCMessage) {
        switch msg.action {

        case "ready":
            isReady = true
            if let dict = msg.data.value as? [String: Any],
               let key  = dict["publicKey"] as? String { publicKey = key }

        case "publicKeyResponse":
            if let dict = msg.data.value as? [String: Any],
               let key  = dict["publicKey"] as? String { publicKey = key }

        case "inviteCreated":
            if let dict = msg.data.value as? [String: Any],
               let inv  = dict["invite"]    as? String { inviteCode = inv }

        case "peerPaired":
            pairingComplete = true
            // @FetchAll in PeopleView auto-updates — no manual refresh needed

        case "locationUpdate":   handleLocationUpdate(msg)
        case "peerDisconnected": handlePeerDisconnected(msg)
        case "placeEvent":       handlePlaceEvent(msg)
        case "sosAlert":         handleSOSAlert(msg)
        case "batteryUpdate":    handleBatteryUpdate(msg)
        case "historyUpdate":    handleHistoryUpdate(msg)
        case "backgroundBurstComplete": lastBurstComplete = true

        case "startupError":
            if let dict = msg.data.value as? [String: Any] {
                startupError = dict["message"] as? String
            }

        default: print("[RPC] unknown: \(msg.action)")
        }
    }

    private func handleLocationUpdate(_ msg: RPCMessage) {
        guard let dict      = msg.data.value as? [String: Any],
              let id        = dict["id"]        as? String,
              let latitude  = dict["latitude"]  as? Double,
              let longitude = dict["longitude"] as? Double else { return }

        var person = Person(
            id:              id,
            name:            dict["name"]     as? String,
            latitude:        latitude,
            longitude:       longitude,
            altitude:        dict["altitude"] as? Double,
            speed:           (dict["speed"]   as? Double).map { max($0, 0) },
            batteryLevel:    (dict["batteryLevel"] as? Double).map { Float($0) },
            batteryCharging: dict["batteryCharging"] as? Bool,
            lastSeen:        (dict["timestamp"] as? Double)
                .map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date(),
            addedAt:         Date()
        )
        if let b64 = dict["avatarData"] as? String {
            person.avatarData = Data(base64Encoded: b64)
        } else if let existing = try? findPerson(id: id) {
            person.avatarData = existing.avatarData
        }
        try? savePerson(person)
        try? saveHistory(LocationHistory(
            id:         UUID().uuidString,
            personId:   id,
            latitude:   latitude,
            longitude:  longitude,
            speed:      person.speed,
            placeName:  nil,
            recordedAt: person.lastSeen ?? Date()
        ))
    }

    private func handlePeerDisconnected(_ msg: RPCMessage) {
        guard let dict = msg.data.value as? [String: Any],
              let key  = dict["peerKey"] as? String else { return }
        try? markPersonOffline(id: key)
    }

    private func handlePlaceEvent(_ msg: RPCMessage) {
        guard let dict      = msg.data.value as? [String: Any],
              let peerName  = dict["name"]      as? String,
              let event     = dict["event"]     as? String,
              let placeName = dict["placeName"] as? String else { return }
        let emoji = dict["emoji"] as? String ?? "📍"
        let title = event == "arrived"
            ? "\(emoji) \(peerName) arrived at \(placeName)"
            : "\(emoji) \(peerName) left \(placeName)"
        notify(id: "place-\(peerName)-\(Date().timeIntervalSince1970)", title: title, body: "")
    }

    private func handleSOSAlert(_ msg: RPCMessage) {
        guard let dict = msg.data.value as? [String: Any],
              let name = dict["name"] as? String,
              let type = dict["type"] as? String else { return }
        let title = type == "crash"
            ? "🚨 \(name) may have been in a crash"
            : "🆘 \(name) sent an SOS"
        notify(id: "sos-\(name)", title: title, body: "Tap to see their location", critical: true)
    }

    private func handleBatteryUpdate(_ msg: RPCMessage) {
        guard let dict  = msg.data.value as? [String: Any],
              let id    = dict["id"]           as? String,
              let level = dict["batteryLevel"] as? Double else { return }
        if var p = try? findPerson(id: id) {
            p.batteryLevel    = Float(level)
            p.batteryCharging = dict["batteryCharging"] as? Bool
            try? savePerson(p)
        }
        if level <= Double(BatteryManager.lowThreshold),
           let name = dict["name"] as? String {
            notify(id: "battery-\(id)",
                   title: "🔋 \(name)'s battery is low",
                   body:  "\(Int(level * 100))% remaining")
        }
    }

    private func handleHistoryUpdate(_ msg: RPCMessage) {
        guard let dict    = msg.data.value as? [String: Any],
              let peerKey = dict["peerKey"] as? String,
              let entries = dict["entries"] as? [[String: Any]] else { return }
        for entry in entries {
            guard let lat = entry["latitude"]  as? Double,
                  let lon = entry["longitude"] as? Double else { continue }
            let ts = (entry["timestamp"] as? Double)
                .map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date()
            try? saveHistory(LocationHistory(
                id:         UUID().uuidString,
                personId:   peerKey,
                latitude:   lat,
                longitude:  lon,
                speed:      entry["speed"] as? Double,
                placeName:  entry["placeName"] as? String,
                recordedAt: ts
            ))
        }
    }

    private func notify(id: String, title: String, body: String, critical: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body
        content.sound = critical ? .defaultCritical : .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}

struct RPCMessage: Codable {
    let action: String
    let data: AnyCodable
}

struct AnyCodable: Codable {
    let value: Any?
    init(_ v: Any?) { value = v }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if      let v = try? c.decode(String.self)               { value = v }
        else if let v = try? c.decode(Bool.self)                 { value = v }
        else if let v = try? c.decode(Int.self)                  { value = v }
        else if let v = try? c.decode(Double.self)               { value = v }
        else if c.decodeNil()                                    { value = nil }
        else if let v = try? c.decode([String: AnyCodable].self) { value = v.mapValues { $0.value } }
        else if let v = try? c.decode([AnyCodable].self)         { value = v.map { $0.value } }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown JSON") }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case let b as Bool:           try c.encode(b)
        case let i as Int:            try c.encode(i)
        case let d as Double:         try c.encode(d)
        case let s as String:         try c.encode(s)
        case let a as [Any?]:         try c.encode(a.map { AnyCodable($0) })
        case let d as [String: Any?]: try c.encode(d.mapValues { AnyCodable($0) })
        default:                      try c.encodeNil()
        }
    }
}
