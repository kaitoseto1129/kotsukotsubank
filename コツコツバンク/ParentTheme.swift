//
//  ParentTheme.swift
//  コツコツバンク
//

import SwiftUI

enum ParentTheme {
    static let accent = Color(red: 0.90, green: 0.06, blue: 0.13)
    static let accentSoft = Color(red: 1.0, green: 0.55, blue: 0.1)
    static let card = Color.white

    static let backgroundGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.95, blue: 0.90), Color(red: 0.96, green: 0.97, blue: 1.0)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let ctaGradient = LinearGradient(
        colors: [accent, accentSoft],
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
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
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
        .background(Color(white: 0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isFocused ? ParentTheme.accent.opacity(0.6) : Color.clear, lineWidth: 1.5)
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
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(isEnabled ? AnyShapeStyle(ParentTheme.ctaGradient) : AnyShapeStyle(Color.gray.opacity(0.35)))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: isEnabled ? ParentTheme.accent.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
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
                    .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 8, x: 0, y: 4)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)

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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

/// 保護者/子どもをスライドで切り替えるトグル。どちらの背景色でも見えるようMaterialを使う。
struct ModeSwitchControl: View {
    var isGuardian: Bool
    var onSwitchToGuardian: () -> Void
    var onSwitchToChild: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            option(emoji: "🧑", selected: isGuardian, action: onSwitchToGuardian)
            option(emoji: "🧒", selected: !isGuardian, action: onSwitchToChild)
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.easeInOut(duration: 0.2), value: isGuardian)
    }

    @ViewBuilder
    private func option(emoji: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(emoji)
                .font(.system(size: 16))
                .frame(width: 36, height: 30)
                .background {
                    if selected {
                        Capsule().fill(ParentTheme.ctaGradient)
                    } else {
                        Capsule().fill(Color.white.opacity(0.001))
                    }
                }
                .opacity(selected ? 1 : 0.45)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
