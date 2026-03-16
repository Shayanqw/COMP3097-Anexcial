import SwiftUI
import AVFoundation

struct StoreScanView: View {
    @State private var items: [StoreItemResponse] = []
    @State private var scannedPayload = ""
    @State private var selectedItemId: Int?
    @State private var memberName: String?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showCamera = false
    @State private var redeemPoints = ""
    @State private var showRedeem = false
    @State private var isLoadingItems = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Scanned QR payload") {
                    TextField("member:uuid", text: $scannedPayload)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .onChange(of: scannedPayload) { _ in lookupMember() }
                    if let name = memberName {
                        Text("Member: \(name)")
                            .foregroundStyle(Theme.success)
                    }
                }
                Section("Award points") {
                    Picker("Item", selection: $selectedItemId) {
                        Text("Select item").tag(nil as Int?)
                        ForEach(items) { item in
                            Text("\(item.name) (\(item.points) pts)").tag(item.id as Int?)
                        }
                    }
                    Button("Award points") {
                        Task { await awardPoints() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(scannedPayload.isEmpty || selectedItemId == nil)
                }
                Section("Redeem points") {
                    TextField("Points to redeem", text: $redeemPoints)
                        .keyboardType(.numberPad)
                    Button("Redeem points") {
                        Task { await redeemPointsAction() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(scannedPayload.isEmpty || Int(redeemPoints) == nil)
                }
                Section {
                    Button("Scan QR with camera") {
                        showCamera = true
                    }
                    .frame(maxWidth: .infinity)
                }
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Scan member QR")
            .onAppear { Task { await loadItems() } }
            .sheet(isPresented: $showCamera) {
                QRScannerView { payload in
                    scannedPayload = payload
                    showCamera = false
                    lookupMember()
                }
            }
            .alert("Success", isPresented: .constant(successMessage != nil)) {
                Button("OK") { successMessage = nil }
            } message: {
                if let m = successMessage { Text(m) }
            }
        }
    }

    private func loadItems() async {
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            let client = APIClient()
            let loaded: [StoreItemResponse] = try await client.request("store/items/")
            items = loaded
            if selectedItemId == nil, let first = items.first {
                selectedItemId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func lookupMember() {
        memberName = nil
        errorMessage = nil
        guard !scannedPayload.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            do {
                let client = APIClient()
                let res: MemberLookupResponse = try await client.request("store/member-lookup/?payload=\(scannedPayload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
                if res.ok, let name = res.username {
                    memberName = name
                } else {
                    memberName = nil
                }
            } catch {
                memberName = nil
            }
        }
    }

    private func awardPoints() async {
        errorMessage = nil
        guard let itemId = selectedItemId else { return }
        struct Body: Encodable {
            let scanned_payload: String
            let item_id: Int
        }
        do {
            let _: SuccessResponse = try await APIClient().request("store/points/award/", method: "POST", body: Body(scanned_payload: scannedPayload.trimmingCharacters(in: .whitespaces), item_id: itemId))
            successMessage = "Points awarded."
            scannedPayload = ""
            memberName = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func redeemPointsAction() async {
        errorMessage = nil
        guard let points = Int(redeemPoints), points > 0 else { return }
        struct Body: Encodable {
            let scanned_payload: String
            let points: Int
        }
        do {
            let _: SuccessResponse = try await APIClient().request("store/points/redeem/", method: "POST", body: Body(scanned_payload: scannedPayload.trimmingCharacters(in: .whitespaces), points: points))
            successMessage = "Points redeemed."
            scannedPayload = ""
            memberName = nil
            redeemPoints = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
