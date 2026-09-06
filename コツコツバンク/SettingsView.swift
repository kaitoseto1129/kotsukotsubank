//
//  SettingsView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ChildProfile.createdAt) private var allChildren: [ChildProfile]
    @Query private var allGoals: [Goal]
    @Query private var allMissions: [Mission]

    private var children: [ChildProfile] {
        allChildren.filter { $0.accountID == session.account?.id }
    }

    @State private var showAddChild = false
    @State private var editingChild: ChildProfile?
    @State private var avatarSelectedPhoto: PhotosPickerItem?
    @State private var showAvatarCamera = false
    @State private var showAvatarCameraUnavailableAlert = false

    private var currencyBinding: Binding<AppCurrency> {
        Binding(
            get: { AppCurrency(rawValue: session.account?.currencyCode ?? AppCurrency.jpy.rawValue) ?? .jpy },
            set: { session.account?.currencyCode = $0.rawValue }
        )
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: session.account?.languageCode ?? AppLanguage.ja.rawValue) ?? .ja },
            set: { session.account?.languageCode = $0.rawValue }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("アカウント") {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(ParentTheme.accent.opacity(0.15))
                                .frame(width: 60, height: 60)
                            if let data = session.account?.avatarImageData, let image = PlatformImage(data: data) {
                                image.resizableImage
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(ParentTheme.accent)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text(session.account?.email ?? "-")
                            } icon: {
                                Image(systemName: "envelope.fill")
                                    .foregroundStyle(ParentTheme.accent)
                            }
                            .font(.subheadline)

                            HStack(spacing: 16) {
                                PhotosPicker(selection: $avatarSelectedPhoto, matching: .images) {
                                    Label("写真から選ぶ", systemImage: "photo.on.rectangle")
                                }

                                Button {
                                    #if os(iOS)
                                    if CameraCaptureView.isCameraAvailable {
                                        showAvatarCamera = true
                                    } else {
                                        showAvatarCameraUnavailableAlert = true
                                    }
                                    #else
                                    showAvatarCameraUnavailableAlert = true
                                    #endif
                                } label: {
                                    Label("撮影する", systemImage: "camera.fill")
                                }
                            }
                            .font(.caption.bold())
                            .foregroundStyle(ParentTheme.accent)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("通貨") {
                    Picker("通貨", selection: currencyBinding) {
                        ForEach(AppCurrency.allCases, id: \.self) { currency in
                            Text(LocalizedStringKey(currency.label)).tag(currency)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("言語") {
                    Picker("言語", selection: languageBinding) {
                        ForEach(AppLanguage.allCases, id: \.self) { language in
                            Text(language.label).tag(language)
                        }
                    }
                }

                Section("お子様(最大5人)") {
                    ForEach(children) { child in
                        Button {
                            editingChild = child
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: child.colorHex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Image(systemName: child.avatarSystemImage)
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                    }
                                Text(child.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteChildren)

                    if children.count < 5 {
                        Button {
                            showAddChild = true
                        } label: {
                            Label("お子様を追加", systemImage: "person.badge.plus")
                                .foregroundStyle(ParentTheme.accent)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        SupabaseSync.shared.stop()
                        session.logOut()
                        dismiss()
                    } label: {
                        Label("ログアウト", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .tint(ParentTheme.accent)
            .navigationTitle("設定")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            #endif
            .sheet(isPresented: $showAddChild) {
                if let accountID = session.account?.id {
                    AddChildView(accountID: accountID)
                }
            }
            .sheet(item: $editingChild) { child in
                AddChildView(accountID: child.accountID, existingChild: child)
            }
            .onChange(of: avatarSelectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        session.account?.avatarImageData = data
                    }
                }
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showAvatarCamera) {
                CameraCaptureView { data in
                    session.account?.avatarImageData = data
                }
                .ignoresSafeArea()
            }
            #endif
            .alert("カメラが使えません", isPresented: $showAvatarCameraUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("この端末ではカメラが使用できないため、「写真から選ぶ」から選んでください。")
            }
            .preferredColorScheme(.light)
        }
    }

    /// お子様を削除する際、そのお子様に紐づく目標・タスクも一緒に削除して孤立データを残さない。
    /// 端末間同期のため、削除は「墓標」を残してから hard delete する。
    private func deleteChildren(at offsets: IndexSet) {
        for index in offsets {
            let child = children[index]
            for goal in allGoals where goal.childID == child.id {
                modelContext.insert(SyncTombstone(rowID: goal.id, table: "goals", accountID: goal.accountID))
                modelContext.delete(goal)
            }
            for mission in allMissions where mission.childID == child.id {
                modelContext.insert(SyncTombstone(rowID: mission.id, table: "missions", accountID: mission.accountID))
                modelContext.delete(mission)
            }
            modelContext.insert(SyncTombstone(rowID: child.id, table: "child_profiles", accountID: child.accountID))
            modelContext.delete(child)
        }
    }
}

#Preview {
    SettingsView()
        .environment(SessionStore())
        .modelContainer(for: [ChildProfile.self], inMemory: true)
}
