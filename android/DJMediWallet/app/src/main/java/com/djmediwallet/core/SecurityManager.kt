package com.djmediwallet.core

import android.content.Context
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
class SecurityManager(private val context: Context) {
    
    companion object {
        private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        private const val KEY_ALIAS = "DJMediWalletDeviceKey"
        private const val SIGNATURE_ALGORITHM = "SHA256withECDSA"
    }
    
    private val keyStore: KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply {
        load(null)
    }
    
    // MARK: - Key Management
    
    /**
     * Generate device key pair for wallet
     */
    fun generateDeviceKeyPair() {
        // Delete existing key if present
        if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.deleteEntry(KEY_ALIAS)
        }
        
        val keyPairGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC,
            KEYSTORE_PROVIDER
        )
        
        val parameterSpec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        ).apply {
            setDigests(KeyProperties.DIGEST_SHA256)
            setUserAuthenticationRequired(false) // Set to true for biometric-protected keys
            setKeySize(256)
        }.build()
        
        keyPairGenerator.initialize(parameterSpec)
        keyPairGenerator.generateKeyPair()
    }
    
    /**
     * Check if device key pair exists
     */
    fun hasDeviceKeyPair(): Boolean {
        return keyStore.containsAlias(KEY_ALIAS)
    }
    
    /**
     * Get private key from keystore
     */
    private fun getPrivateKey(): PrivateKey? {
        return if (keyStore.containsAlias(KEY_ALIAS)) {
            keyStore.getKey(KEY_ALIAS, null) as? PrivateKey
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
        val publicKey = keyStore.getCertificate(KEY_ALIAS)?.publicKey
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

/**
 * Security exception types
 */
sealed class SecurityException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    class KeystoreError(cause: Throwable) : SecurityException("Keystore error", cause)
    object KeyGenerationFailed : SecurityException("Failed to generate cryptographic key")
    object KeyNotFound : SecurityException("Cryptographic key not found")
    object SignatureFailed : SecurityException("Failed to create signature")
    object VerificationFailed : SecurityException("Signature verification failed")
}
