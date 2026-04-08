// app/Application/App.swift
import BareKit
import SwiftUI
import UserNotifications
import BackgroundTasks
import SQLiteData

@main
struct WhereFamApp: SwiftUI.App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var worker      = Worker()
    @StateObject private var rpc         = RPCViewModel()
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var store       = StoreKitManager.shared
    @StateObject private var battery     = BatteryManager.shared
    @StateObject private var safety      = SafetyManager.shared

    @Environment(\.scenePhase) private var scenePhase

    init() {
        prepareDependencies {
            $0.defaultDatabase = try! appDatabase()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(rpc)
                .environmentObject(coordinator)
                .environmentObject(store)
                .environmentObject(safety)
                .environmentObject(battery)
                .onAppear(perform: boot)
                .onOpenURL { DeepLinkHandler.shared.handle($0, rpc: rpc) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                worker.suspend()
                BackgroundTaskManager.shared.scheduleBurstIfNeeded()
            case .active:
                worker.resume()
            default: break
            }
        }
    }

    private func boot() {
        BackgroundTaskManager.shared.registerTasks()
        worker.start()
        rpc.configure(with: worker.ipc)

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge, .criticalAlert]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        // Start read loop so Swift receives JS events
        Task { await rpc.readLoop() }

        // Boot the JS side — sends 'start' to Bare, waits for 'ready'
        Task { await coordinator.start(rpc: rpc) }
    }
}
