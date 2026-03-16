import SwiftUI

struct StoreDashboardView: View {
    @State private var dashboard: DashboardResponse?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let d = dashboard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Quick view of your members, points awarded, and redemptions this week.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                            HStack(spacing: 12) {
                                KPICard(label: "Members", value: "\(d.kpi.members)")
                                KPICard(label: "Points (7d)", value: "\(d.kpi.points_week)")
                                KPICard(label: "Redemptions (7d)", value: "\(d.kpi.redeems_week)")
                            }
                            Text("Onboarding status: \(d.onboarding_status)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            NavigationLink(destination: StoreScanView()) {
                                Label("Scan & award points", systemImage: "qrcode.viewfinder")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.accent)
                                    .foregroundStyle(.black)
                                    .cornerRadius(10)
                            }
                            NavigationLink(destination: StoreOnboardingView()) {
                                Label("Submit onboarding info", systemImage: "doc.badge.clock")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.surface)
                                    .foregroundStyle(Theme.text)
                                    .cornerRadius(10)
                            }
                            if !d.items.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Items")
                                        .font(.headline)
                                        .foregroundStyle(Theme.text)
                                    ForEach(d.items) { item in
                                        HStack {
                                            Text(item.name)
                                            Spacer()
                                            Text("\(item.points) pts")
                                                .foregroundStyle(Theme.muted)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .padding()
                                .background(Theme.surface)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                } else {
                    Text(errorMessage ?? "Failed to load")
                        .foregroundStyle(Theme.danger)
                }
            }
            .background(Theme.background)
            .navigationTitle("\(dashboard?.store.name ?? "Store") – dashboard")
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient()
            dashboard = try await client.request("store/dashboard/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct KPICard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Theme.muted)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.surface)
        .cornerRadius(10)
    }
}
