import Foundation
import Security

// Device-level check-in rate limit, stored in the Keychain.
//
// Why Keychain and not per-account storage: the free tier allows 1 analysis
// per week. If the limit lived on the account, a user could sign out, create
// a fresh account, and analyze again — burning API credits indefinitely.
// The Keychain record is shared across all accounts on the device AND
// survives app deletion/reinstall, so new accounts can't reset the clock.
//
// (A determined user with multiple physical devices still bypasses this;
// closing that fully requires server-side accounts.)
enum DeviceCheckInGate {

    private static let service = "com.techelmar.morph.gate"
    private static let account = "last_analysis_date"

    // MARK: - Keychain-backed last analysis date

    static var lastAnalysisDate: Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              let interval = TimeInterval(string) else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    static func recordAnalysis() {
        let data = String(Date().timeIntervalSince1970).data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    // MARK: - Gating rules (Free: 1/week · Pro: 1/day)

    static func canCheckIn(isPro: Bool) -> Bool {
        guard let last = lastAnalysisDate else { return true }
        let cal = Calendar.current
        if isPro {
            return !cal.isDateInToday(last)
        }
        return !cal.isDate(last, equalTo: Date(), toGranularity: .weekOfYear)
    }

    /// When the next check-in unlocks. Nil if one is available now.
    static func nextCheckInDate(isPro: Bool) -> Date? {
        guard !canCheckIn(isPro: isPro), let last = lastAnalysisDate else { return nil }
        let cal = Calendar.current
        if isPro {
            return cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: last) ?? Date())
        }
        return cal.dateInterval(of: .weekOfYear, for: last)?.end
    }
}
