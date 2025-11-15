//
//  SecureStorage.swift
//  DJMediWallet
//
//  Secure storage for medical credentials
//

import Foundation
import CoreData

/// Manages secure storage of medical credentials
public class SecureStorage {
    
    // MARK: - Properties
    
    private let serviceName: String
    private var isStorageInitialized = false
    
    // Core Data stack
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: serviceName)
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
    
    private var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Initialization
    
    /// Initialize storage with service name
    /// - Parameter serviceName: Service name for storage identification
    public init(serviceName: String) {
        self.serviceName = serviceName
    }
    
    /// Initialize storage
    public func initialize(completion: @escaping (Result<Void, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Trigger Core Data stack initialization
            _ = self.persistentContainer
            
            self.isStorageInitialized = true
            
            DispatchQueue.main.async {
                completion(.success(()))
            }
        }
    }
    
    /// Check if storage is initialized
    public func isInitialized() -> Bool {
        return isStorageInitialized
    }
    
    // MARK: - Storage Operations
    
    /// Store a medical credential
    public func storeCredential(_ credential: MedicalCredential, completion: @escaping (Result<String, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Serialize credential to JSON
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(credential)
                
                // Store in encrypted format
                let encrypted = try self.encrypt(data)
                
                // Save to Core Data or file system
                try self.saveEncryptedData(encrypted, id: credential.id)
                
                DispatchQueue.main.async {
                    completion(.success(credential.id))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.storageFailed(error)))
                }
            }
        }
    }
    
    /// Retrieve all credentials
    public func retrieveAllCredentials(completion: @escaping (Result<[MedicalCredential], WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let ids = try self.getAllCredentialIds()
                var credentials: [MedicalCredential] = []
                
                for id in ids {
                    if let credential = try? self.retrieveCredentialSync(id: id) {
                        credentials.append(credential)
                    }
                }
                
                DispatchQueue.main.async {
                    completion(.success(credentials))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.retrievalFailed(error)))
                }
            }
        }
    }
    
    /// Retrieve credential by ID
    public func retrieveCredential(id: String, completion: @escaping (Result<MedicalCredential, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let credential = try self.retrieveCredentialSync(id: id)
                
                DispatchQueue.main.async {
                    completion(.success(credential))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.retrievalFailed(error)))
                }
            }
        }
    }
    
    private func retrieveCredentialSync(id: String) throws -> MedicalCredential {
        // Retrieve encrypted data
        let encrypted = try loadEncryptedData(id: id)
        
        // Decrypt
        let data = try decrypt(encrypted)
        
        // Deserialize
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MedicalCredential.self, from: data)
    }
    
    /// Delete a credential
    public func deleteCredential(id: String, completion: @escaping (Result<Void, WalletError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.deleteEncryptedData(id: id)
                
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
    
    // MARK: - Encryption
    
    private func encrypt(_ data: Data) throws -> Data {
        // In production, use AES-256 encryption with key from Keychain
        // For now, return data as-is (placeholder)
        return data
    }
    
    private func decrypt(_ data: Data) throws -> Data {
        // In production, use AES-256 decryption with key from Keychain
        // For now, return data as-is (placeholder)
        return data
    }
    
    // MARK: - File System Storage
    
    private func getStorageDirectory() throws -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let appSupportDir = paths.first else {
            throw StorageError.directoryNotFound
        }
        
        let storageDir = appSupportDir.appendingPathComponent("Credentials")
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: storageDir.path) {
            try FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        }
        
        return storageDir
    }
    
    private func saveEncryptedData(_ data: Data, id: String) throws {
        let storageDir = try getStorageDirectory()
        let fileURL = storageDir.appendingPathComponent("\(id).enc")
        try data.write(to: fileURL, options: .atomic)
    }
    
    private func loadEncryptedData(id: String) throws -> Data {
        let storageDir = try getStorageDirectory()
        let fileURL = storageDir.appendingPathComponent("\(id).enc")
        return try Data(contentsOf: fileURL)
    }
    
    private func deleteEncryptedData(id: String) throws {
        let storageDir = try getStorageDirectory()
        let fileURL = storageDir.appendingPathComponent("\(id).enc")
        try FileManager.default.removeItem(at: fileURL)
    }
    
    private func getAllCredentialIds() throws -> [String] {
        let storageDir = try getStorageDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: nil)
        
        return files
            .filter { $0.pathExtension == "enc" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    // MARK: - Metadata

    public func storeMetadata<T: Codable>(_ value: T, forKey key: String) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let encrypted = try encrypt(data)
        let url = try metadataURL(for: key)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encrypted.write(to: url, options: .atomic)
    }
    
    public func loadMetadata<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        let url = try metadataURL(for: key)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let encrypted = try Data(contentsOf: url)
        let data = try decrypt(encrypted)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    public func deleteMetadata(forKey key: String) throws {
        let url = try metadataURL(for: key)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    private func metadataURL(for key: String) throws -> URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let baseDir = paths.first else {
            throw StorageError.directoryNotFound
        }
        let metadataDir = baseDir.appendingPathComponent("Metadata")
        return metadataDir.appendingPathComponent("\(key).meta")
    }
}

// MARK: - Storage Error Types

public enum StorageError: Error {
    case directoryNotFound
    case fileNotFound
    case encryptionFailed
    case decryptionFailed
    case saveFailed
    case loadFailed
    
    public var localizedDescription: String {
        switch self {
        case .directoryNotFound:
            return "Storage directory not found"
        case .fileNotFound:
            return "Credential file not found"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .saveFailed:
            return "Failed to save data"
        case .loadFailed:
            return "Failed to load data"
        }
    }
}
