import SwiftUI

enum AppTheme {
    // MARK: - Colors (swiftui-design skill)
    static let background = Color(hex: 0xF9F9F9)
    static let surface = Color.white
    static let inputFill = Color(hex: 0xF5F5F5)
    static let primaryText = Color(hex: 0x2D2D2D)
    static let secondaryText = Color(hex: 0x8E8E93)

    static let pastelBlue = Color(hex: 0xC6E7FF)
    static let pastelPurple = Color(hex: 0xDCD6F7)
    static let pastelGreen = Color(hex: 0xE1EACD)
    static let pastelOrange = Color(hex: 0xFFDDAE)
    static let pastelPink = Color(hex: 0xFFD6E0)

    static let income = Color(hex: 0x34C759)
    static let expense = Color(hex: 0xFF3B30)
    static let accent = Color(hex: 0x2D2D2D)

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
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                    .stroke(Color.black.opacity(0.03), lineWidth: 1)
            )
    }
}

extension View {
    func appCard() -> some View {
        modifier(CardModifier())
    }

    /// Centers content and caps width on regular-size (iPad) layouts.
    func readableWidth(_ maxWidth: CGFloat = AdaptiveLayout.pageMaxWidth) -> some View {
        modifier(ReadableWidthModifier(maxWidth: maxWidth))
    }

    /// Comfortable sheet presentation: detents on iPhone, centered form sheet on iPad.
    func appSheetChrome(detents: Set<PresentationDetent> = [.large]) -> some View {
        modifier(AppSheetChromeModifier(detents: detents))
    }
}

enum AdaptiveLayout {
    static let pageMaxWidth: CGFloat = 840
    static let formMaxWidth: CGFloat = 560
    static let authMaxWidth: CGFloat = 440
    static let lockMaxWidth: CGFloat = 420

    static func metricColumns(horizontalSizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let count = horizontalSizeClass == .regular ? 4 : 2
        return Array(repeating: GridItem(.flexible(), spacing: AppTheme.md), count: count)
    }

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
            content
                .presentationDragIndicator(.visible)
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
                .stroke(Color.black.opacity(0.06), lineWidth: 10)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled ? Color.gray.opacity(0.3) : AppTheme.primaryText)
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
