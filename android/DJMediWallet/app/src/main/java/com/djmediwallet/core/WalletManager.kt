package com.djmediwallet.core

import android.content.Context
import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.models.credential.CredentialPresentation
import com.djmediwallet.storage.SecureStorage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.*

/**
 * Main wallet manager for handling medical credentials
 */
class WalletManager private constructor(private val context: Context) {
    
    private val securityManager: SecurityManager = SecurityManager(context)
    private val credentialManager: CredentialManager = CredentialManager()
    private val storage: SecureStorage = SecureStorage(context)
    
    companion object {
        @Volatile
        private var INSTANCE: WalletManager? = null
        
        fun getInstance(context: Context): WalletManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: WalletManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }
    
    // MARK: - Wallet Lifecycle
    
    /**
     * Initialize wallet with user authentication
     */
    suspend fun initializeWallet(): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            // Generate device key pair
            securityManager.generateDeviceKeyPair()
            
            // Initialize secure storage
            storage.initialize()
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(WalletException.InitializationFailed(e))
        }
    }
    
    /**
     * Check if wallet is initialized
     */
    fun isWalletInitialized(): Boolean {
        return securityManager.hasDeviceKeyPair() && storage.isInitialized()
    }
    
    // MARK: - Credential Management
    
    /**
     * Add a new medical credential to the wallet
     */
    suspend fun addCredential(credential: MedicalCredential): Result<String> = withContext(Dispatchers.IO) {
        try {
            // Validate credential
            if (!credentialManager.validateCredential(credential)) {
                return@withContext Result.failure(WalletException.InvalidCredential)
            }
            
            // Store credential securely
            storage.storeCredential(credential)
            
            Result.success(credential.id)
        } catch (e: Exception) {
            Result.failure(WalletException.StorageFailed(e))
        }
    }
    
    /**
     * Retrieve all credentials
     */
    suspend fun getAllCredentials(): Result<List<MedicalCredential>> = withContext(Dispatchers.IO) {
        try {
            val credentials = storage.retrieveAllCredentials()
            Result.success(credentials)
        } catch (e: Exception) {
            Result.failure(WalletException.RetrievalFailed(e))
        }
    }
    
    /**
     * Retrieve credential by ID
     */
    suspend fun getCredential(id: String): Result<MedicalCredential> = withContext(Dispatchers.IO) {
        try {
            val credential = storage.retrieveCredential(id)
            Result.success(credential)
        } catch (e: Exception) {
            Result.failure(WalletException.RetrievalFailed(e))
        }
    }
    
    /**
     * Delete a credential
     */
    suspend fun deleteCredential(id: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            storage.deleteCredential(id)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(WalletException.DeletionFailed(e))
        }
    }
    
    // MARK: - Credential Presentation
    
    /**
     * Create a presentation for sharing with healthcare providers
     */
    suspend fun createPresentation(credentialIds: List<String>): Result<CredentialPresentation> = withContext(Dispatchers.IO) {
        try {
            // Retrieve credentials
            val credentials = credentialIds.mapNotNull { id ->
                try {
                    storage.retrieveCredential(id)
                } catch (e: Exception) {
                    null
                }
            }
            
            if (credentials.size != credentialIds.size) {
                return@withContext Result.failure(WalletException.RetrievalFailed(Exception("Some credentials not found")))
            }
            
            // Sign presentation
            val presentation = securityManager.signPresentation(credentials)
            
            Result.success(presentation)
        } catch (e: Exception) {
            Result.failure(WalletException.SigningFailed(e))
        }
    }
    
    // MARK: - Security
    
    /**
     * Authenticate user with biometrics or PIN
     */
    suspend fun authenticateUser(): Result<Unit> = withContext(Dispatchers.Main) {
        try {
            securityManager.authenticateUser()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(WalletException.AuthenticationFailed)
        }
    }
}

/**
 * Wallet exception types
 */
sealed class WalletException(message: String, cause: Throwable? = null) : Exception(message, cause) {
    object NotInitialized : WalletException("Wallet not initialized")
    class InitializationFailed(cause: Throwable) : WalletException("Wallet initialization failed", cause)
    object InvalidCredential : WalletException("Invalid credential format")
    class StorageFailed(cause: Throwable) : WalletException("Storage operation failed", cause)
    class RetrievalFailed(cause: Throwable) : WalletException("Credential retrieval failed", cause)
    class DeletionFailed(cause: Throwable) : WalletException("Credential deletion failed", cause)
    class SigningFailed(cause: Throwable) : WalletException("Signing operation failed", cause)
    object AuthenticationFailed : WalletException("User authentication failed")
    class Unknown(cause: Throwable) : WalletException("Unknown error", cause)
}
