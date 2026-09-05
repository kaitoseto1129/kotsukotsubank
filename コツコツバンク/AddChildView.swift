//
//  AddChildView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddChildView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let accountID: UUID
    var existingChild: ChildProfile?

    private let icons = ["face.smiling.fill", "star.fill", "heart.fill", "bolt.fill", "leaf.fill"]
    private let colors = ["3478F6", "FF6B00", "34C759", "AF52DE", "FF2D55"]
    private let emptyStateIcons = ["sparkles", "star.circle.fill", "sun.max.fill", "party.popper.fill", "trophy.fill", "book.fill"]

    @State private var name = ""
    @State private var selectedIcon = "face.smiling.fill"
    @State private var selectedColor = "3478F6"
    @State private var selectedEmptyStateIcon = "sparkles"
    @State private var avatarImageData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false

    private var isEditing: Bool { existingChild != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: selectedColor).opacity(0.18))
                                .frame(width: 96, height: 96)
                            Circle()
                                .fill(Color(hex: selectedColor))
                                .frame(width: 76, height: 76)
                                .shadow(color: Color(hex: selectedColor).opacity(0.4), radius: 8, x: 0, y: 4)

                            if let avatarImageData, let image = PlatformImage(data: avatarImageData) {
                                image.resizableImage
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: selectedIcon)
                                    .font(.title)
                                    .foregroundStyle(.white)
                            }
                        }

                        HStack(spacing: 16) {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("写真を選ぶ", systemImage: "photo.on.rectangle")
                                    .font(.caption.bold())
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
                                Label("写真を撮る", systemImage: "camera.fill")
                                    .font(.caption.bold())
                            }

                            if avatarImageData != nil {
                                Button(role: .destructive) {
                                    avatarImageData = nil
                                } label: {
                                    Label("削除", systemImage: "trash")
                                        .font(.caption.bold())
                                }
                            }
                        }
                        .tint(ParentTheme.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("お子様の情報") {
                    TextField("お名前", text: $name)
                }

                Section("アイコン") {
                    HStack {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? Color(hex: selectedColor) : Color(white: 0.9))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("カラー") {
                    HStack {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                selectedColor = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if selectedColor == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    HStack {
                        ForEach(emptyStateIcons, id: \.self) { icon in
                            Button {
                                selectedEmptyStateIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(selectedEmptyStateIcon == icon ? Color(hex: selectedColor) : Color(white: 0.9))
                                    .foregroundStyle(selectedEmptyStateIcon == icon ? .white : .primary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("今日のタスクがない時のイラスト")
                } footer: {
                    Text("お子様のTOP画面で、今日のミッションがまだない時に表示されます")
                }
            }
            .navigationTitle(isEditing ? "お子様を編集" : "お子様を追加")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "保存" : "追加") { save() }
                        .disabled(name.isEmpty)
                }
            }
            #endif
            .tint(ParentTheme.accent)
            .preferredColorScheme(.light)
        }
        .onAppear {
            guard let existingChild else { return }
            name = existingChild.name
            selectedIcon = existingChild.avatarSystemImage
            selectedColor = existingChild.colorHex
            avatarImageData = existingChild.avatarImageData
            selectedEmptyStateIcon = existingChild.emptyStateIconName
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    avatarImageData = data
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { data in
                avatarImageData = data
            }
            .ignoresSafeArea()
        }
        #endif
        .alert("カメラが使えません", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラが使用できないため、「写真を選ぶ」から選んでください。")
        }
    }

    private func save() {
        if let existingChild {
            existingChild.name = name
            existingChild.avatarSystemImage = selectedIcon
            existingChild.colorHex = selectedColor
            existingChild.avatarImageData = avatarImageData
            existingChild.emptyStateIconName = selectedEmptyStateIcon
        } else {
            let child = ChildProfile(
                accountID: accountID,
                name: name,
                avatarSystemImage: selectedIcon,
                colorHex: selectedColor
            )
            child.avatarImageData = avatarImageData
            child.emptyStateIconName = selectedEmptyStateIcon
            modelContext.insert(child)
        }
        dismiss()
    }
}

#Preview {
    AddChildView(accountID: UUID())
        .modelContainer(for: [ChildProfile.self], inMemory: true)
}
