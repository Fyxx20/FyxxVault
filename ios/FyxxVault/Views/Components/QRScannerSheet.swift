import SwiftUI
import AVFoundation

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScanned: (String) -> Void
    @State private var scannedValue = ""

    var body: some View {
        ZStack {
            #if canImport(UIKit)
            QRScannerRepresentable { value in scannedValue = value; onScanned(value); dismiss() }.ignoresSafeArea()
            #else
            FVAnimatedBackground()
            #endif
            LinearGradient(colors: [.black.opacity(0.72), .black.opacity(0.1), .black.opacity(0.72)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack { Button(String(localized: "common.close")) { dismiss() }.font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(FVColor.cyanLight); Spacer() }
                    .padding(.horizontal, 20).padding(.top, 6)
                VStack(spacing: 6) {
                    Text(String(localized: "qr.scanner.title")).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(String(localized: "qr.scanner.instruction")).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.82))
                }
                Spacer()
                RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(FVColor.cyanLight.opacity(0.9), lineWidth: 2).frame(width: 250, height: 250)
                Spacer()
            }
        }
    }
}

#if canImport(UIKit)
struct QRScannerRepresentable: UIViewControllerRepresentable {
    var onCodeScanned: (String) -> Void
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController(); vc.onCodeScanned = onCodeScanned; return vc
    }
    func updateUIViewController(_ vc: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasEmittedCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        session.sessionPreset = .high
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }
        session.addInput(input)
        if camera.isFocusModeSupported(.continuousAutoFocus) {
            try? camera.lockForConfiguration()
            camera.focusMode = .continuousAutoFocus
            if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
            camera.unlockForConfiguration()
        }
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill; preview.frame = view.bounds
        view.layer.addSublayer(preview); previewLayer = preview
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasEmittedCode = false
        if !session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() } }
    }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); previewLayer?.frame = view.bounds }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning { DispatchQueue.global(qos: .userInitiated).async { self.session.stopRunning() } }
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasEmittedCode, let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let code = obj.stringValue else { return }
        hasEmittedCode = true; session.stopRunning(); onCodeScanned?(code)
    }
}
#endif
