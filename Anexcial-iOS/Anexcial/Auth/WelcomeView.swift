import SwiftUI

struct WelcomeView: View {
    var body: some View {
        NavigationStack {
            PublicWelcomeHubView()
        }
        .tint(Theme.accent)
    }
}

private struct PublicWelcomeHubView: View {
    @State private var bootstrap: PublicBootstrapResponse?
    @State private var statusPayload: StatusResponse?
    @State private var bootstrapError: String?
    @State private var statusError: String?
    @State private var consultationPlan: ConsultationRoute?

    var body: some View {
        Group {
            if let bootstrap {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        homeIntroSection(bootstrap)

                        VStack(alignment: .leading, spacing: 10) {
                            hubExploreRow(title: "Pricing", systemImage: "creditcard") {
                                PublicPricingDetailView(bootstrap: bootstrap, consultationPlan: $consultationPlan)
                            }
                            hubExploreRow(title: "Resources", systemImage: "book.closed") {
                                PublicResourcesDetailView(bootstrap: bootstrap)
                            }
                            hubExploreRow(title: "Status", systemImage: "waveform.path.ecg") {
                                PublicStatusDetailView(
                                    statusPayload: statusPayload,
                                    statusError: statusError,
                                    awaitingStatus: statusPayload == nil && statusError == nil
                                )
                            }
                        }

                        contactSection()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
            } else if let bootstrapError {
                PublicErrorStateView(title: "Unable to load", message: bootstrapError)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle("Anexcial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if bootstrap != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink {
                            LoginView()
                        } label: {
                            Label("Sign in", systemImage: "person.crop.circle")
                        }
                        NavigationLink {
                            SignupView()
                        } label: {
                            Label("Create account", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Label("Account", systemImage: "person.crop.circle")
                            .labelStyle(.iconOnly)
                            .accessibilityLabel("Sign in and account options")
                    }
                }
            }
        }
        .sheet(item: $consultationPlan) { route in
            NavigationStack {
                ConsultationFormView(initialPlan: route.plan)
            }
        }
        .task { await loadHubData() }
    }

    private func loadHubData() async {
        guard bootstrap == nil, bootstrapError == nil else { return }
        async let bootstrapTask: PublicBootstrapResponse = APIClient(token: nil).request("public/bootstrap/")
        async let statusTask: StatusResponse = APIClient(token: nil).request("public/status/")
        do {
            bootstrap = try await bootstrapTask
        } catch {
            bootstrapError = error.localizedDescription
        }
        do {
            statusPayload = try await statusTask
        } catch {
            statusError = error.localizedDescription
        }
    }

    private func hubExploreRow<Destination: View>(title: String, systemImage: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func contactSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Contact")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
            Text("If you have any trouble or questions, contact support@anexcial.com.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(14)
    }

    @ViewBuilder
    private func homeIntroSection(_ bootstrap: PublicBootstrapResponse) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .center, spacing: 8) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: 22, height: 2)
                Text("NEIGHBOURHOOD LOYALTY, REFINED")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .tracking(0.6)
            }
            Text("Reward the regulars who make local places feel alive.")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.text)
            Text("Anexcial gives stores a premium invite-only loyalty experience built around community, trusted membership, and quick QR-based check-ins. Members, stores, and admins all get a clearer view of how loyalty grows.")
                .font(.body)
                .foregroundStyle(Theme.muted)

            VStack(spacing: 12) {
                homeMarketingFeatureCard(
                    title: "Invite-only",
                    subtitle: "Exclusive onboarding for trusted members."
                )
                homeMarketingFeatureCard(
                    title: "Counter-ready",
                    subtitle: "Fast QR scan flow for busy store teams."
                )
                homeMarketingFeatureCard(
                    title: "Sales-assisted launch",
                    subtitle: "Consultation and onboarding keep rollout clean."
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 22, height: 2)
                        Text("DESIGNED FOR TRUST")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .tracking(0.6)
                    }
                    Text("3 roles")
                        .font(.title.bold())
                        .foregroundStyle(Theme.accent)
                    Text("Members collect rewards, stores run the counter, and admins keep the network healthy.")
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface)
                .cornerRadius(14)

                homeRoleCard(
                    kicker: "MEMBERS",
                    body: "Join with an invite, carry one QR identity, and keep rewards with the places you really return to."
                )
                homeRoleCard(
                    kicker: "STORES",
                    body: "Manage catalog items, award points quickly, and see loyalty turn into repeat visits."
                )
                homeRoleCard(
                    kicker: "ADMINS",
                    body: "Review store onboarding, oversee operations, and keep the ecosystem curated."
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Featured resource")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                NavigationLink(destination: PublicPageView(title: bootstrap.featured_resource.title, path: bootstrap.featured_resource.href)) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(bootstrap.featured_resource.title)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text(bootstrap.featured_resource.description)
                            .foregroundStyle(Theme.muted)
                        Text(bootstrap.featured_resource.cta)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(16)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Catalog")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                ForEach(Array(bootstrap.catalog_links.prefix(3))) { link in
                    NavigationLink(destination: PublicPageView(title: link.title, path: link.href)) {
                        PublicLinkCard(link: link)
                    }
                }
            }
        }
    }

    private func homeMarketingFeatureCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.muted.opacity(0.25), lineWidth: 1)
        )
    }

    private func homeRoleCard(kicker: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kicker)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.text)
                .tracking(0.8)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface)
        .cornerRadius(14)
    }
}

private struct PublicPricingDetailView: View {
    @Environment(\.openURL) private var openURL

    let bootstrap: PublicBootstrapResponse
    @Binding var consultationPlan: ConsultationRoute?

    @State private var isAnnual = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Billing period", selection: $isAnnual) {
                    Text("Monthly").tag(false)
                    Text("Annual").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Monthly or annual billing")

                if isAnnual, let annualNote = bootstrap.pricing_plans.first?.annual_note, !annualNote.isEmpty {
                    Text(annualNote)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                ForEach(bootstrap.pricing_plans) { plan in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(plan.name)
                                .font(.title3.bold())
                                .foregroundStyle(Theme.text)
                            Spacer()
                            if !plan.badge.isEmpty {
                                Text(plan.badge)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(plan.highlight ? Theme.accent : Theme.muted)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(isAnnual ? "\(plan.annual_price) \(plan.annual_period)" : "\(plan.monthly_price) \(plan.monthly_period)")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                        Text(plan.description)
                            .foregroundStyle(Theme.muted)
                        ForEach(plan.features, id: \.self) { feature in
                            Text("- \(feature)")
                                .foregroundStyle(Theme.text)
                        }
                        Button(plan.cta_label) {
                            handlePlanAction(plan)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .foregroundStyle(.black)
                    }
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(18)
                }

            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
        .background(Theme.background)
        .navigationTitle("Pricing")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handlePlanAction(_ plan: PricingPlanResponse) {
        if plan.cta_href.contains("/consultation") {
            consultationPlan = ConsultationRoute(plan: plan.slug)
        } else if let url = APIClient.resolveWebURL(plan.cta_href) {
            openURL(url)
        }
    }
}

private struct PublicResourcesDetailView: View {
    let bootstrap: PublicBootstrapResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Catalog")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                ForEach(bootstrap.catalog_links) { link in
                    resourceRow(title: link.title) {
                        PublicPageView(title: link.title, path: link.href)
                    }
                }

                Text("Guides")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                ForEach(bootstrap.resource_columns.flatMap(\.items)) { link in
                    resourceRow(title: link.title) {
                        PublicPageView(title: link.title, path: link.href)
                    }
                }

                Text("Policies")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                resourceRow(title: "Privacy policy") {
                    PublicPageView(title: "Privacy policy", path: "public/privacy/")
                }
                resourceRow(title: "Terms") {
                    PublicPageView(title: "Terms", path: "public/terms/")
                }

                Text("Consultation")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 8)
                resourceRow(title: "Book a consultation") {
                    ConsultationFormView()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal)
        }
        .background(Theme.background)
        .navigationTitle("Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func resourceRow<Destination: View>(title: String, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
            HStack {
                Text(title)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding()
            .background(Theme.surface)
            .cornerRadius(12)
        }
    }
}

private struct PublicStatusDetailView: View {
    let statusPayload: StatusResponse?
    let statusError: String?
    let awaitingStatus: Bool

    var body: some View {
        Group {
            if let statusPayload {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        statusSubheading("Service")
                        LabeledContent("Status", value: statusPayload.ok ? "Ready" : "Not ready")
                        LabeledContent("Environment", value: statusPayload.environment)
                        LabeledContent("Release", value: statusPayload.release_id)
                            .padding(.bottom, 12)

                        if let database = statusPayload.database {
                            statusSubheading("Database")
                            LabeledContent("Healthy", value: database.ok ? "Yes" : "No")
                            LabeledContent("Engine", value: database.engine)
                                .padding(.bottom, 12)
                        }
                        if let stripe = statusPayload.stripe {
                            statusSubheading("Billing")
                            LabeledContent("Checkout", value: stripe.checkout_ready ? "Ready" : "Missing")
                            LabeledContent("Webhook", value: stripe.webhook_ready ? "Ready" : "Missing")
                            LabeledContent("Portal", value: stripe.portal_ready ? "Ready" : "Missing")
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .cornerRadius(14)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                }
            } else if let statusError {
                Text(statusError)
                    .font(.subheadline)
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            } else if awaitingStatus {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                Text("Status unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .navigationTitle("Status")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusSubheading(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.muted)
            .padding(.top, 4)
            .padding(.bottom, 6)
    }
}

private struct ConsultationRoute: Identifiable {
    let plan: String

    var id: String { plan }
}

private struct PublicPageView: View {
    let title: String
    let path: String

    @State private var page: PublicPageResponse?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let page {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(page.eyebrow)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.accent)
                        Text(page.title)
                            .font(.title.bold())
                            .foregroundStyle(Theme.text)
                        Text(page.summary)
                            .foregroundStyle(Theme.muted)

                        ForEach(page.sections) { section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundStyle(Theme.text)
                                Text(section.body)
                                    .foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(14)
                        }
                    }
                    .padding()
                }
            } else if let errorMessage {
                PublicErrorStateView(
                    title: "Unable to load page",
                    message: errorMessage
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadPage() }
    }

    private func loadPage() async {
        guard page == nil else { return }
        do {
            if path.hasPrefix("public/") {
                page = try await APIClient(token: nil).request(path)
            } else if path.contains("/catalog/"), let slug = slugFrom(path) {
                page = try await APIClient(token: nil).request("public/catalog/\(slug)/")
            } else if path.contains("/resources/"), let slug = slugFrom(path) {
                page = try await APIClient(token: nil).request("public/resources/\(slug)/")
            } else if path.contains("/privacy") {
                page = try await APIClient(token: nil).request("public/privacy/")
            } else if path.contains("/terms") {
                page = try await APIClient(token: nil).request("public/terms/")
            } else {
                errorMessage = "Unsupported page link."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func slugFrom(_ path: String) -> String? {
        path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .last
    }
}

private struct ConsultationFormView: View {
    @Environment(\.openURL) private var openURL

    @State private var businessName = ""
    @State private var contactName = ""
    @State private var email = ""
    @State private var locationCount = "1"
    @State private var launchIntent = "launch-soon"
    @State private var plan = "growth"
    @State private var notes = ""
    @State private var wantsBooking = true
    @State private var successMessage: String?
    @State private var errorMessage: String?
    @State private var isLoading = false

    init(initialPlan: String? = nil) {
        _plan = State(initialValue: initialPlan ?? "growth")
    }

    var body: some View {
        Form {
            Section("Business") {
                TextField("Business name", text: $businessName)
                TextField("Contact name", text: $contactName)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Location count", text: $locationCount)
                    .keyboardType(.numberPad)
            }

            Section("Launch") {
                Picker("Plan", selection: $plan) {
                    Text("Starter").tag("starter")
                    Text("Growth").tag("growth")
                    Text("Pro").tag("pro")
                    Text("Enterprise").tag("enterprise")
                }
                Picker("Launch intent", selection: $launchIntent) {
                    Text("Launch soon").tag("launch-soon")
                    Text("Exploring fit").tag("exploring-fit")
                    Text("Multiple locations").tag("launch-multiple-locations")
                }
                Toggle("Book follow-up", isOn: $wantsBooking)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(4...6)
            }

            if let successMessage {
                Section {
                    Text(successMessage)
                        .foregroundStyle(Theme.success)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(Theme.danger)
                }
            }

            Section {
                Button("Submit consultation") {
                    Task { await submit() }
                }
                .frame(maxWidth: .infinity)
                .disabled(isLoading || businessName.isEmpty || contactName.isEmpty || email.isEmpty)
            }
        }
        .navigationTitle("Consultation")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func submit() async {
        struct Body: Encodable {
            let plan: String
            let business_name: String
            let contact_name: String
            let email: String
            let location_count: Int
            let launch_intent: String
            let notes: String
            let wants_booking: Bool
        }

        errorMessage = nil
        successMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response: ConsultationResponse = try await APIClient(token: nil).request(
                "public/consultation/",
                method: "POST",
                body: Body(
                    plan: plan,
                    business_name: businessName,
                    contact_name: contactName,
                    email: email,
                    location_count: Int(locationCount) ?? 1,
                    launch_intent: launchIntent,
                    notes: notes,
                    wants_booking: wantsBooking
                )
            )
            successMessage = "Consultation submitted."
            if response.should_book, let url = URL(string: response.booking_url), !response.booking_url.isEmpty {
                openURL(url)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PublicLinkCard: View {
    let link: LinkCardResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(link.title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            if let description = link.description, !description.isEmpty {
                Text(description)
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.surface)
        .cornerRadius(14)
    }
}

private struct PublicErrorStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
