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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(ParentTheme.accentSoft)
                    Text("目標・ご褒美設定")
                        .font(.system(.title3, design: .rounded).bold())
                }
                .padding(.top, 8)

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(white: 0.94))
                            .frame(height: 170)

                        if let imageData, let image = PlatformImage(data: imageData) {
                            image.resizableImage
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 170)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .clipped()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title)
                                Text("ご褒美の画像を選ぶ")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)

                VStack(spacing: 12) {
                    ParentTextField(title: "商品名", text: $title, icon: "tag.fill")
                    ParentTextField(title: "値段", text: $priceText, isNumeric: true, icon: (AppCurrency(rawValue: session.account?.currencyCode ?? AppCurrency.jpy.rawValue) ?? .jpy).systemImage)

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
                .cardStyle()

                if let fetchErrorMessage {
                    Label(fetchErrorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(ParentTheme.accent)
                }

                ParentPrimaryButton(
                    title: "保存",
                    isEnabled: !title.isEmpty && Double(priceText) != nil,
                    action: save
                )

                Text("リンクの横のボタンで、商品名・画像・値段の取得を試せます(サイトによっては取得できないことがあります)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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
    }

    private func fetchFromLink() {
        fetchErrorMessage = nil
        isFetchingLink = true
        Task {
            do {
                let metadata = try await ProductLinkFetcher.fetch(urlString: productURL)
                if let fetchedTitle = metadata.title, !fetchedTitle.isEmpty {
                    title = fetchedTitle
                }
                if let price = metadata.price {
                    priceText = String(Int(price))
                }
                if let imageData = metadata.imageData {
                    self.imageData = imageData
                }
                if metadata.title == nil && metadata.price == nil && metadata.imageData == nil {
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
        priceText = String(Int(goal.price))
        productURL = goal.productURL ?? ""
        imageData = goal.imageData
    }

    private func save() {
        guard let price = Double(priceText) else { return }

        if let goal = activeGoal {
            goal.title = title
            goal.price = price
            goal.productURL = productURL.isEmpty ? nil : productURL
            goal.imageData = imageData
        } else {
            let goal = Goal(title: title, price: price, productURL: productURL.isEmpty ? nil : productURL, imageData: imageData, childID: child.id)
            modelContext.insert(goal)
        }
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
