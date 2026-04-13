import SwiftUI

struct StoreDashboardView: View {
    @EnvironmentObject var auth: AuthState

    @State private var dashboard: DashboardResponse?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let dashboard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Quick view of your members, points awarded, and redemptions this week.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)

                            HStack(spacing: 12) {
                                KPICard(label: "Members", value: "\(dashboard.kpi.members)")
                                KPICard(label: "Points (7d)", value: "\(dashboard.kpi.points_week)")
                                KPICard(label: "Redemptions (7d)", value: "\(dashboard.kpi.redeems_week)")
                            }

                            Text("Onboarding status: \(dashboard.onboarding_status)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)
                            Text("Mode: \(dashboard.subscription_info.plan_label) | \(dashboard.subscription_info.status_label)")
                                .font(.caption)
                                .foregroundStyle(Theme.muted)

                            NavigationLink(destination: StoreScanView()) {
                                primaryActionLabel("Scan & award points", systemImage: "qrcode.viewfinder")
                            }

                            NavigationLink(destination: StoreOnboardingView()) {
                                secondaryActionLabel("Submit onboarding info", systemImage: "doc.badge.clock")
                            }

                            if !dashboard.items.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Items")
                                        .font(.headline)
                                        .foregroundStyle(Theme.text)
                                    ForEach(dashboard.items) { item in
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

                            Button("Log out", role: .destructive) {
                                auth.logout()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 16) {
                        Text(errorMessage ?? "Failed to load")
                            .foregroundStyle(Theme.danger)
                            .multilineTextAlignment(.center)
                        Button("Log out", role: .destructive) {
                            auth.logout()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .background(Theme.background)
            .navigationTitle("\(dashboard?.store.name ?? "Store") dashboard")
            .toolbar {
                if isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Log out", role: .destructive) {
                            auth.logout()
                        }
                    }
                }
            }
            .refreshable { await load() }
            .task { await load() }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            dashboard = try await APIClient().request("store/dashboard/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func primaryActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.accent)
            .foregroundStyle(.black)
            .cornerRadius(10)
    }

    private func secondaryActionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.surface)
            .foregroundStyle(Theme.text)
            .cornerRadius(10)
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
