import Foundation

actor SNOMEDStore {
    struct CategoryCount: Codable, Hashable, Sendable {
        let category: String
        let count: Int
    }

    enum StoreError: Error {
        case invalidCSV
        case invalidEncoding
        case persistenceFailure
    }

    private var conceptsById: [String: SNOMEDConcept] = [:]
    private let persistenceURL: URL?

    init(persistenceURL: URL? = nil) {
        self.persistenceURL = persistenceURL
        if let url = persistenceURL,
           let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            if let decoded = try? decoder.decode([String: SNOMEDConcept].self, from: data) {
                conceptsById = decoded
            }
        }
    }

    static func defaultPersistenceURL() -> URL {
        let fileManager = FileManager.default
        if let appSupport = try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) {
            return appSupport.appendingPathComponent("snomed_cache.json")
        }
        return fileManager.temporaryDirectory.appendingPathComponent("snomed_cache.json")
    }

    func importCSV(from url: URL) async throws {
        let seeds = try await parseCSV(url: url)
        guard seeds.isEmpty == false else { return }

        let timestamp = Date()
        for seed in seeds {
            if var concept = conceptsById[seed.conceptId] {
                concept.term = seed.term
                concept.category = seed.category
                concept.lastUpdated = timestamp
                conceptsById[seed.conceptId] = concept
            } else {
                let concept = SNOMEDConcept(conceptId: seed.conceptId, term: seed.term, category: seed.category, lastUpdated: timestamp)
                conceptsById[seed.conceptId] = concept
            }
        }

        try persistIfNeeded()
    }

    func concepts(matching query: String, category: String? = nil, limit: Int = 20) -> [SNOMEDConcept] {
        let sanitizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sanitizedQuery.isEmpty == false else { return [] }

        let lowercasedQuery = sanitizedQuery.lowercased()
        var matches = conceptsById.values.filter { concept in
            let matchesTerm = concept.term.lowercased().contains(lowercasedQuery)
            if let category, category.isEmpty == false {
                return matchesTerm && concept.category.caseInsensitiveCompare(category) == .orderedSame
            }
            return matchesTerm
        }
        matches.sort { $0.term.localizedCaseInsensitiveCompare($1.term) == .orderedAscending }
        if limit > 0 && matches.count > limit {
            matches = Array(matches.prefix(limit))
        }
        return matches
    }

    func categoriesWithCounts() -> [CategoryCount] {
        var counts: [String: Int] = [:]
        for concept in conceptsById.values {
            counts[concept.category, default: 0] += 1
        }
        return counts
            .map { CategoryCount(category: $0.key, count: $0.value) }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
    }

    func concept(withId conceptId: String) -> SNOMEDConcept? {
        conceptsById[conceptId]
    }

    func totalConcepts() -> Int {
        conceptsById.count
    }

    private func persistIfNeeded() throws {
        guard let url = persistenceURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(conceptsById)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try data.write(to: url, options: .atomic)
        } catch {
            throw StoreError.persistenceFailure
        }
    }

    private func parseCSV(url: URL) async throws -> [ConceptSeed] {
        try await Task.detached(priority: .utility) {
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

    private struct ConceptSeed: Hashable, Sendable {
        let conceptId: String
        let term: String
        let category: String
    }
}

extension SNOMEDStore.StoreError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidCSV:
            return "The selected file is not a valid SNOMED CSV export."
        case .invalidEncoding:
            return "The SNOMED data could not be read using UTF-8 encoding."
        case .persistenceFailure:
            return "DJ Medi Wallet could not save the imported SNOMED data."
        }
    }
}
