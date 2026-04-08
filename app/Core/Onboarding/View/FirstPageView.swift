// app/Core/Onboarding/View/FirstPageView.swift
import SwiftUI

struct FirstPageView: View {
    
    var body: some View {
        VStack {
            Spacer()
                Text("Welcome!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                    .foregroundColor(Color(UIColor(#colorLiteral(red: 1, green: 0.7349339692, blue: 0.5137254902, alpha: 1))))
            
            Image(systemName: "figure.2.and.child.holdinghands")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
                .foregroundColor(Color(UIColor(#colorLiteral(red: 1, green: 0.7349339692, blue: 0.5137254902, alpha: 1))))
                .padding(.bottom, 32)
            
            HStack {
                Text("Stay connected with your loved ones ")
                    .font(.title2)
                    .padding([.leading, .trailing])
                    .foregroundColor(.gray)
                    
                Text("Globally, Securely and Privately.")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(UIColor(#colorLiteral(red: 1, green: 0.7349339692, blue: 0.5137254902, alpha: 1))))
                    .padding([.leading, .trailing])
                    
            }
            
            Spacer()
        }
        .padding()
        
    }
}
