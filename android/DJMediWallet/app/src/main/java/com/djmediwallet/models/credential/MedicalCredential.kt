package com.djmediwallet.models.credential

import com.djmediwallet.models.fhir.FHIRResource
import java.util.*

/**
 * Represents a verifiable medical credential
 */
data class MedicalCredential(
    val id: String,
    val type: String,
    val issuer: String,
    val issuanceDate: Date,
    val expirationDate: Date? = null,
    val fhirResource: FHIRResource? = null,
    val proof: CredentialProof? = null
) {
    /**
     * Check if credential is expired
     */
    val isExpired: Boolean
        get() = expirationDate?.let { Date().after(it) } ?: false
    
    /**
     * Check if credential is valid
     */
    val isValid: Boolean
        get() = !isExpired && !Date().before(issuanceDate)
}

/**
 * FHIR Resource wrapper
 */
data class FHIRResource(
    val resourceType: String,
    val id: String? = null,
    val data: Map<String, Any>? = null
)

/**
 * Credential proof/signature
 */
data class CredentialProof(
    val type: String,
    val created: Date,
    val verificationMethod: String,
    val proofValue: String
)

/**
 * Credential presentation for sharing
 */
data class CredentialPresentation(
    val id: String,
    val credentials: List<MedicalCredential>,
    val signature: String,
    val publicKey: String,
    val timestamp: Date
)
