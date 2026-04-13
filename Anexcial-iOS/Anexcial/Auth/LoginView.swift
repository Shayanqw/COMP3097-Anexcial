import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthState

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                heroBlock

                credentialCard

                if let err = errorMessage {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(Theme.danger)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.danger.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                signInButton

                VStack(alignment: .leading, spacing: 10) {
                    NavigationLink {
                        SignupView()
                    } label: {
                        HStack {
                            Text("Create an account")
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

                    Text("Anexcial is invite-only. You will need a store invite or approved access to open a new account.")
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
        .background(loginBackdrop.ignoresSafeArea())
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(Theme.accent)
    }

    private var loginBackdrop: some View {
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

            Text("Welcome back")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.text)

            Text("Sign in to your trusted profile. The same credentials unlock your member, store, or admin workspace.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var credentialCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Credentials")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                TextField("Email or username", text: $email)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.text)
                    .tint(Theme.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)

                Rectangle()
                    .fill(Theme.muted.opacity(0.18))
                    .frame(height: 1)
                    .padding(.leading, 18)

                SecureField("Password", text: $password)
                    .textContentType(.password)
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
                    Text("Signing you in…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .background(
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

    private var signInButton: some View {
        Button {
            Task { await doLogin() }
        } label: {
            Text("Sign in")
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
