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
    private let maxRetryAttempts = 3
    private let initialRetryDelay: UInt64 = 500_000_000 // 0.5s
    private let maximumRetryDelay: UInt64 = 4_000_000_000 // 4s

    private init() {
        if let config = SupabaseConfig.loadDefault() {
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
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw ServiceError.notAuthenticated
        }
    }

    func fetchPatientRecords(for patientId: UUID) async throws -> [MedicalCredential] {
        let client = try requireClient()
        return try await performWithRetry { [self] in
            let response = try await client
                .from("health_records")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .order("updated_at", ascending: false)
                .execute()
            let data = response.data
            guard data.isEmpty == false else { return [] }
            let payload = try self.decoder.decode([SupabaseHealthRecord].self, from: data)
            return await MainActor.run {
                payload.map { $0.toCredential() }
            }
        }
    }

    func authStateChangeStream() async throws -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        let client = try requireClient()
        return client.auth.authStateChanges
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else {
            throw ServiceError.misconfigured
        }
        return client
    }

    private func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var attempt = 0
        var delay = initialRetryDelay
        while true {
            do {
                return try await operation()
            } catch {
                attempt += 1
                guard attempt < maxRetryAttempts, shouldRetry(error) else {
                    throw map(error)
                }
                try await Task.sleep(nanoseconds: delay)
                delay = min(delay * 2, maximumRetryDelay)
            }
        }
    }

    private func shouldRetry(_ error: Error) -> Bool {
        if let serviceError = error as? ServiceError {
            switch serviceError {
            case .notAuthenticated, .invalidUserIdentifier, .misconfigured:
                return false
            case .requestFailed:
                return true
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        return true
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
