import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

// MARK: - ButtonStyle type eraser (fixes ternary .buttonStyle errors)

struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }

    func makeBody(configuration: Configuration) -> some View {
        _makeBody(configuration)
    }
}

// MARK: - Theme

enum AnexcialTheme {
    static let bgTop = Color(red: 17/255, green: 24/255, blue: 39/255)     // #111827
    static let bgMid = Color(red: 2/255, green: 6/255, blue: 23/255)       // #020617
    static let bgBottom = Color.black

    static let surface = Color(red: 15/255, green: 23/255, blue: 42/255)   // #0F172A-ish
    static let border = Color(red: 51/255, green: 65/255, blue: 85/255)    // #334155
    static let muted = Color(red: 156/255, green: 163/255, blue: 175/255)  // #9CA3AF

    static let progressA = Color(red: 165/255, green: 180/255, blue: 252/255) // #A5B4FC
    static let progressB = Color(red: 56/255, green: 189/255, blue: 248/255)  // #38BDF8

    static let good = Color(red: 110/255, green: 231/255, blue: 183/255)   // #6EE7B7
}

struct AnexcialBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AnexcialTheme.bgTop, AnexcialTheme.bgMid, AnexcialTheme.bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

struct AnexcialCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RadialGradient(colors: [Color.white.opacity(0.10), .clear],
                                   center: .topLeading, startRadius: 10, endRadius: 240)
                    AnexcialTheme.surface.opacity(0.92)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AnexcialTheme.border.opacity(0.85), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 22, x: 0, y: 14)
    }
}

struct MutedCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(16)
            .background(AnexcialTheme.surface.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AnexcialTheme.border.opacity(0.55), lineWidth: 1)
            )
    }
}

struct Badge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(2)
            .foregroundStyle(AnexcialTheme.muted)
    }
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.black.opacity(0.92))
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(colors: [
                    Color(red: 229/255, green: 231/255, blue: 235/255),
                    Color(red: 249/255, green: 250/255, blue: 251/255)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}

struct GhostCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(AnexcialTheme.surface.opacity(0.65))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AnexcialTheme.border.opacity(0.70), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
    }
}

struct FieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(2)
            .foregroundStyle(AnexcialTheme.muted)
    }
}

struct AnexcialTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FieldLabel(text: label)
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(AnexcialTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(AnexcialTextFieldStyle())
            }
        }
    }
}

struct AnexcialTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .background(AnexcialTheme.surface.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

struct ProgressBar: View {
    let value: Double // 0..1
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 99)
                    .fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: 99)
                    .fill(LinearGradient(colors: [AnexcialTheme.progressA, AnexcialTheme.progressB],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Models (sample data)

enum AppRole: String, CaseIterable, Identifiable {
    case member = "Member"
    case store = "Store"
    case admin = "Admin"
    var id: String { rawValue }
}

struct StoreSummary: Identifiable, Hashable {
    let id: Int
    let name: String
    let meta: String
    let points: Int
    let threshold: Int
    let rewardLabel: String
    var rewardAvailable: Bool { points >= threshold }
    var progress: Double { threshold == 0 ? 0 : Double(points) / Double(threshold) }
}

struct PointsHistoryRow: Identifiable {
    let id = UUID()
    let date: String
    let item: String
    let points: Int
}

struct InviteRow: Identifiable {
    let id = UUID()
    let code: String
    let status: String
    let note: String
}

struct StoreItemRow: Identifiable {
    let id = UUID()
    let name: String
    let points: Int
}

// MARK: - Root Shell

struct AnexcialIOSAppUI: View {
    @State private var signedInRole: AppRole? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AnexcialBackground()

                Group {
                    if let role = signedInRole {
                        switch role {
                        case .member: MemberShell(onLogout: { signedInRole = nil })
                        case .store:  StoreShell(onLogout: { signedInRole = nil })
                        case .admin:  AdminShell(onLogout: { signedInRole = nil })
                        }
                    } else {
                        LandingView(onSignIn: { signedInRole = $0 }, onSignUp: { signedInRole = $0 })
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}


// MARK: - Landing

struct LandingView: View {
    var onSignIn: (AppRole) -> Void
    var onSignUp: (AppRole) -> Void

    @State private var showAuth = false
    @State private var authMode: AuthMode = .signIn

    enum AuthMode { case signIn, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {

                AnexcialCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Neighbourhood loyalty, built for real regulars.")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)

                        Text("Anexcial is an invite-only loyalty system for local cafés, shops, and community spaces. Stores invite their regulars, members collect points with a simple QR code, and admins see how the whole ecosystem is growing.")
                            .font(.subheadline)
                            .foregroundStyle(AnexcialTheme.muted)

                        HStack(spacing: 10) {
                            Button(action: { authMode = .signIn; showAuth = true }) {
                                Text("Sign in")
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())

                            Button(action: { authMode = .signUp; showAuth = true }) {
                                Text("Sign up")
                            }
                            .buttonStyle(GhostCapsuleButtonStyle())
                        }

                        // Wrap badges so they look good on iPhone + iPad
                        ViewThatFits {
                            HStack(spacing: 8) {
                                Badge(text: "Members earn shared rewards")
                                Badge(text: "Stores understand real regulars")
                                Badge(text: "Admins oversee the network")
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Badge(text: "Members earn shared rewards")
                                Badge(text: "Stores understand real regulars")
                                Badge(text: "Admins oversee the network")
                            }
                        }
                        .padding(.top, 4)
                    }
                }

                MutedCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Who is Anexcial for?")
                                .font(.headline.weight(.medium))
                            Spacer()
                            Text("Three roles • One network")
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)
                        }

                        personaBlock(title: "Members", body: "Join by invite, collect points with your personal QR code, and redeem rewards with the places you actually visit.")
                        personaBlock(title: "Stores", body: "Invite your regulars, award points at the counter, and see how loyalty translates to real visits and redemptions.")
                        personaBlock(title: "Admins", body: "Oversee multiple neighbourhoods, monitor performance, and control who can join as a store or member.")

                        Text("Prototype focus: login, sign-up, and basic dashboards for each role.")
                            .font(.caption)
                            .foregroundStyle(AnexcialTheme.muted)
                    }
                }

                MutedCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("How Anexcial works")
                                .font(.headline.weight(.medium))
                            Spacer()
                            Text("End-to-end flow")
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            howStep("1. Admin onboards stores", "Approves new stores, configures rules, issues invite codes.")
                            howStep("2. Stores invite members", "Stores share invite links and set point values.")
                            howStep("3. Members scan & earn", "Members show QR at checkout and collect points.")
                            howStep("4. Rewards & insights", "Redeem rewards; stores/admins see growth over time.")
                        }
                        .font(.subheadline)
                    }
                }

                VStack(spacing: 12) {
                    marketingImageCard(assetName: "Cafe", title: "Loved by neighbourhood cafés", body: "Warm, familiar, trusted. Built for the places you actually return to.")
                    marketingImageCard(assetName: "Qr", title: "Effortless QR scanning", body: "No loyalty cards. No friction. Show QR → earn points.")
                    marketingImageCard(assetName: "Invite", title: "Invite-only community", body: "Membership feels personal. Every invite means something.")
                }

                Text("Anexcial iOS UI prototype • SwiftUI")
                    .font(.caption2)
                    .foregroundStyle(AnexcialTheme.muted)
                    .padding(.top, 8)
            }
            // This is the “make it feel like a real app on iPad” part:
            // give it a comfy max width instead of tiny phone width
            .frame(maxWidth: 820)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showAuth) {
            AuthSheet(mode: authMode, onDone: { role in
                showAuth = false
                if authMode == .signIn { onSignIn(role) }
                else { onSignUp(role) }
            })
        }
    }

    private func personaBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(AnexcialTheme.muted)
        }
    }

    private func howStep(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(body).foregroundStyle(AnexcialTheme.muted)
        }
    }

    private func marketingImageCard(assetName: String, title: String, body: String) -> some View {
        AnexcialCard {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    if UIImage(named: assetName) != nil {
                        Image(assetName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle().fill(Color.white.opacity(0.08))
                        Text("Add asset: \(assetName)")
                            .font(.caption)
                            .foregroundStyle(AnexcialTheme.muted)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(AnexcialTheme.muted)
            }
        }
    }
}

// MARK: - Auth Sheet (Sign in / Sign up)

struct AuthSheet: View {
    let mode: LandingView.AuthMode
    var onDone: (AppRole) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: AppRole = .member

    @State private var inviteCode = "DEMO123"
    @State private var storeName = ""
    @State private var neighbourhood = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            AnexcialBackground()

            VStack(spacing: 14) {
                AnexcialCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(mode == .signIn ? "Sign in" : "Create an account")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(mode == .signIn
                             ? "Choose how you’re signing in: member, store, or admin."
                             : "Members join by invite; stores onboard to reward regulars.")
                        .font(.subheadline)
                        .foregroundStyle(AnexcialTheme.muted)

                        Picker("Role", selection: $selectedRole) {
                            ForEach(mode == .signUp ? [.member, .store] : AppRole.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)

                        Divider().opacity(0.25)

                        if mode == .signUp {
                            if selectedRole == .member {
                                AnexcialTextField(label: "Invite code", placeholder: "Enter invite code", text: $inviteCode)
                                AnexcialTextField(label: "Email", placeholder: "you@example.com", text: $email)
                                AnexcialTextField(label: "Password", placeholder: "Create a password", text: $password, isSecure: true)
                                Text("Members must have a valid invite code from a participating store.")
                                    .font(.caption)
                                    .foregroundStyle(AnexcialTheme.muted)
                            } else {
                                AnexcialTextField(label: "Store name", placeholder: "Far’s Café", text: $storeName)
                                AnexcialTextField(label: "Business email", placeholder: "owner@yourcafe.com", text: $email)
                                AnexcialTextField(label: "Neighbourhood", placeholder: "Annex, Bloor St", text: $neighbourhood)
                                AnexcialTextField(label: "Password", placeholder: "Create a password", text: $password, isSecure: true)
                                Text("Store sign-ups may require admin approval before going live.")
                                    .font(.caption)
                                    .foregroundStyle(AnexcialTheme.muted)
                            }
                        } else {
                            AnexcialTextField(label: "\(selectedRole.rawValue) email (or username)",
                                              placeholder: "you@example.com or username",
                                              text: $email)
                            AnexcialTextField(label: "Password", placeholder: "Your password", text: $password, isSecure: true)

                            Text(hintForRole(selectedRole))
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                onDone(selectedRole)
                                dismiss()
                            }) {
                                Text(mode == .signIn ? "Continue" : "Create account")
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())

                            Button(action: { dismiss() }) {
                                Text("Cancel")
                            }
                            .buttonStyle(GhostCapsuleButtonStyle())
                        }
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(16)
        }
    }

    private func hintForRole(_ role: AppRole) -> String {
        switch role {
        case .member: return "Members see their joined stores, points, rewards, and personal QR code."
        case .store: return "Stores can invite members, award points, and monitor recent redemptions."
        case .admin: return "Admins manage stores, verify new stores, and oversee neighbourhood performance."
        }
    }
}

// MARK: - Member Flow

struct MemberShell: View {
    var onLogout: () -> Void

    @State private var stores: [StoreSummary] = [
        .init(id: 1, name: "Far’s Café", meta: "Bloor St W • Annex", points: 70, threshold: 100, rewardLabel: "Free pastry"),
        .init(id: 2, name: "Annex Books", meta: "Spadina • Annex", points: 120, threshold: 100, rewardLabel: "$5 off"),
        .init(id: 3, name: "Neighbour Market", meta: "Kensington-ish", points: 15, threshold: 50, rewardLabel: "Free coffee")
    ]

    @State private var showQR = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    ForEach(stores) { store in
                        NavigationLink(destination: MemberStoreDetailView(store: store)) {
                            StoreCard(store: store)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 6)

                Text("Sprint UI: member-facing layout, cards, and progress states.")
                    .font(.caption2)
                    .foregroundStyle(AnexcialTheme.muted)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 900)
            .padding(16)
            .padding(.bottom, 30)
        }
        .sheet(isPresented: $showQR) {
            MemberQRView(userUUID: UUID().uuidString)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("My stores & points")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                Text("Track points and rewards at every place you’ve joined.")
                    .font(.subheadline)
                    .foregroundStyle(AnexcialTheme.muted)
            }
            Spacer()
            Button(action: { showQR = true }) {
                Text("My QR")
            }
            .buttonStyle(GhostCapsuleButtonStyle())
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Logout", action: onLogout)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .offset(x: 0, y: -40)
        }
    }
}

struct StoreCard: View {
    let store: StoreSummary

    var body: some View {
        AnexcialCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(store.meta)
                        .font(.caption)
                        .foregroundStyle(AnexcialTheme.muted)
                }

                Text("Points: \(store.points)")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                if store.rewardAvailable {
                    Text("🎉 \(store.rewardLabel)")
                        .font(.caption)
                        .foregroundStyle(AnexcialTheme.good)
                } else {
                    Text("\(store.points) / \(store.threshold) to next reward")
                        .font(.caption)
                        .foregroundStyle(AnexcialTheme.muted)
                }

                ProgressBar(value: store.progress)

                HStack {
                    Text(store.rewardAvailable ? "Redeem available" : "Active member")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 2)
            }
        }
    }
}

struct MemberStoreDetailView: View {
    let store: StoreSummary

    @State private var history: [PointsHistoryRow] = [
        .init(date: "Feb 10", item: "Latte", points: 10),
        .init(date: "Feb 08", item: "Espresso", points: 8),
        .init(date: "Feb 01", item: "Pastry", points: 12)
    ]

    @State private var showRedeemAlert = false

    var body: some View {
        ZStack {
            AnexcialBackground()

            ScrollView {
                VStack(spacing: 14) {
                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.name)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Recent visits & points history (UI stub).")
                                .font(.subheadline)
                                .foregroundStyle(AnexcialTheme.muted)

                            if store.rewardAvailable {
                                Button("Redeem reward") { showRedeemAlert = true }
                                    .buttonStyle(PrimaryCapsuleButtonStyle())
                                    .padding(.top, 4)
                            }
                        }
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Points history")

                            VStack(spacing: 10) {
                                ForEach(history) { row in
                                    HStack {
                                        Text(row.date).foregroundStyle(.white.opacity(0.85))
                                        Spacer()
                                        Text(row.item).foregroundStyle(.white.opacity(0.85))
                                        Spacer()
                                        Text("\(row.points)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .font(.subheadline)
                                    .padding(.vertical, 6)

                                    Divider().opacity(0.12)
                                }
                            }
                        }
                    }

                    Text("Sprint MVP: stub details page to demonstrate navigation + layout.")
                        .font(.caption2)
                        .foregroundStyle(AnexcialTheme.muted)
                }
                .frame(maxWidth: 900)
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .alert("Redeem reward", isPresented: $showRedeemAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("UI demo: redemption flow would call the backend here.")
        }
    }
}

// MARK: - Member QR

struct MemberQRView: View {
    let userUUID: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        ZStack {
            AnexcialBackground()

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("My member QR")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("Show this code at participating stores to collect points on every visit.")
                        .font(.subheadline)
                        .foregroundStyle(AnexcialTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                AnexcialCard {
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                                .foregroundStyle(AnexcialTheme.border.opacity(0.8))
                                .background(AnexcialTheme.surface.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .frame(width: 240, height: 240)

                            if let img = qrImage(from: "member:\(userUUID)") {
                                Image(uiImage: img)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 210, height: 210)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            } else {
                                Text("QR unavailable")
                                    .font(.caption)
                                    .foregroundStyle(AnexcialTheme.muted)
                            }
                        }

                        Text("ID: \(userUUID)")
                            .font(.caption.monospaced())
                            .foregroundStyle(AnexcialTheme.muted)

                        Text("Present this QR at a participating store to earn points.")
                            .font(.caption)
                            .foregroundStyle(AnexcialTheme.muted)
                            .multilineTextAlignment(.center)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: 700)
            .padding(16)
        }
    }

    private func qrImage(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgimg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgimg)
    }
}

// MARK: - Store Flow

struct StoreShell: View {
    var onLogout: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Far’s Café – dashboard")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Quick view of members, points awarded, and redemptions this week.")
                            .font(.subheadline)
                            .foregroundStyle(AnexcialTheme.muted)
                    }
                    Spacer()
                    Menu {
                        Button("Logout", action: onLogout)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    KpiTile(label: "Members", value: "42")
                    KpiTile(label: "Points awarded (7d)", value: "1,280")
                    KpiTile(label: "Redemptions (7d)", value: "19")
                }

                MutedCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Today’s tools")
                                .font(.headline.weight(.medium))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("Store view")
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)
                        }

                        NavigationLink("Scan & award points") { StoreScanAwardView() }
                            .buttonStyle(PrimaryCapsuleButtonStyle())

                        NavigationLink("Manage invites") { StoreInvitesView() }
                            .buttonStyle(GhostCapsuleButtonStyle())

                        NavigationLink("Items & rules") { StoreItemsRulesView() }
                            .buttonStyle(GhostCapsuleButtonStyle())

                        Text("Prototype: numbers and actions are simulated for presentation.")
                            .font(.caption2)
                            .foregroundStyle(AnexcialTheme.muted)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(maxWidth: 900)
            .padding(16)
            .padding(.bottom, 30)
        }
    }
}

struct KpiTile: View {
    let label: String
    let value: String
    var body: some View {
        AnexcialCard {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: label)
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

// MARK: - Store Scan & Award

struct StoreScanAwardView: View {
    @State private var isCameraRunning = false
    @State private var scanStatus = "idle"

    @State private var payload = ""
    @State private var selectedItem = "Espresso"
    @State private var points = 10

    @State private var memberName: String? = nil
    @State private var memberUUID: String? = nil
    @State private var memberError: String? = nil
    @State private var isLookingUp = false

    private let items = ["Espresso", "Latte", "Cappuccino", "Pastry"]

    var body: some View {
        ZStack {
            AnexcialBackground()

            ScrollView {
                VStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan member QR")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("Use the store device camera to scan a member’s QR code. The payload will auto-fill the form.")
                            .font(.subheadline)
                            .foregroundStyle(AnexcialTheme.muted)
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                SectionLabel(text: "Camera scanner")
                                Spacer()

                                Button(action: {
                                    isCameraRunning.toggle()
                                    scanStatus = isCameraRunning ? "camera on — scanning…" : "idle"
                                }) {
                                    Text(isCameraRunning ? "Stop" : "Start camera")
                                }
                                .buttonStyle(
                                    isCameraRunning
                                    ? AnyButtonStyle(GhostCapsuleButtonStyle())
                                    : AnyButtonStyle(PrimaryCapsuleButtonStyle())
                                )

                            }

                            ZStack {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(AnexcialTheme.border.opacity(0.65), lineWidth: 1)
                                    )
                                    .frame(height: 320)

                                QRScannerView(isRunning: $isCameraRunning) { code in
                                    payload = code
                                    scanStatus = "scanned ✓ (payload filled)"
                                    lookupMember(for: code)
                                    isCameraRunning = false
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .frame(height: 320)
                                .opacity(isCameraRunning ? 1 : 0)

                                if !isCameraRunning {
                                    VStack(spacing: 8) {
                                        Image(systemName: "qrcode.viewfinder")
                                            .font(.system(size: 34, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.65))
                                        Text("Camera preview")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("Tap “Start camera” to scan.\n(If camera permission is off, use Simulate.)")
                                            .font(.caption)
                                            .foregroundStyle(AnexcialTheme.muted)
                                            .multilineTextAlignment(.center)

                                        Button(action: {
                                            let demo = "member:\(UUID().uuidString)"
                                            payload = demo
                                            scanStatus = "scanned ✓ (payload filled)"
                                            lookupMember(for: demo)
                                        }) {
                                            Text("Simulate scan")
                                        }
                                        .buttonStyle(GhostCapsuleButtonStyle())
                                        .padding(.top, 6)
                                    }
                                }
                            }

                            Text("Status: \(scanStatus)")
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)

                            Text("Tip: Member QR encodes member:<uuid>")
                                .font(.caption)
                                .foregroundStyle(AnexcialTheme.muted)
                        }
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "Award points")

                            AnexcialTextField(
                                label: "Scanned QR payload",
                                placeholder: "member:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
                                text: $payload
                            )

                            if isLookingUp {
                                Text("Looking up member…")
                                    .font(.caption)
                                    .foregroundStyle(AnexcialTheme.muted)
                            }

                            if let name = memberName, let uuid = memberUUID {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Member: \(name)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("(\(uuid))")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(AnexcialTheme.muted)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AnexcialTheme.border.opacity(0.7), lineWidth: 1)
                                )
                            }

                            if let err = memberError {
                                Text(err)
                                    .font(.caption)
                                    .foregroundStyle(Color.red.opacity(0.95))
                                    .padding(12)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "Item")
                                Picker("Item", selection: $selectedItem) {
                                    ForEach(items, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(AnexcialTheme.surface.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                FieldLabel(text: "Points")
                                Stepper(value: $points, in: 1...500) {
                                    Text("\(points)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                                .background(AnexcialTheme.surface.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            }

                            Button("Award points") {
                                scanStatus = "awarded (UI stub)"
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                            .padding(.top, 4)

                            Text("Sprint MVP: confirms member from QR payload; backend call can be added later.")
                                .font(.caption2)
                                .foregroundStyle(AnexcialTheme.muted)
                                .padding(.top, 2)
                        }
                    }
                }
                .frame(maxWidth: 900)
                .padding(16)
                .padding(.bottom, 30)
            }
        }
    }

    private func lookupMember(for payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        memberName = nil
        memberUUID = nil
        memberError = nil
        isLookingUp = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isLookingUp = false
            if trimmed.lowercased().hasPrefix("member:"), trimmed.count > 15 {
                memberName = "demo_member"
                memberUUID = String(trimmed.dropFirst("member:".count))
            } else {
                memberError = "Lookup failed. Expected format: member:<uuid>"
            }
        }
    }
}

// MARK: - Store Invites

struct StoreInvitesView: View {
    private let invites: [InviteRow] = [
        .init(code: "DEMO123", status: "Active", note: "Presentation invite"),
        .init(code: "ANNEX88", status: "Active", note: "Regulars"),
        .init(code: "OLD001", status: "Expired", note: "Old batch")
    ]

    var body: some View {
        ZStack {
            AnexcialBackground()

            ScrollView {
                VStack(spacing: 14) {
                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Manage invites")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Create and share invite codes (MVP stub for presentation).")
                                .font(.subheadline)
                                .foregroundStyle(AnexcialTheme.muted)
                        }
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Active invite codes")

                            ForEach(invites) { inv in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(inv.code).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        Spacer()
                                        Text(inv.status)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                    Text(inv.note)
                                        .font(.caption)
                                        .foregroundStyle(AnexcialTheme.muted)
                                }
                                .padding(.vertical, 8)

                                Divider().opacity(0.12)
                            }

                            Text("MVP note: invite generation + tracking will be database-backed later. For now, the system accepts DEMO123.")
                                .font(.caption2)
                                .foregroundStyle(AnexcialTheme.muted)
                                .padding(.top, 4)
                        }
                    }
                }
                .frame(maxWidth: 900)
                .padding(16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Store Items & Rules

struct StoreItemsRulesView: View {
    private let items: [StoreItemRow] = [
        .init(name: "Espresso", points: 8),
        .init(name: "Latte", points: 10),
        .init(name: "Cappuccino", points: 10),
        .init(name: "Pastry", points: 12)
    ]

    private let rules: [String] = [
        "Points are awarded per item purchase.",
        "One reward per threshold reached.",
        "Rewards are redeemed at checkout."
    ]

    var body: some View {
        ZStack {
            AnexcialBackground()

            ScrollView {
                VStack(spacing: 14) {
                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Items & rules")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Configure point values and reward rules (MVP display page).")
                                .font(.subheadline)
                                .foregroundStyle(AnexcialTheme.muted)
                        }
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Items")
                            ForEach(items) { item in
                                HStack {
                                    Text(item.name).foregroundStyle(.white.opacity(0.9))
                                    Spacer()
                                    Text("\(item.points)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                }
                                .padding(.vertical, 6)
                                Divider().opacity(0.12)
                            }
                            Text("MVP note: item editing can be enabled when the Items model is added.")
                                .font(.caption2)
                                .foregroundStyle(AnexcialTheme.muted)
                                .padding(.top, 2)
                        }
                    }

                    AnexcialCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "Rules")

                            ForEach(rules, id: \.self) { r in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("•").foregroundStyle(AnexcialTheme.muted)
                                    Text(r).foregroundStyle(.white.opacity(0.9))
                                }
                                .font(.subheadline)
                            }

                            MutedCard {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Current reward")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("100 points → Free pastry")
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.9))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .frame(maxWidth: 900)
                .padding(16)
                .padding(.bottom, 30)
            }
        }
    }
}

// MARK: - Admin Placeholder

struct AdminShell: View {
    var onLogout: () -> Void
    var body: some View {
        ZStack {
            AnexcialBackground()
            VStack(spacing: 14) {
                AnexcialCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Admin – overview")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("This is a placeholder iOS admin screen. Your web project relies on Django admin, so iOS just mirrors the role concept.")
                            .font(.subheadline)
                            .foregroundStyle(AnexcialTheme.muted)
                        Button("Logout", action: onLogout)
                            .buttonStyle(GhostCapsuleButtonStyle())
                            .padding(.top, 6)
                    }
                }
                Spacer()
            }
            .padding(16)
        }
    }
}

// MARK: - QR Scanner (AVFoundation)

struct QRScannerView: UIViewRepresentable {
    @Binding var isRunning: Bool
    var onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        context.coordinator.attachPreview(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.setRunning(isRunning)
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let session = AVCaptureSession()
        private let output = AVCaptureMetadataOutput()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private var didConfigure = false

        private let onCode: (String) -> Void
        private var lastScanAt: Date = .distantPast

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
            super.init()
            configureSession()
        }

        func attachPreview(to view: UIView) {
            if previewLayer == nil {
                let layer = AVCaptureVideoPreviewLayer(session: session)
                layer.videoGravity = .resizeAspectFill
                layer.frame = view.bounds
                view.layer.addSublayer(layer)
                previewLayer = layer
            }
            DispatchQueue.main.async {
                self.previewLayer?.frame = view.bounds
            }
        }

        private func configureSession() {
            guard !didConfigure else { return }
            didConfigure = true

            session.beginConfiguration()
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            if session.canAddOutput(output) {
                session.addOutput(output)
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                output.metadataObjectTypes = [.qr]
            }

            session.commitConfiguration()
        }

        func setRunning(_ running: Bool) {
            if running {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    guard granted else { return }
                    DispatchQueue.global(qos: .userInitiated).async {
                        if !self.session.isRunning { self.session.startRunning() }
                    }
                }
            } else {
                DispatchQueue.global(qos: .userInitiated).async {
                    if self.session.isRunning { self.session.stopRunning() }
                }
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard Date().timeIntervalSince(lastScanAt) > 1 else { return }

            if let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
               obj.type == .qr,
               let value = obj.stringValue {
                lastScanAt = Date()
                onCode(value)
            }
        }
    }
}
