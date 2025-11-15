import Foundation
import Combine

@MainActor
final class SNOMEDService: ObservableObject {
    @Published private(set) var categories: [SNOMEDStore.CategoryCount] = []
    @Published private(set) var importStatus: ImportStatus = .idle

    enum ImportStatus: Equatable {
        case idle
        case importing
        case completed(total: Int)
        case failed(String)
    }

    private let store: SNOMEDStore

    init(store: SNOMEDStore) {
        self.store = store
    }

    func refreshCategories() async {
        do {
            categories = try await store.categoriesWithCounts()
        } catch {
            categories = []
        }
    }

    func search(term: String, category: String? = nil, limit: Int = 20) async -> [SNOMEDConcept] {
        do {
            return try await store.concepts(matching: term, category: category, limit: limit)
        } catch {
            return []
        }
    }

    func importCSV(from url: URL) {
        Task {
            importStatus = .importing
            do {
                try await store.importCSV(from: url)
                let total = try await store.totalConcepts()
                importStatus = .completed(total: total)
                await refreshCategories()
            } catch {
                importStatus = .failed(error.localizedDescription)
            }
        }
    }

    func concept(withId conceptId: String) async -> SNOMEDConcept? {
        do {
            return try await store.concept(withId: conceptId)
        } catch {
            return nil
        }
    }
}
