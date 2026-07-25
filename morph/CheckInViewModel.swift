import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class CheckInViewModel: ObservableObject {
    @Published var checkIns: [PhysiqueCheckIn] = []
    @Published var isAnalyzing: Bool = false
    @Published var errorMessage: String?
    @Published var currentDraft: PhysiqueCheckIn = PhysiqueCheckIn(weightKg: 75)
    @Published var analysisJustCompleted: Bool = false
    @Published var selectedTab: Int = 0

    private let legacyStorageKey = "morph_checkins"
    private let aiService = ClaudeAIService()
    private let accountEmail: String

    // Check-ins hold 4 photos each — far too large for UserDefaults (~4MB plist limit),
    // so they live in a JSON file in Documents, one file per account so each
    // account's history is fully separate.
    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sanitized = accountEmail.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }
        let filename = sanitized.isEmpty ? "checkins.json" : "checkins_\(String(sanitized)).json"
        return docs.appendingPathComponent(filename)
    }

    private var legacyFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("checkins.json")
    }

    init(accountEmail: String = "") {
        self.accountEmail = accountEmail
        loadCheckIns()
    }

    // MARK: - Draft Management

    func resetDraft(weight: Double) {
        currentDraft = PhysiqueCheckIn(weightKg: weight)
    }

    func setPhoto(_ data: Data, direction: PhotoDirection) {
        let processed = Self.downscale(data)
        switch direction {
        case .front:  currentDraft.photoFront = processed
        case .back:   currentDraft.photoBack  = processed
        case .left:   currentDraft.photoLeft  = processed
        case .right:  currentDraft.photoRight = processed
        }
    }

    // Downscale to max 1200px and re-encode as JPEG. Keeps local storage small and
    // guarantees the base64 payload stays under the Claude API's 5MB image limit.
    static func downscale(_ data: Data, maxDimension: CGFloat = 1200) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else {
            return image.jpegData(compressionQuality: 0.8) ?? data
        }
        let scale = maxDimension / largest
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
        #else
        return data
        #endif
    }

    // MARK: - Submit for Analysis

    func submitCheckIn(userProfile: UserProfile, isPro: Bool = false) async {
        guard currentDraft.isComplete else {
            errorMessage = "Please upload all 4 photos before submitting."
            return
        }
        isAnalyzing = true
        errorMessage = nil

        var checkIn = currentDraft
        checkIn.date = Date()

        do {
            let analysis = try await aiService.analyzePhysique(
                checkIn: checkIn,
                profile: userProfile,
                previousCheckIn: checkIns.first
            )
            checkIn.analysis = analysis
            checkIns.insert(checkIn, at: 0)
            saveCheckIns()
            DeviceCheckInGate.recordAnalysis()
            NotificationManager.reschedule(isPro: isPro)
            analysisJustCompleted = true
            Haptics.success()
        } catch {
            errorMessage = error.localizedDescription
            Haptics.error()
        }
        isAnalyzing = false
    }

    // MARK: - Deletion

    func deleteCheckIn(_ checkIn: PhysiqueCheckIn) {
        checkIns.removeAll { $0.id == checkIn.id }
        saveCheckIns()
    }

    func clearAll() {
        checkIns = []
        try? FileManager.default.removeItem(at: storageURL)
    }

    // MARK: - Derived Stats

    var latestAnalysis: PhysiqueAnalysis? { checkIns.first?.analysis }
    var hasAnyCheckIn: Bool { !checkIns.isEmpty }

    /// Analysis from the check-in before the latest, for delta display.
    var previousAnalysis: PhysiqueAnalysis? {
        checkIns.count > 1 ? checkIns[1].analysis : nil
    }

    /// Consecutive calendar weeks (ending this week or last) with at least one check-in.
    var weeklyStreak: Int {
        let cal = Calendar.current
        let weeks = Set(checkIns.compactMap { cal.dateInterval(of: .weekOfYear, for: $0.date)?.start })
        guard !weeks.isEmpty,
              var cursor = cal.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        if !weeks.contains(cursor) {
            guard let lastWeek = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = lastWeek
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    var hasCheckInThisWeek: Bool {
        guard let latest = checkIns.first else { return false }
        return Calendar.current.isDate(latest.date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var hasCheckInToday: Bool {
        guard let latest = checkIns.first else { return false }
        return Calendar.current.isDateInToday(latest.date)
    }

    // MARK: - Check-In Gating (Free: 1/week · Pro: 1/day)
    // Delegated to the device-level Keychain gate so creating new accounts
    // (or reinstalling) can't reset the limit.

    func canCheckIn(isPro: Bool) -> Bool {
        DeviceCheckInGate.canCheckIn(isPro: isPro)
    }

    /// When the next check-in unlocks. Nil if one is available now.
    func nextCheckInDate(isPro: Bool) -> Date? {
        DeviceCheckInGate.nextCheckInDate(isPro: isPro)
    }

    /// Weight change since the previous check-in (kg), nil if fewer than 2.
    var weightDeltaKg: Double? {
        guard checkIns.count > 1 else { return nil }
        return checkIns[0].weightKg - checkIns[1].weightKg
    }

    /// Total weight change since the first check-in (kg).
    var totalWeightDeltaKg: Double? {
        guard checkIns.count > 1, let first = checkIns.last else { return nil }
        return checkIns[0].weightKg - first.weightKg
    }

    /// 0...1 progress from starting weight toward goal weight. Nil when not meaningful.
    func goalProgress(goalKg: Double) -> Double? {
        guard let start = checkIns.last?.weightKg,
              let current = checkIns.first?.weightKg,
              abs(start - goalKg) > 0.5 else { return nil }
        let progress = (start - current) / (start - goalKg)
        return min(max(progress, 0), 1)
    }

    // MARK: - Persistence

    private func saveCheckIns() {
        guard let data = try? JSONEncoder().encode(checkIns) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func loadCheckIns() {
        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([PhysiqueCheckIn].self, from: data) {
            checkIns = loaded
            return
        }
        // One-time migration: adopt the old shared checkins.json for this account
        if !accountEmail.isEmpty,
           FileManager.default.fileExists(atPath: legacyFileURL.path),
           let data = try? Data(contentsOf: legacyFileURL),
           let loaded = try? JSONDecoder().decode([PhysiqueCheckIn].self, from: data) {
            checkIns = loaded
            saveCheckIns()
            try? FileManager.default.removeItem(at: legacyFileURL)
            return
        }
        // One-time migration from the even older UserDefaults storage
        if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
           let loaded = try? JSONDecoder().decode([PhysiqueCheckIn].self, from: data) {
            checkIns = loaded
            saveCheckIns()
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
    }
}
