import SwiftUI
#if os(iOS)
@preconcurrency import AVFoundation
#endif

struct BarcodeScannerSheetView: View {
    let theme: EcoTheme
    let onCodeScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var permissionStatus: PermissionStatus = .checking
    @State private var scannerError: String?

    var body: some View {
        ZStack {
            theme.screenGradient.ignoresSafeArea()

            VStack(spacing: 18) {
                header

                scannerBody
                    .padding(.horizontal, 20)

                helperText
                    .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.top, 20)
        }
        .task {
            await updatePermissionState()
        }
    }

    private var header: some View {
        HStack {
            Button {
                HapticsService.tap()
                dismiss()
            } label: {
                Text("✕")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .ecoCardStyle(theme: theme, cornerRadius: 12)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Scan Barcode")
                .font(.headline.weight(.heavy))
                .foregroundStyle(theme.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var scannerBody: some View {
        switch permissionStatus {
        case .checking:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 360)
                .ecoCardStyle(theme: theme, cornerRadius: 24)
        case .granted:
            #if os(iOS)
            BarcodeCameraView { code in
                HapticsService.success()
                onCodeScanned(code)
                dismiss()
            } onError: { errorDescription in
                scannerError = errorDescription
                permissionStatus = .error
            }
            .frame(maxWidth: .infinity, minHeight: 360)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(theme.borderColor, lineWidth: 1)
            }
            #else
            unsupportedView("Scanner works on iPhone only.")
            #endif
        case .denied:
            unsupportedView("Camera permission denied. Enable it in Settings.")
        case .unsupported:
            unsupportedView("Camera is not available on this device.")
        case .error:
            unsupportedView(scannerError ?? "Scanner could not start.")
        }
    }

    private var helperText: some View {
        Text("Point camera at product barcode. We’ll map it to your fridge items automatically.")
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(theme.secondaryText)
    }

    private func unsupportedView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .ecoCardStyle(theme: theme, cornerRadius: 24)
    }

    private func updatePermissionState() async {
        #if os(iOS)
        guard AVCaptureDevice.default(for: .video) != nil else {
            permissionStatus = .unsupported
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionStatus = .granted
        case .notDetermined:
            let granted = await requestCameraAccess()
            permissionStatus = granted ? .granted : .denied
        case .denied, .restricted:
            permissionStatus = .denied
        @unknown default:
            permissionStatus = .error
        }
        #else
        permissionStatus = .unsupported
        #endif
    }

    #if os(iOS)
    private func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    #endif
}

private enum PermissionStatus {
    case checking
    case granted
    case denied
    case unsupported
    case error
}

#if os(iOS)
private struct BarcodeCameraView: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> BarcodeCameraCoordinator {
        BarcodeCameraCoordinator(onCodeScanned: onCodeScanned, onError: onError)
    }

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        context.coordinator.attachPreview(view)
        return view
    }

    func updateUIView(_ uiView: ScannerPreviewView, context: Context) {
        context.coordinator.attachPreview(uiView)
    }

    static func dismantleUIView(_ uiView: ScannerPreviewView, coordinator: BarcodeCameraCoordinator) {
        coordinator.stopSession()
    }
}

private final class BarcodeCameraCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "ecochef.barcode.session")
    private let desiredMetadataTypes: [AVMetadataObject.ObjectType] = [
        .ean13, .ean8, .upce, .code128, .code39, .qr
    ]
    private var didScan = false
    private let onCodeScanned: (String) -> Void
    private let onError: (String) -> Void
    private var isConfigured = false

    init(
        onCodeScanned: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onCodeScanned = onCodeScanned
        self.onError = onError
        super.init()
    }

    func attachPreview(_ previewView: ScannerPreviewView) {
        previewView.previewLayer.videoGravity = .resizeAspectFill
        previewView.previewLayer.session = session

        guard !isConfigured else {
            queue.async { [weak self] in
                guard let self else { return }
                guard !self.session.isRunning else { return }
                self.didScan = false
                self.session.startRunning()
            }
            return
        }
        didScan = false
        configureSession()
    }

    func stopSession() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfigured else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard
                let captureDevice = AVCaptureDevice.default(for: .video),
                let input = try? AVCaptureDeviceInput(device: captureDevice),
                self.session.canAddInput(input)
            else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.onError("Camera input unavailable.")
                }
                return
            }
            self.session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard self.session.canAddOutput(output) else {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.onError("Metadata output unavailable.")
                }
                return
            }
            self.session.addOutput(output)

            // Set delegate on the main actor to satisfy main-actor-isolated conformance usage.
            Task { @MainActor in
                output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

                let supportedTypes = self.desiredMetadataTypes.filter {
                    output.availableMetadataObjectTypes.contains($0)
                }
                guard !supportedTypes.isEmpty else {
                    // Commit configuration back on the queue, then report error on main.
                    self.queue.async { [weak self] in
                        guard let self else { return }
                        self.session.commitConfiguration()
                        Task { @MainActor in
                            self.onError("No supported barcode types on this device.")
                        }
                    }
                    return
                }
                output.metadataObjectTypes = supportedTypes

                // Finish configuration and start session on the private queue.
                self.queue.async { [weak self] in
                    guard let self else { return }
                    // Mark configured on the main actor to respect isolation.
                    Task { @MainActor [weak self] in
                        self?.isConfigured = true
                    }
                    self.session.commitConfiguration()
                    self.session.startRunning()
                }
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            let code = object.stringValue
        else { return }

        didScan = true
        onCodeScanned(code)
        stopSession()
    }
}

private final class ScannerPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
#endif
