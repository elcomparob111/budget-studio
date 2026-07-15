import WidgetKit
import SwiftUI

// MARK: - Timeline

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SafeToSpendEntry {
        SafeToSpendEntry(date: Date(), snapshot: WidgetSnapshot(
            safeToSpend: 1_240,
            monthLabel: "July",
            updatedAt: Date().timeIntervalSince1970,
            signedIn: true
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (SafeToSpendEntry) -> Void) {
        completion(SafeToSpendEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SafeToSpendEntry>) -> Void) {
        let entry = SafeToSpendEntry(date: Date(), snapshot: WidgetSnapshot.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct SafeToSpendEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Palette (mirrors AppTheme; widget can't import the app target)

private enum WidgetTheme {
    static let background = Color(red: 249 / 255, green: 249 / 255, blue: 249 / 255)
    static let surface = Color.white
    static let primary = Color(red: 45 / 255, green: 45 / 255, blue: 45 / 255)
    static let secondary = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let pastelBlue = Color(red: 198 / 255, green: 231 / 255, blue: 1)
    static let pastelGreen = Color(red: 225 / 255, green: 234 / 255, blue: 205 / 255)
    static let pastelOrange = Color(red: 1, green: 221 / 255, blue: 174 / 255)
    static let pastelPink = Color(red: 1, green: 214 / 255, blue: 224 / 255)
    static let expense = Color(red: 1, green: 59 / 255, blue: 48 / 255)
}

// MARK: - Views

struct BudgetStudioWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var overBudget: Bool { entry.snapshot.safeToSpend < 0 }

    var body: some View {
        Group {
            if !entry.snapshot.signedIn {
                signedOutLayout
            } else if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .widgetURL(AppGroup.addExpenseURL)
    }

    private var widgetBackground: some View {
        ZStack {
            WidgetTheme.background
            // Soft atmosphere — sky → sage, matching the app's pastel system.
            LinearGradient(
                colors: [
                    WidgetTheme.pastelBlue.opacity(0.55),
                    WidgetTheme.background,
                    WidgetTheme.pastelGreen.opacity(0.45),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Soft light orb in the corner for depth without clutter.
            Circle()
                .fill(WidgetTheme.pastelOrange.opacity(0.35))
                .frame(width: 120, height: 120)
                .blur(radius: 2)
                .offset(x: family == .systemMedium ? 130 : 48, y: family == .systemMedium ? -28 : -36)
            Circle()
                .fill(WidgetTheme.pastelBlue.opacity(0.4))
                .frame(width: 90, height: 90)
                .offset(x: family == .systemMedium ? -110 : -40, y: family == .systemMedium ? 40 : 50)
        }
    }

    // MARK: Small

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                accentGlyph
                Spacer(minLength: 0)
                statusChip
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(monthCaption)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetTheme.secondary)
                    .lineLimit(1)

                Text(entry.snapshot.safeToSpend, format: .currency(code: currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(overBudget ? WidgetTheme.expense : WidgetTheme.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            addChip(compact: true)
        }
        .padding(2)
    }

    // MARK: Medium

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    accentGlyph
                    Text("BUDGET STUDIO")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.secondary)
                        .tracking(0.8)
                    Spacer(minLength: 0)
                    statusChip
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(monthCaption)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetTheme.secondary)

                    Text(entry.snapshot.safeToSpend, format: .currency(code: currencyCode))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(overBudget ? WidgetTheme.expense : WidgetTheme.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .monospacedDigit()
                }

                Spacer(minLength: 0)
            }

            VStack {
                Spacer(minLength: 0)
                addChip(compact: false)
                Spacer(minLength: 0)
            }
        }
        .padding(2)
    }

    // MARK: Signed out

    private var signedOutLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                accentGlyph
                Text("BUDGET STUDIO")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(WidgetTheme.secondary)
                    .tracking(0.8)
            }

            Text("Your safe-to-spend\nlives here")
                .font(.system(size: family == .systemMedium ? 20 : 16, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("Open & sign in")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(WidgetTheme.surface.opacity(0.9), in: Capsule())
                .overlay(Capsule().stroke(Color.black.opacity(0.04), lineWidth: 1))
        }
        .padding(2)
    }

    // MARK: Pieces

    private var accentGlyph: some View {
        Text(overBudget && entry.snapshot.signedIn ? "⚠️" : "💵")
            .font(.system(size: 18))
            .frame(width: 36, height: 36)
            .background(
                (overBudget && entry.snapshot.signedIn ? WidgetTheme.pastelPink : WidgetTheme.pastelGreen)
                    .opacity(0.85),
                in: Circle()
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var statusChip: some View {
        if entry.snapshot.signedIn {
            Text(overBudget ? "Over" : "On track")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WidgetTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (overBudget ? WidgetTheme.pastelPink : WidgetTheme.pastelGreen).opacity(0.9),
                    in: Capsule()
                )
        }
    }

    private func addChip(compact: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: compact ? 11 : 13, weight: .bold))
            Text(compact ? "Add" : "Add expense")
                .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(WidgetTheme.primary)
        .padding(.horizontal, compact ? 10 : 14)
        .padding(.vertical, compact ? 7 : 12)
        .frame(maxWidth: compact ? .infinity : nil)
        .background(WidgetTheme.surface.opacity(0.92), in: Capsule())
        .overlay(Capsule().stroke(Color.black.opacity(0.04), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    private var monthCaption: String {
        let month = entry.snapshot.monthLabel
        if month.isEmpty { return "Safe to spend" }
        return "Safe to spend · \(month)"
    }

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
}

// MARK: - Widget

@main
struct BudgetStudioWidget: Widget {
    let kind = "BudgetStudioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BudgetStudioWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Safe to spend")
        .description("See what's left in your plan and tap to add an expense.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
