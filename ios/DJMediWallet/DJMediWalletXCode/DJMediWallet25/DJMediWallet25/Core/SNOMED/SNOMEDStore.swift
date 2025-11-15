import Foundation
import GRDB

actor SNOMEDStore {
    struct CategoryCount: Codable, Hashable {
        let category: String
        let count: Int
    }

    enum StoreError: Error {
        case invalidCSV
        case databaseUnavailable
    }

    private let dbQueue: DatabaseQueue

    init(databaseURL: URL) throws {
        dbQueue = try DatabaseQueue(path: databaseURL.path)
        try migrator.migrate(dbQueue)
    }

    func importCSV(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw StoreError.invalidCSV
        }
        let lines = content.split(whereSeparator: { $0.isNewline })
        guard lines.isEmpty == false else { return }

        try await dbQueue.write { db in
            for (index, rawLine) in lines.enumerated() {
                if index == 0 && rawLine.contains("concept_id") {
                    continue
                }
                let parts = rawLine.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count >= 3 else { continue }
                let conceptId = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                if conceptId.isEmpty { continue }
                let term = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                let category = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                let record = SNOMEDConcept(conceptId: conceptId, term: term, category: category)
                try record.upsert(db)
            }
        }
    }

    func concepts(matching query: String, category: String? = nil, limit: Int = 20) async throws -> [SNOMEDConcept] {
        try await dbQueue.read { db in
            var request = SNOMEDConcept
                .filter(sql: "term LIKE ?", arguments: ["%\(query)%"])
                .order(SNOMEDConcept.Columns.term.asc)
                .limit(limit)
            if let category {
                request = request.filter(SNOMEDConcept.Columns.category == category)
            }
            return try request.fetchAll(db)
        }
    }

    func categoriesWithCounts() async throws -> [CategoryCount] {
        try await dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: "SELECT category, COUNT(*) AS count FROM snomed_concepts GROUP BY category ORDER BY category ASC")
            return rows.map { row in
                CategoryCount(category: row["category"], count: row["count"])
            }
        }
    }

    func concept(withId conceptId: String) async throws -> SNOMEDConcept? {
        try await dbQueue.read { db in
            try SNOMEDConcept.fetchOne(db, key: conceptId)
        }
    }

    func totalConcepts() async throws -> Int {
        try await dbQueue.read { db in
            try SNOMEDConcept.fetchCount(db)
        }
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createSNOMEDConcepts") { db in
            try db.create(table: SNOMEDConcept.databaseTableName) { table in
                table.column("concept_id", .text).primaryKey(onConflict: .replace)
                table.column("term", .text).notNull()
                table.column("category", .text).notNull()
                table.column("last_updated", .datetime).notNull().defaults(to: Date())
                table.index(["term"])
                table.index(["category"])
            }
        }
        return migrator
    }
}
