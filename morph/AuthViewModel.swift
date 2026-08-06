import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var currentUser: UserProfile = UserProfile()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let supa = SupabaseClient.shared
    private var session: SupabaseClient.Session?

    init() {
        if let s = SupabaseClient.loadSession() {
            session = s
            currentUser.id = s.userID
            currentUser.email = s.email
            isLoggedIn = true
            Task { await loadProfile() }
        }
    }

    // MARK: - Email Validation (client-side pre-check; server validates too)

    private static let validTLDs: Set<String> = [
        "com", "net", "org", "edu", "gov", "mil", "int", "io", "co", "ai", "app",
        "dev", "me", "us", "uk", "ca", "au", "de", "fr", "it", "es", "nl", "se",
        "no", "fi", "dk", "ch", "at", "be", "ie", "nz", "jp", "kr", "cn", "in",
        "br", "mx", "ru", "pl", "pt", "gr", "cz", "ro", "hu", "tr", "sa", "ae",
        "il", "za", "ar", "cl", "id", "my", "sg", "th", "vn", "ph", "hk", "tw",
        "info", "biz", "xyz", "online", "site", "tech", "store", "live", "pro",
        "cloud", "gg", "tv", "fm", "email", "fit", "health", "life", "team"
    ]

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9-]+(\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}$"
        guard NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: trimmed) else { return false }
        guard let tld = trimmed.split(separator: ".").last else { return false }
        return validTLDs.contains(String(tld))
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        let key = Self.normalize(email)
        guard Self.isValidEmail(key) else {
            errorMessage = "Please enter a valid email address."
            isLoading = false
            return
        }
        do {
            let s = try await supa.signUp(email: key, password: password, name: name)
            session = s
            SupabaseClient.saveSession(s)
            var profile = UserProfile()
            profile.id = s.userID
            profile.email = s.email
            profile.name = name
            currentUser = profile
            hasCompletedOnboarding = false
            isLoggedIn = true
            try? await pushProfile()          // trigger already made the row; sync the name
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        let key = Self.normalize(email)
        do {
            let s = try await supa.signIn(email: key, password: password)
            session = s
            SupabaseClient.saveSession(s)
            currentUser.id = s.userID
            currentUser.email = s.email
            isLoggedIn = true
            await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() {
        if let s = session {
            Task { await supa.signOut(session: s) }
        }
        SupabaseClient.clearSession()
        session = nil
        isLoggedIn = false
        hasCompletedOnboarding = false
        currentUser = UserProfile()
    }

    /// Removes the user's data (profile + check-ins + photos are cascaded server-side
    /// via RLS/foreign keys) and ends the session. Satisfies App Store guideline 5.1.1.
    func deleteAccount() {
        guard let s = session else { return }
        Task {
            _ = try? await supa.delete(table: "check_ins", filter: "user_id=eq.\(s.userID)", session: s)
            _ = try? await supa.delete(table: "profiles", filter: "id=eq.\(s.userID)", session: s)
            await supa.signOut(session: s)
        }
        SupabaseClient.clearSession()
        session = nil
        isLoggedIn = false
        hasCompletedOnboarding = false
        currentUser = UserProfile()
    }

    func completeOnboarding(profile: UserProfile) {
        var updated = profile
        updated.hasCompletedOnboarding = true
        updated.id = session?.userID ?? updated.id
        updated.email = session?.email ?? updated.email
        currentUser = updated
        hasCompletedOnboarding = true
        Task { try? await pushProfile() }
    }

    func updateProfile(_ profile: UserProfile) {
        var updated = profile
        updated.id = session?.userID ?? updated.id
        updated.email = session?.email ?? updated.email
        currentUser = updated
        Task { try? await pushProfile() }
    }

    // MARK: - Profile sync

    private func loadProfile() async {
        guard let s = session else { return }
        do {
            let (rows, s2) = try await supa.select(path: "/profiles?id=eq.\(s.userID)&select=*", session: s)
            session = s2
            SupabaseClient.saveSession(s2)
            if let row = rows.first {
                currentUser = Self.profile(from: row, id: s.userID, email: s.email)
                hasCompletedOnboarding = currentUser.hasCompletedOnboarding
            }
        } catch {
            // Non-fatal — keep the session; user can still use the app.
            errorMessage = error.localizedDescription
        }
    }

    private func pushProfile() async throws {
        guard let s = session else { return }
        let s2 = try await supa.update(table: "profiles",
                                       filter: "id=eq.\(s.userID)",
                                       row: Self.dict(from: currentUser),
                                       session: s)
        session = s2
        SupabaseClient.saveSession(s2)
    }

    // MARK: - Mapping (UserProfile <-> profiles row)

    private static func profile(from row: [String: Any], id: String, email: String) -> UserProfile {
        var p = UserProfile()
        p.id = id
        p.email = email
        p.name = row["name"] as? String ?? ""
        if let b64 = row["avatar_url"] as? String, let data = Data(base64Encoded: b64) {
            p.avatarData = data
        }
        p.age = row["age"] as? Int ?? 25
        p.gender = UserProfile.Gender(rawValue: row["gender"] as? String ?? "") ?? .preferNotToSay
        p.heightCm = (row["height_cm"] as? Double) ?? 175
        p.weightKg = (row["weight_kg"] as? Double) ?? 75
        p.goalWeightKg = (row["goal_weight_kg"] as? Double) ?? 70
        p.fitnessGoal = UserProfile.FitnessGoal(rawValue: row["fitness_goal"] as? String ?? "") ?? .buildMuscle
        p.activityLevel = UserProfile.ActivityLevel(rawValue: row["activity_level"] as? String ?? "") ?? .moderate
        p.hasCompletedOnboarding = row["has_completed_onboarding"] as? Bool ?? false
        return p
    }

    private static func dict(from p: UserProfile) -> [String: Any] {
        var row: [String: Any] = [
            "name": p.name,
            "age": p.age,
            "gender": p.gender.rawValue,
            "height_cm": p.heightCm,
            "weight_kg": p.weightKg,
            "goal_weight_kg": p.goalWeightKg,
            "fitness_goal": p.fitnessGoal.rawValue,
            "activity_level": p.activityLevel.rawValue,
            "has_completed_onboarding": p.hasCompletedOnboarding
        ]
        // Avatar stored as base64 text (small, downscaled to 400px on capture)
        if let data = p.avatarData {
            row["avatar_url"] = data.base64EncodedString()
        }
        return row
    }
}
