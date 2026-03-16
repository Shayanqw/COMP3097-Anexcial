import SwiftUI
import CoreImage.CIFilterBuiltins

struct MemberQRView: View {
    @State private var memberUUID: String?
    @State private var qrPayload: String?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let uuid = memberUUID, let payload = qrPayload {
                    VStack(spacing: 24) {
                        Text("Show this code at participating stores to collect points on every visit.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        if let img = qrImage(from: payload) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 220, height: 220)
                                .padding()
                        }
                        Text("ID: \(uuid)")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                        Text("Present this QR at a participating store to earn points.")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(errorMessage ?? "Failed to load QR")
                        .foregroundStyle(Theme.danger)
                }
            }
            .background(Theme.background)
            .navigationTitle("My member QR")
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let client = APIClient()
            let res: MemberQRResponse = try await client.request("member/qr/")
            memberUUID = res.member_uuid
            qrPayload = res.qr_payload
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func qrImage(from string: String) -> UIImage? {
        let data = Data(string.utf8)
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
