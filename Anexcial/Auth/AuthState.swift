import Foundation

@MainActor
final class AuthState: ObservableObject {
    @Published var currentUser: UserResponse?
    @Published var isLoading = true
    /// Set when user just signed in or signed up; show "Signed in as [Role]" then clear.
    @Published var signedInRoleForBanner: String?

    init() {
        Task { await restoreSession() }
    }

    /// Pre-seeded admin (no signup on iOS). Sign in with this to use Admin flow.
    private static let defaultAdminEmail = "shayan@gmail.com"
    private static let defaultAdminPassword = "shayan"

    /// Restore session from local storage only (no server).
    func restoreSession() async {
        // #region agent log
        let hasToken = KeychainStorage.shared.token != nil
        let hasSessionUser = KeychainStorage.shared.currentSessionUser != nil
        debugLog(location: "AuthState.swift:restoreSession", message: "restoreSession entry", data: ["hasToken": hasToken, "hasSessionUser": hasSessionUser], hypothesisId: "A")
        // #endregion
        defer { isLoading = false }
        seedDefaultAdminIfNeeded()
        guard hasToken, let user = KeychainStorage.shared.currentSessionUser else {
            // #region agent log
            debugLog(location: "AuthState.swift:restoreSession", message: "restoreSession cleared", data: ["currentUserSet": false], hypothesisId: "A")
            // #endregion
            currentUser = nil
            return
        }
        currentUser = user
        // #region agent log
        debugLog(location: "AuthState.swift:restoreSession", message: "restoreSession restored", data: ["userId": user.id, "role": user.role], hypothesisId: "A")
        // #endregion
    }

    /// Login using locally stored credentials only. Checks default admin first, then local account.
    func login(email: String, password: String) async throws {
        let emailLower = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // 1) Default admin (never overwritten by sign-up)
        if let admin = KeychainStorage.shared.defaultAdminUser,
           KeychainStorage.shared.defaultAdminPassword == password,
           admin.email.lowercased() == emailLower {
            if KeychainStorage.shared.token == nil {
                KeychainStorage.shared.token = "local-\(UUID().uuidString)"
            }
            KeychainStorage.shared.currentSessionUser = admin
            currentUser = admin
            signedInRoleForBanner = admin.role
            return
        }
        // 2) Local account (Member/Store from sign-up)
        guard let user = KeychainStorage.shared.localUser,
              KeychainStorage.shared.localPassword == password,
              user.email.lowercased() == emailLower else {
            throw APIError.http(status: 401, message: "Invalid email or password")
        }
        if KeychainStorage.shared.token == nil {
            KeychainStorage.shared.token = "local-\(UUID().uuidString)"
        }
        KeychainStorage.shared.currentSessionUser = user
        currentUser = user
        signedInRoleForBanner = user.role
    }

    /// Register and store account locally only (no server).
    func register(role: String, email: String, password: String, inviteCode: String?) async throws {
        // #region agent log
        debugLog(location: "AuthState.swift:register", message: "register entry", data: ["role": role, "emailLength": email.count], hypothesisId: "C")
        // #endregion
        let user = UserResponse(
            id: 1,
            username: email,
            email: email,
            role: role
        )
        KeychainStorage.shared.token = "local-\(UUID().uuidString)"
        KeychainStorage.shared.localUser = user
        KeychainStorage.shared.localPassword = password
        KeychainStorage.shared.currentSessionUser = user
        currentUser = user
        signedInRoleForBanner = user.role
        // #region agent log
        let verifyToken = KeychainStorage.shared.token != nil
        let verifyUser = KeychainStorage.shared.localUser != nil
        let verifyPass = KeychainStorage.shared.localPassword != nil
        debugLog(location: "AuthState.swift:register", message: "register after save", data: ["tokenSet": verifyToken, "localUserSet": verifyUser, "localPasswordSet": verifyPass], hypothesisId: "C")
        // #endregion
    }

    func logout() {
        KeychainStorage.shared.token = nil
        KeychainStorage.shared.currentSessionUser = nil
        KeychainStorage.shared.memberQRUUID = nil
        KeychainStorage.shared.memberQRPayload = nil
        signedInRoleForBanner = nil
        currentUser = nil
    }

    /// Seeds the default admin in separate Keychain keys so it's never overwritten by sign-up. No signup needed for admin on iOS.
    private func seedDefaultAdminIfNeeded() {
        guard KeychainStorage.shared.defaultAdminUser == nil else { return }
        let admin = UserResponse(
            id: 0,
            username: Self.defaultAdminEmail,
            email: Self.defaultAdminEmail,
            role: "admin"
        )
        KeychainStorage.shared.defaultAdminUser = admin
        KeychainStorage.shared.defaultAdminPassword = Self.defaultAdminPassword
    }
}
