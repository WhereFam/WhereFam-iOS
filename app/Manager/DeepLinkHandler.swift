// app/Manager/DeepLinkHandler.swift
import Foundation

@MainActor
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()
    private init() {}

    func handle(_ url: URL) {
        guard url.scheme == "wherefam" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params     = Dictionary(uniqueKeysWithValues:
            (components?.queryItems ?? []).compactMap { i in i.value.map { (i.name, $0) } })

        switch url.host {
        case "invite":
            guard let code = params["code"], !code.isEmpty else { return }
            if let rpc = AppEnvironment.shared.rpc {
                // App already running — fire immediately
                Task { await rpc.send(.joinWithInvite, data: ["invite": code]) }
            } else {
                // App cold launching — store for when JS is ready
                AppEnvironment.shared.pendingInvite = code
            }

        case "add":
            // Legacy — direct peer key
            guard let key = params["id"], !key.isEmpty else { return }
            NotificationCenter.default.post(
                name: .deepLinkAddPeer,
                object: nil,
                userInfo: ["peerID": key]
            )

        default: break
        }
    }
}

extension Notification.Name {
    static let deepLinkAddPeer   = Notification.Name("deepLinkAddPeer")
    static let apnsTokenReceived = Notification.Name("apnsTokenReceived")
}
