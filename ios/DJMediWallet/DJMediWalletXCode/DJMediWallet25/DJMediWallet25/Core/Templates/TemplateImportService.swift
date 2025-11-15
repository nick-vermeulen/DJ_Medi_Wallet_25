import Foundation
import SwiftData

@MainActor
struct TemplateImportService {
    enum ImportError: Error {
        case unsupportedFormat
        case decodingFailed
    }

    let context: ModelContext

    func importFile(at url: URL) throws {
        switch url.pathExtension.lowercased() {
        case "json":
            try importTemplatesJSON(url: url)
        case "sql":
            try importExamSQL(url: url)
        default:
            throw ImportError.unsupportedFormat
        }
    }

    private func importTemplatesJSON(url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([TemplateRecord].self, from: data)
        for record in records {
            let template: ReportTemplate
            if let existing = fetchTemplate(identifier: record.identifier) {
                template = existing
            } else {
                template = ReportTemplate(
                    identifier: record.identifier,
                    title: record.title,
                    category: record.category,
                    summary: record.summary,
                    payloadJSON: record.payloadJSON,
                    createdAt: record.createdAt,
                    updatedAt: record.updatedAt ?? record.createdAt
                )
                context.insert(template)
            }
            template.title = record.title
            template.category = record.category
            template.summary = record.summary
            template.payloadJSON = record.payloadJSON
            template.updatedAt = record.updatedAt ?? Date()
        }
        try context.save()
    }

    private func importExamSQL(url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let statements = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        for statement in statements where statement.lowercased().hasPrefix("insert") {
            guard let valuesRange = statement.range(of: "VALUES", options: .caseInsensitive) else { continue }
            let valuesPart = statement[valuesRange.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " ()"))
            let tokens = valuesPart.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "' \"")) }
            guard tokens.count >= 4 else { continue }
            let identifier = tokens[0]
            let name = tokens[1]
            let category = tokens[2]
            let payload = tokens[3]
            let data = Data(payload.utf8)
            let preset: ExamPreset
            if let existing = fetchPreset(identifier: identifier) {
                preset = existing
            } else {
                preset = ExamPreset(identifier: identifier, name: name, category: category, defaultObservations: data)
                context.insert(preset)
            }
            preset.name = name
            preset.category = category
            preset.defaultObservations = data
            preset.updatedAt = Date()
        }
        try context.save()
    }

    private func fetchTemplate(identifier: String) -> ReportTemplate? {
        let descriptor = FetchDescriptor<ReportTemplate>(predicate: #Predicate { $0.identifier == identifier })
        return try? context.fetch(descriptor).first
    }

    private func fetchPreset(identifier: String) -> ExamPreset? {
        let descriptor = FetchDescriptor<ExamPreset>(predicate: #Predicate { $0.identifier == identifier })
        return try? context.fetch(descriptor).first
    }

    private struct TemplateRecord: Codable {
        let identifier: String
        let title: String
        let category: String
        let summary: String
        let payloadJSON: String
        let createdAt: Date
        let updatedAt: Date?
    }
}
