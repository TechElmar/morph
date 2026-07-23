import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var step = 0
    @State private var draft = UserProfile()

    private let totalSteps = 4

    var body: some View {
        ZStack {
            MorphColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgressBar(current: step, total: totalSteps)
                    .padding(.horizontal, MorphSpacing.xl)
                    .padding(.top, MorphSpacing.lg)

                // Step content
                TabView(selection: $step) {
                    BasicInfoStep(draft: $draft).tag(0)
                    GoalsStep(draft: $draft).tag(1)
                    ActivityStep(draft: $draft).tag(2)
                    ReadyStep(draft: $draft).tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                // Navigation buttons
                HStack(spacing: MorphSpacing.md) {
                    if step > 0 {
                        MorphButton(title: "Back", style: .ghost) {
                            withAnimation { step -= 1 }
                        }
                        .frame(width: 100)
                    }

                    MorphButton(
                        title: step == totalSteps - 1 ? "Start My Journey" : "Continue",
                        style: .primary
                    ) {
                        if step == totalSteps - 1 {
                            var profile = draft
                            profile.email = authVM.currentUser.email
                            profile.name = authVM.currentUser.name
                            authVM.completeOnboarding(profile: profile)
                        } else {
                            withAnimation { step += 1 }
                        }
                    }
                }
                .padding(.horizontal, MorphSpacing.xl)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: MorphSpacing.sm) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= current ? MorphColors.accent : MorphColors.border)
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: current)
            }
        }
    }
}

// MARK: - Step 1: Basic Info
private struct BasicInfoStep: View {
    @Binding var draft: UserProfile
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MorphSpacing.lg) {
                OnboardingStepHeader(
                    emoji: "👤",
                    title: "About You",
                    subtitle: "Your stats help the AI calibrate scores to your body type"
                )

                VStack(spacing: MorphSpacing.md) {
                    // Units
                    VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                        FieldLabel("Units")
                        HStack(spacing: MorphSpacing.sm) {
                            ForEach(WeightUnit.allCases, id: \.rawValue) { u in
                                SelectChip(title: u.label, isSelected: unit == u) {
                                    unitRaw = u.rawValue
                                }
                            }
                        }
                    }

                    // Age
                    StepperField(label: "Age", value: $draft.age, range: 13...80, unit: "yrs")

                    // Gender
                    VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                        FieldLabel("Gender")
                        HStack(spacing: MorphSpacing.sm) {
                            ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                                SelectChip(title: g.rawValue, isSelected: draft.gender == g) {
                                    draft.gender = g
                                }
                            }
                        }
                    }

                    // Height
                    VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                        FieldLabel("Height: \(WeightFormat.height(draft.heightCm, unit: unit))")
                        Slider(value: $draft.heightCm, in: 140...220, step: 1)
                            .tint(MorphColors.accent)
                    }

                    // Weight
                    VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                        FieldLabel("Current Weight")
                        WeightSlider(weightKg: $draft.weightKg, unit: unit)
                    }
                }
            }
            .padding(MorphSpacing.xl)
        }
    }
}

// MARK: - Step 2: Goals
private struct GoalsStep: View {
    @Binding var draft: UserProfile
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MorphSpacing.lg) {
                OnboardingStepHeader(
                    emoji: "🎯",
                    title: "Your Goal",
                    subtitle: "This shapes how the AI evaluates and coaches you"
                )

                VStack(spacing: MorphSpacing.sm) {
                    ForEach(UserProfile.FitnessGoal.allCases, id: \.self) { goal in
                        GoalCard(goal: goal, isSelected: draft.fitnessGoal == goal) {
                            draft.fitnessGoal = goal
                        }
                    }
                }

                // Goal weight (only for loseFat/recomposition)
                if draft.fitnessGoal == .loseFat || draft.fitnessGoal == .recomposition {
                    VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                        FieldLabel("Goal Weight")
                        WeightSlider(weightKg: $draft.goalWeightKg, unit: unit)
                    }
                    .padding(.top, MorphSpacing.sm)
                }
            }
            .padding(MorphSpacing.xl)
        }
    }
}

private struct GoalCard: View {
    let goal: UserProfile.FitnessGoal
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MorphSpacing.md) {
                Image(systemName: goal.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? MorphColors.accent : MorphColors.textSecondary)
                    .frame(width: 28)

                Text(goal.rawValue)
                    .font(MorphFonts.body(15))
                    .foregroundColor(isSelected ? MorphColors.textPrimary : MorphColors.textSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MorphColors.accent)
                }
            }
            .padding(MorphSpacing.md)
            .background(isSelected ? MorphColors.accentDim : MorphColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.md)
                    .stroke(isSelected ? MorphColors.accent : MorphColors.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 3: Activity Level
private struct ActivityStep: View {
    @Binding var draft: UserProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MorphSpacing.lg) {
                OnboardingStepHeader(
                    emoji: "⚡️",
                    title: "Activity Level",
                    subtitle: "Helps calculate your caloric needs and pacing"
                )

                VStack(spacing: MorphSpacing.sm) {
                    ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                        ActivityCard(level: level, isSelected: draft.activityLevel == level) {
                            draft.activityLevel = level
                        }
                    }
                }
            }
            .padding(MorphSpacing.xl)
        }
    }
}

private struct ActivityCard: View {
    let level: UserProfile.ActivityLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.rawValue)
                        .font(MorphFonts.body(15))
                        .foregroundColor(isSelected ? MorphColors.textPrimary : MorphColors.textSecondary)
                    Text(level.description)
                        .font(MorphFonts.caption())
                        .foregroundColor(MorphColors.textTertiary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MorphColors.accent)
                }
            }
            .padding(MorphSpacing.md)
            .background(isSelected ? MorphColors.accentDim : MorphColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.md)
                    .stroke(isSelected ? MorphColors.accent : MorphColors.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Ready
private struct ReadyStep: View {
    @Binding var draft: UserProfile

    var body: some View {
        VStack(spacing: MorphSpacing.xl) {
            Spacer()

            VStack(spacing: MorphSpacing.lg) {
                Text("💪")
                    .font(.system(size: 64))

                Text("You're all set,\n\(draft.name.isEmpty ? "Athlete" : draft.name.components(separatedBy: " ").first ?? draft.name).")
                    .font(MorphFonts.heading(28))
                    .foregroundColor(MorphColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Upload your first 4-angle photo set and\nget your AI physique assessment.")
                    .font(MorphFonts.body(15))
                    .foregroundColor(MorphColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // What to expect
            VStack(spacing: MorphSpacing.sm) {
                ReadyItem(icon: "chart.bar.fill",    text: "Scores for symmetry, body fat, proportions & more")
                ReadyItem(icon: "fork.knife",         text: "Personalized nutrition recommendations")
                ReadyItem(icon: "dumbbell.fill",      text: "Targeted training focus areas")
                ReadyItem(icon: "arrow.up.right",     text: "Weekly progress tracking over time")
            }
            .padding(.horizontal, MorphSpacing.xl)

            Spacer()
        }
    }
}

private struct ReadyItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: MorphSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(MorphColors.accent)
                .frame(width: 20)
            Text(text)
                .font(MorphFonts.body(14))
                .foregroundColor(MorphColors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Helpers
struct OnboardingStepHeader: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
            Text(emoji).font(.system(size: 36))
            Text(title)
                .font(MorphFonts.heading(26))
                .foregroundColor(MorphColors.textPrimary)
            Text(subtitle)
                .font(MorphFonts.body(14))
                .foregroundColor(MorphColors.textSecondary)
        }
    }
}

struct FieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MorphFonts.caption())
            .foregroundColor(MorphColors.textSecondary)
            .tracking(0.5)
    }
}

struct SelectChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(MorphFonts.caption(13))
                .foregroundColor(isSelected ? MorphColors.accent : MorphColors.textSecondary)
                .padding(.horizontal, MorphSpacing.md)
                .padding(.vertical, MorphSpacing.sm)
                .background(isSelected ? MorphColors.accentDim : MorphColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? MorphColors.accent : MorphColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        HStack {
            FieldLabel(label)
            Spacer()
            HStack(spacing: MorphSpacing.md) {
                Button { if value > range.lowerBound { value -= 1 } } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(MorphColors.accent)
                }
                Text("\(value) \(unit)")
                    .font(MorphFonts.mono(15))
                    .foregroundColor(MorphColors.textPrimary)
                    .frame(width: 70)
                Button { if value < range.upperBound { value += 1 } } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(MorphColors.accent)
                }
            }
        }
    }
}
