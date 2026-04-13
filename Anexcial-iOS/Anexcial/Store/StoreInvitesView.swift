import SwiftUI

struct StoreInvitesView: View {
    @State private var response: StoreInvitesResponse?
    @State private var newCode = ""
    @State private var maxUses = "100"
    @State private var expiresDays = "30"
    @State private var recipientEmail = ""
    @State private var sendNow = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                if let response {
                    Section("Plan access") {
                        LabeledContent("Plan", value: response.subscription_info.plan_label)
                        LabeledContent("Billing", value: response.subscription_info.status_label)
                        LabeledContent(
                            "Invite usage",
                            value: "\(response.subscription_info.usage.active_invites) / \(response.subscription_info.active_invites_limit)"
                        )
                        if !response.recommended_upgrade_plan.isEmpty {
                            Text("Recommended next plan: \(response.recommended_upgrade_plan.capitalized)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }

                Section("Create invite code") {
                    TextField("Code (for example CAFEAPRIL)", text: $newCode)
                        .textContentType(.none)
                        .autocapitalization(.allCharacters)
                    TextField("Max uses", text: $maxUses)
                        .keyboardType(.numberPad)
                    TextField("Expires in days (0 = never)", text: $expiresDays)
                        .keyboardType(.numberPad)
                    Toggle("Email this invite now", isOn: $sendNow)
                    if sendNow {
                        TextField("Recipient email", text: $recipientEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                    }
                    Button("Create code") {
                        Task { await createInvite() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(newCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section("Active invite codes") {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        ForEach(response?.invites ?? []) { invite in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(invite.code)
                                        .font(.headline)
                                        .foregroundStyle(Theme.text)
                                    Spacer()
                                    Text(invite.status)
                                        .font(.caption)
                                        .foregroundStyle(invite.status == "Active" ? Theme.success : Theme.muted)
                                }
                                Text("Uses \(invite.uses_count)/\(invite.max_uses)")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.muted)
                                Text("Expires: \(invite.expires)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                                if !invite.note.isEmpty {
                                    Text(invite.note)
                                        .font(.caption)
                                        .foregroundStyle(Theme.muted)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if (response?.invites.isEmpty ?? true) {
                            Text("No invite codes yet.")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Manage invites")
            .refreshable { await load() }
            .task { await load() }
            .alert("Invite created", isPresented: successBinding) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    successMessage = nil
                }
            }
        )
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            response = try await APIClient().request("store/invites/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createInvite() async {
        errorMessage = nil
        let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else {
            errorMessage = "Invite code is required."
            return
        }
        guard let max = Int(maxUses), max > 0 else {
            errorMessage = "Max uses must be a positive number."
            return
        }
        guard let days = Int(expiresDays), days >= 0 else {
            errorMessage = "Expires in days must be zero or higher."
            return
        }

        struct Body: Encodable {
            let code: String
            let max_uses: Int
            let expires_days: Int
            let recipient_email: String?
            let send_now: Bool
        }

        do {
            let created: StoreInviteCreateResponse = try await APIClient().request(
                "store/invites/",
                method: "POST",
                body: Body(
                    code: code,
                    max_uses: max,
                    expires_days: days,
                    recipient_email: recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines),
                    send_now: sendNow
                )
            )
            successMessage = created.emailed
                ? "Invite code \(created.invite.code) created and emailed."
                : "Invite code \(created.invite.code) created."
            newCode = ""
            maxUses = "100"
            expiresDays = "30"
            recipientEmail = ""
            sendNow = false
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
