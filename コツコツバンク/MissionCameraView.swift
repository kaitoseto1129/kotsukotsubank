//
//  MissionCameraView.swift
//  コツコツバンク
//

import SwiftUI
import PhotosUI

struct MissionCameraView: View {
    let mission: Mission
    let childName: String
    let onFinished: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImageData: Data?
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("写真を撮ってね")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(Palette.textPrimary)

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.cardGradient)
                    .frame(width: 280, height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Palette.accent.opacity(0.1), lineWidth: 1.5)
                    )

                if let capturedImageData, let image = PlatformImage(data: capturedImageData) {
                    image.resizableImage
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .clipped()
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Palette.accent.opacity(0.3))
                }
            }
            .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)

            HStack(spacing: 20) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("画像選択", systemImage: "photo.on.rectangle")
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Palette.cardGradient)
                        .clipShape(Capsule())
                }

                Button {
                    #if os(iOS)
                    if CameraCaptureView.isCameraAvailable {
                        showCamera = true
                    } else {
                        showCameraUnavailableAlert = true
                    }
                    #else
                    showCameraUnavailableAlert = true
                    #endif
                } label: {
                    Label("シャッター", systemImage: "camera.shutter.button.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Palette.ctaGradient)
                        .clipShape(Capsule())
                        .shadow(color: Palette.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }

            if capturedImageData != nil {
                NavigationLink {
                    MissionCommentSubmitView(mission: mission, photoData: capturedImageData, childName: childName, onFinished: onFinished)
                } label: {
                    Text("これでOK!")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Palette.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Palette.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(PressableButtonStyle())
                .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    capturedImageData = data
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { data in
                capturedImageData = data
            }
            .ignoresSafeArea()
        }
        #endif
        .alert("カメラが使えません", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラが使用できないため、「画像選択」から写真を選んでください。")
        }
    }
}

#Preview {
    NavigationStack {
        MissionCameraView(mission: Mission(title: "お皿洗い", reward: 100, childID: UUID()), childName: "子ども1", onFinished: {})
    }
    .preferredColorScheme(.dark)
}
