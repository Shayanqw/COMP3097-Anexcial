import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthState
    @State private var role = "member"
    @State private var email = ""
    @State private var password = ""
    @State private var inviteCode = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var roleLabel: String {
        switch role {
        case "store": return "Store"
        default: return "Member"
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Role", selection: $role) {
                    Text("Member").tag("member")
                    Text("Store").tag("store")
                }
                .pickerStyle(.segmented)
                Text("Signing up as: \(roleLabel)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } header: {
                Text("Account type")
            }
            if role == "member" {
                Section {
                    TextField("Invite code", text: $inviteCode)
                        .textContentType(.none)
                        .autocapitalization(.allCharacters)
                } header: {
                    Text("Invite code from a store")
                }
            }
            Section {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
            } header: {
                Text("Account")
            }
            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundStyle(Theme.danger)
                }
            }
            Section {
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Signing up as \(roleLabel)…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
                Button("Create account") {
                    Task { await doRegister() }
                }
                .frame(maxWidth: .infinity)
                .disabled(email.isEmpty || password.isEmpty || (role == "member" && inviteCode.isEmpty) || isLoading)
            }
        }
        .navigationTitle("Sign up")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func doRegister() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.register(
                role: role,
                email: email,
                password: password,
                inviteCode: role == "member" ? inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() : nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
