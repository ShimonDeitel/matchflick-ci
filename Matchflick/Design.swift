import SwiftUI
import UIKit

// MARK: - "Swipe Reel" color system — Minder's own visual lens
// Flat surfaces, system semantic colors (so Light AND Dark both look right),
// a single hot-pink/red swipe-app accent (in Tinder's family) standing in for the shared
// house blue — signals "swipe app" at a glance while staying entirely flat, no gradients.

extension Color {
    static let matchflickAccent = Color(hex: "#FD3A69")             // swipe-reel red-pink, the single accent
    static let matchflickCard = Color(uiColor: .secondarySystemBackground)
    static let matchflickCard2 = Color(uiColor: .tertiarySystemBackground)
    static let matchflickField = Color(uiColor: .tertiarySystemFill)
    static let matchflickHair = Color(uiColor: .separator)
}

// MARK: - Flat surfaces (cards / pills / buttons)

extension View {
    func matchflickCard(cornerRadius: CGFloat = 20) -> some View {
        self.padding(16)
            .background(Color.matchflickCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func matchflickPill() -> some View {
        self.padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.matchflickCard, in: Capsule())
    }

    /// Primary action — a clean, flat Apple-blue filled capsule.
    func prominentButton() -> some View { self.buttonStyle(FilledAccentButtonStyle()) }
    /// Secondary action — flat tinted capsule.
    func softButton() -> some View { self.buttonStyle(SoftButtonStyle()) }
}

struct FilledAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .background(Color.matchflickAccent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.medium))
            .foregroundStyle(Color.matchflickAccent)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(Color.matchflickCard, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A springy scale-down-on-press style for the circular swipe-vote buttons.
struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

// MARK: - Background (flat, adapts to light/dark)

struct MatchflickBackground: View {
    var body: some View { Color(uiColor: .systemBackground).ignoresSafeArea() }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

// MARK: - Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
