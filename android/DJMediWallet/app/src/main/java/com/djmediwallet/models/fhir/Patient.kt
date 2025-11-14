package com.djmediwallet.models.fhir

/**
 * FHIR Resource wrapper
 */
data class FHIRResource(
    val resourceType: String,
    val id: String? = null,
    val data: Map<String, Any>? = null
)

/**
 * FHIR Patient resource
 */
data class Patient(
    val resourceType: String = "Patient",
    val id: String? = null,
    val identifier: List<Identifier>? = null,
    val active: Boolean? = true,
    val name: List<HumanName>? = null,
    val telecom: List<ContactPoint>? = null,
    val gender: String? = null,
    val birthDate: String? = null,
    val address: List<Address>? = null,
    val contact: List<PatientContact>? = null
)

/**
 * FHIR Identifier
 */
data class Identifier(
    val system: String? = null,
    val value: String? = null,
    val use: String? = null,
    val type: CodeableConcept? = null
)

/**
 * FHIR HumanName
 */
data class HumanName(
    val use: String? = null,
    val family: String? = null,
    val given: List<String>? = null,
    val prefix: List<String>? = null,
    val suffix: List<String>? = null
) {
    val fullName: String
        get() {
            val parts = mutableListOf<String>()
            prefix?.let { parts.addAll(it) }
            given?.let { parts.addAll(it) }
            family?.let { parts.add(it) }
            suffix?.let { parts.addAll(it) }
            return parts.joinToString(" ")
        }
}

/**
 * FHIR ContactPoint
 */
data class ContactPoint(
    val system: String? = null,
    val value: String? = null,
    val use: String? = null
)

/**
 * FHIR Address
 */
data class Address(
    val use: String? = null,
    val type: String? = null,
    val line: List<String>? = null,
    val city: String? = null,
    val state: String? = null,
    val postalCode: String? = null,
    val country: String? = null
) {
    val fullAddress: String
        get() {
            val parts = mutableListOf<String>()
            line?.let { parts.addAll(it) }
            city?.let { parts.add(it) }
            state?.let { parts.add(it) }
            postalCode?.let { parts.add(it) }
            country?.let { parts.add(it) }
            return parts.joinToString(", ")
        }
}

/**
 * FHIR Patient Contact
 */
data class PatientContact(
    val relationship: List<CodeableConcept>? = null,
    val name: HumanName? = null,
    val telecom: List<ContactPoint>? = null,
    val address: Address? = null
)

/**
 * FHIR CodeableConcept
 */
data class CodeableConcept(
    val coding: List<Coding>? = null,
    val text: String? = null
) {
    val display: String?
        get() = text ?: coding?.firstOrNull()?.display
}

/**
 * FHIR Coding
 */
data class Coding(
    val system: String? = null,
    val code: String? = null,
    val display: String? = null,
    val version: String? = null
) {
    val isSNOMED: Boolean
        get() = system == "http://snomed.info/sct"
}
