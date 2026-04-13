import SwiftUI
import AVFoundation

struct StoreScanView: View {
    @State private var items: [StoreItemResponse] = []
    @State private var scannedPayload = ""
    @State private var selectedItemId: Int?
    @State private var memberName: String?
    @State private var memberUUID: String?
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showCamera = false
    @State private var redeemPoints = ""
    @State private var isLoadingItems = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Scanned QR payload") {
                    TextField("member:uuid", text: $scannedPayload)
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .onChange(of: scannedPayload) { _ in
                            triggerLookup()
                        }
                    if let memberName {
                        Text("Member: \(memberName)")
                            .foregroundStyle(Theme.success)
                    }
                    if let memberUUID {
                        Text("UUID: \(memberUUID)")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                }

                Section("Award points") {
                    if isLoadingItems {
                        ProgressView("Loading store items...")
                    } else if items.isEmpty {
                        Text("Create at least one store item before scanning members.")
                            .foregroundStyle(Theme.muted)
                    } else {
                        Picker("Item", selection: $selectedItemId) {
                            Text("Select item").tag(nil as Int?)
                            ForEach(items) { item in
                                Text("\(item.name) (\(item.points) pts)").tag(item.id as Int?)
                            }
                        }
                    }

                    Button("Award points") {
                        Task { await awardPoints() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(scannedPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedItemId == nil)
                }

                Section("Redeem points") {
                    TextField("Points to redeem", text: $redeemPoints)
                        .keyboardType(.numberPad)
                    Button("Redeem points") {
                        Task { await redeemPointsAction() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(scannedPayload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Int(redeemPoints) == nil)
                }

                Section {
                    Button("Scan QR with camera") {
                        showCamera = true
                    }
                    .frame(maxWidth: .infinity)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Scan member QR")
            .refreshable { await loadItems() }
            .task { await loadItems() }
            .sheet(isPresented: $showCamera) {
                QRScannerView { payload in
                    scannedPayload = payload
                    showCamera = false
                    triggerLookup()
                }
            }
            .alert("Success", isPresented: successBinding) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }

    private var successBinding: Binding<Bool> {
        Binding(
            get: { successMessage != nil },
            set: { isPresented in
                if !isPresented {
                    successMessage = nil
                }
            }
        )
    }

    private func loadItems() async {
        errorMessage = nil
        isLoadingItems = true
        defer { isLoadingItems = false }
        do {
            let response: StoreItemsResponse = try await APIClient().request("store/items/")
            items = response.items
            if selectedItemId == nil, let first = response.items.first {
                selectedItemId = first.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerLookup() {
        Task { await lookupMember() }
    }

    private func lookupMember() async {
        let payload = scannedPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        memberName = nil
        memberUUID = nil
        guard !payload.isEmpty else { return }
        do {
            let encodedPayload = payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? payload
            let result: MemberLookupResponse = try await APIClient().request("store/member-lookup/?payload=\(encodedPayload)")
            if result.ok {
                memberName = result.username
                memberUUID = result.member_uuid
            }
        } catch {
            memberName = nil
            memberUUID = nil
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
            let result: SuccessResponse = try await APIClient().request(
                "store/points/award/",
                method: "POST",
                body: Body(
                    scanned_payload: scannedPayload.trimmingCharacters(in: .whitespacesAndNewlines),
                    item_id: itemId
                )
            )
            successMessage = result.message ?? "Points awarded."
            clearLookup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func redeemPointsAction() async {
        errorMessage = nil
        guard let points = Int(redeemPoints), points > 0 else {
            errorMessage = "Redeem points must be a positive number."
            return
        }

        struct Body: Encodable {
            let scanned_payload: String
            let points: Int
        }

        do {
            let result: SuccessResponse = try await APIClient().request(
                "store/points/redeem/",
                method: "POST",
                body: Body(
                    scanned_payload: scannedPayload.trimmingCharacters(in: .whitespacesAndNewlines),
                    points: points
                )
            )
            successMessage = result.message ?? "Points redeemed."
            clearLookup()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearLookup() {
        scannedPayload = ""
        memberName = nil
        memberUUID = nil
        redeemPoints = ""
    }
}
