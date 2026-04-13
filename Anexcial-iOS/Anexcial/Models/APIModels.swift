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

struct MeResponse: Codable {
    let user: UserResponse
}

struct SuccessResponse: Codable {
    let ok: Bool?
    let success: Bool?
    let message: String?
    let detail: String?
}

struct ThemePaletteResponse: Codable {
    let background: String
    let surface: String
    let text: String
    let muted: String
    let accent: String
    let success: String
    let danger: String
}

struct PublicHomeResponse: Codable {
    let eyebrow: String
    let headline: String
    let body: String
    let tagline: String
}

struct LinkCardResponse: Codable, Identifiable {
    let title: String
    let href: String
    let description: String?
    let tag: String?
    let external: Bool?

    var id: String { href }
}

struct SocialLinkResponse: Codable, Identifiable {
    let label: String
    let href: String
    let icon: String

    var id: String { label }
}

struct MarketingSiteResponse: Codable {
    let tagline: String
    let support_email: String
    let contact_email: String
    let analytics_notice: String
    let google_calendar_url: String
    let google_calendar_embed_url: String
    let stripe_links: [String: String]
    let social_links: [SocialLinkResponse]
}

struct PricingPlanResponse: Codable, Identifiable {
    let slug: String
    let name: String
    let monthly_price: String
    let monthly_period: String
    let annual_price: String
    let annual_period: String
    let badge: String
    let highlight: Bool
    let description: String
    let features: [String]
    let cta_label: String
    let cta_href: String
    let cta_event: String
    let billing_note: String
    let annual_note: String

    var id: String { slug }
}

struct ComparisonRowResponse: Codable, Identifiable {
    let label: String
    let values: [String]

    var id: String { label }
}

struct ResourceColumnResponse: Codable, Identifiable {
    let title: String
    let items: [LinkCardResponse]

    var id: String { title }
}

struct FeaturedResourceResponse: Codable {
    let eyebrow: String
    let title: String
    let description: String
    let href: String
    let cta: String
}

struct PublicBootstrapResponse: Codable {
    let app_name: String
    let theme: ThemePaletteResponse
    let home: PublicHomeResponse
    let marketing_site: MarketingSiteResponse
    let pricing_plans: [PricingPlanResponse]
    let comparison_rows: [ComparisonRowResponse]
    let catalog_links: [LinkCardResponse]
    let resource_columns: [ResourceColumnResponse]
    let featured_resource: FeaturedResourceResponse
}

struct PageSectionResponse: Codable, Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

struct PublicPageResponse: Codable {
    let eyebrow: String
    let title: String
    let summary: String
    let sections: [PageSectionResponse]
}

struct StatusDatabaseResponse: Codable {
    let ok: Bool
    let engine: String
    let error: String?
}

struct StatusEmailResponse: Codable {
    let backend: String
    let configured: Bool
}

struct StatusStripeResponse: Codable {
    let checkout_ready: Bool
    let webhook_ready: Bool
    let portal_ready: Bool
}

struct StatusErrorTrackingResponse: Codable {
    let configured: Bool
    let environment: String
}

struct StatusChecksResponse: Codable {
    let debug_disabled: Bool
    let secure_ssl_redirect: Bool
    let session_cookie_secure: Bool
    let csrf_cookie_secure: Bool
    let allowed_hosts_configured: Bool
    let app_base_url_configured: Bool
    let postgres_expected: Bool
}

struct StatusResponse: Codable {
    let ok: Bool
    let service: String
    let environment: String
    let release_id: String
    let request_id: String?
    let database: StatusDatabaseResponse?
    let email: StatusEmailResponse?
    let stripe: StatusStripeResponse?
    let error_tracking: StatusErrorTrackingResponse?
    let checks: StatusChecksResponse?
}

struct ConsultationResponse: Codable {
    let ok: Bool
    let lead_id: Int
    let booking_url: String
    let booking_embed_url: String
    let should_book: Bool
}

struct StoreCard: Codable, Identifiable {
    let id: Int
    let name: String
    let points: Int
    let threshold: Int
    let reward_label: String
    let reward_available: Bool
}

struct HistoryEntry: Codable, Identifiable {
    let date: String
    let item: String
    let points: Int

    var id: String { "\(date)-\(item)-\(points)" }
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

struct MemberRedeemResponse: Codable {
    let ok: Bool
    let message: String
    let store: StoreDetail
}

struct MemberQRResponse: Codable {
    let member_uuid: String
    let qr_payload: String
    let qr_data_uri: String?
}

struct StoreItemResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let points: Int
    let is_active: Bool?
    let created_at: String?
}

struct StoreInfo: Codable {
    let id: Int
    let name: String
    let reward_threshold: Int
    let reward_label: String
    let is_active: Bool?
}

struct KPI: Codable {
    let members: Int
    let points_week: Int
    let redeems_week: Int
}

struct SubscriptionUsageResponse: Codable {
    let active_invites: Int
    let active_items: Int
}

struct SubscriptionOverLimitResponse: Codable {
    let invites: Bool
    let items: Bool
}

struct StoreSubscriptionInfoResponse: Codable {
    let plan_slug: String
    let plan_label: String
    let billing_status: String
    let status_label: String
    let access_active: Bool
    let cancel_at_period_end: Bool
    let current_period_start: String?
    let current_period_end: String?
    let stripe_customer_id: String
    let stripe_subscription_id: String
    let last_webhook_event_id: String
    let last_webhook_at: String?
    let last_webhook_created_at: String?
    let active_invites_limit: Int
    let item_limit: Int
    let analytics_level: String
    let usage: SubscriptionUsageResponse
    let over_limit: SubscriptionOverLimitResponse
    let recommended_upgrade_plan: String
}

struct DashboardResponse: Codable {
    let store: StoreInfo
    let kpi: KPI
    let onboarding_status: String
    let onboarding: OnboardingRequestResponse
    let items: [StoreItemResponse]
    let subscription_info: StoreSubscriptionInfoResponse
    let pricing_plans: [PricingPlanResponse]
    let store_tools_locked: Bool
}

struct StoreItemsResponse: Codable {
    let items: [StoreItemResponse]
    let rules: [String]
    let subscription_info: StoreSubscriptionInfoResponse
    let active_item_count: Int
    let recommended_upgrade_plan: String
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

struct StoreInvitesResponse: Codable {
    let invites: [InviteCodeResponse]
    let subscription_info: StoreSubscriptionInfoResponse
    let active_invites_count: Int
    let recommended_upgrade_plan: String
}

struct StoreInviteCreateResponse: Codable {
    let invite: InviteCodeResponse
    let emailed: Bool
}

struct MemberLookupResponse: Codable {
    let ok: Bool
    let username: String?
    let member_uuid: String?
    let error: String?
}

struct OnboardingRequestResponse: Codable {
    let id: Int?
    let business_name: String?
    let contact_email: String?
    let notes: String?
    let status: String?
    let created_at: String?
    let reviewed_at: String?
    let reviewed_by: String?
}

struct SimpleStoreRef: Codable, Identifiable {
    let id: Int
    let name: String
}

struct BillingEventSubscriptionResponse: Codable {
    let plan_slug: String
    let billing_status: String
}

struct BillingEventResponse: Codable, Identifiable {
    let id: Int
    let event_id: String
    let event_type: String
    let processed_at: String?
    let subscription: BillingEventSubscriptionResponse?
}

struct StoreBillingSubscriptionResponse: Codable {
    let plan_slug: String
    let billing_status: String
    let current_period_start: String?
    let current_period_end: String?
    let cancel_at_period_end: Bool
    let stripe_customer_id: String
    let stripe_subscription_id: String
}

struct BillingActionResponse: Codable, Identifiable {
    let slug: String
    let name: String
    let description: String
    let action: String
    let action_url: String
    let action_label: String

    var id: String { slug }
}

struct StoreBillingResponse: Codable {
    let store: SimpleStoreRef
    let subscription: StoreBillingSubscriptionResponse
    let subscription_info: StoreSubscriptionInfoResponse
    let billing_events: [BillingEventResponse]
    let billing_actions: [BillingActionResponse]
    let portal_url: String
    let billing_support_email: String
    let usage: SubscriptionUsageResponse
    let checkout_state: String
    let checkout_plan: String
    let pricing_plans: [PricingPlanResponse]
}

struct BillingCheckoutResponse: Codable {
    let ok: Bool
    let mode: String
    let url: String?
    let session_id: String?
    let reason: String?
    let error: String?
}

struct AdminSummaryResponse: Codable {
    let total_users: Int
    let active_stores: Int
    let members: Int
    let pending_onboarding: Int
    let active_invites: Int
    let recent_leads: Int
    let active_subscriptions: Int
}

struct AdminDashboardStoreResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let owner: String
    let is_active: Bool
    let member_count: Int
    let plan_label: String
    let status_label: String
}

struct AdminLeadSummaryResponse: Codable, Identifiable {
    let id: Int
    let business_name: String
    let contact_name: String
    let plan: String
    let created_at: String?
}

struct AdminLogResponse: Codable, Identifiable {
    let id: Int
    let summary: String
    let action_key: String
    let reason: String
    let target_type: String
    let target_id: Int
    let actor: String
    let created_at: String?
}

struct AdminDashboardResponse: Codable {
    let summary: AdminSummaryResponse
    let pending_requests: [AdminOnboardingItem]
    let recent_stores: [AdminDashboardStoreResponse]
    let recent_users: [AdminUserRowResponse]
    let recent_leads: [AdminLeadSummaryResponse]
    let recent_admin_logs: [AdminLogResponse]
}

struct AdminUserRowResponse: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let role: String
    let is_active: Bool
    let store_id: Int?
    let store_name: String
    let store_active: Bool?
    let date_joined: String?
}

struct DeleteImpactResponse: Codable {
    let member_profile_deleted: Int?
    let member_transactions_deleted: Int?
    let created_transactions_reassigned: Int?
    let reviewed_onboarding_reassigned: Int?
    let invite_creator_reassigned: Int?
    let store_deleted: Int?
    let store_name: String?
    let store_items_deleted: Int?
    let store_invites_deleted: Int?
    let store_transactions_deleted: Int?
    let store_onboarding_deleted: Int?
}

struct AdminUserDetailResponse: Codable {
    let user: AdminUserRowResponse
    let delete_warning: String
    let delete_impact: DeleteImpactResponse
    let recent_logs: [AdminLogResponse]
}

struct AdminUsersResponse: Codable {
    let users: [AdminUserRowResponse]
}

struct AdminStoreRowResponse: Codable, Identifiable {
    let id: Int
    let name: String
    let owner: String
    let owner_email: String
    let reward_threshold: Int
    let reward_label: String
    let is_active: Bool
    let item_count: Int
    let invite_count: Int
    let member_count: Int
    let last_activity: String?
    let subscription_info: StoreSubscriptionInfoResponse
    let onboarding_status: String?
}

struct AdminStoresResponse: Codable {
    let stores: [AdminStoreRowResponse]
}

struct AdminStoreDetailResponse: Codable {
    let store: AdminStoreRowResponse
    let recent_logs: [AdminLogResponse]
    let billing_events: [BillingEventResponse]
}

struct AdminInviteRowResponse: Codable, Identifiable {
    let id: Int
    let code: String
    let store_id: Int
    let store_name: String
    let is_active: Bool
    let is_usable: Bool
    let max_uses: Int
    let uses_count: Int
    let expires_at: String?
    let created_by: String?
    let created_at: String?
}

struct AdminInvitesResponse: Codable {
    let invites: [AdminInviteRowResponse]
    let stores: [SimpleStoreRef]
}

struct AdminInviteDetailResponse: Codable {
    let invite: AdminInviteRowResponse
    let recent_logs: [AdminLogResponse]
}

struct AdminMemberRowResponse: Codable, Identifiable {
    let store_id: Int
    let store_name: String
    let member_id: Int
    let username: String
    let email: String
    let total_points: Int
    let tx_count: Int
    let last_activity: String?
    let redemption_count: Int

    var id: Int { member_id }
}

struct AdminStoreMemberGroupResponse: Codable, Identifiable {
    let store: SimpleStoreRef
    let members: [AdminMemberRowResponse]

    var id: Int { store.id }
}

struct AdminMembersByStoreResponse: Codable {
    let groups: [AdminStoreMemberGroupResponse]
}

struct AdminConsultationLeadResponse: Codable, Identifiable {
    let id: Int
    let plan: String
    let business_name: String
    let contact_name: String
    let email: String
    let location_count: Int
    let launch_intent: String
    let notes: String
    let wants_booking: Bool
    let created_at: String?
}

struct AdminConsultationLeadsResponse: Codable {
    let leads: [AdminConsultationLeadResponse]
}

struct AdminOnboardingItem: Codable, Identifiable {
    let id: Int
    let business_name: String
    let contact_email: String
    let notes: String?
    let status: String
    let store_id: Int
    let store_name: String
    let reviewed_by: String?
    let reviewed_at: String?
    let created_at: String?
}

struct AdminOnboardingListResponse: Codable {
    let pending_requests: [AdminOnboardingItem]
    let history_requests: [AdminOnboardingItem]
    let recent_review_logs: [AdminLogResponse]
}

struct AdminReviewResponse: Codable {
    let request: AdminOnboardingItem
}
