import SwiftUI

struct SignupView: View {
    @EnvironmentObject var auth: AuthState

    @State private var role = "member"
    @State private var email = ""
    @State private var password = ""
    @State private var inviteCode = ""
    @State private var storeName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var roleLabel: String {
        role == "store" ? "Store" : "Member"
    }

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty, !isLoading else { return false }
        if role == "member" {
            return !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return !storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroBlock

                accountTypeCard

                roleDetailsCard

                credentialsCard

                if let err = errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.danger.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                createAccountButton

                VStack(alignment: .leading, spacing: 10) {
                    NavigationLink {
                        LoginView()
                    } label: {
                        HStack {
                            Text("Already have an account? Sign in")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .imageScale(.medium)
                        }
                        .foregroundStyle(Theme.accent)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Theme.accent.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Text("Membership stays tied to real places. Stores issue invites; we keep the network curated.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(signupBackdrop.ignoresSafeArea())
        .navigationTitle("Create account")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(Theme.accent)
    }

    private var signupBackdrop: some View {
        ZStack(alignment: .top) {
            Theme.background
            LinearGradient(
                colors: [
                    Theme.accent.opacity(0.14),
                    Theme.accent.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 280)
            .blur(radius: 0.5)
        }
    }

    private var heroBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "seal.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                Text("INVITE ONLY")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.accent)
            }

            Text("Create your account")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.text)

            Text("Choose how you will use Anexcial. Members join with a store invite; stores register to run loyalty at the counter.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accountTypeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account type")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            Picker("Role", selection: $role) {
                Text("Member").tag("member")
                Text("Store").tag("store")
            }
            .pickerStyle(.segmented)
            .tint(Theme.accent)
            .padding(.horizontal, 18)

            Text("You are creating a \(roleLabel.lowercased()) account.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
        .premiumCardChrome()
    }

    @ViewBuilder
    private var roleDetailsCard: some View {
        if role == "member" {
            VStack(alignment: .leading, spacing: 0) {
                Text("Invite from your store")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                TextField("Invite code", text: $inviteCode)
                    .textContentType(.none)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.text)
                    .tint(Theme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                Text("Use the code the store gave you—often printed in-store or shared when you are welcomed as a regular.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
            .premiumCardChrome()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("Store profile")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                TextField("Store name", text: $storeName)
                    .textContentType(.organizationName)
                    .foregroundStyle(Theme.text)
                    .tint(Theme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                Text("This is how your location appears to members and in the network.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
            .premiumCardChrome()
        }
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Credentials")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .foregroundStyle(Theme.text)
                    .tint(Theme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.muted.opacity(0.18))
                    .frame(height: 1)
                    .padding(.leading, 18)

                SecureField("Password", text: $password)
                    .textContentType(.newPassword)
                    .foregroundStyle(Theme.text)
                    .tint(Theme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
            .padding(.bottom, 8)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(Theme.accent)
                    Text("Creating your account…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .premiumCardChrome()
    }

    private var createAccountButton: some View {
        Button {
            Task { await doRegister() }
        } label: {
            Text("Create account")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(canSubmit ? Color.black : Theme.muted)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(canSubmit ? Theme.accent : Theme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.accent.opacity(canSubmit ? 0 : 0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
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
                inviteCode: role == "member" ? inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() : nil,
                storeName: role == "store" ? storeName : nil
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared chrome (matches Login credential cards)

private extension View {
    func premiumCardChrome() -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.accent.opacity(0.55),
                            Theme.accent.opacity(0.12),
                            Theme.muted.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, y: 10)
    }
}
