//
//  SecurityManager.swift
//  DJMediWallet
//
//  Manages cryptographic operations and authentication
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit

/// Handles security operations including key management and authentication
public class SecurityManager {
    
    // MARK: - Properties
    
    private let keychainService = "com.djmediwallet.keychain"
    private let deviceKeyTag = "com.djmediwallet.devicekey"
    
    // MARK: - Key Management
    
    /// Generate device key pair for wallet
    public func generateDeviceKeyPair(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Generate P-256 key pair
                let privateKey = P256.Signing.PrivateKey()
                let publicKey = privateKey.publicKey
                
                // Store private key in Keychain
                try self.storePrivateKey(privateKey)
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Check if device key pair exists
    public func hasDeviceKeyPair() -> Bool {
        return retrievePrivateKey() != nil
    }
    
    /// Store private key in Keychain with biometric protection
    private func storePrivateKey(_ key: P256.Signing.PrivateKey) throws {
        let keyData = key.rawRepresentation
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: deviceKeyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Add biometric protection if available
        if #available(iOS 13.0, *) {
            let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                .biometryCurrentSet,
                nil
            )
            query[kSecAttrAccessControl as String] = access
        }
        
        // Delete any existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }
    
    /// Retrieve private key from Keychain
    private func retrievePrivateKey() -> P256.Signing.PrivateKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: deviceKeyTag,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let keyData = item as? Data,
              let privateKey = try? P256.Signing.PrivateKey(rawRepresentation: keyData) else {
            return nil
        }
        
        return privateKey
    }
    
    // MARK: - Authentication
    
    /// Authenticate user with biometrics or device passcode
    public func authenticateUser(completion: @escaping (Result<Void, WalletError>) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(.authenticationFailed))
            return
        }
        
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Authenticate to access your medical wallet"
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(.authenticationFailed))
                }
            }
        }
    }
    
    // MARK: - Signing Operations
    
    /// Sign credential presentation
    public func signPresentation(credentials: [MedicalCredential], completion: @escaping (Result<CredentialPresentation, WalletError>) -> Void) {
        guard let privateKey = retrievePrivateKey() else {
            completion(.failure(.authenticationFailed))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Create presentation
                let presentationId = UUID().uuidString
                let publicKey = privateKey.publicKey
                
                // Serialize credentials for signing
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let credentialsData = try encoder.encode(credentials)
                
                // Sign the data
                let signature = try privateKey.signature(for: credentialsData)
                let signatureString = signature.rawRepresentation.base64EncodedString()
                
                // Get public key string
                let publicKeyData = publicKey.rawRepresentation
                let publicKeyString = publicKeyData.base64EncodedString()
                
                let presentation = CredentialPresentation(
                    id: presentationId,
                    credentials: credentials,
                    signature: signatureString,
                    publicKey: publicKeyString
                )
                
                DispatchQueue.main.async {
                    completion(.success(presentation))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.signingFailed(error)))
                }
            }
        }
    }
    
    /// Verify presentation signature
    public func verifyPresentation(_ presentation: CredentialPresentation) -> Bool {
        do {
            // Decode public key
            guard let publicKeyData = Data(base64Encoded: presentation.publicKey),
                  let publicKey = try? P256.Signing.PublicKey(rawRepresentation: publicKeyData) else {
                return false
            }
            
            // Decode signature
            guard let signatureData = Data(base64Encoded: presentation.signature),
                  let signature = try? P256.Signing.ECDSASignature(rawRepresentation: signatureData) else {
                return false
            }
            
            // Serialize credentials
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let credentialsData = try encoder.encode(presentation.credentials)
            
            // Verify signature
            return publicKey.isValidSignature(signature, for: credentialsData)
        } catch {
            return false
        }
    }
}

// MARK: - Security Error Types

public enum SecurityError: Error {
    case keychainError(OSStatus)
    case keyGenerationFailed
    case keyNotFound
    case signatureFailed
    case verificationFailed
    
    public var localizedDescription: String {
        switch self {
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .keyGenerationFailed:
            return "Failed to generate cryptographic key"
        case .keyNotFound:
            return "Cryptographic key not found"
        case .signatureFailed:
            return "Failed to create signature"
        case .verificationFailed:
            return "Signature verification failed"
        }
    }
}
