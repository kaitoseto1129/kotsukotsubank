//
//  GoalRewardSettingView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData
import PhotosUI

struct GoalRewardSettingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionStore.self) private var session
    let child: ChildProfile

    @Query private var allGoals: [Goal]
    @Query private var allMissions: [Mission]
    /// 受け取り済みでない、現在進行中の目標。受け取り済みの目標は履歴として残し、上書きしない。
    private var activeGoal: Goal? {
        allGoals
            .filter { $0.childID == child.id && $0.redeemedAt == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    @State private var title = ""
    @State private var priceText = ""
    @State private var productURL = ""
    @State private var imageData: Data?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isFetchingLink = false
    @State private var fetchErrorMessage: String?
    @State private var showDeleteImageConfirm = false
    @State private var showCamera = false
    @State private var showCameraUnavailableAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(ParentTheme.accentSoft)
                    Text("目標・ご褒美設定")
                        .font(.system(.title3).bold())
                }
                .padding(.top, 8)

                // ①画像の枠
                Group {
                    if let imageData, let image = PlatformImage(data: imageData) {
                        Button {
                            showDeleteImageConfirm = true
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(white: 0.94))
                                    .frame(height: 170)
                                    .frame(maxWidth: .infinity)

                                image.resizableImage
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 170)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white, .black.opacity(0.5))
                                    .padding(10)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(white: 0.94))
                                .frame(height: 170)

                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title)
                                Text("ご褒美の画像を選ぼう")
                                    .font(.subheadline.bold())
                                Text("Amazon等のURLを入れると自動で入ります")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .confirmationDialog(
                    "この画像を削除しますか?",
                    isPresented: $showDeleteImageConfirm,
                    titleVisibility: .visible
                ) {
                    Button("削除", role: .destructive) {
                        imageData = nil
                        selectedPhoto = nil
                    }
                    Button("キャンセル", role: .cancel) {}
                }

                HStack(spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("写真から選ぶ", systemImage: "photo.on.rectangle")
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
                }
                .tint(ParentTheme.accent)

                // ②URL(ここにAmazon等のリンクを貼ってもらいたいので、赤で目立たせる)
                VStack(alignment: .leading, spacing: 8) {
                    Label("↓ ここにAmazon等の商品URLを貼り付けたら画像が自動的にはいります", systemImage: "arrow.down.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)

                    HStack(spacing: 10) {
                        ParentTextField(title: "amazon等商品リンク", text: $productURL, icon: "link")

                        Button {
                            fetchFromLink()
                        } label: {
                            if isFetchingLink {
                                ProgressView()
                                    .frame(width: 44, height: 44)
                            } else {
                                Image(systemName: "arrow.down.doc.fill")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(ParentTheme.ctaGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .disabled(productURL.isEmpty || isFetchingLink)
                    }
                }
                .padding(16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red, lineWidth: 2)
                )

                Text("リンクの横のボタンで、商品名・画像の取得を試せます(サイトによっては取得できないことがあります)。値段は間違えることがあるため、必ず手入力してください。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let fetchErrorMessage {
                    Label(fetchErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                VStack(spacing: 12) {
                    ParentTextField(title: "商品名", text: $title, icon: "tag.fill")
                    ParentTextField(title: "値段", text: $priceText, isNumeric: true, icon: (AppCurrency(rawValue: session.account?.currencyCode ?? AppCurrency.jpy.rawValue) ?? .jpy).systemImage)
                }
                .cardStyle()

                // ③保存ボタン
                ParentPrimaryButton(
                    title: "保存",
                    isEnabled: !title.isEmpty && (Double(priceText) ?? 0) > 0,
                    action: save
                )
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear(perform: loadExistingGoal)
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    imageData = data
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { data in
                imageData = data
            }
            .ignoresSafeArea()
        }
        #endif
        .alert("カメラが使えません", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("この端末ではカメラが使用できないため、「写真から選ぶ」から選んでください。")
        }
    }

    private func fetchFromLink() {
        fetchErrorMessage = nil
        isFetchingLink = true
        Task {
            do {
                // 値段は自動取得すると間違えることが多いため、商品名と画像だけ自動で入れる。
                // 値段は必ず手入力してもらう。
                let metadata = try await ProductLinkFetcher.fetch(urlString: productURL)
                if let fetchedTitle = metadata.title, !fetchedTitle.isEmpty {
                    title = fetchedTitle
                }
                if let imageData = metadata.imageData {
                    self.imageData = imageData
                }
                if metadata.title == nil && metadata.imageData == nil {
                    fetchErrorMessage = "商品情報を取得できませんでした。手入力してください。"
                }
            } catch {
                fetchErrorMessage = "商品情報を取得できませんでした。手入力してください。"
            }
            isFetchingLink = false
        }
    }

    private func loadExistingGoal() {
        guard let goal = activeGoal else { return }
        title = goal.title
        priceText = wholeNumberString(goal.price)
        productURL = goal.productURL ?? ""
        imageData = goal.imageData
    }

    private func save() {
        guard let price = Double(priceText), price > 0 else { return }

        // 前の目標をすでに達成している(でも子どもがまだ受け取っていない)のに、新しいご褒美を選んだ場合は、
        // 前の目標を受け取り済みにして、新しい目標を0から貯め直す。(達成前なら、いまの目標の内容を直すだけ)
        var goalToEdit = activeGoal
        if let current = goalToEdit {
            let saved = Goal.savedAmount(childID: child.id, goals: allGoals, missions: allMissions)
            if current.price > 0, saved >= current.price {
                current.redeemedAt = .now
                goalToEdit = nil
            }
        }

        if let goal = goalToEdit {
            goal.title = title
            goal.price = price
            goal.productURL = productURL.isEmpty ? nil : productURL
            goal.imageData = imageData
        } else {
            let goal = Goal(title: title, price: price, productURL: productURL.isEmpty ? nil : productURL, imageData: imageData, childID: child.id)
            modelContext.insert(goal)
        }
        AnalyticsService.log(.goalCreated)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GoalRewardSettingView(child: ChildProfile(accountID: UUID(), name: "子ども1"))
    }
    .environment(SessionStore())
    .modelContainer(for: [Goal.self], inMemory: true)
}
