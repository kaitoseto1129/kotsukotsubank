//
//  ParentTheme.swift
//  コツコツバンク
//

import SwiftUI

enum ParentTheme {
    /// メインの青(ヘッダー帯・アイコン・リンク)
    static let accent = Color(red: 0.12, green: 0.31, blue: 0.85)
    /// 差し色の黄色(メインのボタン・目立たせたい所)
    static let accentSoft = Color(red: 1.0, green: 0.72, blue: 0.01)
    /// 黄色いボタンの上の文字色(濃い紺)
    static let ctaText = Color(red: 0.05, green: 0.11, blue: 0.24)
    /// カードや入力欄に使う、ごく薄い青
    static let card = Color(red: 0.93, green: 0.95, blue: 0.99)

    /// 背景は白一色(グラデーションはやめた)
    static let backgroundGradient = LinearGradient(
        colors: [Color.white, Color.white],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 青一色(既存の呼び出しを壊さないため、型はLinearGradientのまま)
    static let ctaGradient = LinearGradient(
        colors: [accent, accent],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct ParentBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ParentTheme.backgroundGradient.ignoresSafeArea())
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ParentTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func parentBackground() -> some View { modifier(ParentBackground()) }
    func cardStyle(padding: CGFloat = 16) -> some View { modifier(CardBackground(padding: padding)) }
}

struct ParentTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var isSecure: Bool = false
    var isEmail: Bool = false
    var isNumeric: Bool = false
    /// 4桁の暗証番号入力用。数字キーパッドを強制し、5文字目以降の入力を切り捨てる。
    var isPIN: Bool = false
    var icon: String? = nil

    @FocusState private var isFocused: Bool
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(isFocused ? ParentTheme.accent : .secondary)
                    .frame(width: 20)
            }

            Group {
                if isSecure {
                    if isRevealed {
                        TextField(title, text: $text)
                            #if os(iOS)
                            .keyboardType(isPIN ? .numberPad : .default)
                            #endif
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(title, text: $text)
                            #if os(iOS)
                            .keyboardType(isPIN ? .numberPad : .default)
                            #endif
                    }
                } else {
                    TextField(title, text: $text)
                        #if os(iOS)
                        .keyboardType(isNumeric ? .decimalPad : (isEmail ? .emailAddress : .default))
                        #endif
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                if isPIN {
                    let digitsOnly = newValue.filter(\.isNumber)
                    text = String(digitsOnly.prefix(4))
                }
            }

            if isSecure {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? ParentTheme.accent : Color(red: 0.82, green: 0.86, blue: 0.95), lineWidth: isFocused ? 2 : 1)
        )
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

struct ParentPrimaryButton: View {
    let title: LocalizedStringKey
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(isEnabled ? ParentTheme.ctaText : Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isEnabled ? AnyShapeStyle(ParentTheme.accentSoft) : AnyShapeStyle(Color.gray.opacity(0.35)))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 顔写真があればそれを、なければアイコン+カラーを表示するアバター
struct AvatarView: View {
    var imageData: Data?
    var systemImage: String
    var colorHex: String
    var diameter: CGFloat = 74

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: colorHex).opacity(0.18))
                .frame(width: diameter * 1.26, height: diameter * 1.26)

            if let imageData, let image = PlatformImage(data: imageData) {
                image.resizableImage
                    .aspectRatio(contentMode: .fill)
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: diameter, height: diameter)
                Image(systemName: systemImage)
                    .font(.system(size: diameter * 0.4))
                    .foregroundStyle(.white)
            }
        }
    }
}

/// ダッシュボードなどで使う、アイコン付きのメニュー行
struct IconMenuRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    var badgeCount: Int = 0

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(ParentTheme.accent)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }

            Text(title)
                .font(.headline)
                .foregroundStyle(ParentTheme.ctaText)

            Spacer()

            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ParentTheme.accent)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(ParentTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// 保護者/子どもをスライドで切り替えるトグル。どちらの背景色でも見えるようMaterialを使う。
struct ModeSwitchControl: View {
    var isGuardian: Bool
    var onSwitchToGuardian: () -> Void
    var onSwitchToChild: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            option(icon: "person.fill", label: "保護者", selected: isGuardian, action: onSwitchToGuardian)
            option(icon: "face.smiling.fill", label: "こども", selected: !isGuardian, action: onSwitchToChild)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.easeInOut(duration: 0.2), value: isGuardian)
    }

    @ViewBuilder
    private func option(icon: String, label: LocalizedStringKey, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 9)
            .frame(height: 34)
            .background {
                if selected {
                    Capsule().fill(ParentTheme.ctaGradient)
                } else {
                    Capsule().fill(Color.white.opacity(0.001))
                }
            }
            .opacity(selected ? 1 : 0.55)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
