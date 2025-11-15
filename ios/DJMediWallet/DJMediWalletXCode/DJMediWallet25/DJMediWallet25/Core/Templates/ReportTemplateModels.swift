import Foundation
import SwiftData

@Model
final class ReportTemplate {
    @Attribute(.unique) var identifier: String
    var title: String
    var category: String
    var summary: String
    var payloadJSON: String
    var createdAt: Date
    var updatedAt: Date

    init(identifier: String, title: String, category: String, summary: String, payloadJSON: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.identifier = identifier
        self.title = title
        self.category = category
        self.summary = summary
        self.payloadJSON = payloadJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ExamPreset {
    @Attribute(.unique) var identifier: String
    var name: String
    var category: String
    var defaultObservations: Data
    var createdAt: Date
    var updatedAt: Date

    init(identifier: String, name: String, category: String, defaultObservations: Data, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.identifier = identifier
        self.name = name
        self.category = category
        self.defaultObservations = defaultObservations
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
