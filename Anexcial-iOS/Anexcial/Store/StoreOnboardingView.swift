import SwiftUI

struct StoreOnboardingView: View {
    @State private var current: OnboardingRequestResponse?
    @State private var businessName = ""
    @State private var contactEmail = ""
    @State private var notes = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isLoading = true

    var body: some View {
        Form {
            if let c = current, c.id != nil {
                Section("Current status") {
                    Text(c.status ?? "Unknown")
                        .foregroundStyle(Theme.text)
                }
            }
            Section("Submit for review") {
                TextField("Business name", text: $businessName)
                TextField("Contact email", text: $contactEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(4...6)
                Button("Submit for review") {
                    Task { await submit() }
                }
                .frame(maxWidth: .infinity)
                .disabled(businessName.isEmpty || contactEmail.isEmpty)
            }
            if let err = errorMessage {
                Section {
                    Text(err).foregroundStyle(Theme.danger)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Store onboarding")
        .onAppear { Task { await load() } }
        .alert("Submitted", isPresented: .constant(successMessage != nil)) {
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
            let loaded: OnboardingRequestResponse = try await client.request("store/onboarding/")
            current = loaded
            if let c = current {
                businessName = c.business_name ?? ""
                contactEmail = c.contact_email ?? ""
                notes = c.notes ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submit() async {
        errorMessage = nil
        struct Body: Encodable {
            let business_name: String
            let contact_email: String
            let notes: String
        }
        do {
            let _: OnboardingRequestResponse = try await APIClient().request("store/onboarding/", method: "POST", body: Body(business_name: businessName.trimmingCharacters(in: .whitespaces), contact_email: contactEmail.trimmingCharacters(in: .whitespaces), notes: notes.trimmingCharacters(in: .whitespaces)))
            successMessage = "Onboarding request submitted for review."
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
