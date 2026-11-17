import AVFoundation
import SwiftUI

struct PreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool
    var onFocus: (CGPoint, CGPoint) -> Void
    var onCaptureRotation: (CGFloat) -> Void

    func makeUIView(context: Context) -> PreviewHost {
        let view = PreviewHost()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        view.onFocus = onFocus
        view.onCaptureRotation = onCaptureRotation
        view.mirrored = mirrored
        return view
    }

    func updateUIView(_ uiView: PreviewHost, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
        uiView.onFocus = onFocus
        uiView.onCaptureRotation = onCaptureRotation
        uiView.mirrored = mirrored
        uiView.refreshRotation()
    }
}

final class PreviewHost: UIView {
    var onFocus: ((CGPoint, CGPoint) -> Void)?
    var onCaptureRotation: ((CGFloat) -> Void)?
    var mirrored = false

    private var coordinator: AVCaptureDevice.RotationCoordinator?
    private var coordinatedDeviceID: String?
    private var previewObservation: NSKeyValueObservation?
    private var captureObservation: NSKeyValueObservation?

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refreshRotation()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshRotation()
    }

    func refreshRotation() {
        guard window != nil else { return }
        guard let device = previewLayer.session?.inputs
            .compactMap({ $0 as? AVCaptureDeviceInput })
            .map(\.device)
            .first(where: { $0.hasMediaType(.video) }) else { return }
        if coordinatedDeviceID != device.uniqueID || coordinator == nil {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
            self.coordinator = coordinator
            coordinatedDeviceID = device.uniqueID
            previewObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] coordinator, _ in
                self?.apply(
                    preview: coordinator.videoRotationAngleForHorizonLevelPreview,
                    capture: coordinator.videoRotationAngleForHorizonLevelCapture
                )
            }
            captureObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.new]) { [weak self] coordinator, _ in
                self?.apply(
                    preview: coordinator.videoRotationAngleForHorizonLevelPreview,
                    capture: coordinator.videoRotationAngleForHorizonLevelCapture
                )
            }
        }
        guard let coordinator else { return }
        apply(
            preview: coordinator.videoRotationAngleForHorizonLevelPreview,
            capture: coordinator.videoRotationAngleForHorizonLevelCapture
        )
    }

    private func apply(preview: CGFloat, capture: CGFloat) {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
        if connection.isVideoRotationAngleSupported(preview) {
            connection.videoRotationAngle = preview
        }
        onCaptureRotation?(capture)
    }

    @objc private func handleTap(_ tap: UITapGestureRecognizer) {
        let viewPoint = tap.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
        onFocus?(devicePoint, viewPoint)
    }
}
