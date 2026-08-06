import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class CheckInViewModel: ObservableObject {
    @Published var checkIns: [PhysiqueCheckIn] = []
    @Published var isAnalyzing: Bool = false
    @Published var isLoading: Bool = false          // loading history from the cloud
    @Published var errorMessage: String?
    @Published var currentDraft: PhysiqueCheckIn = PhysiqueCheckIn(weightKg: 75)
    @Published var analysisJustCompleted: Bool = false
    @Published var selectedTab: Int = 0

    private let aiService = ClaudeAIService()
    private let supa = SupabaseClient.shared
    private let slots: [(PhotoDirection, String)] = [
        (.front, "front"), (.back, "back"), (.left, "left"), (.right, "right")
    ]

    init(accountEmail: String = "") {
        Task { await loadCheckIns() }
    }

    // MARK: - Local photo cache (avoid re-downloading on every launch)

    private var cacheDir: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photo_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private func cacheURL(_ checkInID: String, _ slot: String) -> URL {
        cacheDir.appendingPathComponent("\(checkInID)_\(slot).jpg")
    }
    private func storagePath(_ uid: String, _ checkInID: String, _ slot: String) -> String {
        "\(uid)/\(checkInID)/\(slot).jpg"
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
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.8) ?? data
        #else
        return data
        #endif
    }

    // MARK: - Load from cloud

    func loadCheckIns() async {
        guard let session = SupabaseClient.loadSession() else { return }
        isLoading = true
        do {
            let (rows, _) = try await supa.select(
                path: "/check_ins?user_id=eq.\(session.userID)&select=*&order=date.desc",
                session: session)
            checkIns = rows.compactMap { Self.checkIn(from: $0) }   // metadata first
            if NotificationManager.isEnabled {
                NotificationManager.reschedule(isPro: false, nextUnlock: nextCheckInDate(isPro: false))
            }
            await hydratePhotos(session: session)                   // then photos
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Fill each check-in's photo Data from local cache or Storage.
    private func hydratePhotos(session: SupabaseClient.Session) async {
        for index in checkIns.indices {
            let id = checkIns[index].id
            for (dir, slot) in slots {
                let cache = cacheURL(id, slot)
                var data = try? Data(contentsOf: cache)
                if data == nil {
                    data = try? await supa.downloadPhoto(
                        path: storagePath(session.userID, id, slot), session: session)
                    if let d = data { try? d.write(to: cache, options: .atomic) }
                }
                guard let d = data, index < checkIns.count else { continue }
                switch dir {
                case .front: checkIns[index].photoFront = d
                case .back:  checkIns[index].photoBack  = d
                case .left:  checkIns[index].photoLeft  = d
                case .right: checkIns[index].photoRight = d
                }
            }
        }
    }

    // MARK: - Submit

    func submitCheckIn(userProfile: UserProfile, isPro: Bool = false) async {
        guard currentDraft.isComplete else {
            errorMessage = "Please upload all 4 photos before submitting."
            return
        }
        guard let session = SupabaseClient.loadSession() else {
            errorMessage = "You're signed out. Please sign in again."
            return
        }
        isAnalyzing = true
        errorMessage = nil

        var checkIn = currentDraft
        checkIn.id = UUID().uuidString.lowercased()
        checkIn.date = Date()

        do {
            let analysis = try await aiService.analyzePhysique(
                checkIn: checkIn,
                profile: userProfile,
                previousCheckIn: checkIns.first
            )
            checkIn.analysis = analysis

            // Upload the 4 photos, cache locally, and record storage paths.
            var paths: [String: String] = [:]
            for (dir, slot) in slots {
                guard let data = checkIn.photo(for: dir) else { continue }
                let path = storagePath(session.userID, checkIn.id, slot)
                _ = try await supa.uploadPhoto(data, path: path, session: session)
                try? data.write(to: cacheURL(checkIn.id, slot), options: .atomic)
                paths[slot] = path
            }

            // Insert the row.
            let row: [String: Any] = [
                "id": checkIn.id,
                "user_id": session.userID,
                "date": Self.iso8601.string(from: checkIn.date),
                "weight_kg": checkIn.weightKg,
                "notes": checkIn.notes,
                "analysis": Self.analysisDict(analysis),
                "photo_front": paths["front"] as Any,
                "photo_back": paths["back"] as Any,
                "photo_left": paths["left"] as Any,
                "photo_right": paths["right"] as Any
            ]
            _ = try await supa.upsert(table: "check_ins", row: row, session: session)

            checkIns.insert(checkIn, at: 0)
            NotificationManager.reschedule(isPro: isPro, nextUnlock: nextCheckInDate(isPro: isPro))
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
        guard let session = SupabaseClient.loadSession() else { return }
        let id = checkIn.id
        let paths = slots.map { storagePath(session.userID, id, $0.1) }
        Task {
            _ = try? await supa.delete(table: "check_ins", filter: "id=eq.\(id)", session: session)
            await supa.deletePhotos(paths: paths, session: session)
        }
        for (_, slot) in slots { try? FileManager.default.removeItem(at: cacheURL(id, slot)) }
    }

    func clearAll() {
        let ids = checkIns.map(\.id)
        checkIns = []
        guard let session = SupabaseClient.loadSession() else { return }
        let allPaths = ids.flatMap { id in slots.map { storagePath(session.userID, id, $0.1) } }
        Task {
            _ = try? await supa.delete(table: "check_ins", filter: "user_id=eq.\(session.userID)", session: session)
            await supa.deletePhotos(paths: allPaths, session: session)
        }
        for id in ids { for (_, slot) in slots { try? FileManager.default.removeItem(at: cacheURL(id, slot)) } }
    }

    // MARK: - Derived Stats

    var latestAnalysis: PhysiqueAnalysis? { checkIns.first?.analysis }
    var hasAnyCheckIn: Bool { !checkIns.isEmpty }
    var previousAnalysis: PhysiqueAnalysis? { checkIns.count > 1 ? checkIns[1].analysis : nil }

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
    // Derived from server-synced history, so it's correct across devices.

    func canCheckIn(isPro: Bool) -> Bool {
        isPro ? !hasCheckInToday : !hasCheckInThisWeek
    }

    func nextCheckInDate(isPro: Bool) -> Date? {
        guard !canCheckIn(isPro: isPro), let last = checkIns.first?.date else { return nil }
        let cal = Calendar.current
        if isPro {
            return cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: last) ?? Date())
        }
        return cal.dateInterval(of: .weekOfYear, for: last)?.end
    }

    var weightDeltaKg: Double? {
        guard checkIns.count > 1 else { return nil }
        return checkIns[0].weightKg - checkIns[1].weightKg
    }

    var totalWeightDeltaKg: Double? {
        guard checkIns.count > 1, let first = checkIns.last else { return nil }
        return checkIns[0].weightKg - first.weightKg
    }

    func goalProgress(goalKg: Double) -> Double? {
        guard let start = checkIns.last?.weightKg,
              let current = checkIns.first?.weightKg,
              abs(start - goalKg) > 0.5 else { return nil }
        let progress = (start - current) / (start - goalKg)
        return min(max(progress, 0), 1)
    }

    // MARK: - Mapping (check_ins row <-> PhysiqueCheckIn)

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso8601NoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func parseDate(_ s: String) -> Date {
        iso8601.date(from: s) ?? iso8601NoFraction.date(from: s) ?? Date()
    }

    private static func checkIn(from row: [String: Any]) -> PhysiqueCheckIn? {
        guard let id = row["id"] as? String else { return nil }
        var c = PhysiqueCheckIn(weightKg: (row["weight_kg"] as? Double) ?? 0)
        c.id = id
        c.date = parseDate(row["date"] as? String ?? "")
        c.notes = row["notes"] as? String ?? ""
        if let analysisDict = row["analysis"] as? [String: Any] {
            c.analysis = analysis(from: analysisDict)
        }
        return c
    }

    private static func analysisDict(_ analysis: PhysiqueAnalysis) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(analysis),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return dict
    }

    private static func analysis(from dict: [String: Any]) -> PhysiqueAnalysis? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return try? JSONDecoder().decode(PhysiqueAnalysis.self, from: data)
    }
}
