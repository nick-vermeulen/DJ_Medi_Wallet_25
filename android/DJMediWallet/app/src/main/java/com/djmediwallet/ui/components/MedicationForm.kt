package com.djmediwallet.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.djmediwallet.models.fhir.*
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MedicationForm(
    onSave: (MedicationStatement) -> Unit,
    isSaving: Boolean,
    modifier: Modifier = Modifier
) {
    var selectedMedication by remember { mutableStateOf("") }
    var selectedSnomedCode by remember { mutableStateOf("") }
    var dosage by remember { mutableStateOf("") }
    var frequency by remember { mutableStateOf("Once daily") }
    var route by remember { mutableStateOf("Oral") }
    var startDate by remember { mutableStateOf(Date()) }
    var notes by remember { mutableStateOf("") }
    var medicationExpanded by remember { mutableStateOf(false) }
    var frequencyExpanded by remember { mutableStateOf(false) }
    var routeExpanded by remember { mutableStateOf(false) }

    // Common medications with SNOMED CT codes
    val medications = mapOf(
        "Metformin" to "109081006",
        "Aspirin" to "387458008",
        "Lisinopril" to "386873009",
        "Atorvastatin" to "373444002",
        "Levothyroxine" to "126202002",
        "Metoprolol" to "372826007",
        "Amlodipine" to "386864001",
        "Omeprazole" to "387137007",
        "Simvastatin" to "387584000",
        "Losartan" to "386876004",
        "Albuterol" to "372897005",
        "Gabapentin" to "386845007"
    )

    val frequencies = listOf(
        "Once daily",
        "Twice daily",
        "Three times daily",
        "Four times daily",
        "As needed",
        "Every morning",
        "Every evening",
        "Weekly"
    )

    val routes = listOf(
        "Oral",
        "Sublingual",
        "Topical",
        "Inhalation",
        "Injection",
        "Intravenous"
    )

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = "Medication",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        // Medication Selector with SNOMED codes
        ExposedDropdownMenuBox(
            expanded = medicationExpanded,
            onExpandedChange = { medicationExpanded = !medicationExpanded }
        ) {
            OutlinedTextField(
                value = selectedMedication,
                onValueChange = {},
                readOnly = true,
                label = { Text("Select Medication") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = medicationExpanded) },
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
                expanded = medicationExpanded,
                onDismissRequest = { medicationExpanded = false }
            ) {
                medications.forEach { (medication, snomedCode) ->
                    DropdownMenuItem(
                        text = {
                            Column {
                                Text(medication)
                                Text(
                                    "SNOMED: $snomedCode",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        },
                        onClick = {
                            selectedMedication = medication
                            selectedSnomedCode = snomedCode
                            medicationExpanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = dosage,
            onValueChange = { dosage = it },
            label = { Text("Dosage (e.g., 10 mg)") },
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Frequency Selector
            ExposedDropdownMenuBox(
                expanded = frequencyExpanded,
                onExpandedChange = { frequencyExpanded = !frequencyExpanded },
                modifier = Modifier.weight(1f)
            ) {
                OutlinedTextField(
                    value = frequency,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Frequency") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = frequencyExpanded) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors()
                )
                ExposedDropdownMenu(
                    expanded = frequencyExpanded,
                    onDismissRequest = { frequencyExpanded = false }
                ) {
                    frequencies.forEach { freq ->
                        DropdownMenuItem(
                            text = { Text(freq) },
                            onClick = {
                                frequency = freq
                                frequencyExpanded = false
                            }
                        )
                    }
                }
            }

            // Route Selector
            ExposedDropdownMenuBox(
                expanded = routeExpanded,
                onExpandedChange = { routeExpanded = !routeExpanded },
                modifier = Modifier.weight(1f)
            ) {
                OutlinedTextField(
                    value = route,
                    onValueChange = {},
                    readOnly = true,
                    label = { Text("Route") },
                    trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = routeExpanded) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .menuAnchor(),
                    colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors()
                )
                ExposedDropdownMenu(
                    expanded = routeExpanded,
                    onDismissRequest = { routeExpanded = false }
                ) {
                    routes.forEach { r ->
                        DropdownMenuItem(
                            text = { Text(r) },
                            onClick = {
                                route = r
                                routeExpanded = false
                            }
                        )
                    }
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
                val medication = createMedicationStatement(
                    medicationName = selectedMedication,
                    snomedCode = selectedSnomedCode,
                    dosage = dosage,
                    frequency = frequency,
                    route = route,
                    startDate = startDate,
                    notes = notes
                )
                onSave(medication)
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isSaving && selectedMedication.isNotEmpty() && dosage.isNotEmpty()
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

private fun createMedicationStatement(
    medicationName: String,
    snomedCode: String,
    dosage: String,
    frequency: String,
    route: String,
    startDate: Date,
    notes: String
): MedicationStatement {
    val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
    val dateString = dateFormatter.format(startDate)

    val routeCode = when (route) {
        "Oral" -> "26643006"
        "Sublingual" -> "37161004"
        "Topical" -> "6064005"
        "Inhalation" -> "447694001"
        "Injection" -> "129326001"
        "Intravenous" -> "47625008"
        else -> "26643006"
    }

    return MedicationStatement(
        id = UUID.randomUUID().toString(),
        status = "active",
        medicationCodeableConcept = CodeableConcept(
            coding = listOf(
                Coding(
                    system = "http://snomed.info/sct",
                    code = snomedCode,
                    display = medicationName
                )
            ),
            text = medicationName
        ),
        subject = Reference(
            reference = "Patient/self",
            display = "Self"
        ),
        effectiveDateTime = dateString,
        dateAsserted = dateString,
        dosage = listOf(
            Dosage(
                text = "$dosage $frequency",
                route = CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://snomed.info/sct",
                            code = routeCode,
                            display = route
                        )
                    )
                ),
                doseAndRate = listOf(
                    DoseAndRate(
                        doseQuantity = Quantity(
                            value = null,
                            unit = dosage
                        )
                    )
                ),
                timing = Timing(
                    code = CodeableConcept(
                        text = frequency
                    )
                )
            )
        ),
        note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
    )
}
