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

    private var client: SupabaseClient?
    private var configuration: SupabaseConfig?
    private let urlSession: URLSession
    private let maxRetryAttempts = 3
    private let initialRetryDelay: UInt64 = 500_000_000 // 0.5s
    private let maximumRetryDelay: UInt64 = 4_000_000_000 // 4s

    private init() {
        self.client = nil
        self.urlSession = URLSession(configuration: .default)
    }

    var isConfigured: Bool {
        client != nil
    }

    func currentUserId() async throws -> UUID {
        let client = try await requireClient()
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw ServiceError.notAuthenticated
        }
    }

    func fetchPatientRecords(for patientId: UUID) async throws -> [MedicalCredential] {
        let client = try await requireClient()
        return try await performWithRetry {
            let response = try await client
                .from("health_records")
                .select()
                .eq("patient_id", value: patientId.uuidString)
                .order("updated_at", ascending: false)
                .execute()
            let data = response.data
            guard data.isEmpty == false else { return [] }
            let payload = try SupabaseService.makeDecoder().decode([SupabaseHealthRecord].self, from: data)
            return await MainActor.run {
                payload.map { $0.toCredential() }
            }
        }
    }

    func authStateChangeStream() async throws -> AsyncStream<(event: AuthChangeEvent, session: Session?)> {
        let client = try await requireClient()
        return client.auth.authStateChanges
    }

    private func requireClient() async throws -> SupabaseClient {
        await prepareClientIfNeeded()
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

    func submitPresentationResponse(
        _ response: SDJWTPresentationResponse,
        to endpoint: URL
    ) async throws -> PresentationSubmissionReceipt {
        let encodedResponse = try await SupabaseService.encodeResponseForTransmission(response)
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = encodedResponse

        let (data, rawResponse): (Data, URLResponse)
        do {
            (data, rawResponse) = try await urlSession.data(for: urlRequest)
        } catch {
            throw map(error)
        }

        guard let httpResponse = rawResponse as? HTTPURLResponse else {
            throw ServiceError.requestFailed("Verifier returned an invalid response.")
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ServiceError.requestFailed("Verifier rejected presentation (status \(httpResponse.statusCode)): \(body)")
        }

        if data.isEmpty {
            return PresentationSubmissionReceipt(submissionId: nil, status: "submitted", receivedAt: Date())
        }

        do {
            return try await SupabaseService.decodeSubmissionReceipt(from: data)
        } catch {
            return PresentationSubmissionReceipt(submissionId: nil, status: "submitted", receivedAt: Date())
        }
    }

    func createMessage(_ request: MessageRequest) async throws -> MessageResponse {
        let client = try await requireClient()
        guard let configuration else {
            throw ServiceError.misconfigured
        }

        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            throw ServiceError.notAuthenticated
        }

        return try await performWithRetry { [urlSession] in
            var urlRequest = URLRequest(url: configuration.url.appendingPathComponent("rest/v1/rpc/createMessage"))
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.setValue("return=representation", forHTTPHeaderField: "Prefer")
            urlRequest.setValue(configuration.anonKey, forHTTPHeaderField: "apikey")
            urlRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = try SupabaseService.makeEncoder().encode(request)

            let (data, response) = try await urlSession.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.requestFailed("Supabase returned an invalid response.")
            }

            guard (200 ..< 300).contains(httpResponse.statusCode) else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw ServiceError.requestFailed("createMessage failed with status \(httpResponse.statusCode): \(body)")
            }

            if data.isEmpty {
                return MessageResponse(id: nil, status: "submitted", createdAt: Date())
            }

            let decoder = SupabaseService.makeDecoder()
            if let response = try? decoder.decode(MessageResponse.self, from: data) {
                return response
            }
            if let responses = try? decoder.decode([MessageResponse].self, from: data), let first = responses.first {
                return first
            }

            throw ServiceError.requestFailed("Unexpected payload received from createMessage.")
        }
    }

    private func prepareClientIfNeeded() async {
        guard client == nil else { return }
        guard let config = await MainActor.run(body: { SupabaseConfig.loadDefault() }) else {
            return
        }
        client = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
        configuration = config
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    private static func encodeResponseForTransmission(_ response: SDJWTPresentationResponse) async throws -> Data {
        try await MainActor.run {
            try SupabaseService.makeEncoder().encode(response)
        }
    }

    private static func decodeSubmissionReceipt(from data: Data) async throws -> PresentationSubmissionReceipt {
        try await MainActor.run {
            try SupabaseService.makeDecoder().decode(PresentationSubmissionReceipt.self, from: data)
        }
    }
}

// MARK: - Supabase DTOs

extension SupabaseService {
    struct MessageRequest: Encodable {
        struct Highlight: Encodable {
            let label: String
            let value: String
        }

        let authorId: UUID
        let practitionerName: String
        let practitionerRole: String
        let patientNhsNumber: String
        let requestId: String?
        let requestType: String?
        let reason: String?
        let locationCategory: String
        let locationDescription: String?
        let additionalNotes: String?
        let rawPayload: String
        let highlights: [Highlight]
    }

    struct MessageResponse: Decodable {
        let id: UUID?
        let status: String?
        let createdAt: Date?

        private enum CodingKeys: String, CodingKey {
            case id
            case status
            case createdAt = "created_at"
            case messageId = "message_id"
        }

        init(id: UUID?, status: String?, createdAt: Date?) {
            self.id = id
            self.status = status
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let directId = try container.decodeIfPresent(UUID.self, forKey: .id) {
                id = directId
            } else if let messageId = try container.decodeIfPresent(UUID.self, forKey: .messageId) {
                id = messageId
            } else if let idString = try container.decodeIfPresent(String.self, forKey: .id), let parsed = UUID(uuidString: idString) {
                id = parsed
            } else if let idString = try container.decodeIfPresent(String.self, forKey: .messageId), let parsed = UUID(uuidString: idString) {
                id = parsed
            } else {
                id = nil
            }
            status = try container.decodeIfPresent(String.self, forKey: .status)
            createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        }
    }
}

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
