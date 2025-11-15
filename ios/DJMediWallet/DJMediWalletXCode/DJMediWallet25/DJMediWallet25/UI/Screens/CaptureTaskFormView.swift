import Foundation
import SwiftUI
import CoreLocation

struct CaptureTaskFormView: View {
    struct TaskDraft {
        var qrMetadata: CaptureTaskView.CaptureMetadata
        var nhsNumber: String = ""
        var patientLocation: LocationOption = .manual
        var manualLocationDescription: String = ""
        var selectedRequestType: RequestType = .other
        var additionalNotes: String = ""

        enum LocationOption: String, CaseIterable, Identifiable {
            case clinic = "Clinic"
            case remote = "Remote"
            case manual = "Manual entry"

            var id: String { rawValue }
        }

        enum RequestType: String, CaseIterable, Identifiable {
            case referral = "Referral"
            case diagnostic = "Diagnostic"
            case followUp = "Follow Up"
            case discharge = "Discharge"
            case other = "Other"

            var id: String { rawValue }
        }
    }

    @Binding var draft: TaskDraft
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case nhs
        case manualLocation
        case notes
    }

    var body: some View {
        Section(header: Text("Task Details"), footer: validationFooter) {
            readOnlyRow(title: "Reason", value: draft.qrMetadata.reason ?? "Not provided")

            Picker("Request Type", selection: $draft.selectedRequestType) {
                ForEach(TaskDraft.RequestType.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("NHS Number")
                    .font(.subheadline)
                TextField("10-digit NHS Number", text: $draft.nhsNumber)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .nhs)
                    .onChange(of: draft.nhsNumber) { _ in
                        draft.nhsNumber = draft.nhsNumber.filter { $0.isNumber }.prefix(10).map(String.init).joined()
                    }
                    .overlay(alignment: .trailing) {
                        if draft.nhsNumber.count == 10 {
                            Image(systemName: CaptureTaskFormView.isValidNHSNumber(draft.nhsNumber) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(CaptureTaskFormView.isValidNHSNumber(draft.nhsNumber) ? .green : .orange)
                                .padding(.trailing, 8)
                        }
                    }
            }
            .padding(.vertical, 4)

            Picker("Patient Location", selection: $draft.patientLocation) {
                ForEach(TaskDraft.LocationOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            if draft.patientLocation == .manual {
                TextField("Describe location (e.g. Ward 3A)", text: $draft.manualLocationDescription)
                    .focused($focusedField, equals: .manualLocation)
            }

            TextEditor(text: $draft.additionalNotes)
                .frame(minHeight: 100)
                .focused($focusedField, equals: .notes)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4))
                )
                .padding(.vertical, 4)
        }
    }

    private var validationFooter: some View {
        Group {
            if draft.nhsNumber.isEmpty || CaptureTaskFormView.isValidNHSNumber(draft.nhsNumber) {
                Text("Double-check patient identifiers before sending. NHS numbers use modulus-11 validation.")
            } else {
                Text("NHS number failed validation. Re-enter the 10-digit value.")
                    .foregroundColor(.red)
            }
        }
        .font(.footnote)
        .foregroundColor(.secondary)
    }

    private func readOnlyRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }

    static func isValidNHSNumber(_ input: String) -> Bool {
        let digits = input.compactMap { Int(String($0)) }
        guard digits.count == 10 else { return false }
        let checkDigit = digits[9]
        var total = 0
        for (index, digit) in digits.prefix(9).enumerated() {
            total += digit * (10 - index)
        }
        let modulus = total % 11
        let calculated = 11 - modulus
        switch calculated {
        case 11:
            return checkDigit == 0
        case 10:
            return false
        default:
            return checkDigit == calculated
        }
    }
}
