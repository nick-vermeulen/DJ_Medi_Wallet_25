import Foundation

struct SNOMEDConcept: Codable, Hashable, Identifiable, Sendable {
    let conceptId: String
    var term: String
    var category: String
    var lastUpdated: Date

    var id: String { conceptId }

    init(conceptId: String, term: String, category: String, lastUpdated: Date = Date()) {
        self.conceptId = conceptId
        self.term = term
        self.category = category
        self.lastUpdated = lastUpdated
    }
}
