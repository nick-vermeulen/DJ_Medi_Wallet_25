import Foundation
import SwiftUI
import OSLog
import UIKit

struct CaptureTaskView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var lockManager: AppLockManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPresentingScanner = false
    @State private var scanError: String?
    @State private var capturedMetadata: CaptureMetadata?
    @State private var taskDraft: CaptureTaskFormView.TaskDraft?
    @State private var isSubmitting = false
    @State private var submissionAlert: SubmissionAlert?
    @State private var toastMessage: ToastMessage?

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DJMediWallet25", category: "CaptureTask")
    private static let toastDisplayDuration: UInt64 = 1_400_000_000

    private struct SubmissionAlert: Identifiable {
        enum Kind {
            case success
            case failure
        }

        let id = UUID()
        let kind: Kind
        let message: String

        var title: String {
            switch kind {
            case .success:
                return "Message Sent"
            case .failure:
                return "Unable to Send"
            }
        }

        var isSuccess: Bool { kind == .success }
    }

    private struct ToastMessage: Identifiable {
        let id = UUID()
        let message: String
    }

    private struct ToastBanner: View {
        let message: String

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.92))
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        }
    }

    private struct NormalizedPayload {
        let data: Data
        let dictionary: [String: Any]
        let format: PayloadFormat
        let envelope: String
    }

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
                        submitControls
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
        .alert(item: $submissionAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    if alert.isSuccess {
                        capturedMetadata = nil
                        taskDraft = nil
                    }
                }
            )
        }
        .overlay(alignment: .top) {
            toastOverlay
        }
        .overlay {
            if isSubmitting {
                ProgressView("Sending…")
                    .progressViewStyle(.circular)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: toastMessage != nil)
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
                metadataRow(label: "Payload Format", value: metadata.payloadFormatDisplayName)
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

            DisclosureGroup("View Normalized JSON") {
                ScrollView {
                    Text(metadata.rawJSON)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }
                .frame(maxHeight: 240)
            }
            DisclosureGroup("View Original Envelope") {
                ScrollView {
                    Text(metadata.rawEnvelope)
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

    private var submitControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                submitTask()
            } label: {
                HStack {
                    Spacer()
                    Text(isSubmitting ? "Sending…" : "Send to Supabase")
                        .font(.headline)
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting || taskDraft == nil)

            Text("Submitting creates a Supabase message with this task and QR metadata for follow-up by the practitioner team.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let toastMessage {
            ToastBanner(message: toastMessage.message)
                .padding(.horizontal)
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }

    private func submitTask() {
        guard let draft = taskDraft else {
            submissionAlert = SubmissionAlert(kind: .failure, message: "Create a task draft before sending.")
            Self.logger.error("Submission attempt blocked: draft missing.")
            return
        }

        if let validationMessage = validateDraft(draft) {
            submissionAlert = SubmissionAlert(kind: .failure, message: validationMessage)
            Self.logger.notice("Submission validation failed: \(validationMessage, privacy: .public)")
            return
        }

        guard let profile = lockManager.userProfile else {
            submissionAlert = SubmissionAlert(kind: .failure, message: "Load the practitioner profile before sending.")
            Self.logger.error("Submission attempt blocked: practitioner profile unavailable.")
            return
        }

        isSubmitting = true
        submissionAlert = nil
        Self.logger.info("Submitting capture task to Supabase.")

        let currentDraft = draft
        let currentProfile = profile

        Task {
            do {
                let authorId = try await resolveAuthorIdentifier(for: currentProfile)
                let request = makeMessageRequest(from: currentDraft, authorId: authorId, profile: currentProfile)
                let response = try await walletManager.createMessage(request)

                await handleSubmissionSuccess(response)
            } catch {
                await handleSubmissionFailure(error)
            }
        }
    }

    private func validateDraft(_ draft: CaptureTaskFormView.TaskDraft) -> String? {
        guard CaptureTaskFormView.isValidNHSNumber(draft.nhsNumber) else {
            return "Enter a valid 10-digit NHS number before sending."
        }

        if draft.patientLocation == .manual,
           draft.manualLocationDescription.trimmedNonEmpty == nil {
            return "Provide a description for the manual location."
        }

        return nil
    }

    @MainActor
    private func handleSubmissionSuccess(
        _ response: SupabaseService.MessageResponse
    ) {
        isSubmitting = false

        let statusDescription = (response.status ?? "queued").capitalized
        let acknowledgement = response.id.map { "Reference: \($0.uuidString)" }
        var toastLines = ["Task \(statusDescription)."]
        if let acknowledgement {
            toastLines.append(acknowledgement)
        }
        let toastText = toastLines.joined(separator: "\n")

        Self.logger.info("Capture task submission succeeded with status: \(statusDescription, privacy: .public)")

        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)

        capturedMetadata = nil
        taskDraft = nil

        let toast = ToastMessage(message: toastText)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toastMessage = toast
        }

        let toastId = toast.id

        Task { @MainActor in
            // Delay dismissal slightly so the confirmation toast is perceivable.
            try? await Task.sleep(nanoseconds: Self.toastDisplayDuration)
            guard toastMessage?.id == toastId else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                toastMessage = nil
            }
            dismiss()
        }
    }

    @MainActor
    private func handleSubmissionFailure(_ error: Error) {
        isSubmitting = false

        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        submissionAlert = SubmissionAlert(kind: .failure, message: description)

        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.error)

        Self.logger.error("Capture task submission failed: \(description, privacy: .public)")
    }

    private func resolveAuthorIdentifier(for profile: AppLockManager.UserProfile) async throws -> UUID {
        if let externalId = profile.externalUserId,
           let uuid = UUID(uuidString: externalId) {
            return uuid
        }
        return try await walletManager.currentSupabaseUserId()
    }

    private func makeMessageRequest(
        from draft: CaptureTaskFormView.TaskDraft,
        authorId: UUID,
        profile: AppLockManager.UserProfile
    ) -> SupabaseService.MessageRequest {
        SupabaseService.MessageRequest(
            authorId: authorId,
            practitionerName: "\(profile.firstName) \(profile.lastName)".trimmed,
            practitionerRole: profile.role.displayName,
            patientNhsNumber: draft.nhsNumber,
            requestId: draft.qrMetadata.requestId.flatMap { $0.trimmedNonEmpty },
            requestType: draft.selectedRequestType.rawValue,
            reason: draft.qrMetadata.reason.flatMap { $0.trimmedNonEmpty },
            locationCategory: draft.patientLocation.rawValue,
            locationDescription: draft.patientLocation == .manual ? draft.manualLocationDescription.trimmedNonEmpty : nil,
            additionalNotes: draft.additionalNotes.trimmedNonEmpty,
            rawPayload: draft.qrMetadata.rawJSON,
            highlights: makeHighlights(for: draft)
        )
    }

    private func makeHighlights(for draft: CaptureTaskFormView.TaskDraft) -> [SupabaseService.MessageRequest.Highlight] {
        var highlights: [SupabaseService.MessageRequest.Highlight] = []
        var seen = Set<String>()

        func add(label: String, value: String) {
            guard let cleaned = value.trimmedNonEmpty else { return }
            let key = "\(label.lowercased())::\(cleaned.lowercased())"
            guard seen.insert(key).inserted else { return }
            highlights.append(.init(label: label, value: cleaned))
        }

        if let reason = draft.qrMetadata.reason?.trimmedNonEmpty {
            add(label: "Reason", value: reason)
        }
        if let requestType = draft.qrMetadata.requestType?.trimmedNonEmpty {
            add(label: "Request Type", value: requestType)
        }
        if let identifier = draft.qrMetadata.requestId?.trimmedNonEmpty {
            add(label: "Reference", value: identifier)
        }

        for highlight in draft.qrMetadata.additionalHighlights {
            add(label: highlight.label, value: highlight.value)
        }

        return highlights
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
        let normalized = try Self.normalizeScannedPayload(payload)
        let reason = CaptureTaskView.locateString(for: ["reason", "requestReason", "purpose"], in: normalized.dictionary)
        let requestType = CaptureTaskView.locateString(for: ["requestType", "type", "category"], in: normalized.dictionary)
        let identifier = CaptureTaskView.locateString(for: ["requestId", "id", "identifier"], in: normalized.dictionary)
        let excludedKeys = ["reason", "requestReason", "purpose", "requestType", "type", "category", "requestId", "id", "identifier"].map { $0.lowercased() }
        let highlights = CaptureTaskView.collectHighlights(from: normalized.dictionary, excludingKeys: excludedKeys)
        let prettyJSON = try CaptureTaskView.prettyPrintedJSON(from: normalized.data)

        return CaptureMetadata(
            requestId: identifier,
            requestType: requestType,
            reason: reason,
            additionalHighlights: highlights,
            rawJSON: prettyJSON,
            rawEnvelope: normalized.envelope,
            payloadFormat: normalized.format
        )
    }

    private static func normalizeScannedPayload(_ raw: String) throws -> NormalizedPayload {
        if let detailed = try? PayloadEncoder.decodePayloadDetailed(raw),
           let dictionary = try? decodeJSONDictionary(from: detailed.data) {
            let format = PayloadFormat(from: detailed.format)
            return NormalizedPayload(data: detailed.data, dictionary: dictionary, format: format, envelope: raw)
        }

        if raw.lowercased().hasPrefix("sd-jwt:") {
            let sdjwtData = try decodeSDJWTPayload(raw)
            let dictionary = try decodeJSONDictionary(from: sdjwtData)
            return NormalizedPayload(data: sdjwtData, dictionary: dictionary, format: .sdJWT, envelope: raw)
        }

        guard let utfData = raw.data(using: .utf8) else {
            throw CaptureTaskError.unreadablePayload
        }
        let dictionary = try decodeJSONDictionary(from: utfData)
        return NormalizedPayload(data: utfData, dictionary: dictionary, format: .plainJSON, envelope: raw)
    }

    private static func decodeJSONDictionary(from data: Data) throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw CaptureTaskError.unsupportedPayload
        }
        return dictionary
    }

    private static func decodeSDJWTPayload(_ raw: String) throws -> Data {
        let prefixLength = "sd-jwt:".count
        let startIndex = raw.index(raw.startIndex, offsetBy: prefixLength)
        let suffix = raw[startIndex...]
        let components = suffix.split(separator: "~", omittingEmptySubsequences: false)
        guard let jwtComponent = components.first else {
            throw CaptureTaskError.sdJwtDecodingFailed
        }
        let segments = jwtComponent.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else {
            throw CaptureTaskError.sdJwtDecodingFailed
        }
        let payloadSegment = String(segments[1])
        guard let payloadData = base64URLDecode(payloadSegment) else {
            throw CaptureTaskError.sdJwtDecodingFailed
        }
        return payloadData
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: padding))
        }
        return Data(base64Encoded: base64)
    }

    private enum CaptureTaskError: LocalizedError {
        case unreadablePayload
        case unsupportedPayload
        case sdJwtDecodingFailed

        var errorDescription: String? {
            switch self {
            case .unreadablePayload:
                return "The scanned QR code does not contain a readable payload."
            case .unsupportedPayload:
                return "The QR payload was not valid JSON."
            case .sdJwtDecodingFailed:
                return "The SD-JWT payload could not be decoded."
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
    enum PayloadFormat {
        case sdJWT
        case compressedWithPrefix
        case inferredCompressed
        case plainJSON

        var displayName: String {
            switch self {
            case .sdJWT:
                return "SD-JWT"
            case .compressedWithPrefix:
                return "Compressed JSON (prefixed)"
            case .inferredCompressed:
                return "Compressed JSON (detected)"
            case .plainJSON:
                return "Plain JSON"
            }
        }
    }

    struct CaptureMetadata {
        let requestId: String?
        let requestType: String?
        let reason: String?
        let additionalHighlights: [Highlight]
        let rawJSON: String
        let rawEnvelope: String
        let payloadFormat: PayloadFormat

        var payloadFormatDisplayName: String { payloadFormat.displayName }
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

extension CaptureTaskView.PayloadFormat {
    init(from format: PayloadEncoder.DecodedPayloadFormat) {
        switch format {
        case .prefixedCompressed:
            self = .compressedWithPrefix
        case .inferredCompressed:
            self = .inferredCompressed
        case .plainUTF8:
            self = .plainJSON
        }
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

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNonEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }
}
