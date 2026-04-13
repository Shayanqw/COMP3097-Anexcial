import SwiftUI

struct StoreFlowView: View {
    @EnvironmentObject var auth: AuthState

    var body: some View {
        TabView {
            StoreDashboardView()
                .tabItem { Label("Dashboard", systemImage: "chart.bar") }
            StoreScanView()
                .tabItem { Label("Scan", systemImage: "qrcode.viewfinder") }
            StoreInvitesView()
                .tabItem { Label("Invites", systemImage: "envelope.badge") }
            StoreItemsView()
                .tabItem { Label("Items", systemImage: "list.bullet") }
            StoreMoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RoleBadge(role: roleLabel)
        }
        .tint(Theme.accent)
        .onAppear { UITabBar.appearance().backgroundColor = UIColor(Theme.surface) }
    }

    private var roleLabel: String {
        guard let role = auth.currentUser?.role else { return "Store" }
        switch role {
        case "admin": return "Admin"
        case "store": return "Store"
        default: return "Member"
        }
    }
}
