//
//  WalletConfig.swift
//  DJMediWallet
//
//  Configuration for wallet initialization
//

import Foundation

/// Configuration options for wallet initialization
public struct WalletConfig {
    /// The service name for keychain storage (must not contain ":")
    public let serviceName: String
    
    /// The keychain access group for sharing credentials between apps (optional)
    public let accessGroup: String?
    
    /// Whether user authentication (biometric/passcode) is required for key operations
    public let userAuthenticationRequired: Bool
    
    /// Timeout in seconds after authentication before re-authentication is required (iOS only)
    public let authenticationTimeout: TimeInterval
    
    /// Whether to use Secure Enclave when available (iOS only)
    public let useSecureEnclaveWhenAvailable: Bool
    
    /// Trusted reader certificates for verification
    public let trustedReaderCertificates: [Data]?
    
    /// Default service name
    public static let defaultServiceName = "com.djmediwallet"
    
    /// Create wallet configuration
    /// - Parameters:
    ///   - serviceName: Service name for keychain (default: "com.djmediwallet")
    ///   - accessGroup: Keychain access group for app groups (optional)
    ///   - userAuthenticationRequired: Require biometric/passcode for operations (default: true)
    ///   - authenticationTimeout: Seconds before re-authentication required (default: 30)
    ///   - useSecureEnclaveWhenAvailable: Use Secure Enclave if available (default: true)
    ///   - trustedReaderCertificates: Trusted certificates for readers (optional)
    public init(
        serviceName: String = defaultServiceName,
        accessGroup: String? = nil,
        userAuthenticationRequired: Bool = true,
        authenticationTimeout: TimeInterval = 30,
        useSecureEnclaveWhenAvailable: Bool = true,
        trustedReaderCertificates: [Data]? = nil
    ) throws {
        // Validate service name doesn't contain ":"
        guard !serviceName.contains(":") else {
            throw WalletError.invalidConfiguration("Service name cannot contain ':' character")
        }
        
        self.serviceName = serviceName
        self.accessGroup = accessGroup
        self.userAuthenticationRequired = userAuthenticationRequired
        self.authenticationTimeout = authenticationTimeout
        self.useSecureEnclaveWhenAvailable = useSecureEnclaveWhenAvailable
        self.trustedReaderCertificates = trustedReaderCertificates
    }
    
    /// Default configuration
    public static var `default`: WalletConfig {
        return try! WalletConfig()
    }
}

// MARK: - Wallet Error Extension

extension WalletError {
    public static func invalidConfiguration(_ message: String) -> WalletError {
        return .unknown(NSError(domain: "WalletConfig", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
    }
}
