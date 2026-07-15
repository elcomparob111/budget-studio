import SwiftUI

/// Compact month pay-period list (mirrors web paycheck schedule).
struct PayPeriodScheduleView: View {
    let periods: [PayPeriodPreview]
    var expectedCheckAmount: Double? = nil
    var showNote = true
    var compact = false

    var body: some View {
        if periods.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.sm) {
                Text("Pay periods this month")
                    .font(.app(12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                if !compact, let amount = expectedCheckAmount, amount > 0 {
                    Text("Expected check · \(currency(amount))")
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                VStack(spacing: 0) {
                    ForEach(Array(periods.enumerated()), id: \.element.id) { index, period in
                        HStack {
                            Text(period.rangeLabel)
                                .font(.app(14, weight: period.isCurrent ? .semibold : .medium))
                                .foregroundStyle(period.isCurrent ? AppTheme.primaryText : AppTheme.secondaryText)
                            Spacer(minLength: 8)
                            if period.isCurrent {
                                Text("Current")
                                    .font(.app(11, weight: .bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.inputFill, in: Capsule())
                            }
                        }
                        .padding(.vertical, 8)

                        if index < periods.count - 1 {
                            Divider().opacity(0.35)
                        }
                    }
                }

                if showNote {
                    Text("Add income when you get paid.")
                        .font(.app(12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText.opacity(0.85))
                }
            }
        }
    }
}
