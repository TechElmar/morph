import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var currentUser: UserProfile = UserProfile()
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let userDefaultsKey = "morph_user_profile"

    init() {
        loadFromStorage()
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        // Simulate network delay — replace with your real auth (Firebase/Supabase/etc.)
        try? await Task.sleep(nanoseconds: 800_000_000)
        currentUser.email = email
        currentUser.name = name
        isLoggedIn = true
        isLoading = false
        saveToStorage()
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        try? await Task.sleep(nanoseconds: 800_000_000)
        // In production: validate credentials against your backend
        if email.contains("@") && password.count >= 6 {
            currentUser.email = email
            isLoggedIn = true
        } else {
            errorMessage = "Invalid email or password."
        }
        isLoading = false
    }

    func signOut() {
        isLoggedIn = false
        hasCompletedOnboarding = false
        currentUser = UserProfile()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    func completeOnboarding(profile: UserProfile) {
        var updated = profile
        updated.hasCompletedOnboarding = true
        currentUser = updated
        hasCompletedOnboarding = true
        saveToStorage()
    }

    func updateProfile(_ profile: UserProfile) {
        currentUser = profile
        saveToStorage()
    }

    // MARK: - Persistence (UserDefaults — swap for Keychain/backend in prod)
    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return }
        currentUser = profile
        isLoggedIn = true
        hasCompletedOnboarding = profile.hasCompletedOnboarding
    }
}
