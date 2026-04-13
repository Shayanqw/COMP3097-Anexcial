import Foundation

struct APIClient {
    static let baseURL = URL(string: "https://anexcial.local/api/")!
    static let webBaseURL = URL(string: "https://anexcial.local/")!

    var token: String?

    init(token: String? = nil) {
        self.token = token ?? KeychainStorage.shared.token
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> T {
        let (data, _) = try await perform(path, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func requestVoid(_ path: String, method: String = "GET", body: Encodable? = nil) async throws {
        _ = try await perform(path, method: method, body: body)
    }

    static func resolveWebURL(_ path: String) -> URL? {
        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute
        }
        return URL(string: path, relativeTo: webBaseURL)?.absoluteURL
    }

    private func perform(_ path: String, method: String, body: Encodable?) async throws -> (Data, HTTPURLResponse) {
        let bodyData = try body.map { try JSONEncoder().encode(AnyEncodable($0)) }
        let data = try await LocalAppService.shared.perform(
            path: path,
            method: method,
            token: token,
            bodyData: bodyData
        )
        let response = HTTPURLResponse(
            url: URL(string: path, relativeTo: Self.baseURL)!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case invalidURL(String)
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response."
        case .invalidURL(let path):
            return "Invalid URL: \(path)"
        case .http(_, let message):
            return message
        }
    }
}

struct ErrorResponse: Decodable {
    let error: String
}

struct DetailErrorResponse: Decodable {
    let detail: String
}

private struct AnyEncodable: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private actor LocalAppService {
    static let shared = LocalAppService()

    private var state: LocalAppState
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()
    private let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let loaded = Self.loadState(decoder: decoder) {
            state = loaded
        } else {
            state = LocalAppState.seeded()
            Self.saveState(state, encoder: encoder)
        }
    }

    func perform(path: String, method: String, token: String?, bodyData: Data?) throws -> Data {
        let request = try LocalRequest(path: path, method: method, bodyData: bodyData)

        switch (request.path, request.method) {
        case ("public/bootstrap/", "GET"):
            return try encode(publicBootstrap())
        case let (path, "GET") where path.hasPrefix("public/catalog/"):
            let slug = path.replacingOccurrences(of: "public/catalog/", with: "").trimmingSlashes()
            return try encode(publicPage(slug: slug, catalog: true))
        case let (path, "GET") where path.hasPrefix("public/resources/"):
            let slug = path.replacingOccurrences(of: "public/resources/", with: "").trimmingSlashes()
            return try encode(publicPage(slug: slug, catalog: false))
        case ("public/privacy/", "GET"):
            return try encode(privacyPage())
        case ("public/terms/", "GET"):
            return try encode(termsPage())
        case ("public/status/", "GET"):
            return try encode(localStatus())
        case ("public/consultation/", "POST"):
            return try encode(try localConsultationResponse(body: request.body))
        case ("auth/login/", "POST"):
            return try encode(try login(body: request.body))
        case ("auth/signup/", "POST"):
            return try encode(try signup(body: request.body))
        case ("auth/logout/", "POST"):
            return try encode(SuccessResponse(ok: true, success: true, message: "Logged out.", detail: nil))
        case ("auth/me/", "GET"):
            return try encode(MeResponse(user: try requireUser(token: token)))
        case ("auth/password-reset/", "POST"):
            return try encode(SuccessResponse(
                ok: true,
                success: true,
                message: "Password reset email is skipped in local mode. Use your saved local credentials instead.",
                detail: nil
            ))
        case ("member/stores/", "GET"):
            return try encode(try memberStores(for: requireRole(token: token, role: "member")))
        case let (path, "GET") where path.hasPrefix("member/stores/") && path.hasSuffix("/") && !path.hasSuffix("/redeem/"):
            let storeId = try request.trailingInt(after: "member/stores/")
            return try encode(try memberStoreDetail(storeId: storeId, member: requireRole(token: token, role: "member")))
        case let (path, "POST") where path.hasPrefix("member/stores/") && path.hasSuffix("/redeem/"):
            let storeId = try request.trailingInt(after: "member/stores/")
            return try encode(try memberRedeem(storeId: storeId, member: requireRole(token: token, role: "member")))
        case ("member/qr/", "GET"):
            return try encode(memberQR(member: try requireRole(token: token, role: "member")))
        case ("store/dashboard/", "GET"):
            return try encode(try storeDashboard(for: requireStoreUser(token: token)))
        case ("store/items/", "GET"):
            return try encode(try storeItems(for: requireStoreUser(token: token)))
        case ("store/items/", "POST"):
            return try encode(try createStoreItem(body: request.body, storeUser: requireStoreUser(token: token)))
        case let (path, "PATCH") where path.hasPrefix("store/items/"):
            let itemId = try request.trailingInt(after: "store/items/")
            return try encode(try updateStoreItem(itemId: itemId, body: request.body, storeUser: requireStoreUser(token: token)))
        case ("store/invites/", "GET"):
            return try encode(try storeInvites(for: requireStoreUser(token: token)))
        case ("store/invites/", "POST"):
            return try encode(try createStoreInvite(body: request.body, storeUser: requireStoreUser(token: token)))
        case ("store/member-lookup/", "GET"):
            return try encode(try memberLookup(query: request.query, storeUser: requireStoreUser(token: token)))
        case ("store/points/award/", "POST"):
            return try encode(try awardPoints(body: request.body, storeUser: requireStoreUser(token: token)))
        case ("store/points/redeem/", "POST"):
            return try encode(try redeemPoints(body: request.body, storeUser: requireStoreUser(token: token)))
        case ("store/onboarding/", "GET"):
            return try encode(try storeOnboarding(for: requireStoreUser(token: token)))
        case ("store/onboarding/", "POST"):
            return try encode(try saveStoreOnboarding(body: request.body, storeUser: requireStoreUser(token: token)))
        case ("store/billing/", "GET"):
            return try encode(try localBilling(for: requireStoreUser(token: token)))
        case ("store/billing/checkout/", "POST"):
            return try encode(BillingCheckoutResponse(
                ok: false,
                mode: "local",
                url: nil,
                session_id: nil,
                reason: "Billing is disabled in this on-device demo build.",
                error: nil
            ))
        case ("admin/dashboard/", "GET"):
            return try encode(try adminDashboard(admin: requireAdmin(token: token)))
        case ("admin/users/", "GET"):
            return try encode(try adminUsers(query: request.query, admin: requireAdmin(token: token)))
        case let (path, "GET") where path.hasPrefix("admin/users/"):
            let userId = try request.trailingInt(after: "admin/users/")
            return try encode(try adminUserDetail(userId: userId, admin: requireAdmin(token: token)))
        case let (path, "PATCH") where path.hasPrefix("admin/users/"):
            let userId = try request.trailingInt(after: "admin/users/")
            return try encode(try adminUpdateUser(userId: userId, body: request.body, admin: requireAdmin(token: token)))
        case let (path, "DELETE") where path.hasPrefix("admin/users/"):
            let userId = try request.trailingInt(after: "admin/users/")
            return try encode(try adminDeleteUser(userId: userId, body: request.body, admin: requireAdmin(token: token)))
        case ("admin/stores/", "GET"):
            return try encode(try adminStores(query: request.query, admin: requireAdmin(token: token)))
        case let (path, "GET") where path.hasPrefix("admin/stores/") && !path.hasSuffix("/billing-override/"):
            let storeId = try request.trailingInt(after: "admin/stores/")
            return try encode(try adminStoreDetail(storeId: storeId, admin: requireAdmin(token: token)))
        case let (path, "PATCH") where path.hasPrefix("admin/stores/"):
            let storeId = try request.trailingInt(after: "admin/stores/")
            return try encode(try adminUpdateStore(storeId: storeId, body: request.body, admin: requireAdmin(token: token)))
        case let (path, "POST") where path.hasPrefix("admin/stores/") && path.hasSuffix("/billing-override/"):
            let storeId = try request.trailingInt(after: "admin/stores/")
            return try encode(try adminBillingOverride(storeId: storeId, body: request.body, admin: requireAdmin(token: token)))
        case ("admin/invites/", "GET"):
            return try encode(try adminInvites(query: request.query, admin: requireAdmin(token: token)))
        case ("admin/invites/", "POST"):
            return try encode(try adminCreateInvite(body: request.body, admin: requireAdmin(token: token)))
        case let (path, "GET") where path.hasPrefix("admin/invites/"):
            let inviteId = try request.trailingInt(after: "admin/invites/")
            return try encode(try adminInviteDetail(inviteId: inviteId, admin: requireAdmin(token: token)))
        case let (path, "PATCH") where path.hasPrefix("admin/invites/"):
            let inviteId = try request.trailingInt(after: "admin/invites/")
            return try encode(try adminUpdateInvite(inviteId: inviteId, body: request.body, admin: requireAdmin(token: token)))
        case ("admin/members-by-store/", "GET"):
            return try encode(try adminMembersByStore(query: request.query, admin: requireAdmin(token: token)))
        case ("admin/consultation-leads/", "GET"):
            return try encode(try adminConsultationLeads(query: request.query, admin: requireAdmin(token: token)))
        case ("admin/onboarding-requests/", "GET"):
            return try encode(try adminOnboardingRequests(query: request.query, admin: requireAdmin(token: token)))
        case let (path, "POST") where path.hasPrefix("admin/onboarding-requests/") && path.hasSuffix("/review/"):
            let onboardingId = try request.trailingInt(after: "admin/onboarding-requests/")
            return try encode(try adminReviewOnboarding(onboardingId: onboardingId, body: request.body, admin: requireAdmin(token: token)))
        default:
            throw APIError.http(status: 404, message: "Unsupported local route: \(request.method) \(request.path)")
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    private func save() {
        Self.saveState(state, encoder: encoder)
    }

    private func requireUser(token: String?) throws -> UserResponse {
        guard let token else {
            throw APIError.http(status: 401, message: "Please sign in.")
        }
        guard let id = Int(token.replacingOccurrences(of: "local-user-", with: "")),
              let user = state.users.first(where: { $0.id == id && $0.isActive })
        else {
            throw APIError.http(status: 401, message: "Session expired.")
        }
        return user.response
    }

    private func localUser(from token: String?) throws -> LocalUser {
        let user = try requireUser(token: token)
        guard let match = state.users.first(where: { $0.id == user.id }) else {
            throw APIError.http(status: 401, message: "Session expired.")
        }
        return match
    }

    private func requireRole(token: String?, role: String) throws -> LocalUser {
        let user = try localUser(from: token)
        guard user.role == role else {
            throw APIError.http(status: 403, message: "Access denied.")
        }
        return user
    }

    private func requireStoreUser(token: String?) throws -> LocalUser {
        let user = try localUser(from: token)
        guard user.role == "store" else {
            throw APIError.http(status: 403, message: "Store access only.")
        }
        return user
    }

    private func requireAdmin(token: String?) throws -> LocalUser {
        let user = try localUser(from: token)
        guard user.role == "admin" else {
            throw APIError.http(status: 403, message: "Admin access only.")
        }
        return user
    }

    private func login(body: [String: Any]) throws -> LoginResponse {
        let identifier = string(body["identifier"]).lowercased()
        let password = string(body["password"])
        guard let user = state.users.first(where: {
            $0.isActive &&
            $0.password == password &&
            ($0.email.lowercased() == identifier || $0.username.lowercased() == identifier)
        }) else {
            throw APIError.http(status: 401, message: "Invalid email/username or password.")
        }
        return LoginResponse(token: token(for: user.id), user: user.response)
    }

    private func signup(body: [String: Any]) throws -> LoginResponse {
        let role = string(body["role"])
        let email = string(body["email"]).lowercased()
        let password = string(body["password"])
        let inviteCode = string(body["invite_code"]).uppercased()
        let storeName = string(body["store_name"])

        guard !email.isEmpty, password.count >= 4 else {
            throw APIError.http(status: 400, message: "Email and password are required.")
        }
        guard state.users.allSatisfy({ $0.email.lowercased() != email }) else {
            throw APIError.http(status: 409, message: "An account with that email already exists.")
        }

        let username = uniqueUsername(from: email)
        switch role {
        case "member":
            guard let inviteIndex = state.invites.firstIndex(where: {
                $0.code == inviteCode && $0.isActive && $0.isUsable(referenceDate: Date())
            }) else {
                throw APIError.http(status: 400, message: "Enter a valid invite code.")
            }
            let user = LocalUser(
                id: nextUserId(),
                username: username,
                email: email,
                password: password,
                role: "member",
                isActive: true,
                storeId: nil,
                memberUUID: UUID().uuidString.lowercased(),
                createdAt: Date()
            )
            state.users.append(user)
            state.memberships.append(LocalMembership(storeId: state.invites[inviteIndex].storeId, memberUserId: user.id, joinedAt: Date()))
            state.invites[inviteIndex].usesCount += 1
            appendLog(summary: "Member \(user.username) joined with invite \(state.invites[inviteIndex].code).", actionKey: "member.joined", reason: "", targetType: "user", targetId: user.id, actor: user.username)
            save()
            return LoginResponse(token: token(for: user.id), user: user.response)
        case "store":
            guard !storeName.isEmpty else {
                throw APIError.http(status: 400, message: "Store name is required.")
            }
            var user = LocalUser(
                id: nextUserId(),
                username: username,
                email: email,
                password: password,
                role: "store",
                isActive: true,
                storeId: nil,
                memberUUID: nil,
                createdAt: Date()
            )
            let storeId = nextStoreId()
            user.storeId = storeId
            let store = LocalStore(
                id: storeId,
                ownerUserId: user.id,
                name: storeName,
                rewardThreshold: 120,
                rewardLabel: "House Reward",
                isActive: true,
                createdAt: Date(),
                billingStatus: "local",
                planSlug: "sandbox"
            )
            state.users.append(user)
            state.stores.append(store)
            state.onboarding.append(LocalOnboarding(
                id: nextOnboardingId(),
                storeId: storeId,
                businessName: storeName,
                contactEmail: email,
                notes: "Created locally on device.",
                status: "PENDING",
                createdAt: Date(),
                reviewedAt: nil,
                reviewedBy: nil
            ))
            appendLog(summary: "Store account \(user.username) created \(store.name).", actionKey: "store.created", reason: "", targetType: "store", targetId: store.id, actor: user.username)
            save()
            return LoginResponse(token: token(for: user.id), user: user.response)
        default:
            throw APIError.http(status: 400, message: "Unsupported role.")
        }
    }

    private func memberStores(for member: LocalUser) throws -> [StoreCard] {
        state.memberships
            .filter { $0.memberUserId == member.id }
            .compactMap { membership in
                guard let store = state.stores.first(where: { $0.id == membership.storeId }) else { return nil }
                let points = pointsTotal(storeId: store.id, memberId: member.id)
                return StoreCard(
                    id: store.id,
                    name: store.name,
                    points: points,
                    threshold: store.rewardThreshold,
                    reward_label: store.rewardLabel,
                    reward_available: points >= store.rewardThreshold
                )
            }
            .sorted { $0.name < $1.name }
    }

    private func memberStoreDetail(storeId: Int, member: LocalUser) throws -> StoreDetail {
        guard let store = state.stores.first(where: { $0.id == storeId }) else {
            throw APIError.http(status: 404, message: "Store not found.")
        }
        ensureMembership(storeId: store.id, memberId: member.id)
        let points = pointsTotal(storeId: store.id, memberId: member.id)
        return StoreDetail(
            id: store.id,
            name: store.name,
            points: points,
            reward_threshold: store.rewardThreshold,
            reward_label: store.rewardLabel,
            reward_available: points >= store.rewardThreshold,
            history: memberHistory(storeId: store.id, memberId: member.id)
        )
    }

    private func memberRedeem(storeId: Int, member: LocalUser) throws -> MemberRedeemResponse {
        guard let store = state.stores.first(where: { $0.id == storeId && $0.isActive }) else {
            throw APIError.http(status: 404, message: "Store not found.")
        }
        ensureMembership(storeId: store.id, memberId: member.id)
        let total = pointsTotal(storeId: store.id, memberId: member.id)
        guard total >= store.rewardThreshold else {
            throw APIError.http(status: 400, message: "Not enough points for redemption yet.")
        }

        state.transactions.append(LocalTransaction(
            id: nextTransactionId(),
            storeId: store.id,
            memberUserId: member.id,
            createdByUserId: nil,
            type: "redeem",
            points: -store.rewardThreshold,
            item: store.rewardLabel,
            createdAt: Date()
        ))
        appendLog(summary: "Member \(member.username) redeemed at \(store.name).", actionKey: "member.redeemed", reason: "", targetType: "store", targetId: store.id, actor: member.username)
        save()

        return MemberRedeemResponse(
            ok: true,
            message: "Reward redeemed.",
            store: try memberStoreDetail(storeId: storeId, member: member)
        )
    }

    private func memberQR(member: LocalUser) -> MemberQRResponse {
        let uuid = member.memberUUID ?? UUID().uuidString.lowercased()
        return MemberQRResponse(member_uuid: uuid, qr_payload: "member:\(uuid)", qr_data_uri: nil)
    }

    private func storeDashboard(for storeUser: LocalUser) throws -> DashboardResponse {
        let store = try requireStore(for: storeUser)
        let transactions = state.transactions.filter { $0.storeId == store.id }
        let weekCutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekTransactions = transactions.filter { $0.createdAt >= weekCutoff }
        let members = Set(state.memberships.filter { $0.storeId == store.id }.map(\.memberUserId)).count
        let onboarding = state.onboarding.first(where: { $0.storeId == store.id })
            ?? LocalOnboarding.empty(storeId: store.id, storeName: store.name, email: storeUser.email)

        return DashboardResponse(
            store: store.info,
            kpi: KPI(
                members: members,
                points_week: weekTransactions.filter { $0.points > 0 }.reduce(0) { $0 + $1.points },
                redeems_week: weekTransactions.filter { $0.type == "redeem" }.count
            ),
            onboarding_status: onboarding.status,
            onboarding: onboarding.response(dateFormatter: isoFormatter),
            items: state.items.filter { $0.storeId == store.id && $0.isActive }.map { $0.response(dateFormatter: isoFormatter) },
            subscription_info: localSubscriptionInfo(store: store),
            pricing_plans: localPricingPlans(),
            store_tools_locked: false
        )
    }

    private func storeItems(for storeUser: LocalUser) throws -> StoreItemsResponse {
        let store = try requireStore(for: storeUser)
        let items = state.items.filter { $0.storeId == store.id }.map { $0.response(dateFormatter: isoFormatter) }
        return StoreItemsResponse(
            items: items,
            rules: [
                "Point values are stored on-device in local mode.",
                "Edits apply immediately on this device."
            ],
            subscription_info: localSubscriptionInfo(store: store),
            active_item_count: items.filter { $0.is_active ?? true }.count,
            recommended_upgrade_plan: ""
        )
    }

    private func createStoreItem(body: [String: Any], storeUser: LocalUser) throws -> StoreItemResponse {
        let store = try requireStore(for: storeUser)
        let name = string(body["name"])
        let points = int(body["points"])
        guard !name.isEmpty, points > 0 else {
            throw APIError.http(status: 400, message: "Item name and positive points are required.")
        }

        let item = LocalStoreItem(id: nextItemId(), storeId: store.id, name: name, points: points, isActive: true, createdAt: Date())
        state.items.append(item)
        appendLog(summary: "Added item \(item.name) to \(store.name).", actionKey: "store.item.created", reason: "", targetType: "store", targetId: store.id, actor: storeUser.username)
        save()
        return item.response(dateFormatter: isoFormatter)
    }

    private func updateStoreItem(itemId: Int, body: [String: Any], storeUser: LocalUser) throws -> StoreItemResponse {
        let store = try requireStore(for: storeUser)
        guard let index = state.items.firstIndex(where: { $0.id == itemId && $0.storeId == store.id }) else {
            throw APIError.http(status: 404, message: "Item not found.")
        }
        let name = string(body["name"])
        let points = int(body["points"])
        guard !name.isEmpty, points > 0 else {
            throw APIError.http(status: 400, message: "Item name and positive points are required.")
        }

        state.items[index].name = name
        state.items[index].points = points
        appendLog(summary: "Updated item \(name) for \(store.name).", actionKey: "store.item.updated", reason: "", targetType: "item", targetId: itemId, actor: storeUser.username)
        save()
        return state.items[index].response(dateFormatter: isoFormatter)
    }

    private func storeInvites(for storeUser: LocalUser) throws -> StoreInvitesResponse {
        let store = try requireStore(for: storeUser)
        let invites = state.invites
            .filter { $0.storeId == store.id }
            .sorted { $0.createdAt > $1.createdAt }
            .map { $0.inviteCodeResponse(referenceDate: Date(), dateFormatter: shortDateFormatter, dateTimeFormatter: isoFormatter) }

        return StoreInvitesResponse(
            invites: invites,
            subscription_info: localSubscriptionInfo(store: store),
            active_invites_count: invites.filter { $0.status == "Active" }.count,
            recommended_upgrade_plan: ""
        )
    }

    private func createStoreInvite(body: [String: Any], storeUser: LocalUser) throws -> StoreInviteCreateResponse {
        let store = try requireStore(for: storeUser)
        let code = string(body["code"]).uppercased()
        let maxUses = max(int(body["max_uses"]), 1)
        let expiresDays = max(int(body["expires_days"]), 0)
        guard !code.isEmpty else {
            throw APIError.http(status: 400, message: "Invite code is required.")
        }
        guard state.invites.allSatisfy({ $0.code != code }) else {
            throw APIError.http(status: 409, message: "Invite code already exists.")
        }

        let invite = LocalInvite(
            id: nextInviteId(),
            storeId: store.id,
            code: code,
            maxUses: maxUses,
            usesCount: 0,
            isActive: true,
            expiresAt: expiresDays > 0 ? Calendar.current.date(byAdding: .day, value: expiresDays, to: Date()) : nil,
            createdAt: Date(),
            createdByUserId: storeUser.id
        )
        state.invites.append(invite)
        appendLog(summary: "Created invite \(invite.code) for \(store.name).", actionKey: "store.invite.created", reason: "", targetType: "invite", targetId: invite.id, actor: storeUser.username)
        save()
        return StoreInviteCreateResponse(
            invite: invite.inviteCodeResponse(referenceDate: Date(), dateFormatter: shortDateFormatter, dateTimeFormatter: isoFormatter),
            emailed: false
        )
    }

    private func memberLookup(query: [String: String], storeUser: LocalUser) throws -> MemberLookupResponse {
        let store = try requireStore(for: storeUser)
        let payload = query["payload"] ?? ""
        guard payload.hasPrefix("member:") else {
            throw APIError.http(status: 400, message: "Enter a valid member QR payload.")
        }
        guard let member = memberFromPayload(payload) else {
            throw APIError.http(status: 404, message: "Member not found.")
        }
        ensureMembership(storeId: store.id, memberId: member.id)
        return MemberLookupResponse(ok: true, username: member.username, member_uuid: member.memberUUID, error: nil)
    }

    private func awardPoints(body: [String: Any], storeUser: LocalUser) throws -> SuccessResponse {
        let store = try requireStore(for: storeUser)
        let payload = string(body["scanned_payload"])
        let itemId = int(body["item_id"])
        guard let member = memberFromPayload(payload) else {
            throw APIError.http(status: 404, message: "Member not found.")
        }
        guard let item = state.items.first(where: { $0.id == itemId && $0.storeId == store.id && $0.isActive }) else {
            throw APIError.http(status: 400, message: "Invalid item selection.")
        }

        let recentDuplicate = state.transactions.contains {
            $0.storeId == store.id &&
            $0.memberUserId == member.id &&
            $0.item == item.name &&
            $0.points == item.points &&
            $0.type == "award" &&
            Date().timeIntervalSince($0.createdAt) < 60
        }
        guard !recentDuplicate else {
            throw APIError.http(status: 409, message: "Duplicate scan detected. Try again in a minute.")
        }

        ensureMembership(storeId: store.id, memberId: member.id)
        state.transactions.append(LocalTransaction(
            id: nextTransactionId(),
            storeId: store.id,
            memberUserId: member.id,
            createdByUserId: storeUser.id,
            type: "award",
            points: item.points,
            item: item.name,
            createdAt: Date()
        ))
        appendLog(summary: "Awarded \(item.points) points to \(member.username).", actionKey: "store.points.awarded", reason: "", targetType: "user", targetId: member.id, actor: storeUser.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Member found: \(member.username). Awarded \(item.points) points.", detail: nil)
    }

    private func redeemPoints(body: [String: Any], storeUser: LocalUser) throws -> SuccessResponse {
        let store = try requireStore(for: storeUser)
        let payload = string(body["scanned_payload"])
        let points = int(body["points"])
        guard points > 0 else {
            throw APIError.http(status: 400, message: "Redeem points must be a positive number.")
        }
        guard let member = memberFromPayload(payload) else {
            throw APIError.http(status: 404, message: "Member not found.")
        }

        ensureMembership(storeId: store.id, memberId: member.id)
        let total = pointsTotal(storeId: store.id, memberId: member.id)
        guard total >= points else {
            throw APIError.http(status: 400, message: "Member has insufficient points.")
        }

        state.transactions.append(LocalTransaction(
            id: nextTransactionId(),
            storeId: store.id,
            memberUserId: member.id,
            createdByUserId: storeUser.id,
            type: "redeem",
            points: -points,
            item: "Store redemption",
            createdAt: Date()
        ))
        appendLog(summary: "Redeemed \(points) points for \(member.username).", actionKey: "store.points.redeemed", reason: "", targetType: "user", targetId: member.id, actor: storeUser.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Redeemed \(points) points for \(member.username).", detail: nil)
    }

    private func storeOnboarding(for storeUser: LocalUser) throws -> OnboardingRequestResponse {
        let store = try requireStore(for: storeUser)
        let onboarding = state.onboarding.first(where: { $0.storeId == store.id })
            ?? LocalOnboarding.empty(storeId: store.id, storeName: store.name, email: storeUser.email)
        return onboarding.response(dateFormatter: isoFormatter)
    }

    private func saveStoreOnboarding(body: [String: Any], storeUser: LocalUser) throws -> OnboardingRequestResponse {
        let store = try requireStore(for: storeUser)
        let businessName = string(body["business_name"])
        let contactEmail = string(body["contact_email"])
        let notes = string(body["notes"])

        if let index = state.onboarding.firstIndex(where: { $0.storeId == store.id }) {
            state.onboarding[index].businessName = businessName.isEmpty ? store.name : businessName
            state.onboarding[index].contactEmail = contactEmail.isEmpty ? storeUser.email : contactEmail
            state.onboarding[index].notes = notes
            state.onboarding[index].status = "PENDING"
            state.onboarding[index].reviewedAt = nil
            state.onboarding[index].reviewedBy = nil
        } else {
            state.onboarding.append(LocalOnboarding(
                id: nextOnboardingId(),
                storeId: store.id,
                businessName: businessName.isEmpty ? store.name : businessName,
                contactEmail: contactEmail.isEmpty ? storeUser.email : contactEmail,
                notes: notes,
                status: "PENDING",
                createdAt: Date(),
                reviewedAt: nil,
                reviewedBy: nil
            ))
        }

        appendLog(summary: "Submitted onboarding for \(store.name).", actionKey: "store.onboarding.submitted", reason: notes, targetType: "store", targetId: store.id, actor: storeUser.username)
        save()
        return try storeOnboarding(for: storeUser)
    }

    private func localBilling(for storeUser: LocalUser) throws -> StoreBillingResponse {
        let store = try requireStore(for: storeUser)
        let subscription = localSubscriptionInfo(store: store)
        return StoreBillingResponse(
            store: SimpleStoreRef(id: store.id, name: store.name),
            subscription: StoreBillingSubscriptionResponse(
                plan_slug: subscription.plan_slug,
                billing_status: subscription.billing_status,
                current_period_start: subscription.current_period_start,
                current_period_end: subscription.current_period_end,
                cancel_at_period_end: false,
                stripe_customer_id: "",
                stripe_subscription_id: ""
            ),
            subscription_info: subscription,
            billing_events: [],
            billing_actions: [],
            portal_url: "",
            billing_support_email: "local@anexcial.app",
            usage: subscription.usage,
            checkout_state: "disabled",
            checkout_plan: subscription.plan_slug,
            pricing_plans: localPricingPlans()
        )
    }

    private func adminDashboard(admin: LocalUser) throws -> AdminDashboardResponse {
        let activeStores = state.stores.filter(\.isActive)
        let members = state.users.filter { $0.role == "member" && $0.isActive }
        let pending = state.onboarding.filter { $0.status == "PENDING" }
        let activeInvites = state.invites.filter { $0.isActive && $0.isUsable(referenceDate: Date()) }

        return AdminDashboardResponse(
            summary: AdminSummaryResponse(
                total_users: state.users.count,
                active_stores: activeStores.count,
                members: members.count,
                pending_onboarding: pending.count,
                active_invites: activeInvites.count,
                recent_leads: state.consultationLeads.count,
                active_subscriptions: activeStores.count
            ),
            pending_requests: pending.sorted { $0.createdAt > $1.createdAt }.prefix(5).map { $0.adminItem(storeName: storeName(for: $0.storeId), dateFormatter: isoFormatter) },
            recent_stores: state.stores.sorted { $0.createdAt > $1.createdAt }.prefix(5).map { adminStoreDashboardRow(for: $0) },
            recent_users: state.users.sorted { $0.createdAt > $1.createdAt }.prefix(6).map { adminUserRow(for: $0) },
            recent_leads: state.consultationLeads.sorted { $0.createdAt > $1.createdAt }.prefix(5).map { $0.summary(dateFormatter: isoFormatter) },
            recent_admin_logs: state.adminLogs.sorted { $0.createdAt > $1.createdAt }.prefix(8).map { $0.response(dateFormatter: isoFormatter) }
        )
    }

    private func adminUsers(query: [String: String], admin: LocalUser) throws -> AdminUsersResponse {
        let search = (query["q"] ?? "").lowercased()
        let role = query["role"] ?? ""
        let users = state.users.filter { user in
            (role.isEmpty || user.role == role) &&
            (search.isEmpty || user.username.lowercased().contains(search) || user.email.lowercased().contains(search))
        }
        return AdminUsersResponse(users: users.sorted { $0.createdAt > $1.createdAt }.map { adminUserRow(for: $0) })
    }

    private func adminUserDetail(userId: Int, admin: LocalUser) throws -> AdminUserDetailResponse {
        guard let user = state.users.first(where: { $0.id == userId }) else {
            throw APIError.http(status: 404, message: "User not found.")
        }
        let impact = DeleteImpactResponse(
            member_profile_deleted: user.role == "member" ? 1 : 0,
            member_transactions_deleted: state.transactions.filter { $0.memberUserId == user.id }.count,
            created_transactions_reassigned: state.transactions.filter { $0.createdByUserId == user.id }.count,
            reviewed_onboarding_reassigned: state.onboarding.filter { $0.reviewedBy == user.username }.count,
            invite_creator_reassigned: state.invites.filter { $0.createdByUserId == user.id }.count,
            store_deleted: user.role == "store" ? user.storeId : nil,
            store_name: user.storeId.flatMap(storeName),
            store_items_deleted: user.storeId.map { id in state.items.filter { $0.storeId == id }.count },
            store_invites_deleted: user.storeId.map { id in state.invites.filter { $0.storeId == id }.count },
            store_transactions_deleted: user.storeId.map { id in state.transactions.filter { $0.storeId == id }.count },
            store_onboarding_deleted: user.storeId.map { id in state.onboarding.filter { $0.storeId == id }.count }
        )

        return AdminUserDetailResponse(
            user: adminUserRow(for: user),
            delete_warning: "Deleting this account removes the on-device history tied to it.",
            delete_impact: impact,
            recent_logs: logs(for: "user", id: user.id)
        )
    }

    private func adminUpdateUser(userId: Int, body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        guard let index = state.users.firstIndex(where: { $0.id == userId }) else {
            throw APIError.http(status: 404, message: "User not found.")
        }

        let requestedRole = string(body["role"])
        let isActive = bool(body["is_active"], default: state.users[index].isActive)
        if !requestedRole.isEmpty {
            state.users[index].role = requestedRole
        }
        state.users[index].isActive = isActive

        appendLog(summary: "Updated user \(state.users[index].username).", actionKey: "admin.user.updated", reason: "", targetType: "user", targetId: userId, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "User updated.", detail: nil)
    }

    private func adminDeleteUser(userId: Int, body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        let reason = string(body["delete_reason"])
        guard reason.count >= 8 else {
            throw APIError.http(status: 400, message: "A delete reason is required.")
        }
        guard let user = state.users.first(where: { $0.id == userId }) else {
            throw APIError.http(status: 404, message: "User not found.")
        }
        guard user.role != "admin" || state.users.filter({ $0.role == "admin" && $0.isActive }).count > 1 else {
            throw APIError.http(status: 400, message: "Keep at least one active admin in this demo environment.")
        }

        if let storeId = user.storeId {
            state.stores.removeAll { $0.id == storeId }
            state.items.removeAll { $0.storeId == storeId }
            state.invites.removeAll { $0.storeId == storeId }
            state.transactions.removeAll { $0.storeId == storeId }
            state.onboarding.removeAll { $0.storeId == storeId }
            state.memberships.removeAll { $0.storeId == storeId }
        }
        state.memberships.removeAll { $0.memberUserId == userId }
        state.transactions.removeAll { $0.memberUserId == userId }
        state.users.removeAll { $0.id == userId }

        appendLog(summary: "Deleted user \(user.username).", actionKey: "admin.user.deleted", reason: reason, targetType: "user", targetId: userId, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "User deleted.", detail: nil)
    }

    private func adminStores(query: [String: String], admin: LocalUser) throws -> AdminStoresResponse {
        let search = (query["q"] ?? "").lowercased()
        let status = query["status"] ?? ""
        let stores = state.stores.filter { store in
            let owner = owner(for: store)
            let matchesSearch = search.isEmpty || store.name.lowercased().contains(search) || owner.username.lowercased().contains(search) || owner.email.lowercased().contains(search)
            let matchesStatus = status.isEmpty || (status == "active" ? store.isActive : !store.isActive)
            return matchesSearch && matchesStatus
        }
        return AdminStoresResponse(stores: stores.sorted { $0.createdAt > $1.createdAt }.map { adminStoreRow(for: $0) })
    }

    private func adminStoreDetail(storeId: Int, admin: LocalUser) throws -> AdminStoreDetailResponse {
        guard let store = state.stores.first(where: { $0.id == storeId }) else {
            throw APIError.http(status: 404, message: "Store not found.")
        }
        return AdminStoreDetailResponse(store: adminStoreRow(for: store), recent_logs: logs(for: "store", id: storeId), billing_events: [])
    }

    private func adminUpdateStore(storeId: Int, body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        guard let index = state.stores.firstIndex(where: { $0.id == storeId }) else {
            throw APIError.http(status: 404, message: "Store not found.")
        }

        let name = string(body["name"])
        let rewardThreshold = int(body["reward_threshold"])
        let rewardLabel = string(body["reward_label"])
        let isActive = bool(body["is_active"], default: state.stores[index].isActive)
        let statusReason = string(body["status_reason"])

        if !name.isEmpty { state.stores[index].name = name }
        if rewardThreshold > 0 { state.stores[index].rewardThreshold = rewardThreshold }
        if !rewardLabel.isEmpty { state.stores[index].rewardLabel = rewardLabel }
        state.stores[index].isActive = isActive

        appendLog(summary: "Updated store \(state.stores[index].name).", actionKey: "admin.store.updated", reason: statusReason, targetType: "store", targetId: storeId, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Store updated.", detail: nil)
    }

    private func adminBillingOverride(storeId: Int, body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        guard let index = state.stores.firstIndex(where: { $0.id == storeId }) else {
            throw APIError.http(status: 404, message: "Store not found.")
        }
        let billingStatus = string(body["billing_status"])
        let reason = string(body["billing_reason"])
        guard reason.count >= 4 else {
            throw APIError.http(status: 400, message: "A reason is required for local billing overrides.")
        }
        if !billingStatus.isEmpty {
            state.stores[index].billingStatus = billingStatus
        }
        appendLog(summary: "Set local billing status for \(state.stores[index].name) to \(state.stores[index].billingStatus).", actionKey: "admin.store.billing_override", reason: reason, targetType: "store", targetId: storeId, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Local billing status updated.", detail: nil)
    }

    private func adminInvites(query: [String: String], admin: LocalUser) throws -> AdminInvitesResponse {
        let search = (query["q"] ?? "").lowercased()
        let status = query["status"] ?? ""
        let invites = state.invites.filter { invite in
            let row = adminInviteRow(for: invite)
            let matchesSearch = search.isEmpty || row.code.lowercased().contains(search) || row.store_name.lowercased().contains(search)
            let matchesStatus: Bool
            switch status {
            case "active":
                matchesStatus = row.is_active
            case "inactive":
                matchesStatus = !row.is_active
            default:
                matchesStatus = true
            }
            return matchesSearch && matchesStatus
        }

        return AdminInvitesResponse(
            invites: invites.sorted { $0.createdAt > $1.createdAt }.map { adminInviteRow(for: $0) },
            stores: state.stores.sorted { $0.name < $1.name }.map { SimpleStoreRef(id: $0.id, name: $0.name) }
        )
    }

    private func adminCreateInvite(body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        let storeId = int(body["store_id"])
        let code = string(body["code"]).uppercased()
        let maxUses = int(body["max_uses"])
        let isActive = bool(body["is_active"], default: true)
        let expiresAt = dateFromDayString(string(body["expires_at"]))

        guard state.stores.contains(where: { $0.id == storeId }) else {
            throw APIError.http(status: 400, message: "Choose a valid store.")
        }
        guard !code.isEmpty, maxUses > 0 else {
            throw APIError.http(status: 400, message: "Code and max uses are required.")
        }
        guard state.invites.allSatisfy({ $0.code != code }) else {
            throw APIError.http(status: 409, message: "Invite code already exists.")
        }

        let invite = LocalInvite(
            id: nextInviteId(),
            storeId: storeId,
            code: code,
            maxUses: maxUses,
            usesCount: 0,
            isActive: isActive,
            expiresAt: expiresAt,
            createdAt: Date(),
            createdByUserId: admin.id
        )
        state.invites.append(invite)
        appendLog(summary: "Created invite \(code).", actionKey: "admin.invite.created", reason: "", targetType: "invite", targetId: invite.id, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Invite created.", detail: nil)
    }

    private func adminUpdateInvite(inviteId: Int, body: [String: Any], admin: LocalUser) throws -> SuccessResponse {
        guard let index = state.invites.firstIndex(where: { $0.id == inviteId }) else {
            throw APIError.http(status: 404, message: "Invite not found.")
        }

        let storeId = int(body["store_id"])
        let code = string(body["code"]).uppercased()
        let maxUses = int(body["max_uses"])
        let isActive = bool(body["is_active"], default: state.invites[index].isActive)
        let expiresAt = dateFromDayString(string(body["expires_at"]))

        if state.stores.contains(where: { $0.id == storeId }) {
            state.invites[index].storeId = storeId
        }
        if !code.isEmpty { state.invites[index].code = code }
        if maxUses > 0 { state.invites[index].maxUses = maxUses }
        state.invites[index].isActive = isActive
        state.invites[index].expiresAt = expiresAt

        appendLog(summary: "Updated invite \(state.invites[index].code).", actionKey: "admin.invite.updated", reason: "", targetType: "invite", targetId: inviteId, actor: admin.username)
        save()
        return SuccessResponse(ok: true, success: true, message: "Invite updated.", detail: nil)
    }

    private func adminInviteDetail(inviteId: Int, admin: LocalUser) throws -> AdminInviteDetailResponse {
        guard let invite = state.invites.first(where: { $0.id == inviteId }) else {
            throw APIError.http(status: 404, message: "Invite not found.")
        }
        return AdminInviteDetailResponse(invite: adminInviteRow(for: invite), recent_logs: logs(for: "invite", id: inviteId))
    }

    private func adminMembersByStore(query: [String: String], admin: LocalUser) throws -> AdminMembersByStoreResponse {
        let search = (query["q"] ?? "").lowercased()
        let groups = state.stores.sorted { $0.name < $1.name }.map { store -> AdminStoreMemberGroupResponse in
            let memberships = state.memberships.filter { $0.storeId == store.id }
            let members = memberships.compactMap { membership -> AdminMemberRowResponse? in
                guard let user = state.users.first(where: { $0.id == membership.memberUserId && $0.role == "member" }) else { return nil }
                let txs = state.transactions.filter { $0.storeId == store.id && $0.memberUserId == user.id }
                let row = AdminMemberRowResponse(
                    store_id: store.id,
                    store_name: store.name,
                    member_id: user.id,
                    username: user.username,
                    email: user.email,
                    total_points: pointsTotal(storeId: store.id, memberId: user.id),
                    tx_count: txs.count,
                    last_activity: txs.sorted { $0.createdAt > $1.createdAt }.first.map { isoFormatter.string(from: $0.createdAt) },
                    redemption_count: txs.filter { $0.type == "redeem" }.count
                )
                if search.isEmpty {
                    return row
                }
                let haystack = "\(row.store_name) \(row.username) \(row.email)".lowercased()
                return haystack.contains(search) ? row : nil
            }
            return AdminStoreMemberGroupResponse(store: SimpleStoreRef(id: store.id, name: store.name), members: members)
        }
        .filter { search.isEmpty || !$0.members.isEmpty || $0.store.name.lowercased().contains(search) }

        return AdminMembersByStoreResponse(groups: groups)
    }

    private func adminConsultationLeads(query: [String: String], admin: LocalUser) throws -> AdminConsultationLeadsResponse {
        let search = (query["q"] ?? "").lowercased()
        let plan = query["plan"] ?? ""
        let booking = query["booking"] ?? ""

        let leads = state.consultationLeads.filter { lead in
            let matchesSearch = search.isEmpty || lead.businessName.lowercased().contains(search) || lead.contactName.lowercased().contains(search) || lead.email.lowercased().contains(search)
            let matchesPlan = plan.isEmpty || lead.plan == plan
            let matchesBooking: Bool
            switch booking {
            case "booking":
                matchesBooking = lead.wantsBooking
            case "followup":
                matchesBooking = !lead.wantsBooking
            default:
                matchesBooking = true
            }
            return matchesSearch && matchesPlan && matchesBooking
        }

        return AdminConsultationLeadsResponse(leads: leads.sorted { $0.createdAt > $1.createdAt }.map { $0.response(dateFormatter: isoFormatter) })
    }

    private func adminOnboardingRequests(query: [String: String], admin: LocalUser) throws -> AdminOnboardingListResponse {
        let search = (query["q"] ?? "").lowercased()
        let filtered = state.onboarding.filter { onboarding in
            let haystack = "\(onboarding.businessName) \(onboarding.contactEmail) \(storeName(for: onboarding.storeId))".lowercased()
            return search.isEmpty || haystack.contains(search)
        }

        return AdminOnboardingListResponse(
            pending_requests: filtered.filter { $0.status == "PENDING" }.sorted { $0.createdAt > $1.createdAt }.map { $0.adminItem(storeName: storeName(for: $0.storeId), dateFormatter: isoFormatter) },
            history_requests: filtered.filter { $0.status != "PENDING" }.sorted { $0.createdAt > $1.createdAt }.map { $0.adminItem(storeName: storeName(for: $0.storeId), dateFormatter: isoFormatter) },
            recent_review_logs: state.adminLogs.filter { $0.actionKey == "admin.onboarding.reviewed" }.sorted { $0.createdAt > $1.createdAt }.prefix(10).map { $0.response(dateFormatter: isoFormatter) }
        )
    }

    private func adminReviewOnboarding(onboardingId: Int, body: [String: Any], admin: LocalUser) throws -> AdminReviewResponse {
        guard let index = state.onboarding.firstIndex(where: { $0.id == onboardingId }) else {
            throw APIError.http(status: 404, message: "Onboarding request not found.")
        }
        let action = string(body["action"])
        let reviewReason = string(body["review_reason"])
        guard !reviewReason.isEmpty else {
            throw APIError.http(status: 400, message: "A review reason is required.")
        }

        state.onboarding[index].status = action == "approve" ? "APPROVED" : "REJECTED"
        state.onboarding[index].reviewedAt = Date()
        state.onboarding[index].reviewedBy = admin.username
        appendLog(summary: "\(action == "approve" ? "Approved" : "Rejected") onboarding for \(state.onboarding[index].businessName).", actionKey: "admin.onboarding.reviewed", reason: reviewReason, targetType: "onboarding", targetId: onboardingId, actor: admin.username)
        save()

        return AdminReviewResponse(request: state.onboarding[index].adminItem(storeName: storeName(for: state.onboarding[index].storeId), dateFormatter: isoFormatter))
    }

    private func publicBootstrap() -> PublicBootstrapResponse {
        PublicBootstrapResponse(
            app_name: "Anexcial",
            theme: ThemePaletteResponse(background: "#120d09", surface: "#241913", text: "#f5efe8", muted: "#b7a999", accent: "#d4a574", success: "#7fd0a0", danger: "#ef8d73"),
            home: PublicHomeResponse(
                eyebrow: "On-device demo",
                headline: "Run Anexcial on one device.",
                body: "This iOS build keeps the loyalty experience available without a remote backend. Seeded demo data is ready on first launch.",
                tagline: "Points, invites, and QR flows run entirely on this device."
            ),
            marketing_site: MarketingSiteResponse(
                tagline: "Native loyalty demo for iOS",
                support_email: "support@anexcial.com",
                contact_email: "hello@anexcial.local",
                analytics_notice: "Analytics is disabled in local mode.",
                google_calendar_url: "https://anexcial.local/book",
                google_calendar_embed_url: "https://anexcial.local/book/embed",
                stripe_links: [:],
                social_links: [
                    SocialLinkResponse(label: "Instagram", href: "https://anexcial.local/instagram", icon: "camera"),
                    SocialLinkResponse(label: "LinkedIn", href: "https://anexcial.local/linkedin", icon: "briefcase")
                ]
            ),
            pricing_plans: localPricingPlans(),
            comparison_rows: [
                ComparisonRowResponse(label: "Users", values: ["1 device", "Demo data", "No sync"]),
                ComparisonRowResponse(label: "Billing", values: ["Skipped", "Skipped", "Skipped"]),
                ComparisonRowResponse(label: "Core loyalty", values: ["Included", "Included", "Included"])
            ],
            catalog_links: [
                LinkCardResponse(title: "Store setup", href: "/catalog/store-setup", description: "How invites, items, and onboarding work on this device.", tag: "Guide", external: false),
                LinkCardResponse(title: "Member rewards", href: "/catalog/member-rewards", description: "Redeem rewards and keep member QR payloads consistent on-device.", tag: "Guide", external: false),
                LinkCardResponse(title: "Admin overview", href: "/catalog/admin-sandbox", description: "Manage users, stores, invites, and onboarding in the demo.", tag: "Guide", external: false)
            ],
            resource_columns: [
                ResourceColumnResponse(title: "Getting started", items: [
                    LinkCardResponse(title: "Demo credentials", href: "/resources/demo-credentials", description: "Seeded admin, store, and member accounts available on first launch.", tag: "Resource", external: false),
                    LinkCardResponse(title: "Manual QR fallback", href: "/resources/manual-qr", description: "Use typed payloads in the simulator when the camera is unavailable.", tag: "Resource", external: false)
                ])
            ],
            featured_resource: FeaturedResourceResponse(
                eyebrow: "Featured",
                title: "Device workflow",
                description: "Keep points, invites, onboarding review, and admin operations working with on-device persistence.",
                href: "/resources/device-workflow",
                cta: "Read the device workflow"
            )
        )
    }

    private func publicPage(slug: String, catalog: Bool) -> PublicPageResponse {
        let title: String
        let summary: String
        let sections: [PageSectionResponse]

        switch slug {
        case "store-setup":
            title = "Store setup"
            summary = "Create a store account, configure reward rules, and manage invites locally."
            sections = [
                PageSectionResponse(title: "Store accounts", body: "Store signups create a local store owner and a matching store record on this device."),
                PageSectionResponse(title: "Items and rewards", body: "Each store item has a point value that is stored on-device and used during QR scanning."),
                PageSectionResponse(title: "Invites", body: "Member signup requires a valid local invite code tied to a store.")
            ]
        case "member-rewards":
            title = "Member rewards"
            summary = "Members can view balances, redeem rewards, and show a QR payload using on-device data."
            sections = [
                PageSectionResponse(title: "Balances", body: "Point totals are derived from local transaction history per store."),
                PageSectionResponse(title: "Rewards", body: "Reward availability follows each store's local threshold and reward label."),
                PageSectionResponse(title: "QR", body: "Member QR payloads keep the same format: member:<uuid>.")
            ]
        case "admin-sandbox":
            title = "Admin overview"
            summary = "The admin console operates on demo users, stores, invites, leads, and onboarding requests stored on this device."
            sections = [
                PageSectionResponse(title: "Safety", body: "Destructive actions still require reasons so local audit history stays understandable."),
                PageSectionResponse(title: "Audit trail", body: "Admin actions write local audit entries you can review in detail views.")
            ]
        case "demo-credentials":
            title = "Demo credentials"
            summary = "Use the seeded accounts on first launch to explore every role."
            sections = [
                PageSectionResponse(title: "Admin", body: "Email: admin@anexcial.local\nPassword: Admin123!"),
                PageSectionResponse(title: "Store", body: "Email: store@anexcial.local\nPassword: Store123!"),
                PageSectionResponse(title: "Member", body: "Email: member@anexcial.local\nPassword: Member123!")
            ]
        case "manual-qr":
            title = "Manual QR fallback"
            summary = "The simulator can test member lookup by typing the payload directly."
            sections = [
                PageSectionResponse(title: "Payload format", body: "Use member:<uuid> in the scan form."),
                PageSectionResponse(title: "Demo member", body: "The seeded member payload is shown inside the member QR screen after sign-in.")
            ]
        case "device-workflow", "offline-workflow":
            title = "Device workflow"
            summary = "This demo keeps loyalty flows available using data stored on the current device."
            sections = [
                PageSectionResponse(title: "Persistence", body: "Transactions, invites, and admin actions are written to local storage for this session."),
                PageSectionResponse(title: "Public pages", body: "Marketing and help content is served from bundled mock responses.")
            ]
        default:
            title = catalog ? "Catalog resource" : "Resource"
            summary = "This content is served from bundled data on this device."
            sections = [PageSectionResponse(title: "On-device content", body: "Public pages load from local mock responses while you explore the app.")]
        }

        return PublicPageResponse(eyebrow: catalog ? "Catalog" : "Resource", title: title, summary: summary, sections: sections)
    }

    private func privacyPage() -> PublicPageResponse {
        PublicPageResponse(
            eyebrow: "Policy",
            title: "Privacy policy",
            summary: "This demo stores data on-device for testing only.",
            sections: [
                PageSectionResponse(title: "Local storage", body: "Users, stores, invites, and transaction history are stored only on this device."),
                PageSectionResponse(title: "No remote sync", body: "This build does not send loyalty data to Django, Stripe, or mail services.")
            ]
        )
    }

    private func termsPage() -> PublicPageResponse {
        PublicPageResponse(
            eyebrow: "Policy",
            title: "Terms",
            summary: "This local-only build is intended for demo and evaluation.",
            sections: [
                PageSectionResponse(title: "Scope", body: "Billing, email, and backend operations are intentionally omitted in this mode."),
                PageSectionResponse(title: "Device-only", body: "Data remains on the current device unless the app is removed or storage is cleared.")
            ]
        )
    }

    private func localStatus() -> StatusResponse {
        StatusResponse(
            ok: true,
            service: "anexcial-ios-local",
            environment: "local",
            release_id: "ios-local-demo",
            request_id: nil,
            database: StatusDatabaseResponse(ok: true, engine: "local-file-store", error: nil),
            email: StatusEmailResponse(backend: "disabled", configured: false),
            stripe: StatusStripeResponse(checkout_ready: false, webhook_ready: false, portal_ready: false),
            error_tracking: StatusErrorTrackingResponse(configured: false, environment: "local"),
            checks: StatusChecksResponse(debug_disabled: false, secure_ssl_redirect: false, session_cookie_secure: false, csrf_cookie_secure: false, allowed_hosts_configured: true, app_base_url_configured: true, postgres_expected: false)
        )
    }

    private func localConsultationResponse(body: [String: Any]) throws -> ConsultationResponse {
        let lead = LocalConsultationLead(
            id: nextConsultationLeadId(),
            plan: string(body["plan"]).ifEmpty("growth"),
            businessName: string(body["business_name"]).ifEmpty("Local business"),
            contactName: string(body["contact_name"]).ifEmpty("Local contact"),
            email: string(body["email"]),
            locationCount: max(int(body["location_count"]), 1),
            launchIntent: string(body["launch_intent"]).ifEmpty("launch-soon"),
            notes: string(body["notes"]),
            wantsBooking: bool(body["wants_booking"], default: true),
            createdAt: Date()
        )
        state.consultationLeads.append(lead)
        save()
        return ConsultationResponse(ok: true, lead_id: lead.id, booking_url: "https://anexcial.local/book", booking_embed_url: "https://anexcial.local/book/embed", should_book: lead.wantsBooking)
    }

    private func localPricingPlans() -> [PricingPlanResponse] {
        let annualSavingsNote = "Two months free compared to paying monthly when billed annually."
        return [
            PricingPlanResponse(
                slug: "starter",
                name: "Starter",
                monthly_price: "$29",
                monthly_period: "CAD / month",
                annual_price: "$290",
                annual_period: "CAD / year",
                badge: "",
                highlight: false,
                description: "Explore the app with one store and on-device demo data.",
                features: ["Demo data", "Member QR", "Invite signup"],
                cta_label: "Book consultation",
                cta_href: "/consultation/starter",
                cta_event: "consultation",
                billing_note: "Billing disabled in local mode.",
                annual_note: annualSavingsNote
            ),
            PricingPlanResponse(
                slug: "growth",
                name: "Growth",
                monthly_price: "$79",
                monthly_period: "CAD / month",
                annual_price: "$790",
                annual_period: "CAD / year",
                badge: "Recommended",
                highlight: true,
                description: "Best setup for exploring store and admin flows together on one device.",
                features: ["Store items", "Onboarding review", "Admin invites"],
                cta_label: "Book consultation",
                cta_href: "/consultation/growth",
                cta_event: "consultation",
                billing_note: "Billing is skipped here.",
                annual_note: annualSavingsNote
            ),
            PricingPlanResponse(
                slug: "enterprise",
                name: "Enterprise",
                monthly_price: "$299",
                monthly_period: "CAD / month",
                annual_price: "$2990",
                annual_period: "CAD / year",
                badge: "",
                highlight: false,
                description: "Reserved for larger mock setups with on-device operations only.",
                features: ["Admin controls", "Audit log", "On-device persistence"],
                cta_label: "Book consultation",
                cta_href: "/consultation/enterprise",
                cta_event: "consultation",
                billing_note: "No remote provisioning.",
                annual_note: annualSavingsNote
            )
        ]
    }

    private func localSubscriptionInfo(store: LocalStore) -> StoreSubscriptionInfoResponse {
        let usage = SubscriptionUsageResponse(
            active_invites: state.invites.filter { $0.storeId == store.id && $0.isActive }.count,
            active_items: state.items.filter { $0.storeId == store.id && $0.isActive }.count
        )
        return StoreSubscriptionInfoResponse(
            plan_slug: store.planSlug,
            plan_label: "Demo plan",
            billing_status: store.billingStatus,
            status_label: "On-device",
            access_active: true,
            cancel_at_period_end: false,
            current_period_start: isoFormatter.string(from: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()),
            current_period_end: isoFormatter.string(from: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()),
            stripe_customer_id: "",
            stripe_subscription_id: "",
            last_webhook_event_id: "",
            last_webhook_at: nil,
            last_webhook_created_at: nil,
            active_invites_limit: 999,
            item_limit: 999,
            analytics_level: "local",
            usage: usage,
            over_limit: SubscriptionOverLimitResponse(invites: false, items: false),
            recommended_upgrade_plan: ""
        )
    }

    private func requireStore(for storeUser: LocalUser) throws -> LocalStore {
        guard let storeId = storeUser.storeId, let store = state.stores.first(where: { $0.id == storeId }) else {
            throw APIError.http(status: 404, message: "Store account is not linked to a store.")
        }
        return store
    }

    private func ensureMembership(storeId: Int, memberId: Int) {
        guard !state.memberships.contains(where: { $0.storeId == storeId && $0.memberUserId == memberId }) else { return }
        state.memberships.append(LocalMembership(storeId: storeId, memberUserId: memberId, joinedAt: Date()))
    }

    private func memberHistory(storeId: Int, memberId: Int) -> [HistoryEntry] {
        state.transactions
            .filter { $0.storeId == storeId && $0.memberUserId == memberId }
            .sorted { $0.createdAt > $1.createdAt }
            .map { HistoryEntry(date: shortDateFormatter.string(from: $0.createdAt), item: $0.item, points: $0.points) }
    }

    private func pointsTotal(storeId: Int, memberId: Int) -> Int {
        state.transactions.filter { $0.storeId == storeId && $0.memberUserId == memberId }.reduce(0) { $0 + $1.points }
    }

    private func memberFromPayload(_ payload: String) -> LocalUser? {
        guard payload.hasPrefix("member:") else { return nil }
        let uuid = payload.replacingOccurrences(of: "member:", with: "").lowercased()
        return state.users.first { $0.role == "member" && $0.memberUUID?.lowercased() == uuid && $0.isActive }
    }

    private func token(for userId: Int) -> String { "local-user-\(userId)" }

    private func uniqueUsername(from email: String) -> String {
        let base = email.split(separator: "@").first.map(String.init)?.lowercased() ?? "user"
        var candidate = base.replacingOccurrences(of: ".", with: "_")
        var suffix = 1
        while state.users.contains(where: { $0.username == candidate }) {
            suffix += 1
            candidate = "\(base)_\(suffix)"
        }
        return candidate
    }

    private func owner(for store: LocalStore) -> LocalUser {
        state.users.first(where: { $0.id == store.ownerUserId }) ?? LocalUser(id: 0, username: "Unknown", email: "unknown@anexcial.local", password: "", role: "store", isActive: true, storeId: store.id, memberUUID: nil, createdAt: store.createdAt)
    }

    private func storeName(for id: Int) -> String {
        state.stores.first(where: { $0.id == id })?.name ?? "Unknown store"
    }

    private func storeName(_ id: Int) -> String? {
        state.stores.first(where: { $0.id == id })?.name
    }

    private func adminUserRow(for user: LocalUser) -> AdminUserRowResponse {
        let store = user.storeId.flatMap { id in state.stores.first(where: { $0.id == id }) }
        return AdminUserRowResponse(id: user.id, username: user.username, email: user.email, role: user.role, is_active: user.isActive, store_id: store?.id, store_name: store?.name ?? "", store_active: store?.isActive, date_joined: isoFormatter.string(from: user.createdAt))
    }

    private func adminStoreDashboardRow(for store: LocalStore) -> AdminDashboardStoreResponse {
        let owner = owner(for: store)
        return AdminDashboardStoreResponse(id: store.id, name: store.name, owner: owner.username, is_active: store.isActive, member_count: state.memberships.filter { $0.storeId == store.id }.count, plan_label: "Demo plan", status_label: "On-device")
    }

    private func adminStoreRow(for store: LocalStore) -> AdminStoreRowResponse {
        let owner = owner(for: store)
        let txs = state.transactions.filter { $0.storeId == store.id }
        return AdminStoreRowResponse(
            id: store.id,
            name: store.name,
            owner: owner.username,
            owner_email: owner.email,
            reward_threshold: store.rewardThreshold,
            reward_label: store.rewardLabel,
            is_active: store.isActive,
            item_count: state.items.filter { $0.storeId == store.id }.count,
            invite_count: state.invites.filter { $0.storeId == store.id }.count,
            member_count: state.memberships.filter { $0.storeId == store.id }.count,
            last_activity: txs.sorted { $0.createdAt > $1.createdAt }.first.map { isoFormatter.string(from: $0.createdAt) },
            subscription_info: localSubscriptionInfo(store: store),
            onboarding_status: state.onboarding.first(where: { $0.storeId == store.id })?.status
        )
    }

    private func adminInviteRow(for invite: LocalInvite) -> AdminInviteRowResponse {
        AdminInviteRowResponse(
            id: invite.id,
            code: invite.code,
            store_id: invite.storeId,
            store_name: storeName(for: invite.storeId),
            is_active: invite.isActive,
            is_usable: invite.isUsable(referenceDate: Date()),
            max_uses: invite.maxUses,
            uses_count: invite.usesCount,
            expires_at: invite.expiresAt.map { shortDateFormatter.string(from: $0) },
            created_by: invite.createdByUserId.flatMap { id in state.users.first(where: { $0.id == id })?.username },
            created_at: isoFormatter.string(from: invite.createdAt)
        )
    }

    private func logs(for targetType: String, id: Int) -> [AdminLogResponse] {
        state.adminLogs.filter { $0.targetType == targetType && $0.targetId == id }.sorted { $0.createdAt > $1.createdAt }.map { $0.response(dateFormatter: isoFormatter) }
    }

    private func appendLog(summary: String, actionKey: String, reason: String, targetType: String, targetId: Int, actor: String) {
        state.adminLogs.append(LocalAdminLog(id: nextAdminLogId(), summary: summary, actionKey: actionKey, reason: reason, targetType: targetType, targetId: targetId, actor: actor, createdAt: Date()))
    }

    private func nextUserId() -> Int { (state.users.map(\.id).max() ?? 0) + 1 }
    private func nextStoreId() -> Int { (state.stores.map(\.id).max() ?? 0) + 1 }
    private func nextInviteId() -> Int { (state.invites.map(\.id).max() ?? 0) + 1 }
    private func nextItemId() -> Int { (state.items.map(\.id).max() ?? 0) + 1 }
    private func nextTransactionId() -> Int { (state.transactions.map(\.id).max() ?? 0) + 1 }
    private func nextOnboardingId() -> Int { (state.onboarding.map(\.id).max() ?? 0) + 1 }
    private func nextConsultationLeadId() -> Int { (state.consultationLeads.map(\.id).max() ?? 0) + 1 }
    private func nextAdminLogId() -> Int { (state.adminLogs.map(\.id).max() ?? 0) + 1 }

    private func string(_ value: Any?) -> String {
        switch value {
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let number as NSNumber:
            return number.stringValue
        default:
            return ""
        }
    }

    private func int(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let string as String:
            return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        case let number as NSNumber:
            return number.intValue
        default:
            return 0
        }
    }

    private func bool(_ value: Any?, default defaultValue: Bool) -> Bool {
        switch value {
        case let bool as Bool:
            return bool
        case let string as String:
            switch string.lowercased() {
            case "true", "1", "yes":
                return true
            case "false", "0", "no":
                return false
            default:
                return defaultValue
            }
        case let number as NSNumber:
            return number.boolValue
        default:
            return defaultValue
        }
    }

    private func dateFromDayString(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return shortDateFormatter.date(from: String(value.prefix(10)))
    }

    private static func loadState(decoder: JSONDecoder) -> LocalAppState? {
        guard let data = try? Data(contentsOf: storageURL()) else { return nil }
        return try? decoder.decode(LocalAppState.self, from: data)
    }

    private static func saveState(_ state: LocalAppState, encoder: JSONEncoder) {
        guard let data = try? encoder.encode(state) else { return }
        try? FileManager.default.createDirectory(at: storageURL().deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storageURL(), options: .atomic)
    }

    private static func storageURL() -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("anexcial-local-state.json")
    }
}

private struct LocalRequest {
    let path: String
    let method: String
    let query: [String: String]
    let body: [String: Any]

    init(path: String, method: String, bodyData: Data?) throws {
        self.method = method.uppercased()
        let rawURL = URL(string: path, relativeTo: APIClient.baseURL)
        let components = rawURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: true) }
        // Resolved absolute paths include the "/api/" segment from baseURL, but LocalAppService routes
        // match API-relative paths like "public/bootstrap/".
        var normalizedPath = (components?.path ?? path).trimmingLeadingSlash()
        if normalizedPath.hasPrefix("api/") {
            normalizedPath = String(normalizedPath.dropFirst(4))
        }
        if !normalizedPath.isEmpty, !normalizedPath.hasSuffix("/") {
            normalizedPath += "/"
        }
        self.path = normalizedPath
        self.query = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        if let bodyData, !bodyData.isEmpty {
            let object = try JSONSerialization.jsonObject(with: bodyData)
            self.body = object as? [String: Any] ?? [:]
        } else {
            self.body = [:]
        }
    }

    func trailingInt(after prefix: String) throws -> Int {
        let remainder = path.replacingOccurrences(of: prefix, with: "")
        let normalized = remainder.trimmingSlashes()
        let target = normalized.components(separatedBy: "/").first ?? normalized
        guard let value = Int(target) else {
            throw APIError.invalidURL(path)
        }
        return value
    }
}

private struct LocalAppState: Codable {
    var users: [LocalUser]
    var stores: [LocalStore]
    var memberships: [LocalMembership]
    var invites: [LocalInvite]
    var items: [LocalStoreItem]
    var transactions: [LocalTransaction]
    var onboarding: [LocalOnboarding]
    var consultationLeads: [LocalConsultationLead]
    var adminLogs: [LocalAdminLog]

    static func seeded() -> LocalAppState {
        let createdAt = Date()
        let admin = LocalUser(id: 1, username: "admin", email: "admin@anexcial.local", password: "Admin123!", role: "admin", isActive: true, storeId: nil, memberUUID: nil, createdAt: createdAt)
        let storeOwner = LocalUser(id: 2, username: "brew_bean_owner", email: "store@anexcial.local", password: "Store123!", role: "store", isActive: true, storeId: 1, memberUUID: nil, createdAt: createdAt)
        let member = LocalUser(id: 3, username: "demo_member", email: "member@anexcial.local", password: "Member123!", role: "member", isActive: true, storeId: nil, memberUUID: "8f0ef7e2-93a3-4e31-8a60-8dd3019899c2", createdAt: createdAt)
        let store = LocalStore(id: 1, ownerUserId: 2, name: "Brew & Bean", rewardThreshold: 100, rewardLabel: "Free handcrafted drink", isActive: true, createdAt: createdAt, billingStatus: "local", planSlug: "sandbox")
        let items = [
            LocalStoreItem(id: 1, storeId: 1, name: "Signature latte", points: 15, isActive: true, createdAt: createdAt),
            LocalStoreItem(id: 2, storeId: 1, name: "Pastry pair", points: 10, isActive: true, createdAt: createdAt)
        ]
        let transactions = [
            LocalTransaction(id: 1, storeId: 1, memberUserId: 3, createdByUserId: 2, type: "award", points: 15, item: "Signature latte", createdAt: createdAt.addingTimeInterval(-86400 * 3)),
            LocalTransaction(id: 2, storeId: 1, memberUserId: 3, createdByUserId: 2, type: "award", points: 10, item: "Pastry pair", createdAt: createdAt.addingTimeInterval(-86400 * 2)),
            LocalTransaction(id: 3, storeId: 1, memberUserId: 3, createdByUserId: 2, type: "award", points: 20, item: "Weekend bonus", createdAt: createdAt.addingTimeInterval(-86400))
        ]
        let onboarding = [
            LocalOnboarding(id: 1, storeId: 1, businessName: "Brew & Bean", contactEmail: "store@anexcial.local", notes: "Need quick setup review for local demo mode.", status: "PENDING", createdAt: createdAt, reviewedAt: nil, reviewedBy: nil)
        ]
        let invites = [
            LocalInvite(id: 1, storeId: 1, code: "WELCOME10", maxUses: 50, usesCount: 1, isActive: true, expiresAt: nil, createdAt: createdAt, createdByUserId: 2)
        ]
        let leads = [
            LocalConsultationLead(id: 1, plan: "growth", businessName: "Bean & Bloom", contactName: "Noor Ellis", email: "noor@example.local", locationCount: 2, launchIntent: "launch-soon", notes: "Interested in the local-first demo before rollout.", wantsBooking: true, createdAt: createdAt)
        ]
        let logs = [
            LocalAdminLog(id: 1, summary: "Seeded demo data.", actionKey: "sandbox.seeded", reason: "", targetType: "system", targetId: 0, actor: "system", createdAt: createdAt)
        ]

        return LocalAppState(
            users: [admin, storeOwner, member],
            stores: [store],
            memberships: [LocalMembership(storeId: 1, memberUserId: 3, joinedAt: createdAt)],
            invites: invites,
            items: items,
            transactions: transactions,
            onboarding: onboarding,
            consultationLeads: leads,
            adminLogs: logs
        )
    }
}

private struct LocalUser: Codable {
    var id: Int
    var username: String
    var email: String
    var password: String
    var role: String
    var isActive: Bool
    var storeId: Int?
    var memberUUID: String?
    var createdAt: Date

    var response: UserResponse {
        UserResponse(id: id, username: username, email: email, role: role)
    }
}

private struct LocalStore: Codable {
    var id: Int
    var ownerUserId: Int
    var name: String
    var rewardThreshold: Int
    var rewardLabel: String
    var isActive: Bool
    var createdAt: Date
    var billingStatus: String
    var planSlug: String

    var info: StoreInfo {
        StoreInfo(id: id, name: name, reward_threshold: rewardThreshold, reward_label: rewardLabel, is_active: isActive)
    }
}

private struct LocalMembership: Codable {
    var storeId: Int
    var memberUserId: Int
    var joinedAt: Date
}

private struct LocalInvite: Codable {
    var id: Int
    var storeId: Int
    var code: String
    var maxUses: Int
    var usesCount: Int
    var isActive: Bool
    var expiresAt: Date?
    var createdAt: Date
    var createdByUserId: Int?

    func isUsable(referenceDate: Date) -> Bool {
        isActive && usesCount < maxUses && (expiresAt == nil || expiresAt! >= referenceDate)
    }

    func inviteCodeResponse(referenceDate: Date, dateFormatter: DateFormatter, dateTimeFormatter: ISO8601DateFormatter) -> InviteCodeResponse {
        let status: String
        if !isActive {
            status = "Inactive"
        } else if usesCount >= maxUses {
            status = "Used up"
        } else if let expiresAt, expiresAt < referenceDate {
            status = "Expired"
        } else {
            status = "Active"
        }
        return InviteCodeResponse(id: id, code: code, status: status, max_uses: maxUses, uses_count: usesCount, note: isUsable(referenceDate: referenceDate) ? "Ready for member signup on this device." : "Unavailable in this demo build.", expires: expiresAt.map { dateFormatter.string(from: $0) } ?? "Never", created_at: dateTimeFormatter.string(from: createdAt))
    }
}

private struct LocalStoreItem: Codable {
    var id: Int
    var storeId: Int
    var name: String
    var points: Int
    var isActive: Bool
    var createdAt: Date

    func response(dateFormatter: ISO8601DateFormatter) -> StoreItemResponse {
        StoreItemResponse(id: id, name: name, points: points, is_active: isActive, created_at: dateFormatter.string(from: createdAt))
    }
}

private struct LocalTransaction: Codable {
    var id: Int
    var storeId: Int
    var memberUserId: Int
    var createdByUserId: Int?
    var type: String
    var points: Int
    var item: String
    var createdAt: Date
}

private struct LocalOnboarding: Codable {
    var id: Int
    var storeId: Int
    var businessName: String
    var contactEmail: String
    var notes: String
    var status: String
    var createdAt: Date
    var reviewedAt: Date?
    var reviewedBy: String?

    static func empty(storeId: Int, storeName: String, email: String) -> LocalOnboarding {
        LocalOnboarding(id: 0, storeId: storeId, businessName: storeName, contactEmail: email, notes: "", status: "DRAFT", createdAt: Date(), reviewedAt: nil, reviewedBy: nil)
    }

    func response(dateFormatter: ISO8601DateFormatter) -> OnboardingRequestResponse {
        OnboardingRequestResponse(id: id == 0 ? nil : id, business_name: businessName, contact_email: contactEmail, notes: notes, status: status, created_at: dateFormatter.string(from: createdAt), reviewed_at: reviewedAt.map { dateFormatter.string(from: $0) }, reviewed_by: reviewedBy)
    }

    func adminItem(storeName: String, dateFormatter: ISO8601DateFormatter) -> AdminOnboardingItem {
        AdminOnboardingItem(id: id, business_name: businessName, contact_email: contactEmail, notes: notes, status: status, store_id: storeId, store_name: storeName, reviewed_by: reviewedBy, reviewed_at: reviewedAt.map { dateFormatter.string(from: $0) }, created_at: dateFormatter.string(from: createdAt))
    }
}

private struct LocalConsultationLead: Codable {
    var id: Int
    var plan: String
    var businessName: String
    var contactName: String
    var email: String
    var locationCount: Int
    var launchIntent: String
    var notes: String
    var wantsBooking: Bool
    var createdAt: Date

    func response(dateFormatter: ISO8601DateFormatter) -> AdminConsultationLeadResponse {
        AdminConsultationLeadResponse(id: id, plan: plan, business_name: businessName, contact_name: contactName, email: email, location_count: locationCount, launch_intent: launchIntent, notes: notes, wants_booking: wantsBooking, created_at: dateFormatter.string(from: createdAt))
    }

    func summary(dateFormatter: ISO8601DateFormatter) -> AdminLeadSummaryResponse {
        AdminLeadSummaryResponse(id: id, business_name: businessName, contact_name: contactName, plan: plan, created_at: dateFormatter.string(from: createdAt))
    }
}

private struct LocalAdminLog: Codable {
    var id: Int
    var summary: String
    var actionKey: String
    var reason: String
    var targetType: String
    var targetId: Int
    var actor: String
    var createdAt: Date

    func response(dateFormatter: ISO8601DateFormatter) -> AdminLogResponse {
        AdminLogResponse(id: id, summary: summary, action_key: actionKey, reason: reason, target_type: targetType, target_id: targetId, actor: actor, created_at: dateFormatter.string(from: createdAt))
    }
}

private extension String {
    func trimmingLeadingSlash() -> String {
        hasPrefix("/") ? String(dropFirst()) : self
    }

    func trimmingSlashes() -> String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
