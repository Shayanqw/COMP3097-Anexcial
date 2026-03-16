import Foundation

/// In-memory store for local-only mode so items and invites persist within the session.
private enum LocalMockStore {
    static var storeItems: [StoreItemResponse] = []
    static var inviteCodes: [InviteCodeResponse] = []
    static var onboarding: OnboardingRequestResponse?
    static var nextItemId = 2
    static var nextInviteId = 1
}

/// iOS-only app: no server. All data is local/mock.
struct APIClient {
    static let useLocalOnly = true

    static var baseURL: URL = {
        if let urlString = ProcessInfo.processInfo.environment["ANEXCIAL_API_URL"], let url = URL(string: urlString) {
            return url
        }
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "ANEXCIAL_API_URL") as? String, let url = URL(string: urlString) {
            return url
        }
        return URL(string: "http://127.0.0.1:8000/api/")!
    }()

    var token: String?

    init(token: String? = nil) {
        self.token = token ?? KeychainStorage.shared.token
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        if Self.useLocalOnly {
            let data = try await localMockData(path: path, method: method, body: body)
            return try JSONDecoder().decode(T.self, from: data)
        }
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token {
            req.setValue("Token \(t)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(b))
        }
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            let msg = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.error ?? String(data: data, encoding: .utf8) ?? "Error"
            throw APIError.http(status: http.statusCode, message: msg)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func requestVoid(_ path: String, method: String = "GET", body: Encodable? = nil) async throws {
        if Self.useLocalOnly {
            _ = try await localMockData(path: path, method: method, body: body)
            return
        }
        var req = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token {
            req.setValue("Token \(t)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(b))
        }
        let (_, res) = try await URLSession.shared.data(for: req)
        guard let http = res as? HTTPURLResponse else { throw APIError.invalidResponse }
        if http.statusCode >= 400 {
            throw APIError.http(status: http.statusCode, message: "Request failed")
        }
    }

    private func localMockData(path: String, method: String, body: Encodable?) async throws -> Data {
        let base = path.split(separator: "?").first.map(String.init) ?? path
        let encoder = JSONEncoder()
        // #region agent log
        debugLog(location: "APIClient.swift:localMockData", message: "localMockData entry", data: ["path": path, "base": base, "method": method], hypothesisId: "D")
        // #endregion

        if base == "store/dashboard/" {
            let onboardingStatus = LocalMockStore.onboarding?.status ?? "pending"
            let mock = DashboardResponse(
                store: StoreInfo(id: 1, name: "My Store", reward_threshold: 100, reward_label: "Free reward"),
                kpi: KPI(members: 0, points_week: 0, redeems_week: 0),
                onboarding_status: onboardingStatus,
                items: LocalMockStore.storeItems
            )
            return try encoder.encode(mock)
        }
        if base == "store/items/" {
            if method == "POST" {
                struct ItemBody: Decodable { let name: String?; let points: Int?; let item_id: Int? }
                let name: String
                let points: Int
                let itemId: Int?
                if let b = body, let data = try? JSONEncoder().encode(AnyEncodable(b)), let decoded = try? JSONDecoder().decode(ItemBody.self, from: data) {
                    name = decoded.name ?? "Item"
                    points = decoded.points ?? 10
                    itemId = decoded.item_id
                } else {
                    name = "Item"
                    points = 10
                    itemId = nil
                }
                if let id = itemId, let idx = LocalMockStore.storeItems.firstIndex(where: { $0.id == id }) {
                    let updated = StoreItemResponse(id: id, name: name, points: points)
                    LocalMockStore.storeItems[idx] = updated
                    return try encoder.encode(updated)
                }
                let id = LocalMockStore.nextItemId
                LocalMockStore.nextItemId += 1
                let newItem = StoreItemResponse(id: id, name: name, points: points)
                LocalMockStore.storeItems.append(newItem)
                return try encoder.encode(newItem)
            }
            return try encoder.encode(LocalMockStore.storeItems)
        }
        if base == "store/invites/" {
            if method == "POST" {
                struct InviteBody: Decodable { let code: String?; let max_uses: Int?; let expires_days: Int? }
                let code: String
                let maxUses: Int
                let expiresDays: Int
                if let b = body, let data = try? JSONEncoder().encode(AnyEncodable(b)), let decoded = try? JSONDecoder().decode(InviteBody.self, from: data) {
                    code = decoded.code ?? "DEMO"
                    maxUses = decoded.max_uses ?? 10
                    expiresDays = decoded.expires_days ?? 30
                } else {
                    code = "DEMO"
                    maxUses = 10
                    expiresDays = 30
                }
                let id = LocalMockStore.nextInviteId
                LocalMockStore.nextInviteId += 1
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let expires = formatter.string(from: Calendar.current.date(byAdding: .day, value: expiresDays, to: Date()) ?? Date())
                let inv = InviteCodeResponse(id: id, code: code, status: "active", max_uses: maxUses, uses_count: 0, note: "", expires: expires, created_at: nil)
                LocalMockStore.inviteCodes.append(inv)
                return try encoder.encode(inv)
            }
            return try encoder.encode(LocalMockStore.inviteCodes)
        }
        if base == "store/onboarding/" {
            if method == "POST" {
                struct OnboardingBody: Decodable {
                    let business_name: String?
                    let contact_email: String?
                    let notes: String?
                }
                var status = "pending"
                var businessName: String?
                var contactEmail: String?
                var notes: String?
                if let b = body, let data = try? JSONEncoder().encode(AnyEncodable(b)), let decoded = try? JSONDecoder().decode(OnboardingBody.self, from: data) {
                    businessName = decoded.business_name
                    contactEmail = decoded.contact_email
                    notes = decoded.notes
                    status = "submitted"
                }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                let created = formatter.string(from: Date())
                let req = OnboardingRequestResponse(id: 1, business_name: businessName, contact_email: contactEmail, notes: notes, status: status, created_at: created)
                LocalMockStore.onboarding = req
                return try encoder.encode(req)
            }
            let mock = LocalMockStore.onboarding ?? OnboardingRequestResponse(id: nil, business_name: nil, contact_email: nil, notes: nil, status: "pending", created_at: nil)
            return try encoder.encode(mock)
        }
        if base == "store/points/award/" || base == "store/points/redeem/" {
            return try encoder.encode(SuccessResponse(success: true, message: nil, detail: nil))
        }
        if base.hasPrefix("store/member-lookup") {
            let mock = MemberLookupResponse(ok: true, username: "Member", member_uuid: UUID().uuidString, error: nil)
            return try encoder.encode(mock)
        }
        if base == "member/qr/" {
            let uuid: String
            let payload: String
            if let existingUUID = KeychainStorage.shared.memberQRUUID, let existingPayload = KeychainStorage.shared.memberQRPayload {
                uuid = existingUUID
                payload = existingPayload
            } else {
                uuid = UUID().uuidString
                payload = "ANEXCIAL:\(uuid)"
                KeychainStorage.shared.memberQRUUID = uuid
                KeychainStorage.shared.memberQRPayload = payload
            }
            let mock = MemberQRResponse(member_uuid: uuid, qr_payload: payload)
            return try encoder.encode(mock)
        }
        if base == "member/stores/" || base == "member/stores" {
            return try encoder.encode([StoreCard]())
        }
        if base.hasPrefix("member/stores/") && base != "member/stores/" {
            let parts = base.split(separator: "/")
            let idOpt = parts.count >= 3 ? Int(parts[2]) : nil
            // #region agent log
            debugLog(location: "APIClient.swift:localMockData", message: "member/stores/:id branch", data: ["base": base, "partsCount": parts.count, "storeId": idOpt ?? -1], hypothesisId: "E")
            // #endregion
            if let id = idOpt {
                let mock = StoreDetail(id: id, name: "Store \(id)", points: 0, reward_threshold: 100, reward_label: "Reward", reward_available: false, history: [])
                return try encoder.encode(mock)
            }
        }
        if base.hasPrefix("member/redeem/") {
            return try encoder.encode(SuccessResponse(success: true, message: nil, detail: nil))
        }
        if base == "admin/onboarding-requests/" {
            return try encoder.encode([AdminOnboardingItem]())
        }
        if base.contains("admin/onboarding-requests/") && base.contains("/review/") {
            return try encoder.encode(SuccessResponse(success: true, message: nil, detail: nil))
        }
        if base == "auth/me/" {
            let user = KeychainStorage.shared.localUser ?? UserResponse(id: 0, username: "user", email: "local@example.com", role: "member")
            struct MeWrapper: Encodable { let user: UserResponse }
            return try encoder.encode(MeWrapper(user: user))
        }

        // #region agent log
        debugLog(location: "APIClient.swift:localMockData", message: "localMockData fallback", data: ["base": base, "returning": "SuccessResponse"], hypothesisId: "D")
        // #endregion
        return try encoder.encode(SuccessResponse(success: true, message: nil, detail: nil))
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case http(status: Int, message: String)
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response"
        case .http(_, let m): return m
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
