//
//  ModeSelectionView.swift
//  コツコツバンク
//

import SwiftUI
import SwiftData

struct ModeSelectionView: View {
    @Environment(SessionStore.self) private var session
    @Query(sort: \ChildProfile.createdAt) private var allChildren: [ChildProfile]

    private var children: [ChildProfile] {
        allChildren.filter { $0.accountID == session.account?.id }
    }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            VStack(spacing: 10) {
                Text("🏦")
                    .font(.system(size: 44))
                Text("だれがつかう?")
                    .font(.system(.title2, design: .rounded).bold())
                Text("アイコンをえらんでね")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 22) {
                ModeIcon(
                    systemImage: "person.fill",
                    colorHex: "6E6E6E",
                    label: "保護者"
                ) {
                    session.isEnteringGuardianMode = true
                }

                ForEach(children) { child in
                    ModeIcon(
                        systemImage: child.avatarSystemImage,
                        colorHex: child.colorHex,
                        label: child.name
                    ) {
                        session.mode = .child(child)
                    }
                }
            }

            Spacer()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ParentTheme.backgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct ModeIcon: View {
    let systemImage: String
    let colorHex: String
    let label: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.16))
                        .frame(width: 92, height: 92)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: colorHex), Color(hex: colorHex).opacity(0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 74, height: 74)
                        .shadow(color: Color(hex: colorHex).opacity(0.4), radius: 10, x: 0, y: 6)
                    Image(systemName: systemImage)
                        .font(.title)
                        .foregroundStyle(.white)
                }
                Text(LocalizedStringKey(label))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

extension Color {
    init(hex: String) {
        var hexValue = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexValue = hexValue.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexValue).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

#Preview {
    ModeSelectionView()
        .environment(SessionStore())
        .modelContainer(for: [ChildProfile.self], inMemory: true)
}
