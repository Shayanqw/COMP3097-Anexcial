import SwiftUI

struct StoreItemsView: View {
    @State private var items: [StoreItemResponse] = []
    @State private var name = ""
    @State private var points = "10"
    @State private var editingId: Int?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            List {
                Section("Add / update item") {
                    TextField("Item name", text: $name)
                    TextField("Points", text: $points)
                        .keyboardType(.numberPad)
                    Button(editingId != nil ? "Update item" : "Save item") {
                        Task { await saveItem() }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(name.isEmpty)
                    if editingId != nil {
                        Button("Cancel editing") {
                            editingId = nil
                            name = ""
                            points = "10"
                        }
                        .foregroundStyle(Theme.muted)
                    }
                }
                Section("Items") {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .foregroundStyle(Theme.text)
                                Text("\(item.points) pts")
                                    .font(.caption)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Button("Edit") {
                                editingId = item.id
                                name = item.name
                                points = "\(item.points)"
                            }
                            .foregroundStyle(Theme.accent)
                        }
                        .padding(.vertical, 4)
                    }
                    if items.isEmpty && !isLoading {
                        Text("No items configured.")
                            .foregroundStyle(Theme.muted)
                    }
                }
                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(Theme.danger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Items & rules")
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response: StoreItemsResponse = try await APIClient().request("store/items/")
            items = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveItem() async {
        errorMessage = nil
        let itemName = name.trimmingCharacters(in: .whitespaces)
        guard let pts = Int(points), pts > 0 else {
            errorMessage = "Points must be a positive number."
            return
        }
        struct Body: Encodable {
            let name: String
            let points: Int
        }
        do {
            if let editingId {
                let _: StoreItemResponse = try await APIClient().request("store/items/\(editingId)/", method: "PATCH", body: Body(name: itemName, points: pts))
            } else {
                let _: StoreItemResponse = try await APIClient().request("store/items/", method: "POST", body: Body(name: itemName, points: pts))
            }
            name = ""
            points = "10"
            editingId = nil
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
