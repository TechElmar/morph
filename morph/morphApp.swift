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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                .environmentObject(subscriptionVM)
                .preferredColorScheme(.dark)
        }
    }
}
