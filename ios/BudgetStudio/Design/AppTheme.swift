import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Colors (match web CSS vars in styles.css :root / [data-theme="dark"])
    static let background = Color.adaptiveColor(light: 0xF9F9F9, dark: 0x121212)
    static let surface = Color.adaptiveColor(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let inputFill = Color.adaptiveColor(light: 0xF5F5F5, dark: 0x2C2C2E)
    static let primaryText = Color.adaptiveColor(light: 0x2D2D2D, dark: 0xF5F5F7)
    static let secondaryText = Color.adaptiveColor(light: 0x8E8E93, dark: 0x98989D)

    static let buttonFill = Color.adaptiveColor(light: 0x2D2D2D, dark: 0xF5F5F7)
    static let buttonForeground = Color.adaptiveColor(light: 0xFFFFFF, dark: 0x2D2D2D)
    static let cardStroke = Color.adaptiveColor(light: 0x000000, dark: 0xFFFFFF, lightOpacity: 0.03, darkOpacity: 0.06)
    static let cardShadow = Color.adaptiveColor(light: 0x000000, dark: 0x000000, lightOpacity: 0.04, darkOpacity: 0.35)
    static let ringTrack = Color.adaptiveColor(light: 0x000000, dark: 0xFFFFFF, lightOpacity: 0.06, darkOpacity: 0.12)

    static let pastelBlue = Color.adaptiveColor(light: 0xC6E7FF, dark: 0x1E3A5F)
    static let pastelPurple = Color.adaptiveColor(light: 0xDCD6F7, dark: 0x2E2648)
    static let pastelGreen = Color.adaptiveColor(light: 0xE1EACD, dark: 0x1F3D2A)
    static let pastelOrange = Color.adaptiveColor(light: 0xFFDDAE, dark: 0x4A3418)
    static let pastelPink = Color.adaptiveColor(light: 0xFFD6E0, dark: 0x4A1F28)

    static let income = Color(hex: 0x34C759)
    static let expense = Color(hex: 0xFF3B30)
    static let accent = primaryText
    /// Switch tint — green reads clearly on light and dark cards (primaryText is near-white when ON).
    static let toggleTint = income

    // MARK: - Spacing
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let pagePadding: CGFloat = 24

    // Back-compat aliases used by existing views
    static let ink = primaryText
    static let muted = secondaryText
    static let page = background
    static let card = surface

    static func groupTint(_ group: String) -> Color {
        switch group {
        case "Needs": return pastelBlue
        case "Wants": return pastelPurple
        case "Savings": return pastelGreen
        case "Income": return pastelGreen
        default: return pastelOrange
        }
    }

    /// Soft bar fills for the Overview category breakdown (pastel, group-aware).
    static func chartBarColor(group: String, index: Int) -> Color {
        let palette: [Color]
        switch group {
        case "Needs":
            palette = [pastelBlue, pastelBlue.opacity(0.85), pastelBlue.opacity(0.7), pastelBlue.opacity(0.55)]
        case "Wants":
            palette = [pastelPurple, pastelPink, pastelPurple.opacity(0.8), pastelPink.opacity(0.8)]
        case "Savings":
            palette = [pastelGreen, pastelGreen.opacity(0.85), pastelGreen.opacity(0.7), pastelGreen.opacity(0.55)]
        default:
            palette = [pastelOrange, pastelPink, pastelBlue, pastelPurple]
        }
        return palette[index % palette.count]
    }

    static func groupEmoji(_ group: String) -> String {
        switch group {
        case "Needs": return "🏠"
        case "Wants": return "✨"
        case "Savings": return "🌱"
        case "Income": return "💵"
        default: return "•"
        }
    }
}

extension Color {
    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    private static func uiColor(hex: UInt, opacity: Double = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }

    static func adaptiveColor(
        light: UInt,
        dark: UInt,
        lightOpacity: Double = 1,
        darkOpacity: Double = 1
    ) -> Color {
        Color(
            UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? uiColor(hex: dark, opacity: darkOpacity)
                    : uiColor(hex: light, opacity: lightOpacity)
            }
        )
    }
}

extension Font {
    static func app(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardStroke, lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }

    /// Typed text / cursor color for fields sitting on `AppTheme.inputFill`.
    /// Always use this — system label color can be white in dark appearance while fill stays light.
    func appInputText() -> some View {
        self
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.primaryText)
    }

    /// Centers content and caps width on regular-size (iPad) layouts.
    func readableWidth(_ maxWidth: CGFloat = AdaptiveLayout.pageMaxWidth) -> some View {
        modifier(ReadableWidthModifier(maxWidth: maxWidth))
    }

    /// Comfortable sheet presentation: medium/large detents on iPhone;
    /// page-sized (or large) sheet on iPad so forms are not cramped.
    func appSheetChrome(detents: Set<PresentationDetent> = [.large]) -> some View {
        modifier(AppSheetChromeModifier(detents: detents))
    }

    /// Adds a Done button above the decimal/number pad so users can dismiss it.
    func decimalPadDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
                .font(.app(16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            }
        }
    }
}

enum AdaptiveLayout {
    static let pageMaxWidth: CGFloat = 840
    static let formMaxWidth: CGFloat = 560
    static let authMaxWidth: CGFloat = 440
    static let lockMaxWidth: CGFloat = 420

    static func categoryColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let count = horizontalSizeClass == .regular ? 2 : 1
        return Array(repeating: GridItem(.flexible(), spacing: AppTheme.md), count: count)
    }
}

private struct ReadableWidthModifier: ViewModifier {
    let maxWidth: CGFloat
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: horizontalSizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

private struct AppSheetChromeModifier: ViewModifier {
    let detents: Set<PresentationDetent>
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @ViewBuilder
    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            // Default iPad form sheet is a short centered card that clips forms.
            // Prefer page sizing (iOS 18+); fall back to a large detent on iOS 17.
            if #available(iOS 18.0, *) {
                content
                    .presentationDragIndicator(.visible)
                    .presentationSizing(.page)
            } else {
                content
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
            }
        } else {
            content
                .presentationDragIndicator(.visible)
                .presentationDetents(detents)
                .presentationContentInteraction(.scrolls)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var valueColor: Color = AppTheme.primaryText
    var emoji: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            HStack(spacing: AppTheme.sm) {
                if let emoji {
                    Text(emoji)
                        .font(.app(16))
                }
                Text(title)
                    .font(.app(13, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(value)
                .font(.app(24, weight: .bold))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(subtitle)
                .font(.app(12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard()
    }
}

struct BudgetRingView: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.ringTrack, lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    progress > 1 ? AppTheme.expense : AppTheme.primaryText,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: progress)
            Text(label)
                .font(.app(16, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(width: 84, height: 84)
    }
}

struct GroupPill: View {
    let group: String

    var body: some View {
        HStack(spacing: 4) {
            Text(AppTheme.groupEmoji(group))
                .font(.app(10))
            Text(group)
                .font(.app(12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(AppTheme.groupTint(group).opacity(0.35), in: Capsule())
        .foregroundStyle(AppTheme.primaryText)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(16, weight: .bold))
            .foregroundStyle(AppTheme.buttonForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? Color.gray.opacity(0.3) : AppTheme.buttonFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

func currency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
}

func currencyDetailed(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.maximumFractionDigits = 2
    return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
}
