// app/Core/Root/ContentView.swift
import SwiftUI
import ConcentricOnboarding

struct ContentView: View {
    @AppStorage("completedOnboarding") private var completedOnboarding = false
    @EnvironmentObject var rpc: RPCViewModel

    var body: some View {
        if completedOnboarding {
            HomeView()
        } else {
            ConcentricOnboardingView(pageContents: [
                (AnyView(FirstPageView()),  Color.white),
                (AnyView(SecondPageView()), Color(red: 1, green: 0.73, blue: 0.51)),
                (AnyView(ThirdPageView()),  Color.white),
                (AnyView(FourthPageView()), Color(red: 1, green: 0.73, blue: 0.51)),
                (AnyView(FifthPageView()),  Color.white),
                (AnyView(SixthPageView()),  Color(red: 1, green: 0.73, blue: 0.51))
            ])
            .nextIcon("chevron.right")
            .didGoToLastPage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    completedOnboarding = true
                }
            }
        }
    }
}