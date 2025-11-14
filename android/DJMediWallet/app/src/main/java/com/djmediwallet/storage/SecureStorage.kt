package com.djmediwallet.storage

import android.content.Context
import com.djmediwallet.models.credential.MedicalCredential
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.*

/**
 * Manages secure storage of medical credentials
 */
class SecureStorage(private val context: Context) {
    
    companion object {
        private const val STORAGE_DIR = "credentials"
        private const val FILE_EXTENSION = ".enc"
    }
    
    private var initialized = false
    private val gson: Gson = GsonBuilder()
        .setDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
        .create()
    
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
        val json = gson.toJson(credential)
        
        // Encrypt (placeholder - in production use Android Keystore)
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
        
        // Decrypt (placeholder - in production use Android Keystore)
        val decrypted = decrypt(encrypted)
        
        // Deserialize
        val json = String(decrypted)
        return gson.fromJson(json, MedicalCredential::class.java)
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
