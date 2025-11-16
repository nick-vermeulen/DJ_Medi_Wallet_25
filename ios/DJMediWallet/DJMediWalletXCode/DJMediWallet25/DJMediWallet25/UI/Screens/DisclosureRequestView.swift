import SwiftUI
import Combine
import UIKit

struct DisclosureRequestView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @StateObject private var viewModel = DisclosureRequestViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introCard
                qrSection
                if let request = viewModel.request {
                    requestDetails(for: request)
                }
            }
            .padding()
        }
        .navigationTitle("Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.generateRequest(profile: lockManager.userProfile)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .task {
            viewModel.generateRequest(profile: lockManager.userProfile)
        }
        .onChange(of: lockManager.userProfile, initial: false) { _, profile in
            viewModel.generateRequest(profile: profile)
        }
        .alert("Unable to Create Request", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selective Disclosure Request")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Generate a QR code that asks the patient to share their observations from the last 24 hours along with their current medications. Present this code for the nearby patient wallet to scan.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var qrSection: some View {
        if let image = viewModel.qrImage {
            VStack(spacing: 16) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                Text("Present this QR to the patient wallet.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemGray6))
                .frame(height: 220)
                .overlay {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Creating request…")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
        }
    }

    private func requestDetails(for request: SDJWTPresentationRequest) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Request Details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                metadataRow(label: "Verifier", value: request.metadata.verifierDisplayName)
                metadataRow(label: "Purpose", value: request.metadata.purpose)
                if let nonce = request.metadata.nonce, nonce.isEmpty == false {
                    metadataRow(label: "Nonce", value: nonce)
                }
                if let expiry = request.metadata.expiry {
                    metadataRow(label: "Expires", value: expiry.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )

            VStack(alignment: .leading, spacing: 12) {
                Text("Requested Disclosures")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(request.requestedDisclosures) { claim in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(claim.displayName)
                            .font(.body)
                            .fontWeight(.semibold)
                        if let description = claim.description, description.isEmpty == false {
                            Text(description)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 8) {
                            Label(claim.credentialType, systemImage: "doc.text")
                            if claim.mandatory {
                                Label("Required", systemImage: "checkmark.shield")
                            } else {
                                Label("Optional", systemImage: "hand.raised")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                }
            }

            if viewModel.prettyJSON.isEmpty == false {
                DisclosureGroup("Request JSON") {
                    ScrollView {
                        Text(viewModel.prettyJSON)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 240)
                }
            }

            if viewModel.encodedPayload.isEmpty == false {
                DisclosureGroup("QR Payload") {
                    ScrollView {
                        Text(viewModel.encodedPayload)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 240)
                }
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
}

@MainActor
final class DisclosureRequestViewModel: ObservableObject {
    @Published var request: SDJWTPresentationRequest?
    @Published var qrImage: UIImage?
    @Published var encodedPayload: String = ""
    @Published var prettyJSON: String = ""
    @Published var errorMessage: String?

    private static let responseEndpoint = URL(string: "https://mediwallet.local/presentation-response")!

    func generateRequest(profile: AppLockManager.UserProfile?) {
        do {
            let request = try buildRequest(profile: profile)
            let payload = try PayloadEncoder.encode(request)
            guard let image = QRCodeRenderer.image(for: payload) else {
                throw GenerationError.qrEncodingFailed
            }
            let formattedJSON = try makePrettyJSON(for: request)

            self.request = request
            self.qrImage = image
            self.encodedPayload = payload
            self.prettyJSON = formattedJSON
            self.errorMessage = nil
        } catch {
            request = nil
            qrImage = nil
            encodedPayload = ""
            prettyJSON = ""
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func buildRequest(profile: AppLockManager.UserProfile?) throws -> SDJWTPresentationRequest {
        let requestId = UUID()
        let verifierName = makeVerifierName(from: profile)
        let expiry = Calendar.current.date(byAdding: .minute, value: 15, to: Date())

        let metadata = SDJWTPresentationRequest.Metadata(
            verifierDisplayName: verifierName,
            verifierDid: nil,
            verifierUrl: nil,
            purpose: "Request observations from the last 24 hours and current medication statements.",
            audience: profile?.externalUserId,
            nonce: UUID().uuidString.replacingOccurrences(of: "-", with: ""),
            expiry: expiry,
            responseURI: Self.responseEndpoint
        )

        let claims = [
            SDJWTClaimRequest(
                id: "recent_observations",
                displayName: "Recent Observations (24h)",
                description: "Share observations captured within the previous 24 hours.",
                credentialType: "Observation",
                claimPath: "fhir.*",
                mandatory: false,
                valueType: "Observation"
            ),
            SDJWTClaimRequest(
                id: "current_medication",
                displayName: "Current Medication",
                description: "Share your active medication statements.",
                credentialType: "MedicationStatement",
                claimPath: "fhir.*",
                mandatory: false,
                valueType: "MedicationStatement"
            )
        ]

        return SDJWTPresentationRequest(id: requestId, metadata: metadata, requestedDisclosures: claims)
    }

    private func makePrettyJSON(for request: SDJWTPresentationRequest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(request)
        return String(decoding: data, as: UTF8.self)
    }

    private func makeVerifierName(from profile: AppLockManager.UserProfile?) -> String {
        guard let profile else { return "Healthcare Practitioner" }
        let first = profile.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = profile.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = [first, last].filter { $0.isEmpty == false }
        if components.isEmpty {
            return profile.role.displayName.capitalized
        }
        return components.joined(separator: " ")
    }

    private enum GenerationError: LocalizedError {
        case qrEncodingFailed

        var errorDescription: String? {
            "Unable to render the QR code for this request."
        }
    }
}

#Preview {
    DisclosureRequestView()
        .environmentObject(AppLockManager())
}
