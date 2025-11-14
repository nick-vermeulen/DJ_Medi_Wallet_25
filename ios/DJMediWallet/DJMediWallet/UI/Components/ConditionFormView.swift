//
//  ConditionFormView.swift
//  DJMediWallet
//
//  Form for entering diagnoses/conditions with SNOMED CT codes
//

import SwiftUI

struct ConditionFormView: View {
    let onSave: (Condition) -> Void
    @Binding var isSaving: Bool
    
    @State private var selectedCondition = ""
    @State private var selectedSeverity = "Moderate"
    @State private var notes = ""
    
    // Common conditions with SNOMED CT codes
    private let conditions: [(name: String, code: String)] = [
        ("Hypertension", "38341003"),
        ("Diabetes Mellitus Type 2", "44054006"),
        ("Asthma", "195967001"),
        ("Atrial Fibrillation", "49436004"),
        ("Chronic Obstructive Pulmonary Disease", "13645005"),
        ("Myocardial Infarction", "22298006"),
        ("Hyperlipidemia", "55822004"),
        ("Osteoarthritis", "396275006"),
        ("Depression", "35489007"),
        ("Anxiety Disorder", "197480006")
    ]
    
    private let severities = ["Mild", "Moderate", "Severe"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Diagnosis / Condition")
                .font(.headline)
            
            // Condition Picker
            VStack(alignment: .leading) {
                Text("Select Condition")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Condition", selection: $selectedCondition) {
                    Text("Select...").tag("")
                    ForEach(conditions, id: \.code) { condition in
                        VStack(alignment: .leading) {
                            Text(condition.name)
                            Text("SNOMED: \(condition.code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(condition.name)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedCode = conditions.first(where: { $0.name == selectedCondition })?.code {
                    Text("SNOMED CT: \(selectedCode)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Severity Picker
            VStack(alignment: .leading) {
                Text("Severity")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Severity", selection: $selectedSeverity) {
                    ForEach(severities, id: \.self) { severity in
                        Text(severity).tag(severity)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Notes
            VStack(alignment: .leading) {
                Text("Additional Notes (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $notes)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            // Save Button
            Button(action: handleSave) {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save Record")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || selectedCondition.isEmpty)
        }
    }
    
    private func handleSave() {
        guard let condition = conditions.first(where: { $0.name == selectedCondition }) else {
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: Date())
        
        let severityCode: String
        switch selectedSeverity {
        case "Mild":
            severityCode = "255604002"
        case "Moderate":
            severityCode = "6736007"
        case "Severe":
            severityCode = "24484000"
        default:
            severityCode = "6736007"
        }
        
        let conditionResource = Condition(
            id: UUID().uuidString,
            clinicalStatus: CodeableConcept(
                coding: [
                    Coding(
                        system: "http://terminology.hl7.org/CodeSystem/condition-clinical",
                        code: "active",
                        display: "Active"
                    )
                ]
            ),
            verificationStatus: CodeableConcept(
                coding: [
                    Coding(
                        system: "http://terminology.hl7.org/CodeSystem/condition-ver-status",
                        code: "confirmed",
                        display: "Confirmed"
                    )
                ]
            ),
            category: [
                CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://terminology.hl7.org/CodeSystem/condition-category",
                            code: "encounter-diagnosis",
                            display: "Encounter Diagnosis"
                        )
                    ]
                )
            ],
            severity: CodeableConcept(
                coding: [
                    Coding(
                        system: "http://snomed.info/sct",
                        code: severityCode,
                        display: selectedSeverity
                    )
                ]
            ),
            code: CodeableConcept(
                coding: [
                    Coding(
                        system: "http://snomed.info/sct",
                        code: condition.code,
                        display: condition.name
                    )
                ],
                text: condition.name
            ),
            subject: Reference(
                reference: "Patient/self",
                display: "Self"
            ),
            onsetDateTime: dateString,
            recordedDate: dateString,
            note: notes.isEmpty ? nil : [Annotation(text: notes)]
        )
        
        onSave(conditionResource)
    }
}
