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
    typealias Completion = (Result<String, QRScannerError>) -> Void

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
        private var didEmitResult = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureCamera()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            previewLayer?.frame = view.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        private func configureCamera() {
            let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            switch authorizationStatus {
            case .authorized:
                setupSession()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        granted ? self.setupSession() : self.emit(.failure(.permissionDenied))
                    }
                }
            default:
                emit(.failure(.permissionDenied))
            }
        }

        private func setupSession() {
            guard let camera = AVCaptureDevice.default(for: .video) else {
                emit(.failure(.configurationFailed))
                return
            }

            session.beginConfiguration()

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if session.canAddInput(input) {
                    session.addInput(input)
                } else {
                    emit(.failure(.configurationFailed))
                    session.commitConfiguration()
                    return
                }
            } catch {
                emit(.failure(.configurationFailed))
                session.commitConfiguration()
                return
            }

            let metadataOutput = AVCaptureMetadataOutput()
            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            } else {
                emit(.failure(.configurationFailed))
                session.commitConfiguration()
                return
            }

            session.commitConfiguration()

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            session.startRunning()
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard didEmitResult == false,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let stringValue = metadataObject.stringValue else {
                return
            }

            didEmitResult = true
            emit(.success(stringValue))
        }

        private func emit(_ result: Result<String, QRScannerError>) {
            if session.isRunning {
                session.stopRunning()
            }
            onResult?(result)
            onResult = nil
        }
    }
}