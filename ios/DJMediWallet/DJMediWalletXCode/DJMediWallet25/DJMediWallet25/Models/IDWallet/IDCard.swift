import Foundation

struct IDCard: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var number: String
    var category: String
    var region: String?
    var isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        number: String,
        category: String,
        region: String? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.number = number
        self.category = category
        self.region = region
        self.isDefault = isDefault
    }
}
