// app/Manager/AppEnvironment.swift
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    weak var rpc: RPCViewModel?
    var pendingInvite: String?  // stored if deep link arrives before app is ready
    private init() {}
}
