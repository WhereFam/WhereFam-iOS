// app/Manager/DeepLinkHandler.swift
// wherefam://add?id=<base64url-key>

import Foundation

@MainActor
final class DeepLinkHandler {
    static let shared = DeepLinkHandler()
    private init() {}

    func handle(_ url: URL, rpc: RPCViewModel) {
        guard url.scheme == "wherefam",
              url.host == "add",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let raw   = items.first(where: { $0.name == "id" })?.value,
              !raw.isEmpty else { return }

        // base64url → base64
        var base64 = raw.replacingOccurrences(of: "-", with: "+")
                        .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        NotificationCenter.default.post(name: .deepLinkAddPeer, object: nil,
                                        userInfo: ["peerID": base64])
    }
}

extension Notification.Name {
    static let deepLinkAddPeer = Notification.Name("deepLinkAddPeer")
    static let apnsTokenReceived = Notification.Name("apnsTokenReceived")
}