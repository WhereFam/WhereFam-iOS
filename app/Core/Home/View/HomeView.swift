// app/Core/Home/View/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var rpc:         RPCViewModel
    @EnvironmentObject var coordinator: AppCoordinator
    @EnvironmentObject var safety:      SafetyManager

    @State private var selectedTab: Tab = .map

    enum Tab { case map, people, places, safety }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { mapTab }
                .tabItem { Label("Map",    systemImage: "map.fill") }
                .tag(Tab.map)

            NavigationStack { PeopleView() }
                .tabItem { Label("People", systemImage: "person.2.fill") }
                .tag(Tab.people)

            NavigationStack { PlacesView() }
                .tabItem { Label("Places", systemImage: "mappin.and.ellipse") }
                .tag(Tab.places)

            NavigationStack { SafetyView() }
                .tabItem { Label("Safety", systemImage: "shield.fill") }
                .tag(Tab.safety)
                .badge(safety.sosState != .idle ? "!" : nil)
        }
    }

    @ViewBuilder
    private var mapTab: some View {
        ZStack(alignment: .bottomTrailing) {
            SimpleMapView().ignoresSafeArea()
            VStack(spacing: 25) {
                SOSButton()
                MapMenuFAB()
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Map FAB menu

struct MapMenuFAB: View {
    @EnvironmentObject var rpc: RPCViewModel
    @State private var selected: MenuOpt?

    enum MenuOpt: String, Identifiable {
        case shareID, support, about
        var id: String { rawValue }
    }

    var body: some View {
        Menu {
            Button { selected = .shareID }  label: { Label("Share Your ID",  systemImage: "qrcode") }
            Button { selected = .support }  label: { Label("Support App",    systemImage: "wand.and.stars") }
            ShareLink(item: URL(string: "https://wherefam.com")!) { Label("Refer a Friend", systemImage: "square.and.arrow.up") }
            if let url = URL(string: "https://apps.apple.com/app/id6749550634?action=write-review") {
                Link(destination: url) { Label("Rate App", systemImage: "star") }
            }
            Button { selected = .about } label: { Label("About", systemImage: "info.circle") }
        } label: {
            Image(systemName: "line.3.horizontal.circle.fill")
                .font(.system(size: 44)).foregroundStyle(.blue)
                .background(Circle().fill(.background).shadow(radius: 6))
        }
        .sheet(item: $selected) { opt in
            switch opt {
            case .shareID:  ShareIDView()
            case .support:  StoreKitPaywallView()
            case .about:    AboutView()
            }
        }
    }
}

// MARK: - SOS floating button

struct SOSButton: View {
    @EnvironmentObject var safety: SafetyManager
    var body: some View {
        Button {
            if case .idle     = safety.sosState { safety.triggerManualSOS() }
            else if case .countdown = safety.sosState { safety.cancelSOS() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(bg).clipShape(Capsule())
                .shadow(color: .black.opacity(0.15), radius: 6)
        }
    }

    private var label: String {
        switch safety.sosState {
        case .idle:              return "SOS"
        case .countdown(let s): return "Cancel \(s)s"
        case .active:           return "SOS sent"
        case .cancelled:        return "SOS"
        }
    }
    private var bg: Color {
        switch safety.sosState {
        case .idle, .cancelled: return .red
        case .countdown:        return .orange
        case .active:           return .green
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(RPCViewModel())
        .environmentObject(AppCoordinator())
        .environmentObject(SafetyManager.shared)
}
