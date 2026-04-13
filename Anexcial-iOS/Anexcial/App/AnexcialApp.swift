import SwiftUI

@main
struct AnexcialApp: App {
    @StateObject private var auth = AuthState()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}
