import Foundation
import Security

final class KeychainStorage {
    static let shared = KeychainStorage()

    private let tokenKey = "com.anexcial.ios.token"
    private let currentUserKey = "com.anexcial.ios.currentUser"

    var token: String? {
        get { keychainGet(tokenKey).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let value = newValue {
                keychainSet(tokenKey, value.data(using: .utf8)!)
            } else {
                keychainDelete(tokenKey)
            }
        }
    }

    var currentUser: UserResponse? {
        get {
            guard let data = keychainGet(currentUserKey) else { return nil }
            return try? JSONDecoder().decode(UserResponse.self, from: data)
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                keychainSet(currentUserKey, data)
            } else {
                keychainDelete(currentUserKey)
            }
        }
    }

    func clearSession() {
        token = nil
        currentUser = nil
    }

    private func keychainGet(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func keychainSet(_ account: String, _ data: Data) {
        keychainDelete(account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        _ = SecItemAdd(query as CFDictionary, nil)
    }

    private func keychainDelete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
