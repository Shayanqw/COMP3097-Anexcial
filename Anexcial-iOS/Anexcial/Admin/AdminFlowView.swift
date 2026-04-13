import SwiftUI

struct AdminFlowView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        TabView {
            AdminDashboardTab(signOut: auth.logout)
                .tabItem { Label("Dashboard", systemImage: "rectangle.grid.2x2") }

            AdminUsersTab(signOut: auth.logout)
                .tabItem { Label("Users", systemImage: "person.3") }

            AdminStoresTab(signOut: auth.logout)
                .tabItem { Label("Stores", systemImage: "storefront") }

            AdminInvitesTab(signOut: auth.logout)
                .tabItem { Label("Invites", systemImage: "envelope.badge") }

            AdminOperationsTab(signOut: auth.logout)
                .tabItem { Label("Ops", systemImage: "wrench.and.screwdriver") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RoleBadge(role: roleLabel)
        }
        .tint(Theme.accent)
        .onAppear { UITabBar.appearance().backgroundColor = UIColor(Theme.surface) }
    }

    private var roleLabel: String {
        guard let role = auth.currentUser?.role else { return "Admin" }
        switch role {
        case "admin": return "Admin"
        case "store": return "Store"
        default: return "Member"
        }
    }
}

private struct AdminDashboardTab: View {
    let signOut: () -> Void

    @State private var dashboard: AdminDashboardResponse?
    @State private var errorMessage: String?
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let dashboard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            LazyVGrid(columns: columns, spacing: 12) {
                                AdminMetricCard(title: "Users", value: "\(dashboard.summary.total_users)")
                                AdminMetricCard(title: "Active stores", value: "\(dashboard.summary.active_stores)")
                                AdminMetricCard(title: "Members", value: "\(dashboard.summary.members)")
                                AdminMetricCard(title: "Pending review", value: "\(dashboard.summary.pending_onboarding)")
                                AdminMetricCard(title: "Active invites", value: "\(dashboard.summary.active_invites)")
                                AdminMetricCard(title: "Recent leads", value: "\(dashboard.summary.recent_leads)")
                                AdminMetricCard(title: "Subscriptions", value: "\(dashboard.summary.active_subscriptions)")
                            }

                            AdminSectionCard(title: "Pending onboarding") {
                                if dashboard.pending_requests.isEmpty {
                                    AdminEmptyState(text: "No onboarding requests are waiting for review.")
                                } else {
                                    ForEach(dashboard.pending_requests) { request in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(request.business_name)
                                                .foregroundStyle(Theme.text)
                                            Text("\(request.store_name) - \(request.contact_email)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }

                            AdminSectionCard(title: "Recent stores") {
                                if dashboard.recent_stores.isEmpty {
                                    AdminEmptyState(text: "No recent stores.")
                                } else {
                                    ForEach(dashboard.recent_stores) { store in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(store.name)
                                                .foregroundStyle(Theme.text)
                                            Text("\(store.owner) - \(store.plan_label) - \(store.status_label)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }

                            AdminSectionCard(title: "Recent users") {
                                if dashboard.recent_users.isEmpty {
                                    AdminEmptyState(text: "No recent users.")
                                } else {
                                    ForEach(dashboard.recent_users) { user in
                                        AdminUserRow(user: user)
                                    }
                                }
                            }

                            AdminSectionCard(title: "Recent consultation leads") {
                                if dashboard.recent_leads.isEmpty {
                                    AdminEmptyState(text: "No recent leads.")
                                } else {
                                    ForEach(dashboard.recent_leads) { lead in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(lead.business_name)
                                                .foregroundStyle(Theme.text)
                                            Text("\(lead.contact_name) - \(lead.plan.capitalized)")
                                                .font(.caption)
                                                .foregroundStyle(Theme.muted)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }

                            AdminSectionCard(title: "Recent admin activity") {
                                AdminLogList(logs: dashboard.recent_admin_logs)
                            }

                            Button("Sign out", role: .destructive) {
                                signOut()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Text(errorMessage ?? "Unable to load admin dashboard.")
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                        Button("Sign out", role: .destructive) {
                            signOut()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .background(Theme.background)
            .navigationTitle("Admin dashboard")
            .toolbar {
                if isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Sign out", role: .destructive) {
                            signOut()
                        }
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await APIClient().request("admin/dashboard/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminUsersTab: View {
    let signOut: () -> Void

    @State private var response: AdminUsersResponse?
    @State private var query = ""
    @State private var roleFilter = "all"
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    TextField("Search by username or email", text: $query)
                        .textInputAutocapitalization(.never)
                    Picker("Role", selection: $roleFilter) {
                        Text("All").tag("all")
                        Text("Admin").tag("admin")
                        Text("Store").tag("store")
                        Text("Member").tag("member")
                    }
                    .pickerStyle(.segmented)
                    Button("Apply filters") {
                        Task { await load() }
                    }
                }

                Section("Users") {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(response?.users ?? []) { user in
                            NavigationLink {
                                AdminUserDetailView(userId: user.id) {
                                    Task { await load() }
                                }
                            } label: {
                                AdminUserRow(user: user)
                            }
                        }

                        if (response?.users.isEmpty ?? true) {
                            AdminEmptyState(text: "No users matched this filter.")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Users")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath(
                "admin/users/",
                params: [("q", query), ("role", roleFilter == "all" ? "" : roleFilter)]
            )
            response = try await APIClient().request(path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminUserDetailView: View {
    let userId: Int
    let onUpdated: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var detail: AdminUserDetailResponse?
    @State private var selectedRole = "member"
    @State private var isActive = true
    @State private var deleteReason = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isSubmitting = false

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let detail {
                Section("Account") {
                    LabeledContent("Username", value: detail.user.username)
                    LabeledContent("Email", value: detail.user.email)
                    Picker("Role", selection: $selectedRole) {
                        Text("Member").tag("member")
                        Text("Store").tag("store")
                        Text("Admin").tag("admin")
                    }
                    Toggle("Active account", isOn: $isActive)
                    Button("Save changes") {
                        Task { await save() }
                    }
                    .disabled(isSubmitting)
                }

                Section("Delete safeguards") {
                    Text(detail.delete_warning)
                        .foregroundStyle(Theme.muted)
                    LabeledContent(
                        "Member transactions",
                        value: "\(detail.delete_impact.member_transactions_deleted ?? 0)"
                    )
                    LabeledContent(
                        "Store transactions",
                        value: "\(detail.delete_impact.store_transactions_deleted ?? 0)"
                    )
                    TextField("Required delete reason", text: $deleteReason, axis: .vertical)
                        .lineLimit(3...5)
                    Button("Delete user", role: .destructive) {
                        Task { await deleteUser() }
                    }
                    .disabled(isSubmitting || deleteReason.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                }

                Section("Recent audit history") {
                    AdminLogList(logs: detail.recent_logs)
                }
            } else {
                Text(errorMessage ?? "Unable to load user details.")
                    .foregroundStyle(Theme.danger)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("User detail")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded: AdminUserDetailResponse = try await APIClient().request("admin/users/\(userId)/")
            detail = loaded
            selectedRole = loaded.user.role
            isActive = loaded.user.is_active
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        struct Body: Encodable {
            let role: String
            let is_active: Bool
        }

        do {
            try await APIClient().requestVoid(
                "admin/users/\(userId)/",
                method: "PATCH",
                body: Body(role: selectedRole, is_active: isActive)
            )
            onUpdated()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteUser() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        struct Body: Encodable {
            let delete_reason: String
        }

        do {
            try await APIClient().requestVoid(
                "admin/users/\(userId)/",
                method: "DELETE",
                body: Body(delete_reason: deleteReason.trimmingCharacters(in: .whitespacesAndNewlines))
            )
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminStoresTab: View {
    let signOut: () -> Void

    @State private var response: AdminStoresResponse?
    @State private var query = ""
    @State private var statusFilter = "all"
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    TextField("Search by store or owner", text: $query)
                        .textInputAutocapitalization(.never)
                    Picker("Status", selection: $statusFilter) {
                        Text("All").tag("all")
                        Text("Active").tag("active")
                        Text("Inactive").tag("inactive")
                    }
                    .pickerStyle(.segmented)
                    Button("Apply filters") {
                        Task { await load() }
                    }
                }

                Section("Stores") {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(response?.stores ?? []) { store in
                            NavigationLink {
                                AdminStoreDetailView(storeId: store.id) {
                                    Task { await load() }
                                }
                            } label: {
                                AdminStoreRow(store: store)
                            }
                        }

                        if (response?.stores.isEmpty ?? true) {
                            AdminEmptyState(text: "No stores matched this filter.")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Stores")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath(
                "admin/stores/",
                params: [("q", query), ("status", statusFilter == "all" ? "" : statusFilter)]
            )
            response = try await APIClient().request(path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminStoreDetailView: View {
    let storeId: Int
    let onUpdated: () -> Void

    @State private var detail: AdminStoreDetailResponse?
    @State private var name = ""
    @State private var rewardThreshold = "100"
    @State private var rewardLabel = ""
    @State private var isActive = true
    @State private var statusReason = ""
    @State private var billingStatus = "active"
    @State private var billingReason = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isSubmitting = false

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let detail {
                Section("Store settings") {
                    LabeledContent("Owner", value: detail.store.owner)
                    LabeledContent("Owner email", value: detail.store.owner_email)
                    TextField("Store name", text: $name)
                    TextField("Reward threshold", text: $rewardThreshold)
                        .keyboardType(.numberPad)
                    TextField("Reward label", text: $rewardLabel)
                    Toggle("Store is active", isOn: $isActive)
                    TextField("Reason for activation change", text: $statusReason, axis: .vertical)
                        .lineLimit(2...4)
                    Button("Save store") {
                        Task { await saveStore() }
                    }
                    .disabled(isSubmitting)
                }

                Section("Billing override") {
                    Picker("Billing status", selection: $billingStatus) {
                        ForEach(adminBillingStatuses, id: \.value) { status in
                            Text(status.label).tag(status.value)
                        }
                    }
                    TextField("Reason for billing override", text: $billingReason, axis: .vertical)
                        .lineLimit(2...4)
                    Button("Save billing override") {
                        Task { await saveBillingOverride() }
                    }
                    .disabled(isSubmitting)
                }

                Section("Billing events") {
                    if detail.billing_events.isEmpty {
                        AdminEmptyState(text: "No billing events recorded.")
                    } else {
                        ForEach(detail.billing_events) { event in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.event_type)
                                    .foregroundStyle(Theme.text)
                                Text(event.event_id)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                    }
                }

                Section("Recent audit history") {
                    AdminLogList(logs: detail.recent_logs)
                }
            } else {
                Text(errorMessage ?? "Unable to load store details.")
                    .foregroundStyle(Theme.danger)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Store detail")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded: AdminStoreDetailResponse = try await APIClient().request("admin/stores/\(storeId)/")
            detail = loaded
            name = loaded.store.name
            rewardThreshold = "\(loaded.store.reward_threshold)"
            rewardLabel = loaded.store.reward_label
            isActive = loaded.store.is_active
            billingStatus = loaded.store.subscription_info.billing_status
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveStore() async {
        errorMessage = nil
        guard let threshold = Int(rewardThreshold), threshold > 0 else {
            errorMessage = "Reward threshold must be a positive number."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        struct Body: Encodable {
            let name: String
            let reward_threshold: Int
            let reward_label: String
            let is_active: Bool
            let status_reason: String
        }

        do {
            try await APIClient().requestVoid(
                "admin/stores/\(storeId)/",
                method: "PATCH",
                body: Body(
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    reward_threshold: threshold,
                    reward_label: rewardLabel.trimmingCharacters(in: .whitespacesAndNewlines),
                    is_active: isActive,
                    status_reason: statusReason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            onUpdated()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveBillingOverride() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        struct Body: Encodable {
            let billing_status: String
            let billing_reason: String
        }

        do {
            try await APIClient().requestVoid(
                "admin/stores/\(storeId)/billing-override/",
                method: "POST",
                body: Body(
                    billing_status: billingStatus,
                    billing_reason: billingReason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            onUpdated()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminInvitesTab: View {
    let signOut: () -> Void

    @State private var response: AdminInvitesResponse?
    @State private var query = ""
    @State private var statusFilter = "all"
    @State private var selectedStoreId: Int?
    @State private var code = ""
    @State private var maxUses = "100"
    @State private var isActive = true
    @State private var hasExpiration = false
    @State private var expiresAt = Date()
    @State private var editingInviteId: Int?
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            List {
                Section(editingInviteId == nil ? "Create invite" : "Update invite") {
                    Picker("Store", selection: $selectedStoreId) {
                        Text("Select store").tag(nil as Int?)
                        ForEach(response?.stores ?? []) { store in
                            Text(store.name).tag(store.id as Int?)
                        }
                    }
                    TextField("Invite code", text: $code)
                        .textInputAutocapitalization(.characters)
                    TextField("Max uses", text: $maxUses)
                        .keyboardType(.numberPad)
                    Toggle("Invite is active", isOn: $isActive)
                    Toggle("Set expiration date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires", selection: $expiresAt, displayedComponents: .date)
                    }
                    Button(editingInviteId == nil ? "Create invite" : "Save invite") {
                        Task { await saveInvite() }
                    }
                    .disabled(isSubmitting || selectedStoreId == nil || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if editingInviteId != nil {
                        Button("Cancel editing") {
                            resetForm()
                        }
                        .foregroundStyle(Theme.muted)
                    }
                }

                Section("Filters") {
                    TextField("Search by code or store", text: $query)
                    Picker("Status", selection: $statusFilter) {
                        Text("All").tag("all")
                        Text("Active").tag("active")
                        Text("Inactive").tag("inactive")
                    }
                    .pickerStyle(.segmented)
                    Button("Apply filters") {
                        Task { await load() }
                    }
                }

                Section("Invites") {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(response?.invites ?? []) { invite in
                            VStack(alignment: .leading, spacing: 8) {
                                NavigationLink {
                                    AdminInviteDetailView(inviteId: invite.id)
                                } label: {
                                    AdminInviteRow(invite: invite)
                                }

                                Button("Edit in form") {
                                    beginEditing(invite)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }

                        if (response?.invites.isEmpty ?? true) {
                            AdminEmptyState(text: "No invites matched this filter.")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Invites")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        signOut()
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath(
                "admin/invites/",
                params: [("q", query), ("status", statusFilter == "all" ? "" : statusFilter)]
            )
            let loaded: AdminInvitesResponse = try await APIClient().request(path)
            response = loaded
            if selectedStoreId == nil {
                selectedStoreId = loaded.stores.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveInvite() async {
        errorMessage = nil
        guard let selectedStoreId else {
            errorMessage = "Choose a store before saving."
            return
        }
        guard let uses = Int(maxUses), uses > 0 else {
            errorMessage = "Max uses must be a positive number."
            return
        }

        struct Body: Encodable {
            let store_id: Int
            let code: String
            let max_uses: Int
            let expires_at: String?
            let is_active: Bool
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let expiresValue = hasExpiration ? adminDayFormatter.string(from: expiresAt) : nil
        let body = Body(
            store_id: selectedStoreId,
            code: code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
            max_uses: uses,
            expires_at: expiresValue,
            is_active: isActive
        )

        do {
            if let editingInviteId {
                try await APIClient().requestVoid("admin/invites/\(editingInviteId)/", method: "PATCH", body: body)
            } else {
                try await APIClient().requestVoid("admin/invites/", method: "POST", body: body)
            }
            resetForm()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginEditing(_ invite: AdminInviteRowResponse) {
        editingInviteId = invite.id
        selectedStoreId = invite.store_id
        code = invite.code
        maxUses = "\(invite.max_uses)"
        isActive = invite.is_active
        if let expiresString = invite.expires_at, let date = adminDayFormatter.date(from: String(expiresString.prefix(10))) {
            hasExpiration = true
            expiresAt = date
        } else {
            hasExpiration = false
            expiresAt = Date()
        }
    }

    private func resetForm() {
        editingInviteId = nil
        code = ""
        maxUses = "100"
        isActive = true
        hasExpiration = false
        expiresAt = Date()
    }
}

private struct AdminInviteDetailView: View {
    let inviteId: Int

    @State private var detail: AdminInviteDetailResponse?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let detail {
                Section("Invite") {
                    LabeledContent("Code", value: detail.invite.code)
                    LabeledContent("Store", value: detail.invite.store_name)
                    LabeledContent("Usage", value: "\(detail.invite.uses_count)/\(detail.invite.max_uses)")
                    LabeledContent("Active", value: detail.invite.is_active ? "Yes" : "No")
                    LabeledContent("Usable", value: detail.invite.is_usable ? "Yes" : "No")
                    LabeledContent("Expires", value: detail.invite.expires_at ?? "Never")
                }
                Section("Recent audit history") {
                    AdminLogList(logs: detail.recent_logs)
                }
            } else {
                Text(errorMessage ?? "Unable to load invite details.")
                    .foregroundStyle(Theme.danger)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Invite detail")
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await APIClient().request("admin/invites/\(inviteId)/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminOperationsTab: View {
    let signOut: () -> Void

    @State private var selectedSection = AdminOperationsSection.members

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Section", selection: $selectedSection) {
                    ForEach(AdminOperationsSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedSection {
                case .members:
                    AdminMembersWorkspace()
                case .leads:
                    AdminLeadsWorkspace()
                case .review:
                    AdminOnboardingWorkspace()
                }
            }
            .background(Theme.background)
            .navigationTitle("Operations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        signOut()
                    }
                }
            }
        }
    }
}

private struct AdminMembersWorkspace: View {
    @State private var response: AdminMembersByStoreResponse?
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section("Search") {
                TextField("Search members or stores", text: $query)
                Button("Search") {
                    Task { await load() }
                }
            }

            Section("Members by store") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(response?.groups ?? []) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.store.name)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            if group.members.isEmpty {
                                Text("No members in this store.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            } else {
                                ForEach(group.members) { member in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.username)
                                            .foregroundStyle(Theme.text)
                                        Text("\(member.email) - \(member.total_points) points - \(member.redemption_count) redemptions")
                                            .font(.caption)
                                            .foregroundStyle(Theme.muted)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if (response?.groups.isEmpty ?? true) {
                        AdminEmptyState(text: "No member data matched this search.")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath("admin/members-by-store/", params: [("q", query)])
            response = try await APIClient().request(path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminLeadsWorkspace: View {
    @State private var response: AdminConsultationLeadsResponse?
    @State private var query = ""
    @State private var planFilter = ""
    @State private var bookingFilter = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section("Filters") {
                TextField("Search leads", text: $query)
                Picker("Plan", selection: $planFilter) {
                    Text("All").tag("")
                    Text("Starter").tag("starter")
                    Text("Growth").tag("growth")
                    Text("Pro").tag("pro")
                    Text("Enterprise").tag("enterprise")
                }
                Picker("Needs", selection: $bookingFilter) {
                    Text("All").tag("")
                    Text("Booking").tag("booking")
                    Text("Follow-up").tag("followup")
                }
                Button("Apply filters") {
                    Task { await load() }
                }
            }

            Section("Consultation leads") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(response?.leads ?? []) { lead in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lead.business_name)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text("\(lead.contact_name) - \(lead.email)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        Text("\(lead.plan.capitalized) - \(lead.location_count) locations - \(lead.wants_booking ? "Wants booking" : "Needs follow-up")")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            if !lead.notes.isEmpty {
                                Text(lead.notes)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if (response?.leads.isEmpty ?? true) {
                        AdminEmptyState(text: "No consultation leads matched this filter.")
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath(
                "admin/consultation-leads/",
                params: [("q", query), ("plan", planFilter), ("booking", bookingFilter)]
            )
            response = try await APIClient().request(path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct AdminOnboardingWorkspace: View {
    @State private var response: AdminOnboardingListResponse?
    @State private var query = ""
    @State private var errorMessage: String?
    @State private var isLoading = true
    @State private var reviewTarget: ReviewTarget?
    @State private var reviewReason = ""
    @State private var isSubmitting = false

    var body: some View {
        List {
            Section("Search") {
                TextField("Search requests", text: $query)
                Button("Search") {
                    Task { await load() }
                }
            }

            Section("Pending requests") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ForEach(response?.pending_requests ?? []) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(request.business_name)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text("\(request.store_name) - \(request.contact_email)")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            if let notes = request.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            HStack {
                                Button("Approve") {
                                    reviewTarget = ReviewTarget(request: request, action: "approve")
                                    reviewReason = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.success)

                                Button("Reject") {
                                    reviewTarget = ReviewTarget(request: request, action: "reject")
                                    reviewReason = ""
                                }
                                .buttonStyle(.bordered)
                                .tint(Theme.danger)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if (response?.pending_requests.isEmpty ?? true) {
                        AdminEmptyState(text: "No onboarding requests are pending.")
                    }
                }
            }

            Section("Review history") {
                ForEach(response?.history_requests ?? []) { request in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.business_name)
                            .foregroundStyle(Theme.text)
                        Text("\(request.status) - \(request.reviewed_by ?? "Unknown reviewer")")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                if response?.history_requests.isEmpty ?? true {
                    AdminEmptyState(text: "No reviewed onboarding requests yet.")
                }
            }

            Section("Recent audit history") {
                AdminLogList(logs: response?.recent_review_logs ?? [])
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $reviewTarget) { target in
            NavigationStack {
                Form {
                    Section("Decision") {
                        Text(target.request.business_name)
                        Text(target.action == "approve" ? "Approve this onboarding request." : "Reject this onboarding request.")
                            .foregroundStyle(Theme.muted)
                        TextField("Required review reason", text: $reviewReason, axis: .vertical)
                            .lineLimit(3...5)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(Theme.danger)
                        }
                    }
                }
                .navigationTitle("Review request")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            reviewTarget = nil
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Submit") {
                            Task { await submitReview(target) }
                        }
                        .disabled(isSubmitting || reviewReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let path = buildQueryPath("admin/onboarding-requests/", params: [("q", query)])
            response = try await APIClient().request(path)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitReview(_ target: ReviewTarget) async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        struct Body: Encodable {
            let action: String
            let review_reason: String
        }

        do {
            try await APIClient().requestVoid(
                "admin/onboarding-requests/\(target.request.id)/review/",
                method: "POST",
                body: Body(
                    action: target.action,
                    review_reason: reviewReason.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            reviewTarget = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private struct ReviewTarget: Identifiable {
        let request: AdminOnboardingItem
        let action: String

        var id: String { "\(request.id)-\(action)" }
    }
}

private struct AdminMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(14)
    }
}

private struct AdminSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(14)
    }
}

private struct AdminEmptyState: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdminUserRow: View {
    let user: AdminUserRowResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.username)
                .foregroundStyle(Theme.text)
            Text(user.email)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("\(user.role.capitalized) - \(user.is_active ? "Active" : "Inactive")")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
            if !user.store_name.isEmpty {
                Text(user.store_name)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AdminStoreRow: View {
    let store: AdminStoreRowResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.name)
                .foregroundStyle(Theme.text)
            Text("\(store.owner) - \(store.owner_email)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("\(store.subscription_info.plan_label) - \(store.subscription_info.status_label)")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 4)
    }
}

private struct AdminInviteRow: View {
    let invite: AdminInviteRowResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(invite.code)
                .foregroundStyle(Theme.text)
            Text("\(invite.store_name) - \(invite.uses_count)/\(invite.max_uses)")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text("\(invite.is_active ? "Active" : "Inactive") - \(invite.is_usable ? "Usable" : "Not usable")")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AdminLogList: View {
    let logs: [AdminLogResponse]

    var body: some View {
        if logs.isEmpty {
            AdminEmptyState(text: "No audit entries yet.")
        } else {
            ForEach(logs) { log in
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.summary)
                        .foregroundStyle(Theme.text)
                    if !log.reason.isEmpty {
                        Text(log.reason)
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    Text("\(log.actor) - \(log.action_key)")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private enum AdminOperationsSection: String, CaseIterable, Identifiable {
    case members
    case leads
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .members:
            return "Members"
        case .leads:
            return "Leads"
        case .review:
            return "Review"
        }
    }
}

private struct BillingStatusOption {
    let value: String
    let label: String
}

private let adminBillingStatuses = [
    BillingStatusOption(value: "pending", label: "Pending"),
    BillingStatusOption(value: "trialing", label: "Trialing"),
    BillingStatusOption(value: "active", label: "Active"),
    BillingStatusOption(value: "past_due", label: "Past due"),
    BillingStatusOption(value: "canceled", label: "Canceled"),
    BillingStatusOption(value: "incomplete", label: "Incomplete")
]

private let adminDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private func buildQueryPath(_ path: String, params: [(String, String)]) -> String {
    let rendered = params.compactMap { key, value -> String? in
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return "\(key)=\(encoded)"
    }
    guard !rendered.isEmpty else { return path }
    return "\(path)?\(rendered.joined(separator: "&"))"
}
