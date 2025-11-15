import Foundation
import UIKit

struct QRGenerationResult: Identifiable {
    let id: UUID
    let payload: String
    let image: UIImage

    init(id: UUID = UUID(), payload: String, image: UIImage) {
        self.id = id
        self.payload = payload
        self.image = image
    }
}
