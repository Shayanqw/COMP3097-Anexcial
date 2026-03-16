import SwiftUI

struct StoreInvitesView: View {
    @State private var invites: [InviteCodeResponse] = []
    @State private var newCode = ""
    @State private var maxUses = "100"
    @State private var expiresDays = "30"
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Create invite code") {
                    TextField("Code (e.g. CAFEAPRIL)", text: $newCode)
                        .textContentType(.none)
                        .autocapitalization(.allCharacters)
                    TextField("Max uses", text: $maxUses)
                        .keyboardType(.numberPad)
                    TextField("Expires (days, 0 = never)", text: $expiresDays)
                        .keyboardType(.numberPad)
                    Button("Create code") {
                        Task { await createInvite() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(newCode.isEmpty)
                }
                Section("Active invite codes") {
                    ForEach(invites) { inv in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(inv.code)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text("\(inv.status) · \(inv.note) · Expires: \(inv.expires)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.vertical, 4)
                    }
                    if invites.isEmpty && !isLoading {
                        Text("No invite codes yet.")
                            .foregroundStyle(Theme.muted)
                    }
                }
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Manage invites")
            .refreshable { await load() }
            .onAppear { Task { await load() } }
            .alert("Created", isPresented: .constant(successMessage != nil)) {
                Button("OK") {
                    successMessage = nil
                    newCode = ""
                    Task { await load() }
                }
            } message: {
                if let m = successMessage { Text(m) }
            }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient()
            let loaded: [InviteCodeResponse] = try await client.request("store/invites/")
            invites = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createInvite() async {
        errorMessage = nil
        let code = newCode.trimmingCharacters(in: .whitespaces).uppercased()
        let max = Int(maxUses) ?? 100
        let days = Int(expiresDays) ?? 0
        struct Body: Encodable {
            let code: String
            let max_uses: Int
            let expires_days: Int
        }
        do {
            let _: InviteCodeResponse = try await APIClient().request("store/invites/", method: "POST", body: Body(code: code, max_uses: max, expires_days: days))
            successMessage = "Invite code \(code) created."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
