//
//  SupabaseService.swift
//  DJMediWallet25
//
//  Centralized integration point for Supabase database, auth, and realtime APIs.
//

import Foundation
import Supabase

actor SupabaseService {
    enum ServiceError: LocalizedError {
        case misconfigured
        case notAuthenticated
        case invalidUserIdentifier
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .misconfigured:
                return "Supabase is not configured for this build."
            case .notAuthenticated:
                return "You are not signed in to Supabase."
            case .invalidUserIdentifier:
                return "Unable to determine the current Supabase user."
            case .requestFailed(let reason):
                return reason
            }
        }
    }

    static let shared = SupabaseService()

    private let client: SupabaseClient?
    private let decoder: JSONDecoder

    private init() {
        if let config = SupabaseConfig.load() {
            self.client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        } else {
            self.client = nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    var isConfigured: Bool {
        client != nil
    }

    func currentUserId() async throws -> UUID {
        let client = try requireClient()
        if let session = client.auth.session, let uuid = UUID(uuidString: session.user.id) {
            return uuid
        }
        throw ServiceError.invalidUserIdentifier
    }

    func fetchPatientRecords(for patientId: UUID) async throws -> [MedicalCredential] {
        let client = try requireClient()
        do {
            let response = try await client.database
                .from("health_records")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .order("updated_at", ascending: false)
                .execute()
            guard let data = response.data else {
                return []
            }
            let payload = try decoder.decode([SupabaseHealthRecord].self, from: data)
            return payload.map { $0.toCredential() }
        } catch {
            throw map(error)
        }
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            throw ServiceError.misconfigured
        }
        return client
    }

    private func map(_ error: Error) -> Error {
        if let serviceError = error as? ServiceError {
            return serviceError
        }
        return ServiceError.requestFailed(error.localizedDescription)
    }
}

// MARK: - Supabase DTOs

private struct SupabaseHealthRecord: Decodable {
    let id: UUID
    let recordType: String?
    let issuer: String?
    let issuanceDate: Date?
    let expirationDate: Date?
    let fhirData: FHIRResource?

    enum CodingKeys: String, CodingKey {
        case id
        case recordType = "record_type"
        case issuer
        case issuanceDate = "issuance_date"
        case expirationDate = "expiration_date"
        case fhirData = "fhir_data"
    }

    func toCredential() -> MedicalCredential {
        MedicalCredential(
            id: id.uuidString,
            type: recordType ?? fhirData?.resourceType ?? "MedicalRecord",
            issuer: issuer ?? "Supabase",
            issuanceDate: issuanceDate ?? Date(),
            expirationDate: expirationDate,
            fhirResource: fhirData
        )
    }
}
