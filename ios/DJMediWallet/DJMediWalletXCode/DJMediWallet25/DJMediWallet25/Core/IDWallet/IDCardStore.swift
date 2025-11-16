import Foundation
import Combine

final class IDCardStore: ObservableObject {
    @Published var cards: [IDCard] = []
    @Published var categories: [String] = IDCardStore.defaultCategories
    @Published var locationPromptsEnabled: Bool

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let cardsKey = "idCards"
    private static let categoriesKey = "categories"
    private static let locationKey = "idCardLocationEnabled"

    static let defaultCategories: [String] = [
        "Healthcare",
        "Loyalty Cards",
        "Memberships",
        "Insurance"
    ]

    init(userDefaults: UserDefaults = .standard) {
        defaults = userDefaults
        let storedLocation = defaults.object(forKey: Self.locationKey) as? Bool
        locationPromptsEnabled = storedLocation ?? true
        loadStoredCards()
        loadStoredCategories()

        $cards
            .dropFirst()
            .sink { [weak self] _ in self?.persistCards() }
            .store(in: &cancellables)

        $categories
            .dropFirst()
            .sink { [weak self] _ in self?.persistCategories() }
            .store(in: &cancellables)

        $locationPromptsEnabled
            .dropFirst()
            .sink { [weak self] newValue in self?.persistLocationSetting(newValue) }
            .store(in: &cancellables)
    }

    func upsert(_ card: IDCard) {
        var updatedCards = cards

        if let index = updatedCards.firstIndex(where: { $0.id == card.id }) {
            updatedCards[index] = card
        } else {
            updatedCards.append(card)
        }

        if card.isDefault {
            updatedCards = updatedCards.map { existing in
                var existingCard = existing
                if existingCard.category == card.category {
                    existingCard.isDefault = existingCard.id == card.id
                }
                return existingCard
            }
        }

        ensureCategoryExists(card.category)
        cards = sortCards(updatedCards)
    }

    func delete(_ card: IDCard) {
        cards.removeAll { $0.id == card.id }
    }

    func addCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard categories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) == false else { return }
        categories.append(trimmed)
        categories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func removeCategory(_ name: String) {
        categories.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        cards.removeAll { $0.category.caseInsensitiveCompare(name) == .orderedSame }
        if categories.isEmpty {
            categories = IDCardStore.defaultCategories
        }
    }

    func defaultCard(in category: String) -> IDCard? {
        cards.first { $0.category.caseInsensitiveCompare(category) == .orderedSame && $0.isDefault }
    }

    func cards(in category: String) -> [IDCard] {
        cards.filter { $0.category.caseInsensitiveCompare(category) == .orderedSame }
    }

    private func loadStoredCards() {
        guard let data = defaults.data(forKey: Self.cardsKey),
              !data.isEmpty,
              let decoded = try? Self.decoder.decode([IDCard].self, from: data) else {
            cards = []
            return
        }
        cards = sortCards(decoded)
    }

    private func loadStoredCategories() {
        guard let data = defaults.data(forKey: Self.categoriesKey),
              !data.isEmpty,
              let decoded = try? Self.decoder.decode([String].self, from: data),
              decoded.isEmpty == false else {
            categories = IDCardStore.defaultCategories
            return
        }
        categories = decoded
    }

    private func persistCards() {
        guard let encoded = try? Self.encoder.encode(cards) else { return }
        defaults.set(encoded, forKey: Self.cardsKey)
    }

    private func persistCategories() {
        guard let encoded = try? Self.encoder.encode(categories) else { return }
        defaults.set(encoded, forKey: Self.categoriesKey)
    }

    private func persistLocationSetting(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.locationKey)
    }

    private func ensureCategoryExists(_ name: String) {
        guard categories.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) == false else { return }
        categories.append(name)
        categories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func sortCards(_ cards: [IDCard]) -> [IDCard] {
        cards.sorted { lhs, rhs in
            if lhs.category.caseInsensitiveCompare(rhs.category) == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
        }
    }
}
