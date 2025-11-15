import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct QRCodeRenderer {
    private static let context = CIContext()

    static func image(for payload: String, scale: CGFloat = 6.0, margin: CGFloat = 2.0) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let padded = transformed.transformed(by: CGAffineTransform(translationX: margin, y: margin))
        guard let cgImage = context.createCGImage(padded, from: padded.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
