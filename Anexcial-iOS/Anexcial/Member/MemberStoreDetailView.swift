import SwiftUI

struct MemberStoreDetailView: View {
    let storeId: Int
    @State private var detail: StoreDetail?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let d = detail {
                List {
                    Section("Points history") {
                        if d.reward_available {
                            Button("Redeem reward") {
                                Task { await redeem() }
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        ForEach(Array(d.history.enumerated()), id: \.offset) { _, h in
                            HStack {
                                Text(h.date)
                                Spacer()
                                Text(h.item)
                                Spacer()
                                Text("\(h.points)")
                            }
                            .foregroundStyle(Theme.text)
                        }
                        if d.history.isEmpty {
                            Text("No history yet.")
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                Text(errorMessage ?? "Failed to load")
                    .foregroundStyle(Theme.danger)
            }
        }
        .background(Theme.background)
        .navigationTitle(detail?.name ?? "Store")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Task { await load() } }
        .alert("Redeemed", isPresented: .constant(successMessage != nil)) {
            Button("OK") { successMessage = nil }
        } message: {
            if let m = successMessage { Text(m) }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient()
            detail = try await client.request("member/stores/\(storeId)/")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func redeem() async {
        do {
            let _: MemberRedeemResponse = try await APIClient().request("member/stores/\(storeId)/redeem/", method: "POST")
            successMessage = "Reward redeemed successfully."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
