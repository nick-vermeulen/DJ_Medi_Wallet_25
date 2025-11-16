//
//  QRScannerView.swift
//  DJMediWallet25
//
//  SwiftUI bridge for QR code scanning using AVFoundation.
//

import AVFoundation
import SwiftUI

enum QRScannerError: LocalizedError {
    case permissionDenied
    case configurationFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access is required to scan verification requests."
        case .configurationFailed:
            return "Unable to configure the camera for scanning."
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    enum ScanDecision {
        case continueScanning
        case finish
    }

    typealias Completion = (Result<String, QRScannerError>) -> ScanDecision

    let completion: Completion

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onResult = completion
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onResult: Completion?

        private let session = AVCaptureSession()
        private var previewLayer: AVCaptureVideoPreviewLayer?
        private let metadataOutput = AVCaptureMetadataOutput()
        private let overlayLayer = CAShapeLayer()
        private let focusBorderLayer = CAShapeLayer()
        private let instructionBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        private let instructionLabel: UILabel = {
            let label = UILabel()
            label.text = "Align the QR code within the frame"
            label.textColor = .white
            label.font = .preferredFont(forTextStyle: .callout)
            label.textAlignment = .center
            label.numberOfLines = 0
            return label
        }()
        private var isHandlingResult = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureInstructionView()
            configureCamera()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            isHandlingResult = false
            if session.isRunning == false {
                session.startRunning()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
            instructionBackground.frame = instructionFrame(for: view.bounds)
            instructionLabel.frame = instructionBackground.contentView.bounds.insetBy(dx: 12, dy: 8)
            updateOverlay()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        private func configureInstructionView() {
            instructionBackground.layer.cornerRadius = 12
            instructionBackground.layer.masksToBounds = true
            instructionBackground.layer.zPosition = 10
            instructionBackground.contentView.addSubview(instructionLabel)
            view.addSubview(instructionBackground)
        }

        private func configureCamera() {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            switch authorizationStatus {
            case .authorized:
                setupSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        granted ? self.setupSession() : self.emitFailure(.permissionDenied)
                    }
                }
            default:
                emitFailure(.permissionDenied)
            }
        }

        private func setupSession() {
            guard let camera = AVCaptureDevice.default(for: .video) else {
                emitFailure(.configurationFailed)
                return
            }

            session.beginConfiguration()

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    emitFailure(.configurationFailed)
                    session.commitConfiguration()
                    return
                }
            } catch {
                emitFailure(.configurationFailed)
                session.commitConfiguration()
                return
            }

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                emitFailure(.configurationFailed)
                session.commitConfiguration()
                return
            }

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            updateOverlay()

            session.startRunning()
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard isHandlingResult == false,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let stringValue = metadataObject.stringValue else {
                return
            }

            isHandlingResult = true
            session.stopRunning()

            let decision = onResult?(.success(stringValue)) ?? .finish
            handle(decision)
        }

        private func emitFailure(_ error: QRScannerError) {
            if session.isRunning {
                session.stopRunning()
            }
            let decision = onResult?(.failure(error)) ?? .finish
            handle(decision)
        }

        private func handle(_ decision: ScanDecision) {
            switch decision {
            case .finish:
                onResult = nil
                isHandlingResult = false
            case .continueScanning:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self else { return }
                    self.isHandlingResult = false
                    if self.onResult != nil {
                        if self.session.isRunning == false {
                            self.session.startRunning()
                        }
                    }
                }
            }
        }

        private func updateOverlay() {
            guard let previewLayer else { return }
            let bounds = view.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            let squareSize = min(bounds.width, bounds.height) * 0.6
            let focusRect = CGRect(
                x: (bounds.width - squareSize) / 2,
                y: (bounds.height - squareSize) / 2,
                width: squareSize,
                height: squareSize
            )

            let path = UIBezierPath(rect: bounds)
            let cutoutPath = UIBezierPath(roundedRect: focusRect, cornerRadius: 20)
            path.append(cutoutPath)
            path.usesEvenOddFillRule = true

            overlayLayer.path = path.cgPath
            overlayLayer.fillRule = .evenOdd
            overlayLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
            overlayLayer.frame = bounds
            overlayLayer.zPosition = 2

            if overlayLayer.superlayer == nil {
                view.layer.addSublayer(overlayLayer)
            }

            focusBorderLayer.path = UIBezierPath(roundedRect: focusRect, cornerRadius: 20).cgPath
            focusBorderLayer.fillColor = UIColor.clear.cgColor
            focusBorderLayer.strokeColor = UIColor.systemGreen.cgColor
            focusBorderLayer.lineWidth = 3
            focusBorderLayer.frame = bounds
            focusBorderLayer.zPosition = 3

            if focusBorderLayer.superlayer == nil {
                view.layer.addSublayer(focusBorderLayer)
            }

            let convertedRect = previewLayer.metadataOutputRectConverted(fromLayerRect: focusRect)
            metadataOutput.rectOfInterest = convertedRect
        }

        private func instructionFrame(for bounds: CGRect) -> CGRect {
            let width = min(bounds.width * 0.85, 320)
            let height: CGFloat = 56
            let originX = (bounds.width - width) / 2
            let originY = max(bounds.maxY - height - 32, bounds.minY + 24)
            return CGRect(x: originX, y: originY, width: width, height: height)
        }
    }
}