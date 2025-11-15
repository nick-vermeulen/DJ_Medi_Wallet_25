import Foundation

struct FHIRObservationInput: Identifiable {
    let id: UUID
    var code: CodeableConcept
    var value: ObservationValue
    var effectiveDate: Date
    var performer: Reference?
    var category: [CodeableConcept]?
    var interpretation: [CodeableConcept]?
    var note: String?

    init(
        id: UUID = UUID(),
        code: CodeableConcept,
        value: ObservationValue,
        effectiveDate: Date = Date(),
        performer: Reference? = nil,
        category: [CodeableConcept]? = nil,
        interpretation: [CodeableConcept]? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.code = code
        self.value = value
        self.effectiveDate = effectiveDate
        self.performer = performer
        self.category = category
        self.interpretation = interpretation
        self.note = note
    }

    enum ObservationValue: Hashable {
        case quantity(value: Double, unit: String?, system: String?, code: String?)
        case text(String)
        case boolean(Bool)
    }
}

struct FHIRDiagnosticReportInput {
    var code: CodeableConcept
    var subject: Reference?
    var issued: Date
    var conclusion: String?
    var performer: [Reference]?
    var observations: [FHIRObservationInput]
}

struct FHIRPayloadBuilder {
    private let dateFormatter: ISO8601DateFormatter

    init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func observationBundle(subject: Reference?, observation: FHIRObservationInput) -> FHIRBundle {
        let resources = makeObservationResource(subject: subject, input: observation)
        let entry = BundleEntry(fullUrl: "urn:uuid:\(resources.id ?? UUID().uuidString)", resource: .observation(resources))
        return FHIRBundle(entry: [entry])
    }

    func examBundle(subject: Reference?, observations: [FHIRObservationInput]) -> FHIRBundle {
        let entries = observations.map { input -> BundleEntry in
            let observation = makeObservationResource(subject: subject, input: input)
            return BundleEntry(fullUrl: "urn:uuid:\(observation.id ?? UUID().uuidString)", resource: .observation(observation))
        }
        return FHIRBundle(type: "collection", entry: entries)
    }

    func diagnosticReportBundle(subject: Reference?, report: FHIRDiagnosticReportInput) -> FHIRBundle {
        let observationEntries = report.observations.map { input -> (FHIRObservation, BundleEntry) in
            let resource = makeObservationResource(subject: subject, input: input)
            let entry = BundleEntry(fullUrl: "urn:uuid:\(resource.id ?? UUID().uuidString)", resource: .observation(resource))
            return (resource, entry)
        }
        let observationRefs = observationEntries.map { resource, _ in
            Reference(reference: "Observation/\(resource.id ?? "")")
        }
        let reportResource = DiagnosticReport(
            status: "final",
            code: report.code,
            subject: subject,
            effectiveDateTime: dateFormatter.string(from: report.issued),
            issued: dateFormatter.string(from: report.issued),
            performer: report.performer,
            result: observationRefs,
            conclusion: report.conclusion
        )
        let reportEntry = BundleEntry(fullUrl: "urn:uuid:\(reportResource.id ?? UUID().uuidString)", resource: .diagnosticReport(reportResource))
        let entries = observationEntries.map { $0.1 } + [reportEntry]
        return FHIRBundle(type: "collection", entry: entries)
    }

    private func makeObservationResource(subject: Reference?, input: FHIRObservationInput) -> FHIRObservation {
        let valueQuantity: Quantity?
        let valueString: String?
        let valueBoolean: Bool?
        switch input.value {
        case .quantity(let value, let unit, let system, let code):
            valueQuantity = Quantity(value: value, unit: unit, system: system, code: code)
            valueString = nil
            valueBoolean = nil
        case .text(let text):
            valueQuantity = nil
            valueString = text
            valueBoolean = nil
        case .boolean(let bool):
            valueQuantity = nil
            valueString = nil
            valueBoolean = bool
        }
        return FHIRObservation(
            id: input.id.uuidString,
            status: "final",
            category: input.category,
            code: input.code,
            subject: subject,
            effectiveDateTime: dateFormatter.string(from: input.effectiveDate),
            issued: dateFormatter.string(from: input.effectiveDate),
            valueQuantity: valueQuantity,
            valueString: valueString,
            valueBoolean: valueBoolean,
            interpretation: input.interpretation,
            note: input.note.map { [Annotation(text: $0)] }
        )
    }
}
