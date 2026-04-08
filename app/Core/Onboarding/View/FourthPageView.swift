// app/Core/Onboarding/View/FourthPageView.swift
import SwiftUI

struct FourthPageView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "location.circle.fill")
                .resizable().scaledToFit().frame(width: 100, height: 100).foregroundStyle(.white)
            Text("Share your location")
                .font(.title.weight(.bold)).foregroundStyle(.white)
            Text("Your location is shared only with people you trust, directly over an encrypted peer-to-peer connection. No server ever sees it.")
                .font(.body).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            Button {
                LocationManager.shared.requestPermission()
            } label: {
                Text("Allow Location Access")
                    .font(.headline).padding()
                    .frame(maxWidth: .infinity)
                    .background(.white)
                    .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.51))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }.padding(.horizontal)
            Spacer()
        }.padding()
    }
}