// app/Manager/AppEnvironment.swift
// Singleton giving non-SwiftUI code access to RPCViewModel

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    weak var rpc: RPCViewModel?
    private init() {}
}