import Foundation
import UserNotifications

// One notification per day, max — no spam.
// Each day at 10:00 the user gets exactly one of:
//   • a check-in reminder, on the day their next check-in unlocks
//   • a motivation message, on every other day
// The next 7 days are scheduled in advance and refreshed every time the
// app becomes active or an analysis completes, so the schedule stays accurate.
enum NotificationManager {

    static let enabledKey = "morph_reminder_enabled"

    private static let motivations = [
        "Consistency beats intensity. Show up today.",
        "Your future physique is built on today's choices.",
        "Small daily wins compound into transformations.",
        "The workout you skip is the one you needed most.",
        "Protein, sleep, training. Keep the big three honest today.",
        "You don't need motivation — you need momentum. Start small.",
        "Discipline is choosing what you want most over what you want now.",
        "Progress photos don't lie. Keep stacking good weeks.",
        "One more rep, one more meal on point. That's the whole game.",
        "Nobody regrets a workout after it's done.",
        "Your only competition is last week's photos.",
        "Hard days build the physique easy days can't.",
        "Fuel like an athlete, train like it matters. It does.",
        "The scale is one data point. The mirror is the trend."
    ]

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func enable(isPro: Bool, onResult: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted { reschedule(isPro: isPro) }
                onResult(granted)
            }
        }
    }

    static func disable() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    static func reschedule(isPro: Bool) {
        guard isEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        let unlockDate = DeviceCheckInGate.nextCheckInDate(isPro: isPro)  // nil = available now
        var messages = motivations.shuffled()

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: Date()) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: day)
            comps.hour = 10
            comps.minute = 0
            guard let fireDate = cal.date(from: comps), fireDate > Date() else { continue }

            let isUnlockDay: Bool
            if let unlock = unlockDate {
                isUnlockDay = cal.isDate(fireDate, inSameDayAs: unlock)
            } else {
                isUnlockDay = offset == 0  // check-in is available right now
            }

            let content = UNMutableNotificationContent()
            content.sound = .default
            if isUnlockDay {
                content.title = "Check-In Unlocked 📸"
                content.body = isPro
                    ? "Your daily check-in is ready. Snap your 4 photos."
                    : "Your weekly check-in is ready. Time to track the progress."
            } else {
                content.title = "Morph"
                content.body = messages.popLast() ?? "Consistency beats intensity. Show up today."
            }

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: "morph_daily_\(offset)",
                content: content,
                trigger: trigger
            ))
        }
    }
}
