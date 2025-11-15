import Foundation
import SwiftUI
import Combine

@MainActor
final class ExamQRViewModel: ObservableObject {
    struct ObservationDraft: Identifiable {
        enum ValueMode: String, CaseIterable, Identifiable {
            case numeric = "Numeric"
            case boolean = "Yes/No"
            case text = "Text"

            var id: String { rawValue }

            init(presetType: ObservationPreset.ValueType) {
                switch presetType {
                case .numeric:
                    self = .numeric
                case .boolean:
                    self = .boolean
                case .text:
                    self = .text
                }
            }
        }

        let id: UUID
        var concept: SNOMEDConcept?
        var searchTerm: String
        var searchResults: [SNOMEDConcept]
        var valueMode: ValueMode
        var numericValue: String
        var unit: String
        var booleanValue: Bool
        var textValue: String
        var observationDate: Date

        init(id: UUID = UUID()) {
            self.id = id
            concept = nil
            searchTerm = ""
            searchResults = []
            valueMode = .numeric
            numericValue = ""
            unit = ""
            booleanValue = true
            textValue = ""
            observationDate = Date()
        }
    }

    @Published var drafts: [ObservationDraft]
    @Published var result: QRGenerationResult?
    @Published var errorMessage: String?

    private let snomed: SNOMEDService
    private let payloadBuilder: FHIRPayloadBuilder

    init(snomed: SNOMEDService, payloadBuilder: FHIRPayloadBuilder) {
        self.snomed = snomed
        self.payloadBuilder = payloadBuilder
        drafts = [ObservationDraft()]
    }

    func addDraft() {
        drafts.append(ObservationDraft())
    }

    func removeDraft(_ draft: ObservationDraft) {
        drafts.removeAll { $0.id == draft.id }
    }

    func applyPreset(_ preset: ExamPreset) {
        guard let presets = try? JSONDecoder().decode([ObservationPreset].self, from: preset.defaultObservations) else {
            return
        }
        var newDrafts: [ObservationDraft] = []
        for preset in presets {
            var draft = ObservationDraft(id: preset.id)
            draft.searchTerm = preset.displayName
            draft.unit = preset.unit ?? ""
            draft.valueMode = ObservationDraft.ValueMode(presetType: preset.valueType)
            draft.textValue = preset.defaultValue ?? ""
            draft.numericValue = preset.defaultValue ?? ""
            newDrafts.append(draft)
        }
        drafts = newDrafts
        for preset in presets {
            Task { [weak self] in
                guard let self, let concept = await self.snomed.concept(withId: preset.conceptId) else { return }
                await MainActor.run {
                    if let index = self.drafts.firstIndex(where: { $0.id == preset.id }) {
                        self.drafts[index].concept = concept
                        self.drafts[index].searchTerm = concept.term
                    }
                }
            }
        }
    }

    func updateSearchTerm(_ term: String, for draftID: ObservationDraft.ID) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].searchTerm = term
        drafts[index].searchResults = []
        guard term.count >= 3 else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard let self else { return }
            let results = await snomed.search(term: term)
            await MainActor.run {
                if let idx = self.drafts.firstIndex(where: { $0.id == draftID }) {
                    self.drafts[idx].searchResults = results
                }
            }
        }
    }

    func selectConcept(_ concept: SNOMEDConcept, for draftID: ObservationDraft.ID) {
        guard let index = drafts.firstIndex(where: { $0.id == draftID }) else { return }
        drafts[index].concept = concept
        drafts[index].searchTerm = concept.term
        drafts[index].searchResults = []
    }

    func generate(subject: Reference?) {
        errorMessage = nil
        do {
            let inputs = try drafts.compactMap { try observationInput(for: $0) }
            let bundle = payloadBuilder.examBundle(subject: subject, observations: inputs)
            let payload = try PayloadEncoder.encode(bundle)
            guard let image = QRCodeRenderer.image(for: payload) else {
                throw ValidationError.qrEncodingFailed
            }
            result = QRGenerationResult(payload: payload, image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observationInput(for draft: ObservationDraft) throws -> FHIRObservationInput? {
        guard let concept = draft.concept else {
            throw ValidationError.missingConcept
        }
        let value: FHIRObservationInput.ObservationValue
        switch draft.valueMode {
        case .numeric:
            guard let numeric = Double(draft.numericValue) else {
                throw ValidationError.invalidNumeric
            }
            value = .quantity(value: numeric, unit: draft.unit.isEmpty ? nil : draft.unit, system: "http://unitsofmeasure.org", code: nil)
        case .boolean:
            value = .boolean(draft.booleanValue)
        case .text:
            guard draft.textValue.isEmpty == false else {
                throw ValidationError.missingText
            }
            value = .text(draft.textValue)
        }
        let code = CodeableConcept(
            coding: [Coding(system: "http://snomed.info/sct", code: concept.conceptId, display: concept.term)],
            text: concept.term
        )
        let category = concept.category.isEmpty ? nil : [CodeableConcept(coding: nil, text: concept.category)]
        return FHIRObservationInput(
            id: draft.id,
            code: code,
            value: value,
            effectiveDate: draft.observationDate,
            category: category
        )
    }

    enum ValidationError: LocalizedError {
        case missingConcept
        case invalidNumeric
        case missingText
        case qrEncodingFailed

        var errorDescription: String? {
            switch self {
            case .missingConcept:
                return "Each observation needs a SNOMED concept."
            case .invalidNumeric:
                return "Provide valid numeric values for all numeric observations."
            case .missingText:
                return "Provide text values for text observations."
            case .qrEncodingFailed:
                return "Unable to render the QR code."
            }
        }
    }
}
