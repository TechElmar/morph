import SwiftUI
import PhotosUI
import Combine

struct CheckInView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var checkInVM: CheckInViewModel
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"
    @State private var currentWeight: Double = 75
    @State private var notes = ""
    @State private var showPaywall = false
    @State private var showPhotoTips = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }
    private var canSubmit: Bool { checkInVM.canCheckIn(isPro: subscriptionVM.isPro) }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                if checkInVM.isAnalyzing {
                    AnalyzingView()
                } else {
                    ScrollView {
                        VStack(spacing: MorphSpacing.xl) {

                            // Header
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                    Text(subscriptionVM.isPro ? "Daily Check-In" : "Weekly Check-In")
                                        .font(MorphFonts.heading(24))
                                        .foregroundColor(MorphColors.textPrimary)
                                    Text("4 full-body photos · front, back, left, right")
                                        .font(MorphFonts.caption())
                                        .foregroundColor(MorphColors.textSecondary)
                                }
                                Spacer()
                                Button {
                                    showPhotoTips = true
                                } label: {
                                    Image(systemName: "questionmark.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(MorphColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, MorphSpacing.xl)
                            .padding(.top, MorphSpacing.lg)

                            // Gate banner when locked
                            if !canSubmit {
                                CheckInLockedCard(
                                    isPro: subscriptionVM.isPro,
                                    nextDate: checkInVM.nextCheckInDate(isPro: subscriptionVM.isPro),
                                    onUpgrade: { showPaywall = true }
                                )
                                .padding(.horizontal, MorphSpacing.xl)
                            }

                            // Photo grid
                            PhotoUploadGrid(checkIn: $checkInVM.currentDraft)
                                .padding(.horizontal, MorphSpacing.xl)

                            // Weight input
                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                Text("TODAY'S WEIGHT")
                                    .font(MorphFonts.caption(10))
                                    .foregroundColor(MorphColors.textTertiary)
                                    .tracking(1.5)

                                WeightSlider(weightKg: $currentWeight, unit: unit)
                            }
                            .padding(MorphSpacing.lg)
                            .morphCard()
                            .padding(.horizontal, MorphSpacing.xl)

                            // Notes
                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                Text("NOTES (OPTIONAL)")
                                    .font(MorphFonts.caption(10))
                                    .foregroundColor(MorphColors.textTertiary)
                                    .tracking(1.5)
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("e.g. been training 5x/week, diet on point this week…")
                                            .font(MorphFonts.body(13))
                                            .foregroundColor(MorphColors.textTertiary)
                                            .padding(4)
                                    }
                                    TextEditor(text: $notes)
                                        .font(MorphFonts.body(13))
                                        .foregroundColor(MorphColors.textSecondary)
                                        .frame(minHeight: 80)
                                        .scrollContentBackground(.hidden)
                                }
                            }
                            .padding(MorphSpacing.lg)
                            .morphCard()
                            .padding(.horizontal, MorphSpacing.xl)

                            if let error = checkInVM.errorMessage {
                                ErrorBanner(message: error)
                                    .padding(.horizontal, MorphSpacing.xl)
                            }

                            // Submit button
                            MorphButton(
                                title: canSubmit ? "Analyze My Physique" : (subscriptionVM.isPro ? "Come Back Tomorrow" : "Upgrade for Daily Check-Ins"),
                                style: canSubmit ? .primary : .secondary,
                                isDisabled: canSubmit && !checkInVM.currentDraft.isComplete
                            ) {
                                if !canSubmit {
                                    if !subscriptionVM.isPro { showPaywall = true }
                                } else {
                                    checkInVM.currentDraft.weightKg = currentWeight
                                    checkInVM.currentDraft.notes = notes
                                    Task {
                                        await checkInVM.submitCheckIn(
                                            userProfile: authVM.currentUser,
                                            isPro: subscriptionVM.isPro
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, MorphSpacing.xl)

                            if !checkInVM.currentDraft.isComplete {
                                Text("\(checkInVM.currentDraft.photoCount)/4 photos added")
                                    .font(MorphFonts.caption(12))
                                    .foregroundColor(MorphColors.textTertiary)
                            }

                            Spacer(minLength: 40)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showPhotoTips) { PhotoTipsSheet() }
        .onAppear {
            currentWeight = authVM.currentUser.weightKg
            checkInVM.resetDraft(weight: currentWeight)
        }
        .overlay {
            if checkInVM.analysisJustCompleted, let analysis = checkInVM.latestAnalysis {
                AnalysisSuccessOverlay(analysis: analysis) {
                    checkInVM.analysisJustCompleted = false
                    checkInVM.selectedTab = 2
                    checkInVM.resetDraft(weight: currentWeight)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: checkInVM.analysisJustCompleted)
    }
}

// MARK: - Photo Upload Grid
struct PhotoUploadGrid: View {
    @Binding var checkIn: PhysiqueCheckIn

    var body: some View {
        VStack(spacing: MorphSpacing.sm) {
            HStack(spacing: MorphSpacing.sm) {
                PhotoSlot(direction: .front,  data: checkIn.photoFront) { checkIn.photoFront = CheckInViewModel.downscale($0) }
                PhotoSlot(direction: .back,   data: checkIn.photoBack)  { checkIn.photoBack  = CheckInViewModel.downscale($0) }
            }
            HStack(spacing: MorphSpacing.sm) {
                PhotoSlot(direction: .left,   data: checkIn.photoLeft)  { checkIn.photoLeft  = CheckInViewModel.downscale($0) }
                PhotoSlot(direction: .right,  data: checkIn.photoRight) { checkIn.photoRight = CheckInViewModel.downscale($0) }
            }
        }
    }
}

// MARK: - Single Photo Slot
struct PhotoSlot: View {
    let direction: PhotoDirection
    let data: Data?
    let onPhoto: (Data) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showTip = false

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let d = data, let img = UIImage(data: d) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: MorphSpacing.sm) {
                        Image(systemName: direction.icon)
                            .font(.system(size: 22))
                            .foregroundColor(MorphColors.textTertiary)
                        Text(direction.rawValue)
                            .font(MorphFonts.caption(12))
                            .foregroundColor(MorphColors.textTertiary)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(MorphColors.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MorphColors.surface)
                }

                // Checkmark overlay when done
                if data != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(MorphColors.success)
                                .padding(6)
                        }
                        Spacer()
                    }
                }

                // Direction label overlay
                VStack {
                    Spacer()
                    Text(direction.rawValue.uppercased())
                        .font(MorphFonts.caption(9))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            .overlay(
                RoundedRectangle(cornerRadius: MorphCorners.md)
                    .stroke(data != nil ? MorphColors.success.opacity(0.5) : MorphColors.border, lineWidth: 1)
            )
        }
        .onChange(of: selectedItem) { _, item in
            Task {
                if let d = try? await item?.loadTransferable(type: Data.self) {
                    onPhoto(d)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Analyzing View (Loading State)
struct AnalyzingView: View {
    @State private var messageIndex = 0
    private let timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    let messages = [
        "Scanning symmetry…",
        "Estimating body composition…",
        "Analyzing proportions…",
        "Calculating your macros…",
        "Building your training plan…",
        "Finalizing your report…"
    ]

    var body: some View {
        VStack(spacing: MorphSpacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MorphColors.accentDim)
                    .frame(width: 100, height: 100)
                Image(systemName: "brain")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(MorphColors.accent)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: MorphSpacing.sm) {
                Text("Analyzing Your Physique")
                    .font(MorphFonts.heading(22))
                    .foregroundColor(MorphColors.textPrimary)
                Text(messages[messageIndex])
                    .font(MorphFonts.body(15))
                    .foregroundColor(MorphColors.textSecondary)
                    .animation(.easeInOut, value: messageIndex)
            }

            ProgressView()
                .tint(MorphColors.accent)
                .scaleEffect(1.5)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(timer) { _ in
            withAnimation { messageIndex = (messageIndex + 1) % messages.count }
        }
    }
}

// MARK: - Analysis Success Overlay
struct AnalysisSuccessOverlay: View {
    let analysis: PhysiqueAnalysis
    let onViewResults: () -> Void

    var body: some View {
        ZStack {
            MorphColors.background.opacity(0.97).ignoresSafeArea()

            VStack(spacing: MorphSpacing.xl) {
                Spacer()

                ScoreRing(score: analysis.overallScore, size: 140, lineWidth: 8, fontSize: 42)

                VStack(spacing: MorphSpacing.sm) {
                    Text("Analysis Complete")
                        .font(MorphFonts.heading(26))
                        .foregroundColor(MorphColors.textPrimary)
                    Text(analysis.coachSummary.components(separatedBy: ".").first.map { $0 + "." } ?? "")
                        .font(MorphFonts.body(15))
                        .foregroundColor(MorphColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, MorphSpacing.xl)
                }

                // Quick stats row
                HStack(spacing: MorphSpacing.sm) {
                    QuickStat(label: "Body Fat", value: analysis.formattedBodyFat)
                    QuickStat(label: "Calories", value: "\(analysis.dailyCalorieTarget)")
                    QuickStat(label: "Protein", value: "\(analysis.proteinGrams)g")
                }
                .padding(.horizontal, MorphSpacing.xl)

                Spacer()

                VStack(spacing: MorphSpacing.md) {
                    MorphButton(title: "View Full Results →", style: .primary) {
                        onViewResults()
                    }
                    .padding(.horizontal, MorphSpacing.xl)
                }
                .padding(.bottom, 48)
            }
        }
    }
}

private struct QuickStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MorphFonts.heading(18))
                .foregroundColor(MorphColors.textPrimary)
            Text(label)
                .font(MorphFonts.caption(11))
                .foregroundColor(MorphColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(MorphSpacing.md)
        .morphCard()
    }
}

// MARK: - Locked State Card
struct CheckInLockedCard: View {
    let isPro: Bool
    let nextDate: Date?
    let onUpgrade: () -> Void

    private var nextDateString: String {
        guard let date = nextDate else { return "" }
        let f = DateFormatter()
        if Calendar.current.isDateInTomorrow(date) {
            return "tomorrow"
        }
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: MorphSpacing.md) {
            HStack(spacing: MorphSpacing.md) {
                Image(systemName: isPro ? "checkmark.seal.fill" : "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isPro ? MorphColors.success : MorphColors.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isPro ? "Today's check-in complete" : "Free check-in used this week")
                        .font(MorphFonts.heading(14))
                        .foregroundColor(MorphColors.textPrimary)
                    Text(isPro
                         ? "Next check-in unlocks \(nextDateString)."
                         : "Next free check-in unlocks \(nextDateString). PRO members check in every day.")
                        .font(MorphFonts.caption(12))
                        .foregroundColor(MorphColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            if !isPro {
                Button(action: onUpgrade) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                        Text("Upgrade to PRO")
                            .font(MorphFonts.heading(13))
                    }
                    .foregroundColor(MorphColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(MorphColors.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MorphSpacing.md)
        .background((isPro ? MorphColors.success : MorphColors.warning).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.lg))
        .overlay(
            RoundedRectangle(cornerRadius: MorphCorners.lg)
                .stroke((isPro ? MorphColors.success : MorphColors.warning).opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - Photo Tips Sheet
struct PhotoTipsSheet: View {
    @Environment(\.dismiss) var dismiss

    private let tips: [(String, String, String)] = [
        ("sun.max.fill", "Consistent lighting", "Same room, same light, every time. Overhead light flattens definition — face a window instead."),
        ("clock.fill", "Same time of day", "Morning before eating is most consistent. Your body changes a lot through the day."),
        ("figure.stand", "Same poses, relaxed", "Arms at sides for front/back, arms forward for sides. Don't flex — relaxed photos show true progress."),
        ("camera.fill", "Arm's length or timer", "Prop your phone at hip height, 2–3 meters away. Use the timer. Full body in frame."),
        ("tshirt.fill", "Fitted clothing", "Shorts or fitted wear. The AI needs to see your actual shape."),
        ("arrow.triangle.2.circlepath", "Weekly rhythm", "Progress photos work by comparison. Keep every variable identical except your body.")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: MorphSpacing.md) {
                        ForEach(tips, id: \.1) { icon, title, detail in
                            HStack(alignment: .top, spacing: MorphSpacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(MorphColors.accentDim)
                                        .frame(width: 38, height: 38)
                                    Image(systemName: icon)
                                        .font(.system(size: 15))
                                        .foregroundColor(MorphColors.accent)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title)
                                        .font(MorphFonts.heading(15))
                                        .foregroundColor(MorphColors.textPrimary)
                                    Text(detail)
                                        .font(MorphFonts.body(13))
                                        .foregroundColor(MorphColors.textSecondary)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(MorphSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .morphCard()
                        }
                    }
                    .padding(MorphSpacing.xl)
                }
            }
            .navigationTitle("Photo Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MorphColors.background, for: .navigationBar)
            .toolbarColorScheme(MorphTheme.colorScheme, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MorphColors.accent)
                }
            }
        }
        .presentationBackground(MorphColors.background)
        .presentationDetents([.large])
    }
}

