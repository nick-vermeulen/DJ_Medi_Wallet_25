//
//  WalletManager.swift
//  DJMediWallet
//
//  Core wallet management functionality
//

import Foundation
import CryptoKit

/// Main wallet manager for handling medical credentials
public class WalletManager {
    
    // MARK: - Properties
    
    private let securityManager: SecurityManager
    private let credentialManager: CredentialManager
    private let storage: SecureStorage
    
    public static let shared = WalletManager()
    
    // MARK: - Initialization
    
    private init() {
        self.securityManager = SecurityManager()
        self.credentialManager = CredentialManager()
        self.storage = SecureStorage()
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
