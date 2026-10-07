//
//  SignUpCompleteView.swift
//  コツコツバンク
//

import SwiftUI

struct SignUpCompleteView: View {
    let children: [ChildProfile]
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didAppear = false
    @State private var childNames: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(ParentTheme.ctaGradient.opacity(0.18))
                            .frame(width: 132, height: 132)
                        Circle()
                            .fill(ParentTheme.card)
                            .frame(width: 100, height: 100)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                    }
                    .scaleEffect(didAppear ? 1 : 0.6)
                    .opacity(didAppear ? 1 : 0)

                    Text("🎉 登録が完了しました!")
                        .font(.system(.title2).bold())
                        .multilineTextAlignment(.center)
                    Text("さっそく使ってみましょう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                if !children.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(ParentTheme.accent.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "figure.2.and.child.holdinghands")
                                    .foregroundStyle(ParentTheme.accent)
                            }
                            Text("お子様のお名前")
                                .font(.system(.headline))
                        }

                        Text("あとから設定画面でも変更できます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(childNames.indices, id: \.self) { index in
                            ParentTextField(
                                title: "お子様\(index + 1)の名前",
                                text: Binding(
                                    get: { childNames[index] },
                                    set: { childNames[index] = $0 }
                                ),
                                icon: "person.fill"
                            )
                        }
                    }
                    .cardStyle()
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(ParentTheme.accent.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.fill")
                                .foregroundStyle(ParentTheme.accent)
                        }
                        Text("保護者モードについて")
                            .font(.system(.headline))
                    }

                    Text("次の画面で「保護者」を選ぶと、保護者専用のパスワードをその場で設定できます。2回目からはそのパスワードで入ります。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .cardStyle()

                ParentPrimaryButton(title: "はじめる") {
                    for (index, child) in children.enumerated() where index < childNames.count {
                        let trimmed = childNames[index].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            child.name = trimmed
                        }
                    }
                    dismiss()
                    onContinue()
                }
            }
            .padding(24)
        }
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                didAppear = true
            }
            if childNames.isEmpty {
                childNames = children.map { $0.name }
            }
        }
    }
}

#Preview {
    SignUpCompleteView(children: [], onContinue: {})
}
