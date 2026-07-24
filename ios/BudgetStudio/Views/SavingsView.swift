import SwiftUI

struct SavingsView: View {
    @EnvironmentObject private var store: BudgetStore

    @State private var showNewGoal = false
    @State private var editingGoal: SavingsGoal?
    @State private var addMoneyGoal: SavingsGoal?

    private var goals: [SavingsGoal] { store.state.goals }

    private var savedTotal: Double {
        goals.reduce(0) { $0 + max(0, $1.current) }
    }

    private var targetTotal: Double {
        goals.reduce(0) { $0 + max(0, $1.target) }
    }

    private var leftTotal: Double {
        max(0, targetTotal - savedTotal)
    }

    private var overallProgress: Double {
        targetTotal > 0 ? min(1, savedTotal / targetTotal) : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.xxl) {
                    heroComposition

                    if goals.isEmpty {
                        emptyState
                    } else {
                        goalsSection
                    }
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.md)
                .padding(.bottom, AppTheme.xxl)
                .readableWidth()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("Savings")
                        .font(.app(17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 36, height: 36)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    }
                    .accessibilityLabel("New goal")
                }
            }
            .sheet(isPresented: $showNewGoal) {
                GoalEditorSheet(mode: .create) { name, target, current in
                    store.addSavingsGoal(name: name, target: target, current: current)
                }
                .appSheetChrome(detents: [.medium, .large])
            }
            .sheet(item: $editingGoal) { goal in
                GoalEditorSheet(mode: .edit(goal)) { name, target, current in
                    store.updateSavingsGoal(id: goal.id, name: name, target: target, current: current)
                }
                .appSheetChrome(detents: [.medium, .large])
            }
            .sheet(item: $addMoneyGoal) { goal in
                AddMoneySheet(goal: goal) { amount in
                    store.addMoneyToGoal(id: goal.id, amount: amount)
                }
                .appSheetChrome(detents: [.height(360), .medium])
            }
        }
    }

    // MARK: - Hero

    private var heroComposition: some View {
        VStack(alignment: .leading, spacing: AppTheme.xl) {
            HStack(alignment: .top, spacing: AppTheme.lg) {
                VStack(alignment: .leading, spacing: AppTheme.sm) {
                    Text("Saved so far")
                        .font(.app(12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .textCase(.uppercase)
                        .tracking(1.2)

                    Text(currency(savedTotal))
                        .font(.app(48, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .monospacedDigit()
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    Text(goals.isEmpty ? "No goals yet" : "\(goals.count) goal\(goals.count == 1 ? "" : "s") · \(currency(leftTotal)) to go")
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !goals.isEmpty {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.ringTrack, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: overallProgress)
                            .stroke(AppTheme.income, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: overallProgress)

                        VStack(spacing: 2) {
                            Text("\(Int((overallProgress * 100).rounded()))%")
                                .font(.app(16, weight: .bold))
                                .foregroundStyle(AppTheme.primaryText)
                                .monospacedDigit()
                            Text("done")
                                .font(.app(10, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                                .textCase(.uppercase)
                        }
                    }
                    .frame(width: 84, height: 84)
                }
            }

            if !goals.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.xl) {
                    heroInlineStat(label: "Target", value: currency(targetTotal), color: AppTheme.primaryText)
                    heroInlineStat(label: "Left", value: currency(leftTotal), color: AppTheme.secondaryText)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(AppTheme.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.pastelGreen.opacity(0.55),
                            AppTheme.pastelBlue.opacity(0.35),
                            AppTheme.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func heroInlineStat(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.app(11, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)
            Text(value)
                .font(.app(18, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.lg) {
            Text("Goals")
                .font(.app(13, weight: .bold))
                .foregroundStyle(AppTheme.secondaryText)
                .textCase(.uppercase)
                .tracking(0.8)

            VStack(spacing: AppTheme.md) {
                ForEach(goals) { goal in
                    goalCard(goal)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppTheme.md) {
            Text("What are you saving for?")
                .font(.app(20, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Emergency fund, a trip, a new laptop — pick a target and watch it grow.")
                .font(.app(15, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
            Button("Create your first goal") { showNewGoal = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, AppTheme.xs)
        }
        .padding(AppTheme.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.cardStroke, lineWidth: 1)
        )
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        let progress = goal.target > 0 ? min(1, goal.current / goal.target) : 0
        let percent = Int((progress * 100).rounded())
        let left = max(0, goal.target - goal.current)
        let done = goal.current >= goal.target

        return VStack(alignment: .leading, spacing: AppTheme.md) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(.app(17, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(currency(goal.current)) of \(currency(goal.target))")
                        .font(.app(13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .monospacedDigit()
                }
                Spacer()
                Text("\(percent)%")
                    .font(.app(24, weight: .bold))
                    .foregroundStyle(done ? AppTheme.income : AppTheme.primaryText)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.ringTrack)
                        .frame(height: 6)
                    Capsule()
                        .fill(done ? AppTheme.income : AppTheme.pastelGreen)
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            Text(done ? "Goal reached" : "\(currency(left)) to go")
                .font(.app(12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: AppTheme.sm) {
                if !done {
                    Button("Add money") { addMoneyGoal = goal }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button("Edit") { editingGoal = goal }
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.inputFill)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("Delete") { store.deleteSavingsGoal(id: goal.id) }
                    .font(.app(14, weight: .semibold))
                    .foregroundStyle(AppTheme.expense)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppTheme.pastelPink.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(AppTheme.lg)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(done ? AppTheme.income.opacity(0.35) : AppTheme.cardStroke, lineWidth: done ? 1.5 : 1)
        )
    }
}

private enum GoalEditorMode {
    case create
    case edit(SavingsGoal)
}

private struct GoalEditorSheet: View {
    let mode: GoalEditorMode
    let onSave: (String, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetText = ""
    @State private var currentText = "0"
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.lg) {
                    labeled("What are you saving for?") {
                        TextField("Emergency fund, vacation...", text: $name)
                            .focused($nameFocused)
                            .font(.app(16, weight: .medium))
                            .appInputText()
                            .padding(.horizontal, AppTheme.lg)
                            .padding(.vertical, AppTheme.md)
                            .background(AppTheme.inputFill)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    labeled("Target amount") {
                        TextField("1000", text: $targetText)
                            .keyboardType(.decimalPad)
                            .font(.app(16, weight: .medium))
                            .appInputText()
                            .padding(.horizontal, AppTheme.lg)
                            .padding(.vertical, AppTheme.md)
                            .background(AppTheme.inputFill)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if isEditing {
                        labeled("Already saved") {
                            TextField("0", text: $currentText)
                                .keyboardType(.decimalPad)
                                .font(.app(16, weight: .medium))
                                .appInputText()
                                .padding(.horizontal, AppTheme.lg)
                                .padding(.vertical, AppTheme.md)
                                .background(AppTheme.inputFill)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }

                    Button(isEditing ? "Save changes" : "Create goal") {
                        let target = Double(targetText.replacingOccurrences(of: ",", with: "")) ?? 0
                        let current = Double(currentText.replacingOccurrences(of: ",", with: "")) ?? 0
                        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, target > 0 else { return }
                        onSave(name, target, isEditing ? current : 0)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle(disabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, AppTheme.pagePadding)
                .padding(.top, AppTheme.lg)
                .padding(.bottom, AppTheme.xl)
                .readableWidth(AdaptiveLayout.formMaxWidth)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit goal" : "New goal")
            .navigationBarTitleDisplayMode(.inline)
            .decimalPadDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .onAppear {
                if case .edit(let goal) = mode {
                    name = goal.name
                    targetText = goal.target.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(goal.target))
                        : String(goal.target)
                    currentText = goal.current.truncatingRemainder(dividingBy: 1) == 0
                        ? String(Int(goal.current))
                        : String(goal.current)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    nameFocused = true
                }
            }
        }
    }

    private func labeled(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.sm) {
            Text(title)
                .font(.app(13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
            content()
        }
    }
}

private struct AddMoneySheet: View {
    let goal: SavingsGoal
    let onAdd: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    private var left: Double { max(0, goal.target - goal.current) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AppTheme.lg) {
                Text(
                    left > 0
                        ? "\(currency(goal.current)) saved · \(currency(left)) left to hit \(currency(goal.target))"
                        : "\(currency(goal.current)) saved · this goal is already complete"
                )
                .font(.app(14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

                VStack(alignment: .leading, spacing: AppTheme.sm) {
                    Text("How much are you adding?")
                        .font(.app(13, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                    TextField("50", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.app(28, weight: .bold))
                        .appInputText()
                        .focused($amountFocused)
                        .padding(.horizontal, AppTheme.lg)
                        .padding(.vertical, AppTheme.md)
                        .background(AppTheme.inputFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.sm) {
                    ForEach([25, 50, 100, 200], id: \.self) { preset in
                        Button("+\(preset)") {
                            amountText = String(preset)
                        }
                        .font(.app(14, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.inputFill)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                Button("Add to goal") {
                    let amount = Double(amountText.replacingOccurrences(of: ",", with: "")) ?? 0
                    guard amount > 0 else { return }
                    onAdd(amount)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle(disabled: (Double(amountText) ?? 0) <= 0))
                .disabled((Double(amountText) ?? 0) <= 0)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppTheme.pagePadding)
            .padding(.top, AppTheme.lg)
            .padding(.bottom, AppTheme.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle(goal.name)
            .navigationBarTitleDisplayMode(.inline)
            .decimalPadDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.app(15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    amountFocused = true
                }
            }
        }
    }
}
