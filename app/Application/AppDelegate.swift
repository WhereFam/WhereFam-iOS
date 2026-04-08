// app/AppDelegate.swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        print("[APNs] token:", hex)
        NotificationCenter.default.post(name: .apnsTokenReceived, object: nil, userInfo: ["token": hex])
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[APNs] registration failed:", error.localizedDescription)
    }
}