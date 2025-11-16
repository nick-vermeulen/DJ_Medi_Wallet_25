import SwiftUI
import VisionKit

@available(iOS 17.0, *)
struct IDCardScannerView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: IDCardScannerView

        init(parent: IDCardScannerView) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(items: addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle(items: [item])
        }

        private func handle(items: [RecognizedItem]) {
            for item in items {
                switch item {
                case .barcode(let barcode):
                    if let payload = barcode.payloadStringValue {
                        DispatchQueue.main.async { self.parent.scannedBarcodeHandler(payload) }
                    }
                case .text(let text):
                    let value = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard value.isEmpty == false else { continue }
                    DispatchQueue.main.async { self.parent.scannedTextHandler(value) }
                @unknown default:
                    break
                }
            }
        }
    }

    var recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType>
    var isScanning: Bool
    var scannedBarcodeHandler: (String) -> Void
    var scannedTextHandler: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: recognizedDataTypes,
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }
}
