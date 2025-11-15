import Foundation
import SwiftData

@Model
final class SNOMEDConcept {
    @Attribute(.unique) var conceptId: String
    var term: String
    var category: String
    var lastUpdated: Date

    init(conceptId: String, term: String, category: String, lastUpdated: Date = Date()) {
        self.conceptId = conceptId
        self.term = term
        self.category = category
        self.lastUpdated = lastUpdated
    }
}
