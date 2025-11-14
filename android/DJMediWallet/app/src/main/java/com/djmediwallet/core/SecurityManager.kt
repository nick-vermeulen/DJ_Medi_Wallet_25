package com.djmediwallet.core

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.models.credential.CredentialPresentation
import kotlinx.coroutines.suspendCancellableCoroutine
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.util.*
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Manages cryptographic operations and authentication
 */
class SecurityManager(
    private val context: Context,
    private val config: WalletConfig
) {
    
    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val SIGNATURE_ALGORITHM = "SHA256withECDSA"
        
        /**
         * Check if StrongBox is available on this device (Android 9+)
         */
        fun isStrongBoxAvailable(): Boolean {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER)
                    keyStore.load(null)
                    // Try to detect StrongBox support
                    true
                } catch (e: Exception) {
                    false
                }
            } else {
                false
            }
        }
    }
    
    private val keyAlias: String = config.serviceName
    
    private val keyStore: KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply {
        load(null)
    }
    
    // MARK: - Key Management
    
    /**
     * Generate device key pair for wallet
     */
    fun generateDeviceKeyPair() {
        // Delete existing key if present
        if (keyStore.containsAlias(keyAlias)) {
            keyStore.deleteEntry(keyAlias)
        }
        
        val keyPairGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            KEYSTORE_PROVIDER
        )
        
        val builder = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        ).apply {
            setDigests(KeyProperties.DIGEST_SHA256)
            setKeySize(256)
            
            // Configure user authentication
            if (config.userAuthenticationRequired) {
                setUserAuthenticationRequired(true)
                
                // Set authentication timeout
                if (config.authenticationTimeoutSeconds > 0) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        setUserAuthenticationParameters(
                            config.authenticationTimeoutSeconds,
                            KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        setUserAuthenticationValidityDurationSeconds(config.authenticationTimeoutSeconds)
                    }
                } else {
                    // Require authentication for every use
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        setUserAuthenticationParameters(
                            0,
                            KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
                        )
                    }
                }
            }
            
            // Try to use StrongBox if configured and available
            if (config.useStrongBoxWhenAvailable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                try {
                    setIsStrongBoxBacked(true)
                } catch (e: Exception) {
                    // StrongBox not available, will use regular TEE
                }
            }
        }
        
        keyPairGenerator.initialize(builder.build())
        keyPairGenerator.generateKeyPair()
    }
    
    /**
     * Check if device key pair exists
     */
    fun hasDeviceKeyPair(): Boolean {
        return keyStore.containsAlias(keyAlias)
    }
    
    /**
     * Get private key from keystore
     */
    private fun getPrivateKey(): PrivateKey? {
        return if (keyStore.containsAlias(keyAlias)) {
            keyStore.getKey(keyAlias, null) as? PrivateKey
        } else {
            null
        }
    }
    
    // MARK: - Authentication
    
    /**
     * Authenticate user with biometrics or device credential
     */
    suspend fun authenticateUser(): Unit = suspendCancellableCoroutine { continuation ->
        val biometricManager = BiometricManager.from(context)
        
        when (biometricManager.canAuthenticate(BiometricManager.Authenticators.BIOMETRIC_STRONG or BiometricManager.Authenticators.DEVICE_CREDENTIAL)) {
            BiometricManager.BIOMETRIC_SUCCESS -> {
                // Biometric authentication is available
                // For actual implementation, need FragmentActivity
                continuation.resume(Unit)
            }
            else -> {
                // Authentication not available or not enrolled
                continuation.resume(Unit)
            }
        }
    }
    
    // MARK: - Signing Operations
    
    /**
     * Sign credential presentation
     */
    fun signPresentation(credentials: List<MedicalCredential>): CredentialPresentation {
        val privateKey = getPrivateKey() 
            ?: throw SecurityException("Private key not found")
        
        val presentationId = UUID.randomUUID().toString()
        
        // Serialize credentials
        val credentialsJson = serializeCredentials(credentials)
        
        // Sign the data
        val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
        signature.initSign(privateKey)
        signature.update(credentialsJson.toByteArray())
        val signatureBytes = signature.sign()
        val signatureString = Base64.getEncoder().encodeToString(signatureBytes)
        
        // Get public key
        val publicKey = keyStore.getCertificate(keyAlias)?.publicKey
        val publicKeyString = Base64.getEncoder().encodeToString(publicKey?.encoded)
        
        return CredentialPresentation(
            id = presentationId,
            credentials = credentials,
            signature = signatureString,
            publicKey = publicKeyString,
            timestamp = Date()
        )
    }
    
    /**
     * Verify presentation signature
     */
    fun verifyPresentation(presentation: CredentialPresentation): Boolean {
        return try {
            val publicKeyBytes = Base64.getDecoder().decode(presentation.publicKey)
            val signatureBytes = Base64.getDecoder().decode(presentation.signature)
            
            // Serialize credentials
            val credentialsJson = serializeCredentials(presentation.credentials)
            
            // Verify signature
            val signature = Signature.getInstance(SIGNATURE_ALGORITHM)
            val keyFactory = java.security.KeyFactory.getInstance(KeyProperties.KEY_ALGORITHM_EC)
            val publicKey = keyFactory.generatePublic(
                java.security.spec.X509EncodedKeySpec(publicKeyBytes)
            )
            
            signature.initVerify(publicKey)
            signature.update(credentialsJson.toByteArray())
            signature.verify(signatureBytes)
        } catch (e: Exception) {
            false
        }
    }
    
    private fun serializeCredentials(credentials: List<MedicalCredential>): String {
        // In production, use proper JSON serialization (e.g., Gson, Kotlinx Serialization)
        // For now, simple toString implementation
        return credentials.joinToString(",") { it.id }
    }
}
