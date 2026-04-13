import SwiftUI

struct MemberProfileView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        NavigationStack {
            Form {
                if let user = auth.currentUser {
                    Section {
                        LabeledContent("Username", value: user.username)
                        LabeledContent("Email", value: user.email)
                        LabeledContent("Role", value: "Member")
                    }
                }
                Section {
                    Button("Log out", role: .destructive) {
                        auth.logout()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Profile")
        }
    }
}
