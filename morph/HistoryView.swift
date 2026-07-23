import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var checkInVM: CheckInViewModel
    @State private var mode: HistoryMode = .timeline

    enum HistoryMode: String, CaseIterable {
        case timeline = "Timeline"
        case compare = "Compare"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()

                if checkInVM.checkIns.isEmpty {
                    VStack(spacing: MorphSpacing.md) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(MorphColors.textTertiary)
                        Text("No history yet")
                            .font(MorphFonts.heading(18))
                            .foregroundColor(MorphColors.textSecondary)
                        Text("Complete your first check-in to start tracking progress.")
                            .font(MorphFonts.body(14))
                            .foregroundColor(MorphColors.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        // Mode picker
                        Picker("Mode", selection: $mode) {
                            ForEach(HistoryMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, MorphSpacing.xl)
                        .padding(.top, MorphSpacing.sm)

                        switch mode {
                        case .timeline:
                            TimelineList()
                        case .compare:
                            CompareView()
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(MorphColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Timeline
private struct TimelineList: View {
    @EnvironmentObject var checkInVM: CheckInViewModel
    @State private var checkInToDelete: PhysiqueCheckIn?

    var body: some View {
        ScrollView {
            VStack(spacing: MorphSpacing.md) {
                if checkInVM.checkIns.count > 1 {
                    TrendChartCard(checkIns: checkInVM.checkIns)
                        .padding(.horizontal, MorphSpacing.xl)
                }

                ForEach(checkInVM.checkIns) { checkIn in
                    NavigationLink(destination: CheckInDetailView(checkIn: checkIn)) {
                        CheckInHistoryCard(checkIn: checkIn)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MorphSpacing.xl)
                    .contextMenu {
                        Button(role: .destructive) {
                            checkInToDelete = checkIn
                        } label: {
                            Label("Delete Check-In", systemImage: "trash")
                        }
                    }
                }

                Spacer(minLength: 40)
            }
            .padding(.top, MorphSpacing.lg)
        }
        .alert("Delete Check-In?", isPresented: Binding(
            get: { checkInToDelete != nil },
            set: { if !$0 { checkInToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let c = checkInToDelete { checkInVM.deleteCheckIn(c) }
                checkInToDelete = nil
            }
            Button("Cancel", role: .cancel) { checkInToDelete = nil }
        } message: {
            Text("This removes the photos and analysis permanently.")
        }
    }
}

// MARK: - Trend Chart (Swift Charts)
private struct TrendChartCard: View {
    let checkIns: [PhysiqueCheckIn]
    @State private var metric: Metric = .score
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    enum Metric: String, CaseIterable {
        case score = "Score"
        case weight = "Weight"
    }

    private struct DataPoint: Identifiable {
        let id: String
        let date: Date
        let value: Double
    }

    private var points: [DataPoint] {
        checkIns.reversed().compactMap { c in
            switch metric {
            case .score:
                guard let a = c.analysis else { return nil }
                return DataPoint(id: c.id, date: c.date, value: a.overallScore)
            case .weight:
                return DataPoint(id: c.id, date: c.date, value: unit.fromKg(c.weightKg))
            }
        }
    }

    private var yDomain: ClosedRange<Double> {
        switch metric {
        case .score:
            return 0...10
        case .weight:
            let values = points.map(\.value)
            let lo = (values.min() ?? 0) - 2
            let hi = (values.max() ?? 100) + 2
            return lo...hi
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.md) {
            HStack {
                Text(metric == .score ? "OVERALL SCORE TREND" : "WEIGHT TREND (\(unit.label))")
                    .font(MorphFonts.caption(10))
                    .foregroundColor(MorphColors.textTertiary)
                    .tracking(1.5)
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            Chart(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [MorphColors.accent.opacity(0.25), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(MorphColors.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(MorphColors.accent)
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(MorphFonts.caption(9))
                        .foregroundStyle(MorphColors.textTertiary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine().foregroundStyle(MorphColors.border)
                    AxisValueLabel()
                        .font(MorphFonts.caption(9))
                        .foregroundStyle(MorphColors.textTertiary)
                }
            }
            .frame(height: 140)
        }
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}

// MARK: - Compare Mode
private struct CompareView: View {
    @EnvironmentObject var checkInVM: CheckInViewModel
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"
    @State private var beforeID: String?
    @State private var afterID: String?
    @State private var angle: PhotoDirection = .front

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    private var before: PhysiqueCheckIn? {
        checkInVM.checkIns.first { $0.id == beforeID } ?? checkInVM.checkIns.last
    }
    private var after: PhysiqueCheckIn? {
        checkInVM.checkIns.first { $0.id == afterID } ?? checkInVM.checkIns.first
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MorphSpacing.lg) {
                if checkInVM.checkIns.count < 2 {
                    VStack(spacing: MorphSpacing.md) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 40))
                            .foregroundColor(MorphColors.textTertiary)
                        Text("Need at least 2 check-ins to compare")
                            .font(MorphFonts.body(14))
                            .foregroundColor(MorphColors.textSecondary)
                    }
                    .padding(.top, 80)
                } else if let before = before, let after = after {
                    // Angle picker
                    HStack(spacing: MorphSpacing.sm) {
                        ForEach(PhotoDirection.allCases) { dir in
                            SelectChip(title: dir.rawValue, isSelected: angle == dir) {
                                angle = dir
                            }
                        }
                    }
                    .padding(.top, MorphSpacing.md)

                    // Side-by-side photos
                    HStack(spacing: MorphSpacing.sm) {
                        ComparePane(
                            title: "BEFORE",
                            checkIn: before,
                            angle: angle,
                            unit: unit,
                            options: checkInVM.checkIns
                        ) { beforeID = $0 }

                        ComparePane(
                            title: "AFTER",
                            checkIn: after,
                            angle: angle,
                            unit: unit,
                            options: checkInVM.checkIns
                        ) { afterID = $0 }
                    }
                    .padding(.horizontal, MorphSpacing.xl)

                    // Delta summary
                    CompareDeltas(before: before, after: after, unit: unit)
                        .padding(.horizontal, MorphSpacing.xl)
                }

                Spacer(minLength: 40)
            }
        }
    }
}

private struct ComparePane: View {
    let title: String
    let checkIn: PhysiqueCheckIn
    let angle: PhotoDirection
    let unit: WeightUnit
    let options: [PhysiqueCheckIn]
    let onSelect: (String) -> Void

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: checkIn.date)
    }

    var body: some View {
        VStack(spacing: MorphSpacing.sm) {
            Text(title)
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
                .tracking(1.5)

            ZStack {
                #if canImport(UIKit)
                if let data = checkIn.photo(for: angle), let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: MorphCorners.md)
                        .fill(MorphColors.surface)
                        .overlay(Image(systemName: "photo").foregroundColor(MorphColors.textTertiary))
                }
                #endif
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
            .overlay(RoundedRectangle(cornerRadius: MorphCorners.md).stroke(MorphColors.border, lineWidth: 1))

            // Date selector
            Menu {
                ForEach(options) { option in
                    Button(menuLabel(option)) { onSelect(option.id) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(dateString)
                        .font(MorphFonts.caption(12))
                        .foregroundColor(MorphColors.textPrimary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(MorphColors.textTertiary)
                }
                .padding(.horizontal, MorphSpacing.md)
                .padding(.vertical, 6)
                .background(MorphColors.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MorphColors.border, lineWidth: 1))
            }

            VStack(spacing: 2) {
                Text(unit.format(checkIn.weightKg))
                    .font(MorphFonts.mono(13))
                    .foregroundColor(MorphColors.textSecondary)
                if let score = checkIn.analysis?.overallScore {
                    Text(String(format: "%.1f / 10", score))
                        .font(MorphFonts.heading(15))
                        .foregroundColor(MorphColors.scoreColor(score))
                }
            }
        }
    }

    private func menuLabel(_ c: PhysiqueCheckIn) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        var label = f.string(from: c.date)
        if let s = c.analysis?.overallScore {
            label += String(format: "  ·  %.1f/10", s)
        }
        return label
    }
}

private struct CompareDeltas: View {
    let before: PhysiqueCheckIn
    let after: PhysiqueCheckIn
    let unit: WeightUnit

    private var daysBetween: Int {
        max(0, Int(after.date.timeIntervalSince(before.date) / 86400))
    }

    var body: some View {
        VStack(spacing: MorphSpacing.md) {
            Text("\(daysBetween) DAYS APART")
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
                .tracking(1.5)

            HStack(spacing: MorphSpacing.sm) {
                DeltaTile(
                    label: "Weight",
                    delta: unit.fromKg(after.weightKg - before.weightKg),
                    formatter: { String(format: "%+.1f %@", $0, unit.rawValue) },
                    positiveIsGood: nil
                )

                if let b = before.analysis?.overallScore, let a = after.analysis?.overallScore {
                    DeltaTile(
                        label: "Score",
                        delta: a - b,
                        formatter: { String(format: "%+.1f", $0) },
                        positiveIsGood: true
                    )
                }

                if let b = before.analysis?.estimatedBodyFatPercent,
                   let a = after.analysis?.estimatedBodyFatPercent {
                    DeltaTile(
                        label: "Body Fat",
                        delta: a - b,
                        formatter: { String(format: "%+.0f%%", $0) },
                        positiveIsGood: false
                    )
                }
            }
        }
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}

private struct DeltaTile: View {
    let label: String
    let delta: Double
    let formatter: (Double) -> String
    let positiveIsGood: Bool?  // nil = neutral coloring

    private var color: Color {
        guard abs(delta) >= 0.05 else { return MorphColors.textSecondary }
        guard let positiveIsGood = positiveIsGood else { return MorphColors.textPrimary }
        return (delta > 0) == positiveIsGood ? MorphColors.success : MorphColors.destructive
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(formatter(delta))
                .font(MorphFonts.heading(16))
                .foregroundColor(color)
            Text(label)
                .font(MorphFonts.caption(11))
                .foregroundColor(MorphColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(MorphSpacing.md)
        .background(MorphColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
    }
}

// MARK: - History Card
struct CheckInHistoryCard: View {
    let checkIn: PhysiqueCheckIn

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: checkIn.date)
    }

    var body: some View {
        HStack(spacing: MorphSpacing.md) {
            #if canImport(UIKit)
            if let data = checkIn.photoFront, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: MorphCorners.sm))
            } else {
                placeholderThumb
            }
            #else
            placeholderThumb
            #endif

            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                Text(dateString)
                    .font(MorphFonts.body(14))
                    .foregroundColor(MorphColors.textPrimary)
                Text(WeightFormat.current.format(checkIn.weightKg))
                    .font(MorphFonts.caption())
                    .foregroundColor(MorphColors.textSecondary)

                if let a = checkIn.analysis {
                    HStack(spacing: MorphSpacing.xs) {
                        ForEach([("S", a.symmetryScore), ("M", a.muscularDevelopmentScore), ("BF", a.bodyFatScore), ("P", a.proportionScore)], id: \.0) { label, score in
                            VStack(spacing: 1) {
                                Text(String(format: "%.0f", score))
                                    .font(MorphFonts.mono(11))
                                    .foregroundColor(MorphColors.scoreColor(score))
                                Text(label)
                                    .font(.system(size: 8))
                                    .foregroundColor(MorphColors.textTertiary)
                            }
                            .frame(width: 28, height: 28)
                            .background(MorphColors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }

            Spacer()

            if let a = checkIn.analysis {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f", a.overallScore))
                        .font(MorphFonts.display(24))
                        .foregroundColor(MorphColors.scoreColor(a.overallScore))
                    Text("/ 10")
                        .font(MorphFonts.caption(10))
                        .foregroundColor(MorphColors.textTertiary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(MorphColors.textTertiary)
        }
        .padding(MorphSpacing.md)
        .morphCard()
    }

    private var placeholderThumb: some View {
        RoundedRectangle(cornerRadius: MorphCorners.sm)
            .fill(MorphColors.surface)
            .frame(width: 60, height: 72)
            .overlay(Image(systemName: "photo").foregroundColor(MorphColors.textTertiary))
    }
}

// MARK: - Check-In Detail
struct CheckInDetailView: View {
    let checkIn: PhysiqueCheckIn
    @EnvironmentObject var checkInVM: CheckInViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteAlert = false
    @State private var shareImage: Image?

    var body: some View {
        ZStack {
            MorphColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: MorphSpacing.lg) {
                    // Photo strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: MorphSpacing.sm) {
                            #if canImport(UIKit)
                            ForEach(PhotoDirection.allCases) { dir in
                                if let d = checkIn.photo(for: dir), let img = UIImage(data: d) {
                                    VStack(spacing: 4) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 180)
                                            .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
                                        Text(dir.rawValue)
                                            .font(MorphFonts.caption(11))
                                            .foregroundColor(MorphColors.textTertiary)
                                    }
                                }
                            }
                            #endif
                        }
                        .padding(.horizontal, MorphSpacing.xl)
                    }

                    if let analysis = checkIn.analysis {
                        OverallScoreCard(analysis: analysis)
                            .padding(.horizontal, MorphSpacing.xl)

                        ScoreGrid(analysis: analysis)
                            .padding(.horizontal, MorphSpacing.xl)

                        MacroCard(analysis: analysis)
                            .padding(.horizontal, MorphSpacing.xl)

                        FeedbackCard(
                            title: "STRENGTHS",
                            items: analysis.strengthAreas,
                            icon: "checkmark.circle.fill",
                            color: MorphColors.success
                        )
                        .padding(.horizontal, MorphSpacing.xl)

                        FeedbackCard(
                            title: "AREAS TO IMPROVE",
                            items: analysis.improvementAreas,
                            icon: "arrow.up.circle.fill",
                            color: MorphColors.warning
                        )
                        .padding(.horizontal, MorphSpacing.xl)

                        CoachSummaryCard(analysis: analysis, showFocus: true)
                            .padding(.horizontal, MorphSpacing.xl)

                        RecommendationsCard(analysis: analysis)
                            .padding(.horizontal, MorphSpacing.xl)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, MorphSpacing.lg)
            }
        }
        .navigationTitle("Check-In Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MorphColors.background, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let shareImage = shareImage {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview("My Morph Score", image: shareImage)
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(MorphColors.accent)
                    }
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(MorphColors.destructive)
                }
            }
        }
        .onAppear { renderShareCard() }
        .alert("Delete Check-In?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                checkInVM.deleteCheckIn(checkIn)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the photos and analysis permanently.")
        }
    }

    private func renderShareCard() {
        #if canImport(UIKit)
        guard let analysis = checkIn.analysis else { return }
        let renderer = ImageRenderer(content: ShareCardView(analysis: analysis, date: checkIn.date))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
        #endif
    }
}

// MARK: - Share Card (rendered offscreen for sharing)
struct ShareCardView: View {
    let analysis: PhysiqueAnalysis
    let date: Date

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .long
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 20) {
            // Brand header
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(MorphColors.accent)
                Text("MORPH")
                    .font(MorphFonts.display(20))
                    .foregroundColor(MorphColors.textPrimary)
                    .tracking(4)
                Spacer()
                Text(dateString)
                    .font(MorphFonts.caption(11))
                    .foregroundColor(MorphColors.textTertiary)
            }

            // Big score
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(MorphColors.border, lineWidth: 8)
                        .frame(width: 110, height: 110)
                    Circle()
                        .trim(from: 0, to: analysis.overallScore / 10)
                        .stroke(
                            MorphColors.scoreColor(analysis.overallScore),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(String(format: "%.1f", analysis.overallScore))
                            .font(MorphFonts.display(34))
                            .foregroundColor(MorphColors.textPrimary)
                        Text("/ 10")
                            .font(MorphFonts.caption(11))
                            .foregroundColor(MorphColors.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Physique Score")
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
                }
                Spacer()
            }

            // Sub-scores
            HStack(spacing: 10) {
                ShareScorePill(label: "Symmetry", score: analysis.symmetryScore)
                ShareScorePill(label: "Muscle", score: analysis.muscularDevelopmentScore)
                ShareScorePill(label: "Leanness", score: analysis.bodyFatScore)
                ShareScorePill(label: "Proportion", score: analysis.proportionScore)
            }

            Text("AI physique analysis by Morph")
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
        }
        .padding(28)
        .frame(width: 420)
        .background(MorphColors.background)
    }
}

private struct ShareScorePill: View {
    let label: String
    let score: Double

    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1f", score))
                .font(MorphFonts.mono(16))
                .foregroundColor(MorphColors.scoreColor(score))
            Text(label)
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(MorphColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MorphColors.border, lineWidth: 1))
    }
}

// MARK: - Macro Card
struct MacroCard: View {
    let analysis: PhysiqueAnalysis

    private var totalCals: Int { analysis.dailyCalorieTarget }
    private var proteinCals: Double { Double(analysis.proteinGrams) * 4 }
    private var carbCals: Double { Double(analysis.carbGrams) * 4 }
    private var fatCals: Double { Double(analysis.fatGrams) * 9 }

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.md) {
            Label("Daily Nutrition Targets", systemImage: "fork.knife")
                .font(MorphFonts.heading(15))
                .foregroundColor(MorphColors.accent)

            HStack(alignment: .bottom, spacing: MorphSpacing.xs) {
                Text("\(totalCals)")
                    .font(MorphFonts.display(38))
                    .foregroundColor(MorphColors.textPrimary)
                Text("kcal / day")
                    .font(MorphFonts.body(14))
                    .foregroundColor(MorphColors.textTertiary)
                    .padding(.bottom, 6)
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MorphColors.success)
                        .frame(width: geo.size.width * (proteinCals / Double(max(totalCals, 1))), height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MorphColors.accent)
                        .frame(width: geo.size.width * (carbCals / Double(max(totalCals, 1))), height: 8)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MorphColors.warning)
                        .frame(width: geo.size.width * (fatCals / Double(max(totalCals, 1))), height: 8)
                }
            }
            .frame(height: 8)

            HStack(spacing: MorphSpacing.sm) {
                MacroTile(label: "Protein", grams: analysis.proteinGrams, color: MorphColors.success, icon: "bolt.fill")
                MacroTile(label: "Carbs",   grams: analysis.carbGrams,    color: MorphColors.accent,  icon: "leaf.fill")
                MacroTile(label: "Fat",     grams: analysis.fatGrams,     color: MorphColors.warning, icon: "drop.fill")
            }

            if !analysis.suggestedTrainingSplit.isEmpty {
                Divider().background(MorphColors.border)
                Label(analysis.suggestedTrainingSplit, systemImage: "dumbbell.fill")
                    .font(MorphFonts.body(13))
                    .foregroundColor(MorphColors.textSecondary)
            }

            if !analysis.mealTimingTips.isEmpty {
                Divider().background(MorphColors.border)
                Text("MEAL TIMING")
                    .font(MorphFonts.caption(10))
                    .foregroundColor(MorphColors.textTertiary)
                    .tracking(1.5)
                ForEach(analysis.mealTimingTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: MorphSpacing.sm) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(MorphColors.accent)
                            .padding(.top, 3)
                        Text(tip)
                            .font(MorphFonts.body(13))
                            .foregroundColor(MorphColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}

struct MacroTile: View {
    let label: String
    let grams: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            Text("\(grams)g")
                .font(MorphFonts.mono(18))
                .foregroundColor(MorphColors.textPrimary)
            Text(label)
                .font(MorphFonts.caption(11))
                .foregroundColor(MorphColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(MorphSpacing.md)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: MorphCorners.md))
        .overlay(RoundedRectangle(cornerRadius: MorphCorners.md).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Feedback Card
struct FeedbackCard: View {
    let title: String
    let items: [String]
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: MorphSpacing.md) {
            Text(title)
                .font(MorphFonts.caption(10))
                .foregroundColor(MorphColors.textTertiary)
                .tracking(1.5)

            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: MorphSpacing.sm) {
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(color)
                            .padding(.top, 2)
                        Text(item)
                            .font(MorphFonts.body(14))
                            .foregroundColor(MorphColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MorphSpacing.lg)
        .morphCard()
    }
}
