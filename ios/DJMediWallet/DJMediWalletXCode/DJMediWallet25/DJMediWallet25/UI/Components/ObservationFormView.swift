//
//  ObservationFormView.swift
//  DJMediWallet
//
//  Form for entering vital signs and observations
//

import SwiftUI

struct ObservationFormView: View {
    let onSave: (FHIRObservation) -> Void
    @Binding var isSaving: Bool
    
    @State private var observationType = "Blood Pressure"
    @State private var systolic = ""
    @State private var diastolic = ""
    @State private var heartRate = ""
    @State private var temperature = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var notes = ""
    
    private let observationTypes = [
        "Blood Pressure",
        "Heart Rate",
        "Body Temperature",
        "Weight",
        "Height"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vital Signs / Observation")
                .font(.headline)
            
            // Observation Type Picker
            Picker("Observation Type", selection: $observationType) {
                ForEach(observationTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.menu)
            
            // Dynamic fields based on type
            Group {
                switch observationType {
                case "Blood Pressure":
                    HStack(spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("Systolic (mmHg)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("120", text: $systolic)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Diastolic (mmHg)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("80", text: $diastolic)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                case "Heart Rate":
                    VStack(alignment: .leading) {
                        Text("Heart Rate (bpm)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("72", text: $heartRate)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                case "Body Temperature":
                    VStack(alignment: .leading) {
                        Text("Temperature (°C)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("37.0", text: $temperature)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                case "Weight":
                    VStack(alignment: .leading) {
                        Text("Weight (kg)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("70.0", text: $weight)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                case "Height":
                    VStack(alignment: .leading) {
                        Text("Height (cm)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("170", text: $height)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                default:
                    EmptyView()
                }
            }
            
            // Notes
            VStack(alignment: .leading) {
                Text("Notes (Optional)")
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
            .disabled(isSaving || !isFormValid())
        }
    }
    
    private func isFormValid() -> Bool {
        switch observationType {
        case "Blood Pressure":
            return !systolic.isEmpty && !diastolic.isEmpty
        case "Heart Rate":
            return !heartRate.isEmpty
        case "Body Temperature":
            return !temperature.isEmpty
        case "Weight":
            return !weight.isEmpty
        case "Height":
            return !height.isEmpty
        default:
            return false
        }
    }
    
    private func handleSave() {
        let observation = createObservation()
        onSave(observation)
    }
    
    private func createObservation() -> FHIRObservation {
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: Date())
        
        switch observationType {
        case "Blood Pressure":
            return FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [
                    CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                                code: "vital-signs",
                                display: "Vital Signs"
                            )
                        ]
                    )
                ],
                code: CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://loinc.org",
                            code: "85354-9",
                            display: "Blood pressure panel"
                        )
                    ]
                ),
                effectiveDateTime: dateString,
                component: [
                    FHIRObservationComponent(
                        code: CodeableConcept(
                            coding: [
                                Coding(
                                    system: "http://loinc.org",
                                    code: "8480-6",
                                    display: "Systolic blood pressure"
                                )
                            ]
                        ),
                        valueQuantity: Quantity(
                            value: Double(systolic),
                            unit: "mmHg",
                            system: "http://unitsofmeasure.org",
                            code: "mm[Hg]"
                        )
                    ),
                    FHIRObservationComponent(
                        code: CodeableConcept(
                            coding: [
                                Coding(
                                    system: "http://loinc.org",
                                    code: "8462-4",
                                    display: "Diastolic blood pressure"
                                )
                            ]
                        ),
                        valueQuantity: Quantity(
                            value: Double(diastolic),
                            unit: "mmHg",
                            system: "http://unitsofmeasure.org",
                            code: "mm[Hg]"
                        )
                    )
                ],
                note: notes.isEmpty ? nil : [Annotation(text: notes)]
            )
            
        case "Heart Rate":
            return FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [
                    CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                                code: "vital-signs",
                                display: "Vital Signs"
                            )
                        ]
                    )
                ],
                code: CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://loinc.org",
                            code: "8867-4",
                            display: "Heart rate"
                        ),
                        Coding(
                            system: "http://snomed.info/sct",
                            code: "364075005",
                            display: "Heart rate"
                        )
                    ]
                ),
                effectiveDateTime: dateString,
                valueQuantity: Quantity(
                    value: Double(heartRate),
                    unit: "beats/minute",
                    system: "http://unitsofmeasure.org",
                    code: "/min"
                ),
                note: notes.isEmpty ? nil : [Annotation(text: notes)]
            )
            
        case "Body Temperature":
            return FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [
                    CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                                code: "vital-signs",
                                display: "Vital Signs"
                            )
                        ]
                    )
                ],
                code: CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://loinc.org",
                            code: "8310-5",
                            display: "Body temperature"
                        ),
                        Coding(
                            system: "http://snomed.info/sct",
                            code: "386725007",
                            display: "Body temperature"
                        )
                    ]
                ),
                effectiveDateTime: dateString,
                valueQuantity: Quantity(
                    value: Double(temperature),
                    unit: "°C",
                    system: "http://unitsofmeasure.org",
                    code: "Cel"
                ),
                note: notes.isEmpty ? nil : [Annotation(text: notes)]
            )
            
        case "Weight":
            return FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [
                    CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                                code: "vital-signs",
                                display: "Vital Signs"
                            )
                        ]
                    )
                ],
                code: CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://loinc.org",
                            code: "29463-7",
                            display: "Body weight"
                        ),
                        Coding(
                            system: "http://snomed.info/sct",
                            code: "27113001",
                            display: "Body weight"
                        )
                    ]
                ),
                effectiveDateTime: dateString,
                valueQuantity: Quantity(
                    value: Double(weight),
                    unit: "kg",
                    system: "http://unitsofmeasure.org",
                    code: "kg"
                ),
                note: notes.isEmpty ? nil : [Annotation(text: notes)]
            )
            
        case "Height":
            return FHIRObservation(
                id: UUID().uuidString,
                status: "final",
                category: [
                    CodeableConcept(
                        coding: [
                            Coding(
                                system: "http://terminology.hl7.org/CodeSystem/observation-category",
                                code: "vital-signs",
                                display: "Vital Signs"
                            )
                        ]
                    )
                ],
                code: CodeableConcept(
                    coding: [
                        Coding(
                            system: "http://loinc.org",
                            code: "8302-2",
                            display: "Body height"
                        ),
                        Coding(
                            system: "http://snomed.info/sct",
                            code: "50373000",
                            display: "Body height"
                        )
                    ]
                ),
                effectiveDateTime: dateString,
                valueQuantity: Quantity(
                    value: Double(height),
                    unit: "cm",
                    system: "http://unitsofmeasure.org",
                    code: "cm"
                ),
                note: notes.isEmpty ? nil : [Annotation(text: notes)]
            )
            
        default:
            fatalError("Unknown observation type")
        }
    }
}
