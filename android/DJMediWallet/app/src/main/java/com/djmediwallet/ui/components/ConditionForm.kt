package com.djmediwallet.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.djmediwallet.models.fhir.*
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConditionForm(
    onSave: (Condition) -> Unit,
    isSaving: Boolean,
    modifier: Modifier = Modifier
) {
    var selectedCondition by remember { mutableStateOf("") }
    var selectedSnomedCode by remember { mutableStateOf("") }
    var selectedSeverity by remember { mutableStateOf("Moderate") }
    var onsetDate by remember { mutableStateOf(Date()) }
    var notes by remember { mutableStateOf("") }
    var conditionExpanded by remember { mutableStateOf(false) }
    var severityExpanded by remember { mutableStateOf(false) }

    // Common conditions with SNOMED CT codes
    val conditions = mapOf(
        "Hypertension" to "38341003",
        "Diabetes Mellitus Type 2" to "44054006",
        "Asthma" to "195967001",
        "Atrial Fibrillation" to "49436004",
        "Chronic Obstructive Pulmonary Disease" to "13645005",
        "Myocardial Infarction" to "22298006",
        "Hyperlipidemia" to "55822004",
        "Osteoarthritis" to "396275006",
        "Depression" to "35489007",
        "Anxiety Disorder" to "197480006"
    )

    val severities = listOf("Mild", "Moderate", "Severe")

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = "Diagnosis / Condition",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        // Condition Selector with SNOMED codes
        ExposedDropdownMenuBox(
            expanded = conditionExpanded,
            onExpandedChange = { conditionExpanded = !conditionExpanded }
        ) {
            OutlinedTextField(
                value = selectedCondition,
                onValueChange = {},
                readOnly = true,
                label = { Text("Select Condition") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = conditionExpanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(),
                colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors(),
                supportingText = {
                    if (selectedSnomedCode.isNotEmpty()) {
                        Text("SNOMED CT: $selectedSnomedCode", style = MaterialTheme.typography.bodySmall)
                    }
                }
            )
            ExposedDropdownMenu(
                expanded = conditionExpanded,
                onDismissRequest = { conditionExpanded = false }
            ) {
                conditions.forEach { (condition, snomedCode) ->
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(condition)
                                Text(
                                    "SNOMED: $snomedCode",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        },
                        onClick = {
                            selectedCondition = condition
                            selectedSnomedCode = snomedCode
                            conditionExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Severity Selector
        ExposedDropdownMenuBox(
            expanded = severityExpanded,
            onExpandedChange = { severityExpanded = !severityExpanded }
        ) {
            OutlinedTextField(
                value = selectedSeverity,
                onValueChange = {},
                readOnly = true,
                label = { Text("Severity") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = severityExpanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(),
                colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors()
            )
            ExposedDropdownMenu(
                expanded = severityExpanded,
                onDismissRequest = { severityExpanded = false }
            ) {
                severities.forEach { severity ->
                    DropdownMenuItem(
                        text = { Text(severity) },
                        onClick = {
                            selectedSeverity = severity
                            severityExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            label = { Text("Additional Notes (Optional)") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                val condition = createCondition(
                    conditionName = selectedCondition,
                    snomedCode = selectedSnomedCode,
                    severity = selectedSeverity,
                    onsetDate = onsetDate,
                    notes = notes
                )
                onSave(condition)
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isSaving && selectedCondition.isNotEmpty()
        ) {
            if (isSaving) {
                CircularProgressIndicator(
                    modifier = Modifier.size(20.dp),
                    color = MaterialTheme.colorScheme.onPrimary
                )
            } else {
                Text("Save Record")
            }
        }
    }
}

private fun createCondition(
    conditionName: String,
    snomedCode: String,
    severity: String,
    onsetDate: Date,
    notes: String
): Condition {
    val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
    val dateString = dateFormatter.format(onsetDate)

    return Condition(
        id = UUID.randomUUID().toString(),
        clinicalStatus = CodeableConcept(
            coding = listOf(
                Coding(
                    system = "http://terminology.hl7.org/CodeSystem/condition-clinical",
                    code = "active",
                    display = "Active"
                )
            )
        ),
        verificationStatus = CodeableConcept(
            coding = listOf(
                Coding(
                    system = "http://terminology.hl7.org/CodeSystem/condition-ver-status",
                    code = "confirmed",
                    display = "Confirmed"
                )
            )
        ),
        category = listOf(
            CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://terminology.hl7.org/CodeSystem/condition-category",
                        code = "encounter-diagnosis",
                        display = "Encounter Diagnosis"
                    )
                )
            )
        ),
        severity = CodeableConcept(
            coding = listOf(
                Coding(
                    system = "http://snomed.info/sct",
                    code = when (severity) {
                        "Mild" -> "255604002"
                        "Moderate" -> "6736007"
                        "Severe" -> "24484000"
                        else -> "6736007"
                    },
                    display = severity
                )
            )
        ),
        code = CodeableConcept(
            coding = listOf(
                Coding(
                    system = "http://snomed.info/sct",
                    code = snomedCode,
                    display = conditionName
                )
            ),
            text = conditionName
        ),
        subject = Reference(
            reference = "Patient/self",
            display = "Self"
        ),
        onsetDateTime = dateString,
        recordedDate = dateString,
        note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
    )
}
