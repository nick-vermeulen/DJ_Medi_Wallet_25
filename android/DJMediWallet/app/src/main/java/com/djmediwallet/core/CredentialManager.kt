package com.djmediwallet.core

import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.models.fhir.FHIRResource

/**
 * Manages validation and processing of medical credentials
 */
class CredentialManager {
    
    companion object {
        private const val SNOMED_SYSTEM = "http://snomed.info/sct"
    }
    
    // MARK: - Credential Validation
    
    /**
     * Validate medical credential structure and content
     */
    fun validateCredential(credential: MedicalCredential): Boolean {
        // Check required fields
        if (credential.id.isEmpty() || 
            credential.type.isEmpty() || 
            credential.issuanceDate.after(Date())) {
            return false
        }
        
        // Validate FHIR resource if present
        credential.fhirResource?.let { resource ->
            return validateFHIRResource(resource)
        }
        
        return true
    }
    
    /**
     * Validate FHIR resource structure
     */
    private fun validateFHIRResource(resource: FHIRResource): Boolean {
        if (resource.resourceType.isEmpty()) {
            return false
        }
        
        return when (resource.resourceType) {
            "Patient" -> validatePatientResource(resource)
            "Observation" -> validateObservationResource(resource)
            "Condition" -> validateConditionResource(resource)
            "MedicationStatement" -> validateMedicationResource(resource)
            "AllergyIntolerance" -> validateAllergyResource(resource)
            "Immunization" -> validateImmunizationResource(resource)
            else -> true // Allow other resource types
        }
    }
    
    private fun validatePatientResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("name") || data.containsKey("identifier")
    }
    
    private fun validateObservationResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("status") && data.containsKey("code")
    }
    
    private fun validateConditionResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("code")
    }
    
    private fun validateMedicationResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("status") && 
               (data.containsKey("medicationCodeableConcept") || data.containsKey("medicationReference"))
    }
    
    private fun validateAllergyResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("code") || data.containsKey("substance")
    }
    
    private fun validateImmunizationResource(resource: FHIRResource): Boolean {
        val data = resource.data ?: return false
        return data.containsKey("status") && data.containsKey("vaccineCode")
    }
    
    // MARK: - SNOMED CT Code Validation
    
    /**
     * Validate SNOMED CT code format
     */
    fun validateSNOMEDCode(code: String): Boolean {
        // SNOMED CT codes are 6-18 digits
        return code.matches(Regex("^[0-9]{6,18}$"))
    }
    
    /**
     * Extract SNOMED codes from FHIR resource
     */
    fun extractSNOMEDCodes(resource: FHIRResource): List<SNOMEDCode> {
        val codes = mutableListOf<SNOMEDCode>()
        
        resource.data?.let { data ->
            searchForCodes(data, codes)
        }
        
        return codes
    }
    
    private fun searchForCodes(value: Any, codes: MutableList<SNOMEDCode>) {
        when (value) {
            is Map<*, *> -> {
                // Check if this is a coding with SNOMED system
                val system = value["system"] as? String
                if (system == SNOMED_SYSTEM) {
                    val code = value["code"] as? String
                    val display = value["display"] as? String
                    if (code != null) {
                        codes.add(SNOMEDCode(code, display))
                    }
                }
                
                // Recursively search nested maps
                value.values.forEach { nestedValue ->
                    if (nestedValue != null) {
                        searchForCodes(nestedValue, codes)
                    }
                }
            }
            is List<*> -> {
                // Recursively search lists
                value.forEach { item ->
                    if (item != null) {
                        searchForCodes(item, codes)
                    }
                }
            }
        }
    }
    
    // MARK: - Credential Processing
    
    /**
     * Extract readable summary from credential
     */
    fun extractSummary(credential: MedicalCredential): String {
        val resource = credential.fhirResource ?: return "Medical Credential: ${credential.type}"
        
        return when (resource.resourceType) {
            "Patient" -> extractPatientSummary(resource)
            "Observation" -> extractObservationSummary(resource)
            "Condition" -> extractConditionSummary(resource)
            "MedicationStatement" -> extractMedicationSummary(resource)
            "AllergyIntolerance" -> extractAllergySummary(resource)
            "Immunization" -> extractImmunizationSummary(resource)
            else -> "${resource.resourceType} Record"
        }
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractPatientSummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Patient Record"
        
        val nameArray = data["name"] as? List<Map<String, Any>>
        nameArray?.firstOrNull()?.let { name ->
            val given = name["given"] as? List<String>
            val family = name["family"] as? String
            if (given != null && family != null) {
                return "${given.joinToString(" ")} $family"
            }
        }
        
        return "Patient Record"
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractObservationSummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Observation"
        
        val code = data["code"] as? Map<String, Any>
        val coding = code?.get("coding") as? List<Map<String, Any>>
        val display = coding?.firstOrNull()?.get("display") as? String
        
        return display ?: "Observation"
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractConditionSummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Condition"
        
        val code = data["code"] as? Map<String, Any>
        val coding = code?.get("coding") as? List<Map<String, Any>>
        val display = coding?.firstOrNull()?.get("display") as? String
        
        return display ?: "Condition"
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractMedicationSummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Medication"
        
        val medication = data["medicationCodeableConcept"] as? Map<String, Any>
        val coding = medication?.get("coding") as? List<Map<String, Any>>
        val display = coding?.firstOrNull()?.get("display") as? String
        
        return display ?: "Medication"
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractAllergySummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Allergy"
        
        val code = data["code"] as? Map<String, Any>
        val coding = code?.get("coding") as? List<Map<String, Any>>
        val display = coding?.firstOrNull()?.get("display") as? String
        
        return display?.let { "Allergy: $it" } ?: "Allergy Record"
    }
    
    @Suppress("UNCHECKED_CAST")
    private fun extractImmunizationSummary(resource: FHIRResource): String {
        val data = resource.data ?: return "Immunization"
        
        val vaccineCode = data["vaccineCode"] as? Map<String, Any>
        val coding = vaccineCode?.get("coding") as? List<Map<String, Any>>
        val display = coding?.firstOrNull()?.get("display") as? String
        
        return display?.let { "Vaccine: $it" } ?: "Immunization"
    }
}

/**
 * SNOMED code data class
 */
data class SNOMEDCode(
    val code: String,
    val display: String?
)

private fun Date(): java.util.Date = java.util.Date()
