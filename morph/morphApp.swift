//
//  morphApp.swift
//  morph
//
//  Created by Elmar Rasho on 2026-06-10.
//

import SwiftUI

@main
struct MorphApp: App {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var subscriptionVM = SubscriptionViewModel()
    @AppStorage(MorphTheme.storageKey) private var appearance = "dark"
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .environmentObject(subscriptionVM)
                .preferredColorScheme(appearance == "light" ? .light : .dark)
                .id(appearance)  // full re-render so MorphColors recompute on theme change
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Keep the 7-day notification window rolling forward
                NotificationManager.reschedule(isPro: subscriptionVM.isPro)
            }
        }
    }
}
