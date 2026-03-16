import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthState
    @State private var role = "member"
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var roleLabel: String {
        switch role {
        case "admin": return "Admin"
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
                    Text("Admin").tag("admin")
                }
                .pickerStyle(.segmented)
                Text("Signing in as: \(roleLabel)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            } header: {
                Text("Account type")
            }
            Section {
                TextField("Email or username", text: $email)
                    .textContentType(.username)
                    .autocapitalization(.none)
                SecureField("Password", text: $password)
                    .textContentType(.password)
                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.9)
                        Text("Signing in as \(roleLabel)…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                }
            } header: {
                Text("Account access")
            }
            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundStyle(Theme.danger)
                }
            }
            Section {
                Button("Sign in") {
                    Task { await doLogin() }
                }
                .frame(maxWidth: .infinity)
                .disabled(email.isEmpty || password.isEmpty || isLoading)
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func doLogin() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
