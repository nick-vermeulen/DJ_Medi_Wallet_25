import Foundation
import SwiftUI
import Combine

@MainActor
final class SingleObservationQRViewModel: ObservableObject {
    enum ValueMode: String, CaseIterable, Identifiable {
        case numeric = "Numeric"
        case boolean = "Yes/No"
        case text = "Text"

        var id: String { rawValue }
    }

    @Published var selectedConcept: SNOMEDConcept?
    @Published var searchTerm: String = ""
    @Published var searchResults: [SNOMEDConcept] = []
    @Published var numericValue: String = ""
    @Published var unit: String = ""
    @Published var booleanValue: Bool = true
    @Published var textValue: String = ""
    @Published var observationDate: Date = Date()
    @Published var valueMode: ValueMode = .numeric
    @Published var result: QRGenerationResult?
    @Published var errorMessage: String?

    private let snomed: SNOMEDService
    private let payloadBuilder: FHIRPayloadBuilder

    private var searchTask: Task<Void, Never>?

    init(snomed: SNOMEDService, payloadBuilder: FHIRPayloadBuilder) {
        self.snomed = snomed
        self.payloadBuilder = payloadBuilder
    }

    func updateSearchTerm(_ term: String) {
        searchTask?.cancel()
        searchTerm = term
        guard term.count >= 3 else {
            searchResults = []
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }
            let results = await snomed.search(term: term)
            self.searchResults = results
        }
    }

    func selectConcept(_ concept: SNOMEDConcept) {
        selectedConcept = concept
        unit = unit.isEmpty ? concept.category : unit
        searchResults = []
        searchTerm = concept.term
    }

    func generate(subject: Reference?) {
        errorMessage = nil
        do {
            guard let concept = selectedConcept else {
                throw ValidationError.missingConcept
            }
            let value = try observationValue()
            let code = CodeableConcept(
                coding: [Coding(system: "http://snomed.info/sct", code: concept.conceptId, display: concept.term)],
                text: concept.term
            )
            let category = concept.category.isEmpty ? nil : [CodeableConcept(coding: nil, text: concept.category)]
            let input = FHIRObservationInput(
                code: code,
                value: value,
                effectiveDate: observationDate,
                category: category
            )
            let bundle = payloadBuilder.observationBundle(subject: subject, observation: input)
            let payload = try PayloadEncoder.encode(bundle)
            guard let image = QRCodeRenderer.image(for: payload) else {
                throw ValidationError.qrEncodingFailed
            }
            result = QRGenerationResult(payload: payload, image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observationValue() throws -> FHIRObservationInput.ObservationValue {
        switch valueMode {
        case .numeric:
            guard let value = Double(numericValue) else {
                throw ValidationError.invalidNumeric
            }
            return .quantity(value: value, unit: unit.isEmpty ? nil : unit, system: "http://unitsofmeasure.org", code: nil)
        case .boolean:
            return .boolean(booleanValue)
        case .text:
            guard textValue.isEmpty == false else {
                throw ValidationError.missingText
            }
            return .text(textValue)
        }
    }

    enum ValidationError: LocalizedError {
        case missingConcept
        case invalidNumeric
        case missingText
        case qrEncodingFailed

        var errorDescription: String? {
            switch self {
            case .missingConcept:
                return "Choose a SNOMED concept before generating the QR code."
            case .invalidNumeric:
                return "Enter a valid numeric value."
            case .missingText:
                return "Provide a text value."
            case .qrEncodingFailed:
                return "Unable to render the QR code."
            }
        }
    }
}
