package com.djmediwallet.models.fhir

/**
 * FHIR Observation resource for vital signs and lab results
 */
data class Observation(
    val resourceType: String = "Observation",
    val id: String? = null,
    val status: String,
    val category: List<CodeableConcept>? = null,
    val code: CodeableConcept,
    val subject: Reference? = null,
    val effectiveDateTime: String? = null,
    val issued: String? = null,
    val valueQuantity: Quantity? = null,
    val valueString: String? = null,
    val valueBoolean: Boolean? = null,
    val component: List<ObservationComponent>? = null,
    val interpretation: List<CodeableConcept>? = null,
    val note: List<Annotation>? = null
)

/**
 * FHIR Observation Component
 */
data class ObservationComponent(
    val code: CodeableConcept,
    val valueQuantity: Quantity? = null,
    val valueString: String? = null,
    val valueBoolean: Boolean? = null
)

/**
 * FHIR Quantity
 */
data class Quantity(
    val value: Double? = null,
    val unit: String? = null,
    val system: String? = null,
    val code: String? = null
) {
    val displayValue: String
        get() = value?.let { v ->
            unit?.let { u -> "$v $u" } ?: v.toString()
        } ?: ""
}

/**
 * FHIR Reference
 */
data class Reference(
    val reference: String? = null,
    val display: String? = null,
    val type: String? = null
)

/**
 * FHIR Annotation
 */
data class Annotation(
    val text: String,
    val authorString: String? = null,
    val time: String? = null
)

/**
 * FHIR Condition resource for diagnoses
 */
data class Condition(
    val resourceType: String = "Condition",
    val id: String? = null,
    val clinicalStatus: CodeableConcept? = null,
    val verificationStatus: CodeableConcept? = null,
    val category: List<CodeableConcept>? = null,
    val severity: CodeableConcept? = null,
    val code: CodeableConcept,
    val subject: Reference,
    val onsetDateTime: String? = null,
    val recordedDate: String? = null,
    val note: List<Annotation>? = null
)

/**
 * FHIR MedicationStatement resource
 */
data class MedicationStatement(
    val resourceType: String = "MedicationStatement",
    val id: String? = null,
    val status: String,
    val medicationCodeableConcept: CodeableConcept? = null,
    val medicationReference: Reference? = null,
    val subject: Reference,
    val effectiveDateTime: String? = null,
    val dateAsserted: String? = null,
    val dosage: List<Dosage>? = null,
    val note: List<Annotation>? = null
)

/**
 * FHIR Dosage
 */
data class Dosage(
    val text: String? = null,
    val timing: Timing? = null,
    val route: CodeableConcept? = null,
    val doseAndRate: List<DoseAndRate>? = null
)

/**
 * FHIR Timing
 */
data class Timing(
    val repeat: TimingRepeat? = null,
    val code: CodeableConcept? = null
)

/**
 * FHIR TimingRepeat
 */
data class TimingRepeat(
    val frequency: Int? = null,
    val period: Double? = null,
    val periodUnit: String? = null
)

/**
 * FHIR DoseAndRate
 */
data class DoseAndRate(
    val type: CodeableConcept? = null,
    val doseQuantity: Quantity? = null
)
