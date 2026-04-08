// app/Core/Onboarding/View/FifthPageView.swift
import SwiftUI

struct FifthPageView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "qrcode.viewfinder")
                .resizable().scaledToFit().frame(width: 100, height: 100)
                .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.51))
            Text("Adding people")
                .font(.title.weight(.bold))
            VStack(alignment: .leading, spacing: 14) {
                HowToRow(icon: "qrcode",           text: "Ask them to open WhereFam and tap Share Your ID")
                HowToRow(icon: "camera.viewfinder", text: "Scan their QR with your camera — opens WhereFam automatically")
                HowToRow(icon: "doc.on.clipboard",  text: "Or paste their ID manually in the People tab")
            }.padding(.horizontal, 8)
            Spacer()
        }.padding()
    }
}

private struct HowToRow: View {
    let icon: String; let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 24)
                .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.51))
            Text(text).font(.body)
        }
    }
}