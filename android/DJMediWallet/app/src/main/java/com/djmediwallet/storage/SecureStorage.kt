package com.djmediwallet.storage

import android.content.Context
import com.djmediwallet.models.credential.MedicalCredential
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.*
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.IvParameterSpec

/**
 * Manages secure storage of medical credentials
 */
class SecureStorage(private val context: Context) {
    
    companion object {
        private const val STORAGE_DIR = "credentials"
        private const val FILE_EXTENSION = ".enc"
        private const val CIPHER_ALGORITHM = "AES/CBC/PKCS5Padding"
        private const val KEY_ALGORITHM = "AES"
    }
    
    private var initialized = false
    
    // MARK: - Initialization
    
    /**
     * Initialize storage
     */
    fun initialize() {
        val storageDir = getStorageDirectory()
        if (!storageDir.exists()) {
            storageDir.mkdirs()
        }
        initialized = true
    }
    
    /**
     * Check if storage is initialized
     */
    fun isInitialized(): Boolean = initialized
    
    // MARK: - Storage Operations
    
    /**
     * Store a medical credential
     */
    suspend fun storeCredential(credential: MedicalCredential) = withContext(Dispatchers.IO) {
        // Serialize credential
        val json = serializeCredential(credential)
        
        // Encrypt
        val encrypted = encrypt(json.toByteArray())
        
        // Save to file
        val file = File(getStorageDirectory(), "${credential.id}$FILE_EXTENSION")
        file.writeBytes(encrypted)
    }
    
    /**
     * Retrieve all credentials
     */
    suspend fun retrieveAllCredentials(): List<MedicalCredential> = withContext(Dispatchers.IO) {
        val credentials = mutableListOf<MedicalCredential>()
        
        getStorageDirectory().listFiles()?.forEach { file ->
            if (file.extension == FILE_EXTENSION.removePrefix(".")) {
                try {
                    val credential = retrieveCredentialFromFile(file)
                    credentials.add(credential)
                } catch (e: Exception) {
                    // Skip corrupted files
                }
            }
        }
        
        credentials
    }
    
    /**
     * Retrieve credential by ID
     */
    suspend fun retrieveCredential(id: String): MedicalCredential = withContext(Dispatchers.IO) {
        val file = File(getStorageDirectory(), "$id$FILE_EXTENSION")
        if (!file.exists()) {
            throw StorageException.FileNotFound
        }
        
        retrieveCredentialFromFile(file)
    }
    
    private fun retrieveCredentialFromFile(file: File): MedicalCredential {
        // Read encrypted data
        val encrypted = file.readBytes()
        
        // Decrypt
        val decrypted = decrypt(encrypted)
        
        // Deserialize
        val json = String(decrypted)
        return deserializeCredential(json)
    }
    
    /**
     * Delete a credential
     */
    suspend fun deleteCredential(id: String) = withContext(Dispatchers.IO) {
        val file = File(getStorageDirectory(), "$id$FILE_EXTENSION")
        if (file.exists()) {
            file.delete()
        } else {
            throw StorageException.FileNotFound
        }
    }
    
    // MARK: - Encryption
    
    private fun encrypt(data: ByteArray): ByteArray {
        // In production, use proper key from Android Keystore
        // For now, simple implementation (placeholder)
        return data
    }
    
    private fun decrypt(data: ByteArray): ByteArray {
        // In production, use proper key from Android Keystore
        // For now, simple implementation (placeholder)
        return data
    }
    
    // MARK: - Serialization
    
    private fun serializeCredential(credential: MedicalCredential): String {
        // In production, use proper JSON serialization (e.g., Gson, Kotlinx Serialization)
        // Simple implementation for now
        return buildString {
            append("{")
            append("\"id\":\"${credential.id}\",")
            append("\"type\":\"${credential.type}\",")
            append("\"issuer\":\"${credential.issuer}\",")
            append("\"issuanceDate\":\"${credential.issuanceDate.time}\",")
            append("\"expirationDate\":${credential.expirationDate?.time ?: "null"}")
            append("}")
        }
    }
    
    private fun deserializeCredential(json: String): MedicalCredential {
        // In production, use proper JSON deserialization
        // Simple implementation for now
        val idRegex = "\"id\":\"([^\"]+)\"".toRegex()
        val typeRegex = "\"type\":\"([^\"]+)\"".toRegex()
        val issuerRegex = "\"issuer\":\"([^\"]+)\"".toRegex()
        val issuanceDateRegex = "\"issuanceDate\":\"([^\"]+)\"".toRegex()
        val expirationDateRegex = "\"expirationDate\":([^,}]+)".toRegex()
        
        val id = idRegex.find(json)?.groupValues?.get(1) ?: throw StorageException.DeserializationFailed
        val type = typeRegex.find(json)?.groupValues?.get(1) ?: throw StorageException.DeserializationFailed
        val issuer = issuerRegex.find(json)?.groupValues?.get(1) ?: throw StorageException.DeserializationFailed
        val issuanceDate = Date(issuanceDateRegex.find(json)?.groupValues?.get(1)?.toLong() ?: throw StorageException.DeserializationFailed)
        
        val expirationDateStr = expirationDateRegex.find(json)?.groupValues?.get(1)
        val expirationDate = if (expirationDateStr != "null") {
            Date(expirationDateStr?.toLong() ?: 0)
        } else {
            null
        }
        
        return MedicalCredential(
            id = id,
            type = type,
            issuer = issuer,
            issuanceDate = issuanceDate,
            expirationDate = expirationDate
        )
    }
    
    // MARK: - File System
    
    private fun getStorageDirectory(): File {
        return File(context.filesDir, STORAGE_DIR)
    }
}

/**
 * Storage exception types
 */
sealed class StorageException(message: String) : Exception(message) {
    object DirectoryNotFound : StorageException("Storage directory not found")
    object FileNotFound : StorageException("Credential file not found")
    object EncryptionFailed : StorageException("Failed to encrypt data")
    object DecryptionFailed : StorageException("Failed to decrypt data")
    object SerializationFailed : StorageException("Failed to serialize credential")
    object DeserializationFailed : StorageException("Failed to deserialize credential")
    object SaveFailed : StorageException("Failed to save data")
    object LoadFailed : StorageException("Failed to load data")
}
