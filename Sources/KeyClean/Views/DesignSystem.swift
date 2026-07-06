import SwiftUI

struct KeyCleanCardBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(cardHighlight, lineWidth: 0.5)
                    }
                    .shadow(color: cardShadow, radius: 8, y: 2)
            }
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color.black.opacity(0.34) : Color.black.opacity(0.035)
    }

    private var cardHighlight: Color {
        colorScheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.045)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.065)
    }
}

extension View {
    func keyCleanCardBackground(cornerRadius: CGFloat = 10) -> some View {
        modifier(KeyCleanCardBackground(cornerRadius: cornerRadius))
    }
}

struct IconActionButton: View {
    let systemName: String
    let help: String
    var tint: Color = .secondary
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(disabled ? Color.secondary.opacity(0.45) : tint)
                .frame(width: 24, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(disabled ? 0.035 : 0.065))
                }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct KeyCleanPrimaryButtonStyle: ButtonStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(configuration.isPressed ? 0.78 : 1))
            }
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(tint.opacity(0.12))
            }
    }
}

struct SettingsSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.4)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .keyCleanCardBackground()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
