// app/Core/Onboarding/View/SecondPageView.swift
import SwiftUI

struct SecondPageView: View {
    @AppStorage("userName") var userName = ""
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("What's your name?")
                .font(.title.weight(.bold)).foregroundStyle(.white)
            TextField("Your name", text: $userName)
                .padding().frame(height: 50)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 25))
                .padding(.horizontal)
            Spacer()
        }.padding()
    }
}