import SwiftUI
import UIKit

struct ObservationQRDetailView: View {
    let record: RecordItem

    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var payloadString: String?
    @State private var formattedJSON: String?
    @State private var isGenerating = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                contentSection
            }
            .padding()
        }
        .navigationTitle("Observation QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await generatePayloadIfNeeded()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(record.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(record.date)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var contentSection: some View {
        if isGenerating {
            ProgressView("Generating QR package…")
                .frame(maxWidth: .infinity)
        } else if let errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange)
                Text(errorMessage)
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        } else {
            if let image = qrImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)))
                    .shadow(radius: 4)
                    .frame(maxWidth: .infinity)
            }

            if let payloadString {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Encoded Payload")
                        .font(.headline)
                    Text(payloadString)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }

            if let formattedJSON {
                VStack(alignment: .leading, spacing: 8) {
                    Text("FHIR Bundle")
                        .font(.headline)
                    Text(formattedJSON)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
    }

    private func generatePayloadIfNeeded() async {
        guard isGenerating else { return }
        do {
            guard let resource = record.credential.fhirResource else {
                throw ObservationQRViewError.missingFHIR
            }
            let bundle = try resource.makeObservationBundle(fallbackIdentifier: record.id)
            let payload = try PayloadEncoder.encode(bundle)
            guard let image = QRCodeRenderer.image(for: payload) else {
                throw ObservationQRViewError.qrEncodingFailed
            }
            let payloadData = try PayloadEncoder.decodePayload(payload)
            let prettyJSON = try Self.prettyPrintedJSON(from: payloadData)

            qrImage = image
            payloadString = payload
            formattedJSON = prettyJSON
            isGenerating = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            isGenerating = false
        }
    }

    private static func prettyPrintedJSON(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .withoutEscapingSlashes])
        return String(decoding: prettyData, as: UTF8.self)
    }

    private enum ObservationQRViewError: LocalizedError {
        case missingFHIR
        case qrEncodingFailed

        var errorDescription: String? {
            switch self {
            case .missingFHIR:
                return "This record does not contain a FHIR Observation payload."
            case .qrEncodingFailed:
                return "Unable to render the QR code for this record."
            }
        }
    }
}
