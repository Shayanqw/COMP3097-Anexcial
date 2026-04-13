import SwiftUI

struct StoreMoreView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    Section("Account") {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: "Store")
                    }
                }

                Section("Operations") {
                    NavigationLink(destination: StoreOnboardingView()) {
                        Label("Onboarding review", systemImage: "doc.badge.clock")
                    }
                    NavigationLink(destination: StoreInvitesView()) {
                        Label("Invite codes", systemImage: "envelope.badge")
                    }
                }

                Section("Support") {
                    Text("If you have any trouble or questions, contact support@anexcial.com.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }

                Section {
                    Button("Log out", role: .destructive) {
                        auth.logout()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("More")
        }
    }
}

struct StoreBillingView: View {
    var body: some View {
        ScrollView {
            Text("If you have any trouble or questions, contact support@anexcial.com.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(Theme.background)
        .navigationTitle("Billing")
    }
}
