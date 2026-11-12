import SwiftUI

enum Theme {
    static let accent = Color(red: 0.35, green: 0.94, blue: 0.82)
    static let accentDeep = Color(red: 0.08, green: 0.72, blue: 0.65)
    static let warn = Color(red: 1.0, green: 0.73, blue: 0.32)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let ink = Color(red: 0.02, green: 0.10, blue: 0.10)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.04, green: 0.07, blue: 0.11),
            Color(red: 0.03, green: 0.11, blue: 0.13),
            Color(red: 0.02, green: 0.04, blue: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let buttonGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension CardCategory {
    var symbol: String {
        switch self {
        case .access: return "building.2.fill"
        case .scooter: return "bolt.car.fill"
        case .home: return "house.fill"
        case .other: return "creditcard.fill"
        }
    }

    var tint: Color {
        switch self {
        case .access: return Color(red: 0.45, green: 0.78, blue: 1.0)
        case .scooter: return Color(red: 1.0, green: 0.72, blue: 0.36)
        case .home: return Theme.accent
        case .other: return Color(red: 0.78, green: 0.66, blue: 1.0)
        }
    }
}

extension CardCompatibility {
    var tint: Color {
        switch self {
        case .full: return Theme.accent
        case .uidOnly: return Theme.warn
        case .unsupported: return Theme.danger
        }
    }

    var symbol: String {
        switch self {
        case .full: return "checkmark.seal.fill"
        case .uidOnly: return "exclamationmark.circle.fill"
        case .unsupported: return "xmark.octagon.fill"
        }
    }
}

struct GlassCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
    }
}

struct KeyValueRow: View {
    let title: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.42))
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(monospaced ? .footnote.monospaced() : .footnote)
                .foregroundStyle(.white.opacity(0.9))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}
