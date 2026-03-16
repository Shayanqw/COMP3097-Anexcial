import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Neighbourhood loyalty, refined")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                    Text("Reward the regulars who make local places feel alive.")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                    Text("Anexcial gives stores a premium invite-only loyalty experience built around community, trusted membership, and quick QR-based check-ins.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)

                    VStack(spacing: 12) {
                        NavigationLink(destination: LoginView()) {
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.accent)
                                .foregroundStyle(.black)
                                .cornerRadius(10)
                        }
                        NavigationLink(destination: SignupView()) {
                            Text("Sign up")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.surface)
                                .foregroundStyle(Theme.text)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Anexcial")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
