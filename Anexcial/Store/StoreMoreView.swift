import SwiftUI

struct StoreMoreView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(destination: StoreOnboardingView()) {
                        Label("Onboarding", systemImage: "doc.badge.clock")
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
            .navigationTitle("More")
        }
    }
}
