import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoggedIn {
                if authVM.hasCompletedOnboarding {
                    MainTabView(accountEmail: authVM.currentUser.email)
                        .id(authVM.currentUser.email)  // rebuild per-account state on account switch
                } else {
                    OnboardingView()
                }
            } else {
                LandingView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authVM.isLoggedIn)
    }
}
