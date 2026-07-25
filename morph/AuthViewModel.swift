import SwiftUI
import Combine
import CryptoKit

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var currentUser: UserProfile = UserProfile()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // Each account is stored separately, keyed by normalized email.
    // Signing out keeps the account; signing back in restores it.
    // Creating a new account starts a completely fresh profile.
    private struct AccountRecord: Codable {
        var profile: UserProfile
        var passwordHash: String
    }

    private var accounts: [String: AccountRecord] = [:]
    private let accountsKey = "morph_accounts"
    private let sessionKey = "morph_current_email"
    private let legacyProfileKey = "morph_user_profile"

    init() {
        loadAccounts()
        restoreSession()
    }

    // MARK: - Email Validation

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
        guard NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: trimmed) else {
            return false
        }
        // Reject made-up TLDs like "iefj" — real emails end in a known TLD
        guard let tld = trimmed.split(separator: ".").last else { return false }
        return validTLDs.contains(String(tld))
    }

    private static func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data("morph::\(password)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        try? await Task.sleep(nanoseconds: 500_000_000)

        let key = Self.normalize(email)
        guard Self.isValidEmail(key) else {
            errorMessage = "Please enter a valid email address."
            isLoading = false
            return
        }
        guard accounts[key] == nil else {
            errorMessage = "An account with this email already exists. Sign in instead."
            isLoading = false
            return
        }

        // Brand-new account = completely fresh profile
        var profile = UserProfile()
        profile.email = key
        profile.name = name
        accounts[key] = AccountRecord(profile: profile, passwordHash: Self.hash(password))
        saveAccounts()
        startSession(with: profile)
        isLoading = false
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        try? await Task.sleep(nanoseconds: 500_000_000)

        let key = Self.normalize(email)
        guard let record = accounts[key] else {
            errorMessage = "No account found for this email. Create one first."
            isLoading = false
            return
        }

        if record.passwordHash.isEmpty {
            // Migrated legacy account with no stored password — adopt this one
            accounts[key]?.passwordHash = Self.hash(password)
            saveAccounts()
        } else if record.passwordHash != Self.hash(password) {
            errorMessage = "Incorrect password."
            isLoading = false
            return
        }

        startSession(with: record.profile)
        isLoading = false
    }

    func signOut() {
        // Keep the account data — only end the session
        UserDefaults.standard.removeObject(forKey: sessionKey)
        isLoggedIn = false
        hasCompletedOnboarding = false
        currentUser = UserProfile()
    }

    func completeOnboarding(profile: UserProfile) {
        var updated = profile
        updated.hasCompletedOnboarding = true
        currentUser = updated
        hasCompletedOnboarding = true
        persistCurrentUser()
    }

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        persistCurrentUser()
    }

    // MARK: - Session

    private func startSession(with profile: UserProfile) {
        currentUser = profile
        isLoggedIn = true
        hasCompletedOnboarding = profile.hasCompletedOnboarding
        UserDefaults.standard.set(Self.normalize(profile.email), forKey: sessionKey)
    }

    private func restoreSession() {
        guard let email = UserDefaults.standard.string(forKey: sessionKey),
              let record = accounts[email] else { return }
        currentUser = record.profile
        isLoggedIn = true
        hasCompletedOnboarding = record.profile.hasCompletedOnboarding
    }

    // MARK: - Persistence

    private func persistCurrentUser() {
        let key = Self.normalize(currentUser.email)
        guard !key.isEmpty else { return }
        if accounts[key] != nil {
            accounts[key]?.profile = currentUser
        } else {
            accounts[key] = AccountRecord(profile: currentUser, passwordHash: "")
        }
        saveAccounts()
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let loaded = try? JSONDecoder().decode([String: AccountRecord].self, from: data) {
            accounts = loaded
        }
        migrateLegacyProfileIfNeeded()
    }

    // One-time migration from the old single-profile storage
    private func migrateLegacyProfileIfNeeded() {
        guard let data = UserDefaults.standard.data(forKey: legacyProfileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        let key = Self.normalize(profile.email)
        if !key.isEmpty, accounts[key] == nil {
            accounts[key] = AccountRecord(profile: profile, passwordHash: "")
            saveAccounts()
            // Preserve the existing login session
            UserDefaults.standard.set(key, forKey: sessionKey)
        }
        UserDefaults.standard.removeObject(forKey: legacyProfileKey)
    }
}
