//
//  MedicationFormView.swift
//  DJMediWallet
//
//  Form for entering medications with SNOMED CT codes
//

import SwiftUI

struct MedicationFormView: View {
    let onSave: (MedicationStatement) -> Void
    @Binding var isSaving: Bool
    
    @State private var selectedMedication = ""
    @State private var dosage = ""
    @State private var frequency = "Once daily"
    @State private var route = "Oral"
    @State private var notes = ""
    
    // Common medications with SNOMED CT codes
    private let medications: [(name: String, code: String)] = [
        ("Metformin", "109081006"),
        ("Aspirin", "387458008"),
        ("Lisinopril", "386873009"),
        ("Atorvastatin", "373444002"),
        ("Levothyroxine", "126202002"),
        ("Metoprolol", "372826007"),
        ("Amlodipine", "386864001"),
        ("Omeprazole", "387137007"),
        ("Simvastatin", "387584000"),
        ("Losartan", "386876004"),
        ("Albuterol", "372897005"),
        ("Gabapentin", "386845007")
    ]
    
    private let frequencies = [
        "Once daily",
        "Twice daily",
        "Three times daily",
        "Four times daily",
        "As needed",
        "Every morning",
        "Every evening",
        "Weekly"
    ]
    
    private let routes = [
        "Oral",
        "Sublingual",
        "Topical",
        "Inhalation",
        "Injection",
        "Intravenous"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Medication")
                .font(.headline)
            
            // Medication Picker
            VStack(alignment: .leading) {
                Text("Select Medication")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Medication", selection: $selectedMedication) {
                    Text("Select...").tag("")
                    ForEach(medications, id: \.code) { medication in
                        VStack(alignment: .leading) {
                            Text(medication.name)
                            Text("SNOMED: \(medication.code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(medication.name)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedCode = medications.first(where: { $0.name == selectedMedication })?.code {
                    Text("SNOMED CT: \(selectedCode)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Dosage
            VStack(alignment: .leading) {
                Text("Dosage (e.g., 10 mg)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("10 mg", text: $dosage)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Frequency and Route
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Frequency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Frequency", selection: $frequency) {
                        ForEach(frequencies, id: \.self) { freq in
                            Text(freq).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                VStack(alignment: .leading) {
                    Text("Route")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Route", selection: $route) {
                        ForEach(routes, id: \.self) { r in
                            Text(r).tag(r)
                        }
                    }
                    .pickerStyle(.menu)
                }
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
            .disabled(isSaving || selectedMedication.isEmpty || dosage.isEmpty)
        }
    }
    
    private func handleSave() {
        guard let medication = medications.first(where: { $0.name == selectedMedication }) else {
            return
        }
        
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: Date())
        
        let routeCode: String
        switch route {
        case "Oral":
            routeCode = "26643006"
        case "Sublingual":
            routeCode = "37161004"
        case "Topical":
            routeCode = "6064005"
        case "Inhalation":
            routeCode = "447694001"
        case "Injection":
            routeCode = "129326001"
        case "Intravenous":
            routeCode = "47625008"
        default:
            routeCode = "26643006"
        }
        
        let medicationStatement = MedicationStatement(
            id: UUID().uuidString,
            status: "active",
            medicationCodeableConcept: CodeableConcept(
                coding: [
                    Coding(
                        system: "http://snomed.info/sct",
                        code: medication.code,
                        display: medication.name
                    )
                ],
                text: medication.name
            ),
            subject: Reference(
                reference: "Patient/self",
                display: "Self"
            ),
            effectiveDateTime: dateString,
            dateAsserted: dateString,
            dosage: [
                Dosage(
                    text: "\(dosage) \(frequency)",
                    timing: Timing(
                        code: CodeableConcept(
                            text: frequency
                        )
                    ),
                    route: CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://snomed.info/sct",
                                code: routeCode,
                                display: route
                            )
                        ]
                    ),
                    doseAndRate: [
                        DoseAndRate(
                            doseQuantity: Quantity(
                                value: nil,
                                unit: dosage
                            )
                        )
                    ]
                )
            ],
            note: notes.isEmpty ? nil : [Annotation(text: notes)]
        )
        
        onSave(medicationStatement)
    }
}
