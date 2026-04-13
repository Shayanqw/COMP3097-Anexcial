import SwiftUI

struct MemberFlowView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        TabView {
            MemberStoresView()
                .tabItem { Label("Stores", systemImage: "storefront") }
            MemberQRView()
                .tabItem { Label("My QR", systemImage: "qrcode") }
            MemberProfileView()
                .tabItem { Label("Profile", systemImage: "person") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RoleBadge(role: roleLabel)
        }
        .tint(Theme.accent)
        .onAppear { UITabBar.appearance().backgroundColor = UIColor(Theme.surface) }
    }

    private var roleLabel: String {
        guard let role = auth.currentUser?.role else { return "Member" }
        switch role {
        case "admin": return "Admin"
        case "store": return "Store"
        default: return "Member"
        }
    }
}
