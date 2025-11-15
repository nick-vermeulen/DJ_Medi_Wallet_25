//
//  PresentationViewModel.swift
//  DJMediWallet25
//
//  State container that orchestrates scanning, consent, and submission of SD-JWT presentations.
//

import Foundation
import Combine

@MainActor
final class PresentationViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case loading
        case ready
        case submitting
        case submitted(PresentationSubmissionReceipt)
        case error(String)
    }

    struct AlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var status: Status = .idle
    @Published var request: SDJWTPresentationRequest?
    @Published var claims: [PresentationDisclosureClaim] = []
    @Published var isScannerPresented = false
    @Published var alert: AlertContext?

    var canSubmit: Bool {
        guard case .ready = status else { return false }
        return claims.contains { $0.include }
    }

    func beginScan() {
        isScannerPresented = true
    }

    func cancelScan() {
        isScannerPresented = false
    }

    func reset() {
        status = .idle
        request = nil
        claims = []
        alert = nil
    }

    func handleScanResult(_ result: Result<String, QRScannerError>, walletManager: WalletManager) {
        isScannerPresented = false

        switch result {
        case .failure(let error):
            alert = AlertContext(title: "Scanner Error", message: error.localizedDescription)
        case .success(let payload):
            Task {
                await loadRequest(from: payload, walletManager: walletManager)
            }
        }
    }

    func loadRequest(from payload: String, walletManager: WalletManager) async {
        status = .loading

        do {
            let presentationRequest = try await PresentationRequestResolver.resolve(from: payload)
            let credentials = try await walletManager.getAllCredentialsAsync()
            let disclosureClaims = try buildClaims(for: presentationRequest, credentials: credentials)

            request = presentationRequest
            claims = disclosureClaims
            status = .ready
        } catch let walletError as WalletError {
            status = .error(walletError.localizedDescription)
            alert = AlertContext(title: "Validation Error", message: walletError.localizedDescription)
        } catch {
            status = .error(error.localizedDescription)
            alert = AlertContext(title: "Request Error", message: error.localizedDescription)
        }
    }

    func submit(walletManager: WalletManager) async {
        guard let activeRequest = request else {
            alert = AlertContext(title: "No Request", message: "Scan a presentation request before submitting.")
            return
        }

        guard case .ready = status else { return }

        do {
            let selections = try buildSelections()
            status = .submitting
            let response = try await walletManager.preparePresentationResponse(for: activeRequest, selections: selections)
            let receipt = try await SupabaseService.shared.submitPresentationResponse(response, to: activeRequest.metadata.responseURI)
            status = .submitted(receipt)
        } catch let walletError as WalletError {
            status = .ready
            alert = AlertContext(title: "Disclosure Error", message: walletError.localizedDescription)
        } catch {
            status = .ready
            alert = AlertContext(title: "Submission Error", message: error.localizedDescription)
        }
    }

    private func buildClaims(for request: SDJWTPresentationRequest, credentials: [MedicalCredential]) throws -> [PresentationDisclosureClaim] {
        var result: [PresentationDisclosureClaim] = []

        for claimRequest in request.requestedDisclosures {
            let matchingCredentials = credentials.filter { credential in
                credentialMatches(claimRequest: claimRequest, credential: credential)
            }

            let options = matchingCredentials.compactMap { credential -> PresentationDisclosureOption? in
                guard let value = credential.value(forClaimPath: claimRequest.claimPath) else { return nil }
                return PresentationDisclosureOption(claim: claimRequest, credential: credential, value: value)
            }

            if claimRequest.mandatory && options.isEmpty {
                throw WalletError.disclosureValidationFailed("No credential satisfies the required claim \(claimRequest.displayName).")
            }

            let disclosureClaim = PresentationDisclosureClaim(
                claim: claimRequest,
                options: options,
                selectedOptionId: options.first?.id,
                include: claimRequest.mandatory
            )

            result.append(disclosureClaim)
        }

        return result
    }

    private func buildSelections() throws -> [SDJWTClaimSelection] {
        var selections: [SDJWTClaimSelection] = []

        for claim in claims where claim.include {
            guard let option = claim.selectedOption else {
                throw WalletError.disclosureValidationFailed("Select a credential to satisfy \(claim.claim.displayName).")
            }
            selections.append(SDJWTClaimSelection(claim: claim.claim, credential: option.credential))
        }

        guard selections.isEmpty == false else {
            throw WalletError.disclosureValidationFailed("No credential data selected for disclosure.")
        }

        return selections
    }

    private func credentialMatches(claimRequest: SDJWTClaimRequest, credential: MedicalCredential) -> Bool {
        if credential.type.caseInsensitiveCompare(claimRequest.credentialType) == .orderedSame {
            return true
        }

        if let resourceType = credential.fhirResource?.resourceType,
           resourceType.caseInsensitiveCompare(claimRequest.credentialType) == .orderedSame {
            return true
        }

        return false
    }
}

// MARK: - Disclosure Claim View Models

struct PresentationDisclosureClaim: Identifiable {
    let claim: SDJWTClaimRequest
    let options: [PresentationDisclosureOption]
    var selectedOptionId: String?
    var include: Bool

    var id: String { claim.id }
    var isRequired: Bool { claim.mandatory }
    var selectedOption: PresentationDisclosureOption? {
        guard let selectedOptionId else { return nil }
        return options.first { $0.id == selectedOptionId }
    }
}

struct PresentationDisclosureOption: Identifiable {
    let id: String
    let credential: MedicalCredential
    let title: String
    let subtitle: String
    let valueSummary: String
    let value: SDJWTClaimValue

    init(claim: SDJWTClaimRequest, credential: MedicalCredential, value: SDJWTClaimValue) {
        self.id = credential.id
        self.credential = credential
        let record = RecordItem(from: credential)
        self.title = record.title
        self.subtitle = record.description
        self.valueSummary = PresentationDisclosureOption.format(value: value)
        self.value = value
    }

    private static func format(value: SDJWTClaimValue) -> String {
        switch value {
        case .string(let string):
            return string
        case .number(let number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        case .bool(let bool):
            return bool ? "Yes" : "No"
        case .null:
            return "Not set"
        case .array(let array):
            return array.map { format(value: $0) }.joined(separator: ", ")
        case .object(let object):
            let parts = object
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \(format(value: $0.value))" }
            return parts.isEmpty ? "—" : parts.joined(separator: ", ")
        }
    }
}