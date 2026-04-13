import Foundation

@MainActor
final class AuthState: ObservableObject {
    @Published var currentUser: UserResponse?
    @Published var isLoading = true
    @Published var signedInRoleForBanner: String?

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        defer { isLoading = false }
        guard let token = KeychainStorage.shared.token else {
            currentUser = nil
            KeychainStorage.shared.currentUser = nil
            return
        }

        do {
            let response: MeResponse = try await APIClient(token: token).request("auth/me/")
            saveSession(token: token, user: response.user)
        } catch {
            clearSession()
        }
    }

    func login(email: String, password: String) async throws {
        struct Body: Encodable {
            let identifier: String
            let password: String
        }

        let response: LoginResponse = try await APIClient(token: nil).request(
            "auth/login/",
            method: "POST",
            body: Body(identifier: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        )
        saveSession(token: response.token, user: response.user)
        signedInRoleForBanner = response.user.role
    }

    func register(role: String, email: String, password: String, inviteCode: String?, storeName: String?) async throws {
        struct Body: Encodable {
            let role: String
            let email: String
            let password: String
            let invite_code: String?
            let store_name: String?
        }

        let response: LoginResponse = try await APIClient(token: nil).request(
            "auth/signup/",
            method: "POST",
            body: Body(
                role: role,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                invite_code: inviteCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                store_name: storeName?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
        saveSession(token: response.token, user: response.user)
        signedInRoleForBanner = response.user.role
    }

    func requestPasswordReset(email: String) async throws -> String {
        struct Body: Encodable { let email: String }
        let response: SuccessResponse = try await APIClient(token: nil).request(
            "auth/password-reset/",
            method: "POST",
            body: Body(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
        )
        return response.message ?? "If an account exists for that email, a reset link has been sent."
    }

    func logout() {
        let token = KeychainStorage.shared.token
        clearSession()
        guard let token else { return }
        Task {
            try? await APIClient(token: token).requestVoid("auth/logout/", method: "POST")
        }
    }

    private func saveSession(token: String, user: UserResponse) {
        KeychainStorage.shared.token = token
        KeychainStorage.shared.currentUser = user
        currentUser = user
    }

    private func clearSession() {
        KeychainStorage.shared.clearSession()
        currentUser = nil
        signedInRoleForBanner = nil
    }
}
