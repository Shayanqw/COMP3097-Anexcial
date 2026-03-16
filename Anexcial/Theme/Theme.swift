import SwiftUI

enum Theme {
    static let background = Color(red: 0x17/255, green: 0x12/255, blue: 0x0f/255)
    static let surface = Color(red: 0x1f/255, green: 0x16/255, blue: 0x12/255)
    static let text = Color(red: 0xf6/255, green: 0xef/255, blue: 0xe8/255)
    static let muted = Color(red: 0xcc/255, green: 0xbf/255, blue: 0xb1/255)
    static let accent = Color(red: 0xe0/255, green: 0xa4/255, blue: 0x58/255)
    static let success = Color(red: 0x7e/255, green: 0xcf/255, blue: 0x9f/255)
    static let danger = Color(red: 0xef/255, green: 0x8e/255, blue: 0x7d/255)
}

struct RoleBadge: View {
    let role: String

    var body: some View {
        Text(role)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.accent)
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.background)
    }
}
