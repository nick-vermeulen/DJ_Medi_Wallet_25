//
//  RecordDetailView.swift
//  DJMediWallet
//
//  Detail view for displaying a medical record
//

import SwiftUI

struct RecordDetailView: View {
    let record: RecordItem
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: record.iconName)
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(record.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(record.title)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                
                // Date
                DetailRow(label: "Date", value: record.date)
                
                Divider()
                
                // Dynamic Fields based on record type
                if let fhirResource = record.credential.fhirResource,
                   let data = fhirResource.data {
                    
                    switch fhirResource.resourceType {
                    case "Observation":
                        ObservationDetails(data: data)
                    case "Condition":
                        ConditionDetails(data: data)
                    case "MedicationStatement":
                        MedicationDetails(data: data)
                    default:
                        EmptyView()
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Record Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ObservationDetails: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            if let status = data["status"] as? String {
                DetailRow(label: "Status", value: status.capitalized)
                Divider()
            }
            
            // Single value
            if let valueQuantity = data["valueQuantity"] as? [String: Any],
               let value = valueQuantity["value"] as? Double,
               let unit = valueQuantity["unit"] as? String {
                DetailRow(label: "Value", value: "\(value) \(unit)")
                Divider()
            }
            
            // Components (e.g., blood pressure)
            if let components = data["component"] as? [[String: Any]] {
                ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                    if let code = component["code"] as? [String: Any],
                       let coding = code["coding"] as? [[String: Any]],
                       let display = coding.first?["display"] as? String,
                       let valueQty = component["valueQuantity"] as? [String: Any],
                       let value = valueQty["value"] as? Double,
                       let unit = valueQty["unit"] as? String {
                        
                        DetailRow(label: display, value: "\(value) \(unit)")
                        
                        if index < components.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            
            // Notes
            if let notes = data["note"] as? [[String: Any]],
               let text = notes.first?["text"] as? String {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct ConditionDetails: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Clinical Status
            if let clinicalStatus = data["clinicalStatus"] as? [String: Any],
               let coding = clinicalStatus["coding"] as? [[String: Any]],
               let display = coding.first?["display"] as? String {
                DetailRow(label: "Clinical Status", value: display)
                Divider()
            }
            
            // Severity
            if let severity = data["severity"] as? [String: Any],
               let coding = severity["coding"] as? [[String: Any]],
               let display = coding.first?["display"] as? String {
                DetailRow(label: "Severity", value: display)
                Divider()
            }
            
            // SNOMED Code
            if let code = data["code"] as? [String: Any],
               let coding = code["coding"] as? [[String: Any]],
               let snomedCode = coding.first?["code"] as? String {
                DetailRow(label: "SNOMED CT Code", value: snomedCode)
                Divider()
            }
            
            // Onset Date
            if let onsetDate = data["onsetDateTime"] as? String {
                let displayDate = String(onsetDate.prefix(10))
                DetailRow(label: "Onset Date", value: displayDate)
                Divider()
            }
            
            // Notes
            if let notes = data["note"] as? [[String: Any]],
               let text = notes.first?["text"] as? String {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}

struct MedicationDetails: View {
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status
            if let status = data["status"] as? String {
                DetailRow(label: "Status", value: status.capitalized)
                Divider()
            }
            
            // Dosage
            if let dosages = data["dosage"] as? [[String: Any]],
               let text = dosages.first?["text"] as? String {
                DetailRow(label: "Dosage", value: text)
                Divider()
            }
            
            // Route
            if let dosages = data["dosage"] as? [[String: Any]],
               let route = dosages.first?["route"] as? [String: Any],
               let coding = route["coding"] as? [[String: Any]],
               let display = coding.first?["display"] as? String {
                DetailRow(label: "Route", value: display)
                Divider()
            }
            
            // SNOMED Code
            if let medication = data["medicationCodeableConcept"] as? [String: Any],
               let coding = medication["coding"] as? [[String: Any]],
               let snomedCode = coding.first?["code"] as? String {
                DetailRow(label: "SNOMED CT Code", value: snomedCode)
                Divider()
            }
            
            // Start Date
            if let effectiveDate = data["effectiveDateTime"] as? String {
                let displayDate = String(effectiveDate.prefix(10))
                DetailRow(label: "Start Date", value: displayDate)
                Divider()
            }
            
            // Notes
            if let notes = data["note"] as? [[String: Any]],
               let text = notes.first?["text"] as? String {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                    Text(text)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}
