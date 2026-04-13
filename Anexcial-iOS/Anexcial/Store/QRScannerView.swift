import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var noticeStack: UIStackView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        #if targetEnvironment(simulator)
        installNotice(
            title: "Simulator has no camera",
            message: "The iOS Simulator does not provide a live camera preview, so this screen stays black even when capture starts.\n\nTest QR scanning on a physical iPhone, or type a member payload (for example member:…) in the text field on the scan screen."
        )
        return
        #endif

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureCaptureSession()
                    } else {
                        self.installNotice(
                            title: "Camera access needed",
                            message: "Anexcial needs the camera to read member QR codes. You can enable it in Settings ▸ Anexcial ▸ Camera, or enter the member payload manually on the previous screen."
                        )
                    }
                }
            }
        case .denied, .restricted:
            installNotice(
                title: "Camera is off",
                message: "Turn on camera access in Settings ▸ Anexcial, or use the manual payload field on the scan screen."
            )
        @unknown default:
            installNotice(
                title: "Camera unavailable",
                message: "This device cannot use the camera for scanning right now. Enter the member QR payload manually instead."
            )
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureCaptureSession() {
        captureSession = AVCaptureSession()
        guard let session = captureSession else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            installNotice(
                title: "No camera found",
                message: "This device does not have a usable back camera. Enter the member payload manually."
            )
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            installNotice(
                title: "Scanner unavailable",
                message: "Could not start QR detection on this device. Use the manual payload field instead."
            )
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        output.metadataObjectTypes = [.qr]
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        if let pl = previewLayer {
            view.layer.insertSublayer(pl, at: 0)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func installNotice(title: String, message: String) {
        noticeStack?.removeFromSuperview()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .preferredFont(forTextStyle: .title2).bold()
        titleLabel.numberOfLines = 0

        let body = UILabel()
        body.text = message
        body.textColor = UIColor(white: 0.75, alpha: 1)
        body.font = .preferredFont(forTextStyle: .subheadline)
        body.numberOfLines = 0

        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        close.tintColor = UIColor(red: 0xe0 / 255, green: 0xa4 / 255, blue: 0x58 / 255, alpha: 1)
        close.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        }, for: .touchUpInside)

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(body)
        stack.addArrangedSubview(close)
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
        ])
        noticeStack = stack
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue else { return }
        captureSession?.stopRunning()
        onScan?(str)
    }
}

private extension UIFont {
    func bold() -> UIFont {
        UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor, size: pointSize)
    }
}
