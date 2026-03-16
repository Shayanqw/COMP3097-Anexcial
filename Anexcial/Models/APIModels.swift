import Foundation

struct UserResponse: Codable {
    let id: Int
    let username: String
    let email: String
    let role: String
}

struct LoginResponse: Codable {
    let token: String
    let user: UserResponse
}

struct StoreCard: Codable, Identifiable {
    let id: Int
    let name: String
    let points: Int
    let threshold: Int
    let reward_label: String
    let reward_available: Bool
}

struct StoreDetail: Codable {
    let id: Int
    let name: String
    let points: Int
    let reward_threshold: Int
    let reward_label: String
    let reward_available: Bool
    let history: [HistoryEntry]
}

struct HistoryEntry: Codable {
    let date: String
    let item: String
    let points: Int
}

struct MemberQRResponse: Codable {
    let member_uuid: String
    let qr_payload: String
}

struct StoreItemResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let points: Int
}

struct DashboardResponse: Codable {
    let store: StoreInfo
    let kpi: KPI
    let onboarding_status: String
    let items: [StoreItemResponse]
}

struct StoreInfo: Codable {
    let id: Int
    let name: String
    let reward_threshold: Int
    let reward_label: String
}

struct KPI: Codable {
    let members: Int
    let points_week: Int
    let redeems_week: Int
}

struct InviteCodeResponse: Codable, Identifiable {
    let id: Int
    let code: String
    let status: String
    let max_uses: Int
    let uses_count: Int
    let note: String
    let expires: String
    let created_at: String?
}

struct OnboardingRequestResponse: Codable {
    let id: Int?
    let business_name: String?
    let contact_email: String?
    let notes: String?
    let status: String?
    let created_at: String?
}

struct AdminOnboardingItem: Codable, Identifiable {
    let id: Int
    let business_name: String
    let contact_email: String
    let notes: String?
    let status: String
    let store_name: String
    let created_at: String?
}

struct MemberLookupResponse: Codable {
    let ok: Bool
    let username: String?
    let member_uuid: String?
    let error: String?
}

struct SuccessResponse: Codable {
    let success: Bool?
    let message: String?
    let detail: String?
}
