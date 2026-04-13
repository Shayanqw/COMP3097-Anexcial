import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthState

    private var signedInAsText: String? {
        guard let role = auth.signedInRoleForBanner else { return nil }
        let label: String
        switch role {
        case "admin": label = "Admin"
        case "store": label = "Store"
        default: label = "Member"
        }
        return "Signed in as \(label)"
    }

    var body: some View {
        Group {
            if auth.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else if let user = auth.currentUser {
                switch user.role {
                case "admin":
                    AdminFlowView()
                case "store":
                    StoreFlowView()
                default:
                    MemberFlowView()
                }
            } else {
                WelcomeView()
            }
        }
        .overlay(alignment: .top) {
            if let text = signedInAsText {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { auth.signedInRoleForBanner = nil }
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        auth.signedInRoleForBanner = nil
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.signedInRoleForBanner)
        .preferredColorScheme(.dark)
    }
}
