//
//  WalletManager.swift
//  DJMediWallet
//
//  Core wallet management functionality
//

import Foundation
import CryptoKit
import Combine

/// Main wallet manager for handling medical credentials
public class WalletManager: ObservableObject {
    
    // MARK: - Properties
    
    private let securityManager: SecurityManager
    private let credentialManager: CredentialManager
    private let storage: SecureStorage
    private let supabaseService: SupabaseService
    public let config: WalletConfig
    
    /// Shared instance with default configuration
    public static let shared: WalletManager = {
        return try! WalletManager(config: .default)
    }()
    
    // MARK: - Initialization
    
    /// Initialize wallet with configuration
    /// - Parameter config: Wallet configuration
    public init(config: WalletConfig) throws {
        self.config = config
        self.securityManager = SecurityManager(config: config)
        self.credentialManager = CredentialManager()
        self.storage = SecureStorage(serviceName: config.serviceName)
    self.supabaseService = SupabaseService.shared
    }
    
    /// Builder for creating wallet with custom configuration
    public class Builder {
        private var serviceName: String = WalletConfig.defaultServiceName
        private var accessGroup: String?
        private var userAuthenticationRequired: Bool = true
        private var authenticationTimeout: TimeInterval = 30
        private var useSecureEnclaveWhenAvailable: Bool = true
        private var trustedReaderCertificates: [Data]?
        
        public init() {}
        
        public func serviceName(_ name: String) -> Builder {
            self.serviceName = name
            return self
        }
        
        public func accessGroup(_ group: String?) -> Builder {
            self.accessGroup = group
            return self
        }
        
        public func userAuthenticationRequired(_ required: Bool) -> Builder {
            self.userAuthenticationRequired = required
            return self
        }
        
        public func authenticationTimeout(_ timeout: TimeInterval) -> Builder {
            self.authenticationTimeout = timeout
            return self
        }
        
        public func useSecureEnclave(_ use: Bool) -> Builder {
            self.useSecureEnclaveWhenAvailable = use
            return self
        }
        
        public func trustedReaderCertificates(_ certificates: [Data]?) -> Builder {
            self.trustedReaderCertificates = certificates
            return self
        }
        
        public func build() throws -> WalletManager {
            let config = try WalletConfig(
                serviceName: serviceName,
                accessGroup: accessGroup,
                userAuthenticationRequired: userAuthenticationRequired,
                authenticationTimeout: authenticationTimeout,
                useSecureEnclaveWhenAvailable: useSecureEnclaveWhenAvailable,
                trustedReaderCertificates: trustedReaderCertificates
            )
            return try WalletManager(config: config)
        }
    }
    
    // MARK: - Wallet Lifecycle
    
    /// Initialize wallet with user authentication
    public func initializeWallet(completion: @escaping (Result<Void, WalletError>) -> Void) {
        // Generate device key pair
        securityManager.generateDeviceKeyPair { result in
            switch result {
            case .success:
                // Initialize secure storage
                self.storage.initialize { storageResult in
                    completion(storageResult)
                }
            case .failure(let error):
                completion(.failure(.initializationFailed(error)))
            }
        }
    }
    
    /// Check if wallet is initialized
    public func isWalletInitialized() -> Bool {
        return securityManager.hasDeviceKeyPair() && storage.isInitialized()
    }
    
    // MARK: - Credential Management
    
    /// Add a new medical credential to the wallet
    public func addCredential(_ credential: MedicalCredential, completion: @escaping (Result<String, WalletError>) -> Void) {
        // Validate credential
        guard credentialManager.validateCredential(credential) else {
            completion(.failure(.invalidCredential))
            return
        }
        
        // Store credential securely
        storage.storeCredential(credential) { result in
            switch result {
            case .success(let id):
                completion(.success(id))
            case .failure(let error):
                completion(.failure(.storageFailed(error)))
            }
        }
    }
    
    /// Retrieve all credentials
    public func getAllCredentials(completion: @escaping (Result<[MedicalCredential], WalletError>) -> Void) {
        storage.retrieveAllCredentials { result in
            completion(result)
        }
    }
    
    /// Retrieve credential by ID
    public func getCredential(id: String, completion: @escaping (Result<MedicalCredential, WalletError>) -> Void) {
        storage.retrieveCredential(id: id) { result in
            completion(result)
        }
    }
    
    /// Delete a credential
    public func deleteCredential(id: String, completion: @escaping (Result<Void, WalletError>) -> Void) {
        storage.deleteCredential(id: id) { result in
            completion(result)
        }
    }

    // MARK: - Supabase Integration

    /// Ensures the secure storage layer is initialized before performing operations.
    public func initializeWalletIfNeeded() async throws {
        guard !isWalletInitialized() else { return }
        try await withCheckedThrowingContinuation { continuation in
            initializeWallet { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Retrieves all credentials from secure storage using Swift concurrency.
    public func getAllCredentialsAsync() async throws -> [MedicalCredential] {
        try await withCheckedThrowingContinuation { continuation in
            getAllCredentials { result in
                switch result {
                case .success(let credentials):
                    continuation.resume(returning: credentials)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Synchronizes the local credential store with the records returned by Supabase for the specified patient.
    /// - Parameter patientId: The Supabase user identifier representing the patient.
    /// - Returns: The list of credentials fetched from Supabase after they are stored locally.
    public func syncPatientRecordsFromSupabase(patientId: UUID) async throws -> [MedicalCredential] {
        let remoteCredentials = try await supabaseService.fetchPatientRecords(for: patientId)
        try await synchronizeLocalStore(with: remoteCredentials)
        return remoteCredentials
    }

    private func synchronizeLocalStore(with remoteCredentials: [MedicalCredential]) async throws {
        let existing = try await getAllCredentialsAsync()
        let existingIds = Set(existing.map { $0.id })
        let remoteIds = Set(remoteCredentials.map { $0.id })

        let idsToDelete = existingIds.subtracting(remoteIds)
        for identifier in idsToDelete {
            try await deleteCredentialAsync(id: identifier)
        }

        for credential in remoteCredentials {
            try await storeCredentialAsync(credential)
        }
    }

    private func storeCredentialAsync(_ credential: MedicalCredential) async throws {
        try await withCheckedThrowingContinuation { continuation in
            storage.storeCredential(credential) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func deleteCredentialAsync(id: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            storage.deleteCredential(id: id) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Metadata
    
    public func storeMetadata<T: Codable>(_ value: T, forKey key: String, completion: @escaping (Result<Void, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.storage.storeMetadata(value, forKey: key)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.storageFailed(error)))
                }
            }
        }
    }
    
    public func loadMetadata<T: Codable>(_ type: T.Type, forKey key: String, completion: @escaping (Result<T?, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let value = try self.storage.loadMetadata(type, forKey: key)
                DispatchQueue.main.async {
                    completion(.success(value))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.retrievalFailed(error)))
                }
            }
        }
    }
    
    public func deleteMetadata(forKey key: String, completion: @escaping (Result<Void, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.storage.deleteMetadata(forKey: key)
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.deletionFailed(error)))
                }
            }
        }
    }
    
    // MARK: - Credential Presentation
    
    /// Create a presentation for sharing with healthcare providers
    public func createPresentation(credentialIds: [String], completion: @escaping (Result<CredentialPresentation, WalletError>) -> Void) {
        // Retrieve credentials
        var credentials: [MedicalCredential] = []
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for id in credentialIds {
            group.enter()
            storage.retrieveCredential(id: id) { result in
                switch result {
                case .success(let credential):
                    credentials.append(credential)
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            guard errors.isEmpty else {
                completion(.failure(.retrievalFailed(errors.first!)))
                return
            }
            
            // Sign presentation
            self.securityManager.signPresentation(credentials: credentials) { result in
                switch result {
                case .success(let presentation):
                    completion(.success(presentation))
                case .failure(let error):
                    completion(.failure(.signingFailed(error)))
                }
            }
        }
    }
    
    // MARK: - Security
    
    /// Authenticate user with biometrics or PIN
    public func authenticateUser(completion: @escaping (Result<Void, WalletError>) -> Void) {
        securityManager.authenticateUser { result in
            completion(result)
        }
    }
}

// MARK: - Wallet Error Types

public enum WalletError: Error {
    case notInitialized
    case initializationFailed(Error)
    case invalidCredential
    case storageFailed(Error)
    case retrievalFailed(Error)
    case deletionFailed(Error)
    case signingFailed(Error)
    case authenticationFailed
    case unknown(Error)
    
    public var localizedDescription: String {
        switch self {
        case .notInitialized:
            return "Wallet not initialized"
        case .initializationFailed(let error):
            return "Wallet initialization failed: \(error.localizedDescription)"
        case .invalidCredential:
            return "Invalid credential format"
        case .storageFailed(let error):
            return "Storage operation failed: \(error.localizedDescription)"
        case .retrievalFailed(let error):
            return "Credential retrieval failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Credential deletion failed: \(error.localizedDescription)"
        case .signingFailed(let error):
            return "Signing operation failed: \(error.localizedDescription)"
        case .authenticationFailed:
            return "User authentication failed"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Credential Presentation

public struct CredentialPresentation: Codable {
    let id: String
    let credentials: [MedicalCredential]
    let signature: String
    let timestamp: Date
    let publicKey: String
    
    public init(id: String, credentials: [MedicalCredential], signature: String, publicKey: String) {
        self.id = id
        self.credentials = credentials
        self.signature = signature
        self.timestamp = Date()
        self.publicKey = publicKey
    }
}
