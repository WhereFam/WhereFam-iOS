// app/Core/Onboarding/View/ThirdPageView.swift
import SwiftUI
import PhotosUI

struct ThirdPageView: View {
    @AppStorage("userAvatarBase64") var avatarBase64: String?
    @State private var image: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Add a photo")
                .font(.title.weight(.bold))
                .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.51))
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let img = image {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(width: 140, height: 140).clipShape(Circle())
                        } else {
                            Circle().fill(Color(red: 1, green: 0.73, blue: 0.51).opacity(0.15))
                                .frame(width: 140, height: 140)
                                .overlay(Image(systemName: "person.fill").font(.system(size: 60))
                                    .foregroundStyle(Color(red: 1, green: 0.73, blue: 0.51)))
                        }
                    }
                    Image(systemName: "plus.circle.fill").font(.system(size: 30))
                        .foregroundStyle(.white)
                        .background(Color(red: 1, green: 0.73, blue: 0.51)).clipShape(Circle())
                }
            }
            Text("Optional — shown to your trusted peers on the map.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .onChange(of: pickerItem) { _, item in
            Task {
                if let item, let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    image = img
                    avatarBase64 = (img.jpegData(compressionQuality: 0.6) ?? data).base64EncodedString()
                }
            }
        }
    }
}