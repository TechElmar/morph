import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var checkInVM: CheckInViewModel
    @EnvironmentObject var subscriptionVM: SubscriptionViewModel
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"
    @AppStorage("morph_reminder_enabled") private var reminderEnabled = false
    @State private var showEditProfile = false
    @State private var showSignOutAlert = false
    @State private var showClearDataAlert = false
    @State private var showPaywall = false

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: MorphSpacing.xl) {
                        // Profile header
                        VStack(spacing: MorphSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(MorphColors.accentDim)
                                    .frame(width: 80, height: 80)
                                Text(initials)
                                    .font(MorphFonts.display(28))
                                    .foregroundColor(MorphColors.accent)
                            }
                            VStack(spacing: 4) {
                                Text(authVM.currentUser.name.isEmpty ? "Athlete" : authVM.currentUser.name)
                                    .font(MorphFonts.heading(20))
                                    .foregroundColor(MorphColors.textPrimary)
                                Text(authVM.currentUser.email)
                                    .font(MorphFonts.caption())
                                    .foregroundColor(MorphColors.textSecondary)
                            }

                            if subscriptionVM.isPro {
                                Label("PRO Member", systemImage: "crown.fill")
                                    .font(MorphFonts.caption(12))
                                    .foregroundColor(MorphColors.background)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(MorphColors.accent)
                                    .clipShape(Capsule())
                            } else {
                                Button { showPaywall = true } label: {
                                    Label("Upgrade to PRO", systemImage: "crown")
                                        .font(MorphFonts.caption(12))
                                        .foregroundColor(MorphColors.accent)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(MorphColors.accentDim)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, MorphSpacing.xl)

                        // Stats summary
                        HStack(spacing: MorphSpacing.sm) {
                            StatTile(label: "Height", value: WeightFormat.height(authVM.currentUser.heightCm, unit: unit))
                            StatTile(label: "Weight", value: unit.format(authVM.currentUser.weightKg, decimals: 0))
                            StatTile(label: "Goal", value: authVM.currentUser.fitnessGoal.rawValue.components(separatedBy: " ").first ?? "")
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        // Settings sections
                        VStack(spacing: MorphSpacing.sm) {
                            SettingsSectionHeader("Profile")
                            SettingsRow(icon: "person.fill", title: "Edit Profile") {
                                showEditProfile = true
                            }
                            SettingsRow(icon: "target", title: "Update Goals") {
                                showEditProfile = true
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        VStack(spacing: MorphSpacing.sm) {
                            SettingsSectionHeader("Preferences")

                            // Unit toggle
                            HStack(spacing: MorphSpacing.md) {
                                Image(systemName: "scalemass")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MorphColors.textSecondary)
                                    .frame(width: 20)
                                Text("Units")
                                    .font(MorphFonts.body(15))
                                    .foregroundColor(MorphColors.textPrimary)
                                Spacer()
                                Picker("Units", selection: $unitRaw) {
                                    ForEach(WeightUnit.allCases, id: \.rawValue) { u in
                                        Text(u.label).tag(u.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 120)
                            }
                            .padding(MorphSpacing.md)
                            .morphCard()

                            // Weekly reminder toggle
                            HStack(spacing: MorphSpacing.md) {
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(MorphColors.textSecondary)
                                    .frame(width: 20)
                                Text("Weekly Check-In Reminder")
                                    .font(MorphFonts.body(15))
                                    .foregroundColor(MorphColors.textPrimary)
                                Spacer()
                                Toggle("", isOn: $reminderEnabled)
                                    .tint(MorphColors.accent)
                                    .labelsHidden()
                            }
                            .padding(MorphSpacing.md)
                            .morphCard()
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        VStack(spacing: MorphSpacing.sm) {
                            SettingsSectionHeader("Subscription")
                            if subscriptionVM.isPro {
                                SettingsRow(icon: "crown.fill", title: "Manage Subscription", accent: true) {
                                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            } else {
                                SettingsRow(icon: "crown.fill", title: "Upgrade to PRO", accent: true) {
                                    showPaywall = true
                                }
                            }
                            SettingsRow(icon: "arrow.counterclockwise", title: "Restore Purchases") {
                                Task { await subscriptionVM.restorePurchases() }
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        VStack(spacing: MorphSpacing.sm) {
                            SettingsSectionHeader("Account")
                            SettingsRow(icon: "trash", title: "Clear All Check-In Data", destructive: true) {
                                showClearDataAlert = true
                            }
                            SettingsRow(icon: "arrow.backward.square", title: "Sign Out", destructive: true) {
                                showSignOutAlert = true
                            }
                        }
                        .padding(.horizontal, MorphSpacing.xl)

                        Text("Morph v1.0 · Powered by Claude AI")
                            .font(MorphFonts.caption(11))
                            .foregroundColor(MorphColors.textTertiary)
                            .padding(.top, MorphSpacing.lg)

                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(MorphColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(isPresented: $showEditProfile) { EditProfileView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) { authVM.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Clear Everything", role: .destructive) { checkInVM.clearAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All check-ins, photos, and analyses will be permanently deleted.")
        }
        .onChange(of: reminderEnabled) { _, enabled in
            if enabled {
                scheduleWeeklyReminder()
            } else {
                UNUserNotificationCenter.current()
                    .removePendingNotificationRequests(withIdentifiers: ["morph_weekly_reminder"])
            }
        }
    }

    private func scheduleWeeklyReminder() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { reminderEnabled = false }
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "Check-In Day 📸"
            content.body = "Time for your weekly physique photos. Let's see the progress."
            content.sound = .default

            var date = DateComponents()
            date.weekday = 1   // Sunday
            date.hour = 10
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(identifier: "morph_weekly_reminder", content: content, trigger: trigger)
            center.add(request)
        }
    }

    private var initials: String {
        let parts = authVM.currentUser.name.components(separatedBy: " ")
        let first = parts.first?.prefix(1) ?? "?"
        let last = parts.count > 1 ? parts.last?.prefix(1) ?? "" : ""
        return "\(first)\(last)".uppercased()
    }
}

private struct StatTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MorphFonts.heading(16))
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

private struct SettingsSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(MorphFonts.caption(10))
            .foregroundColor(MorphColors.textTertiary)
            .tracking(1.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    var accent: Bool = false
    var destructive: Bool = false
    let action: () -> Void

    var tintColor: Color {
        if destructive { return MorphColors.destructive }
        if accent { return MorphColors.accent }
        return MorphColors.textSecondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: MorphSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(tintColor)
                    .frame(width: 20)
                Text(title)
                    .font(MorphFonts.body(15))
                    .foregroundColor(destructive ? MorphColors.destructive : MorphColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(MorphColors.textTertiary)
            }
            .padding(MorphSpacing.md)
            .morphCard()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile Sheet
struct EditProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage(WeightFormat.storageKey) private var unitRaw = "kg"
    @State private var draft: UserProfile = UserProfile()

    private var unit: WeightUnit { WeightUnit(rawValue: unitRaw) ?? .kg }

    var body: some View {
        NavigationStack {
            ZStack {
                MorphColors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: MorphSpacing.lg) {
                        VStack(spacing: MorphSpacing.md) {
                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                FieldLabel("Height: \(WeightFormat.height(draft.heightCm, unit: unit))")
                                Slider(value: $draft.heightCm, in: 140...220, step: 1)
                                    .tint(MorphColors.accent)
                            }
                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                FieldLabel("Current Weight")
                                WeightSlider(weightKg: $draft.weightKg, unit: unit)
                            }
                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                FieldLabel("Goal Weight")
                                WeightSlider(weightKg: $draft.goalWeightKg, unit: unit)
                            }
                            StepperField(label: "Age", value: $draft.age, range: 13...80, unit: "yrs")

                            VStack(alignment: .leading, spacing: MorphSpacing.sm) {
                                FieldLabel("Goal")
                                VStack(spacing: MorphSpacing.xs) {
                                    ForEach(UserProfile.FitnessGoal.allCases, id: \.self) { goal in
                                        SelectChip(title: goal.rawValue, isSelected: draft.fitnessGoal == goal) {
                                            draft.fitnessGoal = goal
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                        .padding(MorphSpacing.lg)
                        .morphCard()

                        MorphButton(title: "Save Changes", style: .primary) {
                            authVM.updateProfile(draft)
                            dismiss()
                        }
                    }
                    .padding(MorphSpacing.xl)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(MorphColors.textSecondary)
                }
            }
            .toolbarBackground(MorphColors.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationBackground(MorphColors.background)
        .onAppear { draft = authVM.currentUser }
    }
}
