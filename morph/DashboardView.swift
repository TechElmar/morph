import SwiftUI

// MARK: - Main Tab View
struct MainTabView: View {
    @StateObject private var checkInVM = CheckInViewModel()
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        TabView(selection: $checkInVM.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)

            CheckInView()
                .tabItem {
                    Label("Check In", systemImage: "camera.fill")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(MorphColors.accent)
        .environmentObject(checkInVM)
    }
}

// MARK: - Dashboard
struct DashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var checkInVM: CheckInViewModel
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"
    @State private var showPaywall = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: MorphSpacing.lg) {

                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hey, \(authVM.currentUser.name.components(separatedBy: " ").first ?? "Athlete") 👋")
                                    .font(MorphFonts.heading(22))
                                    .foregroundColor(MorphColors.textPrimary)
                                Text(weekLabel)
                                    .font(MorphFonts.caption())
                                    .foregroundColor(MorphColors.textSecondary)
                            }
                            Spacer()
                            HStack(spacing: MorphSpacing.sm) {
                                if checkInVM.weeklyStreak > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 13))
                                        Text("\(checkInVM.weeklyStreak)")
                                            .font(MorphFonts.heading(15))
                                    }
                                    .foregroundColor(MorphColors.warning)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(MorphColors.warning.opacity(0.12))
                                    .clipShape(Capsule())
                                }

                                if subscriptionVM.isPro {
                                    HStack(spacing: 4) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 11))
                                        Text("PRO")
                                            .font(MorphFonts.caption(11))
                                    }
                                    .foregroundColor(MorphColors.background)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(MorphColors.accent)
                                    .clipShape(Capsule())
                                } else {
                                    Button { showPaywall = true } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "crown")
                                                .font(.system(size: 11))
                                            Text("PRO")
                                                .font(MorphFonts.caption(11))
                                        }
                                        .foregroundColor(MorphColors.accent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(MorphColors.accentDim)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)
                        .padding(.top, MorphSpacing.lg)

                        if !checkInVM.hasAnyCheckIn {
                            EmptyDashboardCard {
                                checkInVM.selectedTab = 1
                            }
                        } else {
                            // Stats row
                            DashboardStatsRow(unit: unit)
                                .padding(.horizontal, MorphSpacing.xl)

                            // Goal weight progress
                            if authVM.currentUser.fitnessGoal == .loseFat || authVM.currentUser.fitnessGoal == .recomposition,
                               let progress = checkInVM.goalProgress(goalKg: authVM.currentUser.goalWeightKg) {
                                GoalProgressCard(
                                    progress: progress,
                                    currentKg: checkInVM.checkIns.first?.weightKg ?? 0,
                                    goalKg: authVM.currentUser.goalWeightKg,
                                    unit: unit
                                )
                                .padding(.horizontal, MorphSpacing.xl)
                            }

                            // Check-in due prompt
                            if checkInVM.canCheckIn(isPro: subscriptionVM.isPro) {
                                CheckInDueCard {
                                    checkInVM.selectedTab = 1
                                }
                                .padding(.horizontal, MorphSpacing.xl)
                            }

                            if let analysis = checkInVM.latestAnalysis {
                                // Weekly focus hero
                                WeeklyFocusHero(focus: analysis.weeklyFocus)
                                    .padding(.horizontal, MorphSpacing.xl)

                                OverallScoreCard(analysis: analysis)
                                    .padding(.horizontal, MorphSpacing.xl)

                                ScoreGrid(analysis: analysis, previous: checkInVM.previousAnalysis)
                                    .padding(.horizontal, MorphSpacing.xl)

                                MacroCard(analysis: analysis)
                                    .padding(.horizontal, MorphSpacing.xl)

                                CoachSummaryCard(analysis: analysis)
                                    .padding(.horizontal, MorphSpacing.xl)

                                RecommendationsCard(analysis: analysis)
                                    .padding(.horizontal, MorphSpacing.xl)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Stats Row
private struct DashboardStatsRow: View {
    @EnvironmentObject var checkInVM: CheckInViewModel
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: MorphSpacing.sm) {
            StatBox(
                value: "\(checkInVM.checkIns.count)",
                label: "Check-Ins",
                icon: "camera.fill",
                tint: MorphColors.accent
            )

            StatBox(
                value: unit.format(checkInVM.checkIns.first?.weightKg ?? 0, decimals: 0),
                label: weightDeltaLabel,
                icon: "scalemass.fill",
                tint: MorphColors.success
            )

            StatBox(
                value: "\(checkInVM.weeklyStreak)w",
                label: "Streak",
                icon: "flame.fill",
                tint: MorphColors.warning
            )
        }
    }

    private var weightDeltaLabel: String {
        guard let delta = checkInVM.weightDeltaKg, abs(delta) >= 0.05 else { return "Weight" }
        let display = unit.fromKg(abs(delta))
        return String(format: "%@%.1f since last", delta > 0 ? "+" : "−", display)
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(tint)
            Text(value)
                .font(MorphFonts.heading(16))
                .foregroundColor(MorphColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MorphSpacing.md)
        .padding(.horizontal, MorphSpacing.sm)
        .morphCard()
    }
}

// MARK: - Goal Progress Card
private struct GoalProgressCard: View {
    let progress: Double
    let currentKg: Double
    let goalKg: Double
    let unit: WeightUnit

    @State private var animatedProgress: Double = 0

    private var remainingLabel: String {
        let remaining = abs(currentKg - goalKg)
        if remaining < 0.3 { return "Goal reached! 🎉" }
        return "\(unit.format(remaining)) to go"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
            HStack {
                Text("GOAL PROGRESS")
                    .font(MorphFonts.caption(10))
                    .foregroundColor(MorphColors.textTertiary)
                    .tracking(1.5)
                Spacer()
                Text(remainingLabel)
                    .font(MorphFonts.caption(12))
                    .foregroundColor(MorphColors.accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MorphColors.border).frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [MorphColors.accent.opacity(0.7), MorphColors.accent],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geo.size.width * animatedProgress), height: 10)
                }
            }
            .frame(height: 10)

            HStack {
                Text(unit.format(currentKg))
                    .font(MorphFonts.mono(12))
                    .foregroundColor(MorphColors.textSecondary)
                Spacer()
                Text("Goal: \(unit.format(goalKg))")
                    .font(MorphFonts.mono(12))
                    .foregroundColor(MorphColors.textSecondary)
            }
        }
        .padding(MorphSpacing.lg)
        .morphCard()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Check-In Due Card
private struct CheckInDueCard: View {
    let onCheckIn: () -> Void

    var body: some View {
        Button(action: onCheckIn) {
            HStack(spacing: MorphSpacing.md) {
                ZStack {
                    Circle()
                        .fill(MorphColors.accentDim)
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 17))
                        .foregroundColor(MorphColors.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("This week's check-in is due")
                        .font(MorphFonts.heading(14))
                        .foregroundColor(MorphColors.textPrimary)
                    Text("Keep the streak alive — snap your 4 photos")
                        .font(MorphFonts.caption(12))
                        .foregroundColor(MorphColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(MorphColors.accent)
            }
            .padding(MorphSpacing.md)
            .background(MorphColors.accentDim.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.lg))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.lg)
                    .stroke(MorphColors.accent.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weekly Focus Hero
private struct WeeklyFocusHero: View {
    let focus: String

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "scope")
                    .font(.system(size: 12, weight: .bold))
                Text("THIS WEEK'S FOCUS")
                    .font(MorphFonts.caption(10))
                    .tracking(1.5)
            }
            .foregroundColor(MorphColors.accent)

            Text(focus)
                .font(MorphFonts.heading(17))
                .foregroundColor(MorphColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MorphSpacing.lg)
        .background(
            LinearGradient(
                colors: [MorphColors.accentDim, MorphColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.lg))
        .overlay(
            RoundedRectangle(cornerRadius: MorphCorners.lg)
                .stroke(MorphColors.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Empty State
private struct EmptyDashboardCard: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: MorphSpacing.lg) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(MorphColors.textTertiary)

            VStack(spacing: MorphSpacing.sm) {
                Text("No check-ins yet")
                    .font(MorphFonts.heading(20))
                    .foregroundColor(MorphColors.textPrimary)
                Text("Upload your first 4-angle photo set to get\nyour AI physique assessment, macro targets,\nand a personalized training plan.")
                    .font(MorphFonts.body(14))
                    .foregroundColor(MorphColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            MorphButton(title: "Start First Check-In", style: .primary) {
                onStart()
            }
        }
        .padding(MorphSpacing.xxl)
        .frame(maxWidth: .infinity)
        .morphCard()
        .padding(.horizontal, MorphSpacing.xl)
    }
}

// MARK: - Overall Score Card
struct OverallScoreCard: View {
    let analysis: PhysiqueAnalysis

    var body: some View {
        HStack(spacing: MorphSpacing.lg) {
            ScoreRing(score: analysis.overallScore)

            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                Text("Overall Score")
                    .font(MorphFonts.heading(18))
                    .foregroundColor(MorphColors.textPrimary)

                if let bf = analysis.estimatedBodyFatPercent {
                    Label(String(format: "~%.0f%% body fat", bf), systemImage: "drop.fill")
                        .font(MorphFonts.caption(13))
                        .foregroundColor(MorphColors.textSecondary)
                }
                Label(analysis.estimatedMuscleRating.capitalized, systemImage: "figure.strengthtraining.traditional")
                    .font(MorphFonts.caption(13))
                    .foregroundColor(MorphColors.textSecondary)

                if let progress = analysis.progressScore {
                    HStack(spacing: 4) {
                        Image(systemName: progress >= 5 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 11))
                        Text("Progress: \(String(format: "%.1f", progress))/10")
                            .font(MorphFonts.caption(12))
                    }
                    .foregroundColor(progress >= 5 ? MorphColors.success : MorphColors.warning)
                }
            }

            Spacer()
        }
        .padding(MorphSpacing.lg)
        .morphCard(elevated: true)
    }
}

// MARK: - Score Grid
struct ScoreGrid: View {
    let analysis: PhysiqueAnalysis
    var previous: PhysiqueAnalysis? = nil

    var scoreItems: [(String, Double, Double?, String)] {[
        ("Symmetry",   analysis.symmetryScore,            previous?.symmetryScore,            "arrow.left.and.right"),
        ("Muscle Dev", analysis.muscularDevelopmentScore, previous?.muscularDevelopmentScore, "dumbbell.fill"),
        ("Leanness",   analysis.bodyFatScore,             previous?.bodyFatScore,             "flame.fill"),
        ("Proportion", analysis.proportionScore,          previous?.proportionScore,          "ruler.fill"),
    ]}

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: MorphSpacing.md) {
            ForEach(scoreItems, id: \.0) { item in
                ScoreTile(label: item.0, score: item.1, previousScore: item.2, icon: item.3)
            }
        }
    }
}

struct ScoreTile: View {
    let label: String
    let score: Double
    var previousScore: Double? = nil
    let icon: String

    private var delta: Double? {
        guard let prev = previousScore else { return nil }
        let d = score - prev
        return abs(d) >= 0.05 ? d : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(MorphColors.textTertiary)
                Spacer()
                if let delta = delta {
                    Text(String(format: "%@%.1f", delta > 0 ? "▲" : "▼", abs(delta)))
                        .font(MorphFonts.caption(10))
                        .foregroundColor(delta > 0 ? MorphColors.success : MorphColors.destructive)
                }
                Text(String(format: "%.1f", score))
                    .font(MorphFonts.mono(18))
                    .foregroundColor(MorphColors.scoreColor(score))
            }
            Text(label)
                .font(MorphFonts.caption(12))
                .foregroundColor(MorphColors.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(MorphColors.border).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(MorphColors.scoreColor(score))
                        .frame(width: geo.size.width * (score / 10), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(MorphSpacing.md)
        .morphCard()
    }
}

// MARK: - Coach Summary
struct CoachSummaryCard: View {
    let analysis: PhysiqueAnalysis
    var showFocus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.md) {
            Label("Coach's Take", systemImage: "bubble.left.fill")
                .font(MorphFonts.heading(15))
                .foregroundColor(MorphColors.accent)

            Text(analysis.coachSummary)
                .font(MorphFonts.body(14))
                .foregroundColor(MorphColors.textSecondary)
                .lineSpacing(4)

            if showFocus && !analysis.weeklyFocus.isEmpty {
                Divider().background(MorphColors.border)

                Text("THAT WEEK'S FOCUS")
                    .font(MorphFonts.caption(10))
                    .foregroundColor(MorphColors.textTertiary)
                    .tracking(1.5)

                Text(analysis.weeklyFocus)
                    .font(MorphFonts.body(14))
                    .foregroundColor(MorphColors.textPrimary)
                    .padding(MorphSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MorphColors.accentDim)
                    .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}

// MARK: - Recommendations Card
struct RecommendationsCard: View {
    let analysis: PhysiqueAnalysis
    @State private var selectedTab = 0

    private let tabs = ["Diet", "Training", "Schedule", "Supps"]

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.md) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    let idx = tabs.firstIndex(of: tab)!
                    Button(tab) { selectedTab = idx }
                        .font(MorphFonts.caption(11))
                        .foregroundColor(selectedTab == idx ? MorphColors.accent : MorphColors.textTertiary)
                        .padding(.vertical, MorphSpacing.sm)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if selectedTab == idx {
                                Rectangle().fill(MorphColors.accent).frame(height: 2)
                            }
                        }
                }
            }

            if selectedTab == 2 {
                VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                    ForEach(analysis.weeklyTrainingBreakdown, id: \.self) { day in
                        HStack(spacing: MorphSpacing.sm) {
                            Circle().fill(MorphColors.accent).frame(width: 5, height: 5).padding(.top, 1)
                            Text(day)
                                .font(MorphFonts.body(13))
                                .foregroundColor(MorphColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            } else {
                let items: [String] = selectedTab == 0 ? analysis.dietRecommendations :
                                       selectedTab == 1 ? analysis.trainingRecommendations :
                                                          analysis.supplementSuggestions
                VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: MorphSpacing.sm) {
                            Circle().fill(MorphColors.accent).frame(width: 5, height: 5).padding(.top, 6)
                            Text(item)
                                .font(MorphFonts.body(13))
                                .foregroundColor(MorphColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(2)
                        }
                    }
                }
            }
        }
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}
