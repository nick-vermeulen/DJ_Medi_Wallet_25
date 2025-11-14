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
    
    private let config: WalletConfig
    private let deviceKeyTag: String
    
    /// Check if Secure Enclave is available on this device
    public static var isSecureEnclaveAvailable: Bool {
        if #available(iOS 13.0, *) {
            return SecureEnclave.isAvailable
        }
        return false
    }
    
    /// Initialize security manager with configuration
    /// - Parameter config: Wallet configuration
    public init(config: WalletConfig) {
        self.config = config
        self.deviceKeyTag = "\(config.serviceName).devicekey"
    }
    
    // MARK: - Key Management
    
    /// Generate device key pair for wallet
    public func generateDeviceKeyPair(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Try Secure Enclave first if configured and available
                if self.config.useSecureEnclaveWhenAvailable && Self.isSecureEnclaveAvailable {
                    if #available(iOS 13.0, *) {
                        try self.generateSecureEnclaveKey()
                    } else {
                        try self.generateSoftwareKey()
                    }
                } else {
                    try self.generateSoftwareKey()
                }
                
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
    
    /// Generate key in Secure Enclave (iOS 13+)
    @available(iOS 13.0, *)
    private func generateSecureEnclaveKey() throws {
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
            accessControl: createAccessControl()
        )
        try storeSecureEnclaveKey(privateKey)
    }
    
    /// Generate software-based key
    private func generateSoftwareKey() throws {
        let privateKey = P256.Signing.PrivateKey()
        try storePrivateKey(privateKey)
    }
    
    /// Create access control for key with biometric protection
    private func createAccessControl() -> SecAccessControl {
        var flags: SecAccessControlCreateFlags = []
        
        if config.userAuthenticationRequired {
            if #available(iOS 11.3, *) {
                flags.insert(.biometryCurrentSet)
            } else {
                flags.insert(.touchIDCurrentSet)
            }
            flags.insert(.privateKeyUsage)
        }
        
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            flags,
            nil
        )!
        
        return access
    }
    
    /// Check if device key pair exists
    public func hasDeviceKeyPair() -> Bool {
        return retrievePrivateKey() != nil
    }
    
    /// Store Secure Enclave private key in Keychain
    @available(iOS 13.0, *)
    private func storeSecureEnclaveKey(_ key: SecureEnclave.P256.Signing.PrivateKey) throws {
        let keyData = key.dataRepresentation
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: deviceKeyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: keyData,
            kSecAttrAccessControl as String: createAccessControl(),
            kSecUseDataProtectionKeychain as String: true
        ]
        
        if let accessGroup = config.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Delete any existing key first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }
    
    /// Store private key in Keychain with optional biometric protection
    private func storePrivateKey(_ key: P256.Signing.PrivateKey) throws {
        let keyData = key.rawRepresentation
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: deviceKeyTag,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecValueData as String: keyData
        ]
        
        // Add access control if user authentication is required
        if config.userAuthenticationRequired {
            query[kSecAttrAccessControl as String] = createAccessControl()
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        
        if let accessGroup = config.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
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
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: deviceKeyTag,
            kSecReturnData as String: true
        ]
        
        if let accessGroup = config.accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add authentication context if required
        if config.userAuthenticationRequired {
            let context = LAContext()
            context.localizedReason = "Authenticate to access your medical credentials"
            query[kSecUseAuthenticationContext as String] = context
        }
        
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
