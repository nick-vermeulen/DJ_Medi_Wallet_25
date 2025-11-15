//
//  AddRecordView.swift
//  DJMediWallet
//
//  View for adding new medical records
//

import SwiftUI

enum RecordType: String, CaseIterable {
    case observation = "Vital Signs"
    case condition = "Diagnosis"
    case medication = "Medication"
    
    var iconName: String {
        switch self {
        case .observation:
            return "heart.text.square.fill"
        case .condition:
            return "cross.case.fill"
        case .medication:
            return "pills.fill"
        }
    }
}

struct AddRecordView: View {
    @EnvironmentObject var walletManager: WalletManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: RecordType = .observation
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var didSaveSuccessfully = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Record Type Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Record Type")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(RecordType.allCases, id: \.self) { type in
                                RecordTypeButton(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Dynamic Form Based on Type
                    switch selectedType {
                    case .observation:
                        ObservationFormView(
                            onSave: saveObservation,
                            isSaving: $isSaving
                        )
                    case .condition:
                        ConditionFormView(
                            onSave: saveCondition,
                            isSaving: $isSaving
                        )
                    case .medication:
                        MedicationFormView(
                            onSave: saveMedication,
                            isSaving: $isSaving
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Add Medical Record")
            .alert("Save Status", isPresented: $showAlert) {
                Button("OK", role: .cancel) {
                    if didSaveSuccessfully {
                        didSaveSuccessfully = false
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveObservation(_ observation: Observation) {
        let credential = MedicalCredential(
            id: observation.id ?? UUID().uuidString,
            type: "Observation",
            issuer: "Self-reported",
            issuanceDate: Date(),
            fhirResource: FHIRResource(resourceType: "Observation", id: observation.id, data: observation.toDictionary())
        )
        
        performSave(for: credential)
    }
    
    private func saveCondition(_ condition: Condition) {
        let credential = MedicalCredential(
            id: condition.id ?? UUID().uuidString,
            type: "Condition",
            issuer: "Self-reported",
            issuanceDate: Date(),
            fhirResource: FHIRResource(resourceType: "Condition", id: condition.id, data: condition.toDictionary())
        )
        
        performSave(for: credential)
    }
    
    private func saveMedication(_ medication: MedicationStatement) {
        let credential = MedicalCredential(
            id: medication.id ?? UUID().uuidString,
            type: "MedicationStatement",
            issuer: "Self-reported",
            issuanceDate: Date(),
            fhirResource: FHIRResource(resourceType: "MedicationStatement", id: medication.id, data: medication.toDictionary())
        )
        
        performSave(for: credential)
    }

    private func performSave(for credential: MedicalCredential) {
        isSaving = true
        walletManager.addCredential(credential) { result in
            DispatchQueue.main.async {
                isSaving = false
                handleSaveResult(result)
            }
        }
    }

    private func handleSaveResult(_ result: Result<Void, Error>) {
        switch result {
        case .success:
            alertMessage = "Record saved successfully!"
            didSaveSuccessfully = true
        case .failure(let error):
            alertMessage = "Failed to save: \(error.localizedDescription)"
            didSaveSuccessfully = false
        }
        showAlert = true
    }
}

struct RecordTypeButton: View {
    let type: RecordType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title2)
                Text(type.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// Helper extensions for converting FHIR models to dictionaries
extension Observation {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "resourceType": resourceType,
            "status": status,
            "code": code.toDictionary()
        ]
        
        if let id = id { dict["id"] = id }
        if let category = category { dict["category"] = category.map { $0.toDictionary() } }
        if let subject = subject { dict["subject"] = subject.toDictionary() }
        if let effectiveDateTime = effectiveDateTime { dict["effectiveDateTime"] = effectiveDateTime }
        if let valueQuantity = valueQuantity { dict["valueQuantity"] = valueQuantity.toDictionary() }
        if let component = component { dict["component"] = component.map { $0.toDictionary() } }
        if let note = note { dict["note"] = note.map { $0.toDictionary() } }
        
        return dict
    }
}

extension Condition {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "resourceType": resourceType,
            "code": code.toDictionary(),
            "subject": subject.toDictionary()
        ]
        
        if let id = id { dict["id"] = id }
        if let clinicalStatus = clinicalStatus { dict["clinicalStatus"] = clinicalStatus.toDictionary() }
        if let severity = severity { dict["severity"] = severity.toDictionary() }
        if let onsetDateTime = onsetDateTime { dict["onsetDateTime"] = onsetDateTime }
        if let note = note { dict["note"] = note.map { $0.toDictionary() } }
        
        return dict
    }
}

extension MedicationStatement {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "resourceType": resourceType,
            "status": status,
            "subject": subject.toDictionary()
        ]
        
        if let id = id { dict["id"] = id }
        if let medicationCodeableConcept = medicationCodeableConcept {
            dict["medicationCodeableConcept"] = medicationCodeableConcept.toDictionary()
        }
        if let effectiveDateTime = effectiveDateTime { dict["effectiveDateTime"] = effectiveDateTime }
        if let dosage = dosage { dict["dosage"] = dosage.map { $0.toDictionary() } }
        if let note = note { dict["note"] = note.map { $0.toDictionary() } }
        
        return dict
    }
}

extension CodeableConcept {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let coding = coding { dict["coding"] = coding.map { $0.toDictionary() } }
        if let text = text { dict["text"] = text }
        return dict
    }
}

extension Coding {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let system = system { dict["system"] = system }
        if let code = code { dict["code"] = code }
        if let display = display { dict["display"] = display }
        return dict
    }
}

extension Quantity {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let value = value { dict["value"] = value }
        if let unit = unit { dict["unit"] = unit }
        if let system = system { dict["system"] = system }
        if let code = code { dict["code"] = code }
        return dict
    }
}

extension Reference {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let reference = reference { dict["reference"] = reference }
        if let display = display { dict["display"] = display }
        return dict
    }
}

extension ObservationComponent {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["code": code.toDictionary()]
        if let valueQuantity = valueQuantity { dict["valueQuantity"] = valueQuantity.toDictionary() }
        return dict
    }
}

extension Annotation {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["text": text]
        if let authorString = authorString { dict["authorString"] = authorString }
        return dict
    }
}

extension Dosage {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let text = text { dict["text"] = text }
        if let route = route { dict["route"] = route.toDictionary() }
        return dict
    }
}

#Preview {
    AddRecordView()
        .environmentObject(WalletManager.shared)
}
