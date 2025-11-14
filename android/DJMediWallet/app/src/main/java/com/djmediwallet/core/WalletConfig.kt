package com.djmediwallet.core

import java.util.*

/**
 * Configuration options for wallet initialization
 */
data class WalletConfig(
    /**
     * Service identifier for keystore (default: "DJMediWalletDeviceKey")
     */
    val serviceName: String = DEFAULT_SERVICE_NAME,
    
    /**
     * Whether user authentication (biometric/PIN) is required for key operations
     */
    val userAuthenticationRequired: Boolean = true,
    
    /**
     * Timeout in seconds after authentication before re-authentication is required
     * -1 means authentication is required for every use
     */
    val authenticationTimeoutSeconds: Int = 30,
    
    /**
     * Whether to use StrongBox when available (Android 9+)
     */
    val useStrongBoxWhenAvailable: Boolean = true,
    
    /**
     * Trusted reader certificates for verification
     */
    val trustedReaderCertificates: List<ByteArray>? = null
) {
    
    init {
        // Validate service name doesn't contain ":"
        require(!serviceName.contains(":")) {
            "Service name cannot contain ':' character"
        }
        
        require(authenticationTimeoutSeconds == -1 || authenticationTimeoutSeconds > 0) {
            "Authentication timeout must be -1 (always) or positive"
        }
    }
    
    companion object {
        const val DEFAULT_SERVICE_NAME = "DJMediWalletDeviceKey"
        
        /**
         * Default configuration with standard security settings
         */
        val DEFAULT = WalletConfig()
        
        /**
         * Debug configuration with authentication disabled
         */
        val DEBUG = WalletConfig(
            userAuthenticationRequired = false,
            authenticationTimeoutSeconds = -1
        )
    }
    
    /**
     * Builder for creating WalletConfig with fluent API
     */
    class Builder {
        private var serviceName: String = DEFAULT_SERVICE_NAME
        private var userAuthenticationRequired: Boolean = true
        private var authenticationTimeoutSeconds: Int = 30
        private var useStrongBoxWhenAvailable: Boolean = true
        private var trustedReaderCertificates: List<ByteArray>? = null
        
        fun serviceName(name: String) = apply { this.serviceName = name }
        
        fun userAuthenticationRequired(required: Boolean) = apply { 
            this.userAuthenticationRequired = required 
        }
        
        fun authenticationTimeoutSeconds(seconds: Int) = apply { 
            this.authenticationTimeoutSeconds = seconds 
        }
        
        fun useStrongBox(use: Boolean) = apply { 
            this.useStrongBoxWhenAvailable = use 
        }
        
        fun trustedReaderCertificates(certificates: List<ByteArray>?) = apply { 
            this.trustedReaderCertificates = certificates 
        }
        
        fun build(): WalletConfig {
            return WalletConfig(
                serviceName = serviceName,
                userAuthenticationRequired = userAuthenticationRequired,
                authenticationTimeoutSeconds = authenticationTimeoutSeconds,
                useStrongBoxWhenAvailable = useStrongBoxWhenAvailable,
                trustedReaderCertificates = trustedReaderCertificates
            )
        }
    }
}
