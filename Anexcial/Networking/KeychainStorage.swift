import Foundation
import Security

final class KeychainStorage {
    static let shared = KeychainStorage()
    private let tokenKey = "com.anexcial.ios.token"
    private let localUserKey = "com.anexcial.ios.localUser"
    private let localPasswordKey = "com.anexcial.ios.localPassword"
    private let currentSessionUserKey = "com.anexcial.ios.currentSessionUser"
    private let defaultAdminUserKey = "com.anexcial.ios.defaultAdminUser"
    private let defaultAdminPasswordKey = "com.anexcial.ios.defaultAdminPassword"
    private let memberQRUUIDKey = "com.anexcial.ios.memberQRUUID"
    private let memberQRPayloadKey = "com.anexcial.ios.memberQRPayload"

    var token: String? {
        get {
            keychainGet(tokenKey).flatMap { String(data: $0, encoding: .utf8) }
        }
        set {
            if let t = newValue {
                keychainSet(tokenKey, t.data(using: .utf8)!)
            } else {
                keychainDelete(tokenKey)
            }
        }
    }

    var localUser: UserResponse? {
        get {
            guard let data = keychainGet(localUserKey) else { return nil }
            return try? JSONDecoder().decode(UserResponse.self, from: data)
        }
        set {
            if let u = newValue, let data = try? JSONEncoder().encode(u) {
                keychainSet(localUserKey, data)
            } else {
                keychainDelete(localUserKey)
            }
        }
    }

    var localPassword: String? {
        get {
            keychainGet(localPasswordKey).flatMap { String(data: $0, encoding: .utf8) }
        }
        set {
            if let p = newValue {
                keychainSet(localPasswordKey, p.data(using: .utf8)!)
            } else {
                keychainDelete(localPasswordKey)
            }
        }
    }

    /// Who is currently logged in (admin or local user). Restored on launch.
    var currentSessionUser: UserResponse? {
        get {
            guard let data = keychainGet(currentSessionUserKey) else { return nil }
            return try? JSONDecoder().decode(UserResponse.self, from: data)
        }
        set {
            if let u = newValue, let data = try? JSONEncoder().encode(u) {
                keychainSet(currentSessionUserKey, data)
            } else {
                keychainDelete(currentSessionUserKey)
            }
        }
    }

    /// Pre-seeded admin; never overwritten by sign-up. Used only for sign-in.
    var defaultAdminUser: UserResponse? {
        get {
            guard let data = keychainGet(defaultAdminUserKey) else { return nil }
            return try? JSONDecoder().decode(UserResponse.self, from: data)
        }
        set {
            if let u = newValue, let data = try? JSONEncoder().encode(u) {
                keychainSet(defaultAdminUserKey, data)
            } else {
                keychainDelete(defaultAdminUserKey)
            }
        }
    }

    var defaultAdminPassword: String? {
        get { keychainGet(defaultAdminPasswordKey).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let p = newValue { keychainSet(defaultAdminPasswordKey, p.data(using: .utf8)!) }
            else { keychainDelete(defaultAdminPasswordKey) }
        }
    }

    var memberQRUUID: String? {
        get { keychainGet(memberQRUUIDKey).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let v = newValue { keychainSet(memberQRUUIDKey, v.data(using: .utf8)!) }
            else { keychainDelete(memberQRUUIDKey) }
        }
    }

    var memberQRPayload: String? {
        get { keychainGet(memberQRPayloadKey).flatMap { String(data: $0, encoding: .utf8) } }
        set {
            if let v = newValue { keychainSet(memberQRPayloadKey, v.data(using: .utf8)!) }
            else { keychainDelete(memberQRPayloadKey) }
        }
    }

    private func keychainGet(_ account: String) -> Data? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func keychainSet(_ account: String, _ data: Data) {
        keychainDelete(account)
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(add as CFDictionary, nil)
        // #region agent log
        debugLog(location: "KeychainStorage.swift:keychainSet", message: "keychainSet result", data: ["account": account, "status": status, "errSecSuccess": errSecSuccess], hypothesisId: "C")
        // #endregion
    }

    private func keychainDelete(_ account: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(q as CFDictionary)
    }
}
