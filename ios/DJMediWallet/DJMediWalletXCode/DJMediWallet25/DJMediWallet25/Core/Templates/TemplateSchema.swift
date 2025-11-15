import Foundation

struct ObservationPreset: Codable, Hashable, Identifiable {
    var id: UUID
    var conceptId: String
    var displayName: String
    var category: String?
    var defaultValue: String?
    var unit: String?
    var valueType: ValueType

    init(
        id: UUID = UUID(),
        conceptId: String,
        displayName: String,
        category: String? = nil,
        defaultValue: String? = nil,
        unit: String? = nil,
        valueType: ValueType = .numeric
    ) {
        self.id = id
        self.conceptId = conceptId
        self.displayName = displayName
        self.category = category
        self.defaultValue = defaultValue
        self.unit = unit
        self.valueType = valueType
    }

    enum ValueType: String, Codable {
        case numeric
        case boolean
        case text
    }
}

struct TemplatePayload: Codable {
    var reportCode: String
    var reportDisplay: String
    var observations: [ObservationPreset]
}
