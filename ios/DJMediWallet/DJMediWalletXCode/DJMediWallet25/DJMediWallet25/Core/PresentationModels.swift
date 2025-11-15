//
//  PresentationModels.swift
//  DJMediWallet25
//
//  Domain models supporting SD-JWT presentation requests and responses.
//

import Foundation

// MARK: - Presentation Request Models

struct SDJWTPresentationRequest: Codable, Identifiable {
    struct Metadata: Codable {
        let verifierDisplayName: String
        let verifierDid: String?
        let verifierUrl: URL?
        let purpose: String
        let audience: String?
        let nonce: String?
        let expiry: Date?
        let responseURI: URL

        enum CodingKeys: String, CodingKey {
            case verifierDisplayName
            case verifierDid
            case verifierUrl
            case purpose
            case audience
            case nonce
            case expiry
            case responseURI = "responseUri"
        }
    }

    let id: UUID
    let metadata: Metadata
    let requestedDisclosures: [SDJWTClaimRequest]

    enum CodingKeys: String, CodingKey {
        case id = "requestId"
        case metadata
        case requestedDisclosures
    }
}

struct SDJWTClaimRequest: Codable, Identifiable {
    let id: String
    let displayName: String
    let description: String?
    let credentialType: String
    let claimPath: String
    let mandatory: Bool
    let valueType: String?

    enum CodingKeys: String, CodingKey {
        case id = "claimId"
        case displayName
        case description
        case credentialType
        case claimPath
        case mandatory
        case valueType
    }
}

// MARK: - Selective Disclosure Models

struct SDJWTClaimSelection {
    let claim: SDJWTClaimRequest
    let credential: MedicalCredential
}

struct SDJWTDisclosedClaim: Codable, Identifiable {
    let id: String
    let claimId: String
    let credentialId: String
    let credentialType: String
    let claimPath: String
    let purpose: String?
    let mandatory: Bool
    let value: SDJWTClaimValue

    init(claim: SDJWTClaimRequest, credential: MedicalCredential, value: SDJWTClaimValue) {
        self.id = UUID().uuidString
        self.claimId = claim.id
        self.credentialId = credential.id
        self.credentialType = credential.type
        self.claimPath = claim.claimPath
        self.purpose = claim.description
        self.mandatory = claim.mandatory
        self.value = value
    }
}

enum SDJWTClaimValue: Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: SDJWTClaimValue])
    case array([SDJWTClaimValue])
    case null
}

extension SDJWTClaimValue: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let object = try? container.decode([String: SDJWTClaimValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([SDJWTClaimValue].self) {
            self = .array(array)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported claim value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .object(let object):
            try container.encode(object)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
}

struct SDJWTPresentationPayload: Codable {
    let requestId: String
    let audience: String?
    let nonce: String?
    let issuedAt: Date
    let expiresAt: Date?
    let disclosures: [SDJWTDisclosedClaim]
}

struct SDJWTPresentationResponse: Codable {
    let requestId: String
    let payload: String
    let signature: String
    let publicKey: String
    let algorithm: String
    let disclosedClaims: [SDJWTDisclosedClaim]
    let audience: String?
    let nonce: String?
    let issuedAt: Date
}

struct SDJWTPresentationSignature {
    let payload: SDJWTPresentationPayload
    let encodedPayload: String
    let signature: String
    let publicKey: String
    let algorithm: String
}

struct PresentationSubmissionReceipt: Decodable, Equatable {
    let submissionId: String?
    let status: String
    let receivedAt: Date?
}