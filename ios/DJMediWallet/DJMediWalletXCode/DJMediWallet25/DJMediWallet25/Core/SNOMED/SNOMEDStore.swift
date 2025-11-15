import Foundation
import SwiftData

@MainActor
final class SNOMEDStore {
    struct CategoryCount: Codable, Hashable {
        let category: String
        let count: Int
    }

    enum StoreError: Error {
        case invalidCSV
        case invalidEncoding
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func importCSV(from url: URL) async throws {
        let seeds = try await parseCSV(url: url)
        guard seeds.isEmpty == false else { return }

    let existing = try existingConceptsDictionary()

        for seed in seeds {
            if let concept = existing[seed.conceptId] {
                concept.term = seed.term
                concept.category = seed.category
                concept.lastUpdated = Date()
            } else {
                let concept = SNOMEDConcept(
                    conceptId: seed.conceptId,
                    term: seed.term,
                    category: seed.category,
                    lastUpdated: Date()
                )
                context.insert(concept)
            }
        }

        try context.save()
    }

    func concepts(matching query: String, category: String? = nil, limit: Int = 20) throws -> [SNOMEDConcept] {
        let sanitizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitizedQuery.isEmpty == false else { return [] }

        let predicate: Predicate<SNOMEDConcept>
        if let category, category.isEmpty == false {
            predicate = #Predicate { concept in
                concept.term.localizedStandardContains(sanitizedQuery) && concept.category == category
            }
        } else {
            predicate = #Predicate { concept in
                concept.term.localizedStandardContains(sanitizedQuery)
            }
        }

        var descriptor = FetchDescriptor<SNOMEDConcept>(predicate: predicate, sortBy: [SortDescriptor(\.term)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func categoriesWithCounts() throws -> [CategoryCount] {
        let descriptor = FetchDescriptor<SNOMEDConcept>(sortBy: [SortDescriptor(\.category)])
        let concepts = try context.fetch(descriptor)
        var counts: [String: Int] = [:]
        for concept in concepts {
            counts[concept.category, default: 0] += 1
        }
        return counts
            .map { CategoryCount(category: $0.key, count: $0.value) }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
    }

    func concept(withId conceptId: String) throws -> SNOMEDConcept? {
        var descriptor = FetchDescriptor<SNOMEDConcept>(predicate: #Predicate { $0.conceptId == conceptId })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func totalConcepts() throws -> Int {
        try context.fetchCount(FetchDescriptor<SNOMEDConcept>())
    }

    private func existingConceptsDictionary() throws -> [String: SNOMEDConcept] {
        let descriptor = FetchDescriptor<SNOMEDConcept>()
        let concepts = try context.fetch(descriptor)
        return Dictionary(uniqueKeysWithValues: concepts.map { ($0.conceptId, $0) })
    }

    private func parseCSV(url: URL) async throws -> [ConceptSeed] {
        try await Task.detached(priority: .utility) { () -> [ConceptSeed] in
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw StoreError.invalidEncoding
            }
            let lines = content.split(whereSeparator: { $0.isNewline })
            guard lines.isEmpty == false else { return [] }

            var seeds: [ConceptSeed] = []
            seeds.reserveCapacity(lines.count)

            for (index, rawLine) in lines.enumerated() {
                if index == 0 && rawLine.contains("concept_id") { continue }
                let parts = rawLine.split(separator: ",", omittingEmptySubsequences: false)
                guard parts.count >= 3 else { continue }
                let conceptId = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard conceptId.isEmpty == false else { continue }
                let term = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                let category = String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                seeds.append(ConceptSeed(conceptId: conceptId, term: term, category: category))
            }

            return seeds
        }.value
    }

    private struct ConceptSeed: Hashable {
        let conceptId: String
        let term: String
        let category: String
    }
}
