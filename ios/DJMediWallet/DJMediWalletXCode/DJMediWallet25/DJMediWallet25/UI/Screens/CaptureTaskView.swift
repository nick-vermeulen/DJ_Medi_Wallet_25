import Foundation
import SwiftUI

struct CaptureTaskView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var lockManager: AppLockManager

    @State private var isPresentingScanner = false
    @State private var scanError: String?
    @State private var capturedMetadata: CaptureMetadata?
    @State private var taskDraft: CaptureTaskFormView.TaskDraft?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                captureButton
                if let metadata = capturedMetadata {
                    metadataSection(for: metadata)
                    Divider()
                    if let draft = taskDraftBinding {
                        CaptureTaskFormView(draft: draft)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Capture Task")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPresentingScanner) {
            NavigationStack {
                QRScannerView { result in
                    handleScanResult(result)
                }
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isPresentingScanner = false
                        }
                    }
                }
            }
        }
        .alert("Scan Error", isPresented: Binding(
            get: { scanError != nil },
            set: { if !$0 { scanError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scanError ?? "")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan a QR task request")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Use the camera to capture the patient data or task request. The wallet will decode the payload and prepare a new task draft for you to review before submission.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var captureButton: some View {
        Button {
            scanError = nil
            isPresentingScanner = true
        } label: {
            Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Launches the camera to scan a QR request")
    }

    @ViewBuilder
    private func metadataSection(for metadata: CaptureMetadata) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Captured Request")
                .font(.headline)
            VStack(alignment: .leading, spacing: 12) {
                if let reason = metadata.reason, reason.isEmpty == false {
                    metadataRow(label: "Reason", value: reason)
                }
                if let requestType = metadata.requestType, requestType.isEmpty == false {
                    metadataRow(label: "Request Type", value: requestType)
                }
                if let identifier = metadata.requestId, identifier.isEmpty == false {
                    metadataRow(label: "Reference", value: identifier)
                }
                if metadata.additionalHighlights.isEmpty == false {
                    Divider()
                    ForEach(metadata.additionalHighlights) { highlight in
                        metadataRow(label: highlight.label, value: highlight.value)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            DisclosureGroup("View Raw Payload") {
                ScrollView {
                    Text(metadata.rawJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }

    private func handleScanResult(_ result: Result<String, QRScannerError>) {
        isPresentingScanner = false
        switch result {
        case .success(let payload):
            do {
                capturedMetadata = try parsePayload(payload)
                if let metadata = capturedMetadata {
                    taskDraft = CaptureTaskFormView.TaskDraft(qrMetadata: metadata)
                }
            } catch {
                capturedMetadata = nil
                taskDraft = nil
                scanError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        case .failure(let error):
            capturedMetadata = nil
            taskDraft = nil
            scanError = error.errorDescription
        }
    }

    private func parsePayload(_ payload: String) throws -> CaptureMetadata {
        let data: Data
        if let decoded = try? PayloadEncoder.decodePayload(payload) {
            data = decoded
        } else if let utfData = payload.data(using: .utf8) {
            data = utfData
        } else {
            throw CaptureTaskError.unreadablePayload
        }

        let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = jsonObject as? [String: Any] else {
            throw CaptureTaskError.unsupportedPayload
        }

        let reason = CaptureTaskView.locateString(for: ["reason", "requestReason", "purpose"], in: dictionary)
        let requestType = CaptureTaskView.locateString(for: ["requestType", "type", "category"], in: dictionary)
        let identifier = CaptureTaskView.locateString(for: ["requestId", "id", "identifier"], in: dictionary)
        let excludedKeys = ["reason", "requestReason", "purpose", "requestType", "type", "category", "requestId", "id", "identifier"].map { $0.lowercased() }
        let highlights = CaptureTaskView.collectHighlights(from: dictionary, excludingKeys: excludedKeys)
        let prettyJSON = try CaptureTaskView.prettyPrintedJSON(from: data)

        return CaptureMetadata(
            requestId: identifier,
            requestType: requestType,
            reason: reason,
            additionalHighlights: highlights,
            rawJSON: prettyJSON
        )
    }

    private enum CaptureTaskError: LocalizedError {
        case unreadablePayload
        case unsupportedPayload

        var errorDescription: String? {
            switch self {
            case .unreadablePayload:
                return "The scanned QR code does not contain a readable payload."
            case .unsupportedPayload:
                return "The QR payload was not valid JSON."
            }
        }
    }
}

private extension CaptureTaskView {
    var taskDraftBinding: Binding<CaptureTaskFormView.TaskDraft>? {
        guard taskDraft != nil else { return nil }
        return Binding(
            get: { self.taskDraft! },
            set: { self.taskDraft = $0 }
        )
    }
}

extension CaptureTaskView {
    struct CaptureMetadata {
        let requestId: String?
        let requestType: String?
        let reason: String?
        let additionalHighlights: [Highlight]
        let rawJSON: String
    }

    struct Highlight: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    static func locateString(for keys: [String], in dictionary: [String: Any]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String, value.isEmpty == false {
                return value
            }
        }
        for (_, value) in dictionary {
            if let nested = value as? [String: Any], let match = locateString(for: keys, in: nested) {
                return match
            }
            if let array = value as? [[String: Any]] {
                for element in array {
                    if let match = locateString(for: keys, in: element) {
                        return match
                    }
                }
            }
        }
        return nil
    }

    static func collectHighlights(from dictionary: [String: Any], excludingKeys: [String]) -> [Highlight] {
        var highlights: [Highlight] = []
        for (key, value) in dictionary {
            let loweredKey = key.lowercased()
            if excludingKeys.contains(loweredKey) {
                continue
            }
            if let stringValue = value as? String, stringValue.isEmpty == false {
                highlights.append(Highlight(label: key.capitalized, value: stringValue))
            } else if let nested = value as? [String: Any] {
                let nestedHighlights = collectHighlights(from: nested, excludingKeys: excludingKeys)
                highlights.append(contentsOf: nestedHighlights)
            } else if let array = value as? [[String: Any]] {
                for element in array {
                    let nestedHighlights = collectHighlights(from: element, excludingKeys: excludingKeys)
                    highlights.append(contentsOf: nestedHighlights)
                }
            }
        }
        return highlights.uniqued()
    }

    static func prettyPrintedJSON(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .withoutEscapingSlashes])
        return String(decoding: prettyData, as: UTF8.self)
    }
}

private extension Array where Element == CaptureTaskView.Highlight {
    func uniqued() -> [Element] {
        var seen = Set<String>()
        var result: [Element] = []
        for item in self {
            let key = "\(item.label.lowercased())::\(item.value.lowercased())"
            if seen.insert(key).inserted {
                result.append(item)
            }
        }
        return result
    }
}
