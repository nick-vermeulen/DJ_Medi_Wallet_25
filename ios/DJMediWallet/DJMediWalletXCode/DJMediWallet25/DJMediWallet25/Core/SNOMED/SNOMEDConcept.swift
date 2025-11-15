import Foundation
import GRDB

struct SNOMEDConcept: FetchableRecord, PersistableRecord, Codable, Identifiable {
    static let databaseTableName = "snomed_concepts"

    let conceptId: String
    var term: String
    var category: String
    var lastUpdated: Date

    var id: String { conceptId }

    enum Columns {
        static let conceptId = Column("concept_id")
        static let term = Column("term")
        static let category = Column("category")
        static let lastUpdated = Column("last_updated")
    }

    init(conceptId: String, term: String, category: String, lastUpdated: Date = Date()) {
        self.conceptId = conceptId
        self.term = term
        self.category = category
        self.lastUpdated = lastUpdated
    }

    init(row: Row) {
        conceptId = row[Columns.conceptId]
        term = row[Columns.term]
        category = row[Columns.category]
        lastUpdated = row[Columns.lastUpdated]
    }

    func encode(to container: inout PersistenceContainer) {
        container[Columns.conceptId] = conceptId
        container[Columns.term] = term
        container[Columns.category] = category
        container[Columns.lastUpdated] = lastUpdated
    }
}
