// app/Core/Onboarding/View/SixthPageView.swift
import SwiftUI

struct SixthPageView: View {
    @AppStorage("userName") var userName = ""
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .resizable().scaledToFit().frame(width: 80, height: 80)
                .foregroundStyle(.white)
            Text(userName.isEmpty ? "You're all set!" : "You're all set, \(userName)!")
                .font(.title.weight(.bold)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text("Add your first family member to start sharing locations privately.")
                .font(.title3).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            Spacer()
        }.padding()
    }
}