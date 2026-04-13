import SwiftUI

struct MemberStoresView: View {
    @State private var stores: [StoreCard] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = errorMessage {
                    Text(err)
                        .foregroundStyle(Theme.danger)
                        .padding()
                } else if stores.isEmpty {
                    Text("No stores yet. Join a store to start earning points.")
                        .foregroundStyle(Theme.muted)
                        .padding()
                } else {
                    List(stores) { store in
                        NavigationLink(destination: MemberStoreDetailView(storeId: store.id)) {
                            StoreCardRow(store: store)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .background(Theme.background)
            .navigationTitle("My stores & points")
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
            stores = try await client.request("member/stores/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct StoreCardRow: View {
    let store: StoreCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.name)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text("Points: \(store.points)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
            if store.reward_available {
                Text("Reward available: \(store.reward_label)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.success)
            } else {
                Text("\(store.points) / \(store.threshold) to next reward")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            ProgressView(value: min(Double(store.points) / Double(max(store.threshold, 1)), 1))
                .tint(Theme.accent)
        }
        .padding(.vertical, 4)
    }
}
