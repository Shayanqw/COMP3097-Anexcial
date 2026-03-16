import SwiftUI

struct AdminFlowView: View {
    @EnvironmentObject var auth: AuthState
    @State private var requests: [AdminOnboardingItem] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(Theme.danger)
                        .padding()
                } else {
                    List(requests) { req in
                        AdminRequestRow(request: req) {
                            Task { await load() }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.background)
            .safeAreaInset(edge: .top, spacing: 0) {
                RoleBadge(role: roleLabel)
            }
            .navigationTitle("Store onboarding review")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        auth.logout()
                    }
                }
            }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private var roleLabel: String {
        guard let role = auth.currentUser?.role else { return "Admin" }
        switch role {
        case "admin": return "Admin"
        case "store": return "Store"
        default: return "Member"
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient()
            let loaded: [AdminOnboardingItem] = try await client.request("admin/onboarding-requests/")
            requests = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct AdminRequestRow: View {
    let request: AdminOnboardingItem
    let onUpdated: () -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.business_name)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(request.status)
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            Text(request.contact_email)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if request.status == "PENDING" {
                HStack(spacing: 12) {
                    Button("Approve") {
                        Task { await review(action: "approve") }
                    }
                    .foregroundStyle(Theme.success)
                    Button("Reject") {
                        Task { await review(action: "reject") }
                    }
                    .foregroundStyle(Theme.danger)
                }
            }
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(.vertical, 8)
    }

    private func review(action: String) async {
        errorMessage = nil
        struct Body: Encodable {
            let action: String
        }
        do {
            let _: SuccessResponse = try await APIClient().request("admin/onboarding-requests/\(request.id)/review/", method: "POST", body: Body(action: action))
            onUpdated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
