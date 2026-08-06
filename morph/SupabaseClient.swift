import Foundation
import Security

// Lightweight Supabase client (Auth + PostgREST + Storage) over URLSession.
// No third-party SDK — consistent with ClaudeAIService's raw-URLSession approach.
struct SupabaseClient {
    static let shared = SupabaseClient()

    private let base = Secrets.supabaseURL
    private let apiKey = Secrets.supabasePublishableKey

    // MARK: - Session token storage (Keychain)

    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var userID: String
        var email: String
    }

    private static let sessionService = "com.techelmar.morph.session"
    private static let sessionAccount = "supabase_session"

    static func loadSession() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sessionService,
            kSecAttrAccount as String: sessionAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let session = try? JSONDecoder().decode(Session.self, from: data) else { return nil }
        return session
    }

    static func saveSession(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sessionService,
            kSecAttrAccount as String: sessionAccount
        ]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func clearSession() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sessionService,
            kSecAttrAccount as String: sessionAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Errors

    enum SupabaseError: LocalizedError {
        case message(String)
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .message(let m): return m
            case .http(_, let m): return m
            }
        }
    }

    // MARK: - Auth

    private struct AuthResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let user: AuthUser?
        // error fields (GoTrue returns these on failure)
        let error_description: String?
        let msg: String?
        let error: String?
    }
    private struct AuthUser: Decodable {
        let id: String
        let email: String?
    }

    func signUp(email: String, password: String, name: String) async throws -> Session {
        let body: [String: Any] = ["email": email, "password": password, "data": ["name": name]]
        let data = try await postAuth(path: "/auth/v1/signup", body: body)
        return try makeSession(from: data, fallbackEmail: email)
    }

    func signIn(email: String, password: String) async throws -> Session {
        let body: [String: Any] = ["email": email, "password": password]
        let data = try await postAuth(path: "/auth/v1/token?grant_type=password", body: body)
        return try makeSession(from: data, fallbackEmail: email)
    }

    func signOut(session: Session) async {
        var req = URLRequest(url: URL(string: "\(base)/auth/v1/logout")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: req)
    }

    /// Exchange a refresh token for a fresh session. Used when access token expires.
    func refresh(session: Session) async throws -> Session {
        let body: [String: Any] = ["refresh_token": session.refreshToken]
        let data = try await postAuth(path: "/auth/v1/token?grant_type=refresh_token", body: body)
        return try makeSession(from: data, fallbackEmail: session.email)
    }

    private func postAuth(path: String, body: [String: Any]) async throws -> Data {
        var req = URLRequest(url: URL(string: "\(base)\(path)")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.message("No response from server.")
        }
        if !(200...299).contains(http.statusCode) {
            // Surface a friendly GoTrue error message
            if let parsed = try? JSONDecoder().decode(AuthResponse.self, from: data) {
                let msg = parsed.error_description ?? parsed.msg ?? parsed.error ?? "Authentication failed."
                throw SupabaseError.message(friendlyAuthMessage(msg))
            }
            throw SupabaseError.http(http.statusCode, "Authentication failed (\(http.statusCode)).")
        }
        return data
    }

    private func makeSession(from data: Data, fallbackEmail: String) throws -> Session {
        let parsed = try JSONDecoder().decode(AuthResponse.self, from: data)
        guard let access = parsed.access_token,
              let refresh = parsed.refresh_token,
              let user = parsed.user else {
            // Sign-up succeeded but no session (email confirmation is ON)
            throw SupabaseError.message("Account created. Please check your email to confirm, then sign in.")
        }
        return Session(accessToken: access, refreshToken: refresh,
                       userID: user.id, email: user.email ?? fallbackEmail)
    }

    private func friendlyAuthMessage(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.contains("already registered") || lower.contains("already been registered") {
            return "An account with this email already exists. Sign in instead."
        }
        if lower.contains("invalid login") || lower.contains("invalid credentials") {
            return "Incorrect email or password."
        }
        if lower.contains("email not confirmed") {
            return "Please confirm your email before signing in."
        }
        return raw
    }

    // MARK: - Database (PostgREST)

    /// Authenticated REST request. Retries once after refreshing an expired token.
    private func rest(
        _ method: String,
        path: String,
        session: Session,
        body: Data? = nil,
        prefer: String? = nil
    ) async throws -> (Data, Session) {
        var current = session
        for attempt in 0..<2 {
            var req = URLRequest(url: URL(string: "\(base)/rest/v1\(path)")!)
            req.httpMethod = method
            req.timeoutInterval = 30
            req.setValue(apiKey, forHTTPHeaderField: "apikey")
            req.setValue("Bearer \(current.accessToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let prefer = prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
            req.httpBody = body

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw SupabaseError.message("No response from server.")
            }
            if http.statusCode == 401 && attempt == 0 {
                current = try await refresh(session: current)
                SupabaseClient.saveSession(current)
                continue
            }
            guard (200...299).contains(http.statusCode) else {
                let text = String(data: data, encoding: .utf8) ?? ""
                throw SupabaseError.http(http.statusCode, "Sync failed (\(http.statusCode)): \(text.prefix(160))")
            }
            return (data, current)
        }
        throw SupabaseError.message("Could not reach the server. Check your connection.")
    }

    /// GET rows as an array of dictionaries.
    func select(path: String, session: Session) async throws -> ([[String: Any]], Session) {
        let (data, s) = try await rest("GET", path: path, session: session)
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return (json, s)
    }

    /// Upsert a single row. Returns the stored representation.
    func upsert(table: String, row: [String: Any], session: Session) async throws -> ([[String: Any]], Session) {
        let body = try JSONSerialization.data(withJSONObject: [row])
        let (data, s) = try await rest("POST", path: "/\(table)", session: session,
                                       body: body, prefer: "resolution=merge-duplicates,return=representation")
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
        return (json, s)
    }

    /// PATCH rows matching a filter.
    @discardableResult
    func update(table: String, filter: String, row: [String: Any], session: Session) async throws -> Session {
        let body = try JSONSerialization.data(withJSONObject: row)
        let (_, s) = try await rest("PATCH", path: "/\(table)?\(filter)", session: session,
                                    body: body, prefer: "return=minimal")
        return s
    }

    /// DELETE rows matching a filter.
    @discardableResult
    func delete(table: String, filter: String, session: Session) async throws -> Session {
        let (_, s) = try await rest("DELETE", path: "/\(table)?\(filter)", session: session, prefer: "return=minimal")
        return s
    }

    // MARK: - Storage

    private let bucket = "physique-photos"

    /// Upload JPEG bytes to `<userID>/<path>`. Returns the object path stored in the DB.
    @discardableResult
    func uploadPhoto(_ jpeg: Data, path: String, session: Session) async throws -> Session {
        let url = URL(string: "\(base)/storage/v1/object/\(bucket)/\(path)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "x-upsert")
        req.httpBody = jpeg

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.message("Photo upload failed: \(text.prefix(120))")
        }
        return session
    }

    /// Download JPEG bytes from an authenticated storage path.
    func downloadPhoto(path: String, session: Session) async throws -> Data {
        let url = URL(string: "\(base)/storage/v1/object/authenticated/\(bucket)/\(path)")!
        var req = URLRequest(url: url)
        req.timeoutInterval = 60
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseError.message("Photo download failed.")
        }
        return data
    }

    /// Remove all photos under a check-in folder (best-effort).
    func deletePhotos(paths: [String], session: Session) async {
        guard !paths.isEmpty else { return }
        let url = URL(string: "\(base)/storage/v1/object/\(bucket)")!
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue(apiKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["prefixes": paths])
        _ = try? await URLSession.shared.data(for: req)
    }
}
