//
//  RecordDetailView.swift
//  DJMediWallet
//
//  Detail view for displaying a medical record
//

import SwiftUI

struct RecordDetailView: View {
    let record: RecordItem
    @State private var isPresentingObservationQR = false
    
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
                        ObservationDetails(resource: fhirResource)
                        Button {
                            isPresentingObservationQR = true
                        } label: {
                            Label("Generate QR Package", systemImage: "qrcode")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
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
        .sheet(isPresented: $isPresentingObservationQR) {
            NavigationStack {
                ObservationQRDetailView(record: record)
            }
        }
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
    let resource: FHIRResource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let observation = try? resource.decodeObservation() {
                observationView(for: observation)
            } else if let data = resource.data {
                LegacyObservationDetails(data: data)
            } else {
                Text("No observation data available.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func observationView(for observation: FHIRObservation) -> some View {
        let rows = observationRows(for: observation)
        if rows.isEmpty {
            Text("No observation data available.")
                .font(.callout)
                .foregroundColor(.secondary)
        } else {
            ForEach(rows.indices, id: \.self) { index in
                let row = rows[index]
                DetailRow(label: row.label, value: row.value)
                if index < rows.count - 1 {
                    Divider()
                }
            }
        }
        if let noteText = observation.note?.first?.text, noteText.isEmpty == false {
            if rows.isEmpty == false {
                Divider()
            }
            NotesCard(title: "Notes", text: noteText)
        }
    }
    
    private func observationRows(for observation: FHIRObservation) -> [ObservationRow] {
        var rows: [ObservationRow] = []
        rows.append(ObservationRow(label: "Status", value: observation.status.capitalized))
        if let codeText = observation.code.display ?? observation.code.coding?.first?.display ?? observation.code.coding?.first?.code {
            rows.append(ObservationRow(label: "Observation", value: codeText))
        }
        if let result = primaryResultText(for: observation) {
            rows.append(ObservationRow(label: "Result", value: result))
        }
        if let observedAt = formattedObservationDate(for: observation) {
            rows.append(ObservationRow(label: "Observed", value: observedAt))
        }
        if let components = observation.component {
            for component in components {
                guard let label = component.code.display ?? component.code.coding?.first?.display ?? component.code.coding?.first?.code,
                      let value = componentResultText(component) else {
                    continue
                }
                rows.append(ObservationRow(label: label, value: value))
            }
        }
        if let interpretation = interpretationText(for: observation.interpretation) {
            rows.append(ObservationRow(label: "Interpretation", value: interpretation))
        }
        return rows
    }
    
    private func primaryResultText(for observation: FHIRObservation) -> String? {
        if let quantity = observation.valueQuantity, let display = formatQuantity(quantity) {
            return display
        }
        if let valueString = observation.valueString, valueString.isEmpty == false {
            return valueString
        }
        if let valueBoolean = observation.valueBoolean {
            return boolDisplay(valueBoolean)
        }
        return nil
    }
    
    private func componentResultText(_ component: FHIRObservationComponent) -> String? {
        if let quantity = component.valueQuantity, let display = formatQuantity(quantity) {
            return display
        }
        if let valueString = component.valueString, valueString.isEmpty == false {
            return valueString
        }
        if let valueBoolean = component.valueBoolean {
            return boolDisplay(valueBoolean)
        }
        return nil
    }
    
    private func formatQuantity(_ quantity: Quantity) -> String? {
        guard let value = quantity.value else { return nil }
        let number = NSNumber(value: value)
        let formattedValue = observationNumberFormatter.string(from: number) ?? number.stringValue
        if let unit = quantity.unit, unit.isEmpty == false {
            return "\(formattedValue) \(unit)"
        }
        return formattedValue
    }
    
    private func interpretationText(for concepts: [CodeableConcept]?) -> String? {
        guard let concepts, concepts.isEmpty == false else { return nil }
        let descriptions = concepts.compactMap { concept -> String? in
            concept.display ?? concept.coding?.first?.code
        }
        guard descriptions.isEmpty == false else { return nil }
        return descriptions.joined(separator: ", ")
    }
    
    private func formattedObservationDate(for observation: FHIRObservation) -> String? {
        if let effective = observation.effectiveDateTime, let formatted = formattedObservationDateString(effective) {
            return formatted
        }
        if let issued = observation.issued, let formatted = formattedObservationDateString(issued) {
            return formatted
        }
        return nil
    }
}

private struct LegacyObservationDetails: View {
    let data: [String: Any]

    var body: some View {
        let rows = legacyRows
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                Text("No observation data available.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } else {
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    DetailRow(label: row.label, value: row.value)
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            if let noteText = legacyNote, noteText.isEmpty == false {
                if rows.isEmpty == false {
                    Divider()
                }
                NotesCard(title: "Notes", text: noteText)
            }
        }
    }

    private var legacyRows: [ObservationRow] {
        var rows: [ObservationRow] = []
        if let status = data["status"] as? String, status.isEmpty == false {
            rows.append(ObservationRow(label: "Status", value: status.capitalized))
        }
        if let code = data["code"] as? [String: Any], let display = conceptDisplay(from: code) {
            rows.append(ObservationRow(label: "Observation", value: display))
        }
        if let valueQuantity = data["valueQuantity"] as? [String: Any], let display = formattedQuantity(from: valueQuantity) {
            rows.append(ObservationRow(label: "Result", value: display))
        } else if let valueString = data["valueString"] as? String, valueString.isEmpty == false {
            rows.append(ObservationRow(label: "Result", value: valueString))
        } else if let valueBoolean = data["valueBoolean"] as? Bool {
            rows.append(ObservationRow(label: "Result", value: boolDisplay(valueBoolean)))
        }
        if let effective = data["effectiveDateTime"] as? String, let formatted = formattedObservationDateString(effective) {
            rows.append(ObservationRow(label: "Observed", value: formatted))
        } else if let issued = data["issued"] as? String, let formatted = formattedObservationDateString(issued) {
            rows.append(ObservationRow(label: "Observed", value: formatted))
        }
        if let components = data["component"] as? [[String: Any]] {
            for component in components {
                guard let code = component["code"] as? [String: Any],
                      let label = conceptDisplay(from: code),
                      let value = componentValue(from: component) else {
                    continue
                }
                rows.append(ObservationRow(label: label, value: value))
            }
        }
        if let interpretation = data["interpretation"] as? [[String: Any]] {
            let displays = interpretation.compactMap { conceptDisplay(from: $0) }
            if displays.isEmpty == false {
                rows.append(ObservationRow(label: "Interpretation", value: displays.joined(separator: ", ")))
            }
        }
        return rows
    }

    private var legacyNote: String? {
        guard let notes = data["note"] as? [[String: Any]] else { return nil }
        return notes.compactMap { $0["text"] as? String }.first(where: { $0.isEmpty == false })
    }

    private func conceptDisplay(from dict: [String: Any]) -> String? {
        if let text = dict["text"] as? String, text.isEmpty == false {
            return text
        }
        if let coding = dict["coding"] as? [[String: Any]] {
            for entry in coding {
                if let display = entry["display"] as? String, display.isEmpty == false {
                    return display
                }
                if let code = entry["code"] as? String, code.isEmpty == false {
                    return code
                }
            }
        }
        return nil
    }

    private func componentValue(from component: [String: Any]) -> String? {
        if let quantity = component["valueQuantity"] as? [String: Any], let display = formattedQuantity(from: quantity) {
            return display
        }
        if let valueString = component["valueString"] as? String, valueString.isEmpty == false {
            return valueString
        }
        if let valueBoolean = component["valueBoolean"] as? Bool {
            return boolDisplay(valueBoolean)
        }
        return nil
    }

    private func formattedQuantity(from dict: [String: Any]) -> String? {
        let numericValue: NSNumber?
        if let number = dict["value"] as? NSNumber {
            numericValue = number
        } else if let doubleValue = dict["value"] as? Double {
            numericValue = NSNumber(value: doubleValue)
        } else if let intValue = dict["value"] as? Int {
            numericValue = NSNumber(value: intValue)
        } else {
            numericValue = nil
        }
        guard let numericValue else { return nil }
        let formattedValue = observationNumberFormatter.string(from: numericValue) ?? numericValue.stringValue
        if let unit = dict["unit"] as? String, unit.isEmpty == false {
            return "\(formattedValue) \(unit)"
        }
        return formattedValue
    }
}

private struct ObservationRow {
    let label: String
    let value: String
}

private let observationISOFormatterWithFractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let observationISOFormatterBasic: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()

private let observationDisplayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

private let observationNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 3
    formatter.minimumFractionDigits = 0
    return formatter
}()

private func formattedObservationDateString(_ isoString: String) -> String? {
    if let date = observationISOFormatterWithFractional.date(from: isoString) ?? observationISOFormatterBasic.date(from: isoString) {
        return observationDisplayFormatter.string(from: date)
    }
    return isoString.isEmpty ? nil : isoString
}

private func boolDisplay(_ value: Bool) -> String {
    value ? "Yes" : "No"
}

private struct NotesCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
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
