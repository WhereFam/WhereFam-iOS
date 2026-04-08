// app/Core/Home/View/AboutView.swift
import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Links") {
                    Link(destination: URL(string: "https://wherefam.com/privacy.html")!) {
                        Label("Privacy Policy", systemImage: "lock")
                    }
                    Link(destination: URL(string: "https://wherefam.com/terms.html")!) {
                        Label("Terms of Use", systemImage: "checkmark.shield")
                    }
                    Link(destination: URL(string: "https://github.com/wherefam/wherefam")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }

                Section("Privacy") {
                    Label("No server ever stores your location", systemImage: "xmark.icloud")
                    Label("End-to-end encrypted peer-to-peer", systemImage: "lock.fill")
                    Label("All data lives on your device", systemImage: "iphone")
                    Label("12-word backup phrase for identity restore", systemImage: "key.fill")
                }
                .foregroundStyle(.secondary)
            }
            .navigationTitle("WhereFam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}