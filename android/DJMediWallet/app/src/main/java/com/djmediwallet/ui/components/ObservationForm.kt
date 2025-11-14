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
fun ObservationForm(
    onSave: (Observation) -> Unit,
    isSaving: Boolean,
    modifier: Modifier = Modifier
) {
    var observationType by remember { mutableStateOf("Blood Pressure") }
    var systolicValue by remember { mutableStateOf("") }
    var diastolicValue by remember { mutableStateOf("") }
    var heartRateValue by remember { mutableStateOf("") }
    var temperatureValue by remember { mutableStateOf("") }
    var weightValue by remember { mutableStateOf("") }
    var heightValue by remember { mutableStateOf("") }
    var selectedDate by remember { mutableStateOf(Date()) }
    var notes by remember { mutableStateOf("") }
    var expanded by remember { mutableStateOf(false) }

    val observationTypes = listOf(
        "Blood Pressure",
        "Heart Rate",
        "Body Temperature",
        "Weight",
        "Height",
        "Blood Glucose"
    )

    Column(modifier = modifier.fillMaxWidth()) {
        Text(
            text = "Vital Signs / Observation",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        // Observation Type Selector
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = !expanded }
        ) {
            OutlinedTextField(
                value = observationType,
                onValueChange = {},
                readOnly = true,
                label = { Text("Observation Type") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(),
                colors = ExposedDropdownMenuDefaults.outlinedTextFieldColors()
            )
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                observationTypes.forEach { type ->
                    DropdownMenuItem(
                        text = { Text(type) },
                        onClick = {
                            observationType = type
                            expanded = false
                        }
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Dynamic fields based on observation type
        when (observationType) {
            "Blood Pressure" -> {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = systolicValue,
                        onValueChange = { systolicValue = it },
                        label = { Text("Systolic (mmHg)") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                    OutlinedTextField(
                        value = diastolicValue,
                        onValueChange = { diastolicValue = it },
                        label = { Text("Diastolic (mmHg)") },
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        modifier = Modifier.weight(1f)
                    )
                }
            }
            "Heart Rate" -> {
                OutlinedTextField(
                    value = heartRateValue,
                    onValueChange = { heartRateValue = it },
                    label = { Text("Heart Rate (bpm)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )
            }
            "Body Temperature" -> {
                OutlinedTextField(
                    value = temperatureValue,
                    onValueChange = { temperatureValue = it },
                    label = { Text("Temperature (°C)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth()
                )
            }
            "Weight" -> {
                OutlinedTextField(
                    value = weightValue,
                    onValueChange = { weightValue = it },
                    label = { Text("Weight (kg)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth()
                )
            }
            "Height" -> {
                OutlinedTextField(
                    value = heightValue,
                    onValueChange = { heightValue = it },
                    label = { Text("Height (cm)") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        OutlinedTextField(
            value = notes,
            onValueChange = { notes = it },
            label = { Text("Notes (Optional)") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3
        )

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                val observation = createObservation(
                    type = observationType,
                    systolic = systolicValue,
                    diastolic = diastolicValue,
                    heartRate = heartRateValue,
                    temperature = temperatureValue,
                    weight = weightValue,
                    height = heightValue,
                    date = selectedDate,
                    notes = notes
                )
                onSave(observation)
            },
            modifier = Modifier.fillMaxWidth(),
            enabled = !isSaving && isFormValid(
                observationType,
                systolicValue,
                diastolicValue,
                heartRateValue,
                temperatureValue,
                weightValue,
                heightValue
            )
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

private fun isFormValid(
    type: String,
    systolic: String,
    diastolic: String,
    heartRate: String,
    temperature: String,
    weight: String,
    height: String
): Boolean {
    return when (type) {
        "Blood Pressure" -> systolic.isNotBlank() && diastolic.isNotBlank()
        "Heart Rate" -> heartRate.isNotBlank()
        "Body Temperature" -> temperature.isNotBlank()
        "Weight" -> weight.isNotBlank()
        "Height" -> height.isNotBlank()
        else -> false
    }
}

private fun createObservation(
    type: String,
    systolic: String,
    diastolic: String,
    heartRate: String,
    temperature: String,
    weight: String,
    height: String,
    date: Date,
    notes: String
): Observation {
    val dateFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
    val dateString = dateFormatter.format(date)

    return when (type) {
        "Blood Pressure" -> Observation(
            id = UUID.randomUUID().toString(),
            status = "final",
            category = listOf(
                CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://terminology.hl7.org/CodeSystem/observation-category",
                            code = "vital-signs",
                            display = "Vital Signs"
                        )
                    )
                )
            ),
            code = CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://loinc.org",
                        code = "85354-9",
                        display = "Blood pressure panel"
                    )
                )
            ),
            effectiveDateTime = dateString,
            component = listOf(
                ObservationComponent(
                    code = CodeableConcept(
                        coding = listOf(
                            Coding(
                                system = "http://loinc.org",
                                code = "8480-6",
                                display = "Systolic blood pressure"
                            )
                        )
                    ),
                    valueQuantity = Quantity(
                        value = systolic.toDoubleOrNull(),
                        unit = "mmHg",
                        system = "http://unitsofmeasure.org",
                        code = "mm[Hg]"
                    )
                ),
                ObservationComponent(
                    code = CodeableConcept(
                        coding = listOf(
                            Coding(
                                system = "http://loinc.org",
                                code = "8462-4",
                                display = "Diastolic blood pressure"
                            )
                        )
                    ),
                    valueQuantity = Quantity(
                        value = diastolic.toDoubleOrNull(),
                        unit = "mmHg",
                        system = "http://unitsofmeasure.org",
                        code = "mm[Hg]"
                    )
                )
            ),
            note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
        )
        "Heart Rate" -> Observation(
            id = UUID.randomUUID().toString(),
            status = "final",
            category = listOf(
                CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://terminology.hl7.org/CodeSystem/observation-category",
                            code = "vital-signs",
                            display = "Vital Signs"
                        )
                    )
                )
            ),
            code = CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://loinc.org",
                        code = "8867-4",
                        display = "Heart rate"
                    ),
                    Coding(
                        system = "http://snomed.info/sct",
                        code = "364075005",
                        display = "Heart rate"
                    )
                )
            ),
            effectiveDateTime = dateString,
            valueQuantity = Quantity(
                value = heartRate.toDoubleOrNull(),
                unit = "beats/minute",
                system = "http://unitsofmeasure.org",
                code = "/min"
            ),
            note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
        )
        "Body Temperature" -> Observation(
            id = UUID.randomUUID().toString(),
            status = "final",
            category = listOf(
                CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://terminology.hl7.org/CodeSystem/observation-category",
                            code = "vital-signs",
                            display = "Vital Signs"
                        )
                    )
                )
            ),
            code = CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://loinc.org",
                        code = "8310-5",
                        display = "Body temperature"
                    ),
                    Coding(
                        system = "http://snomed.info/sct",
                        code = "386725007",
                        display = "Body temperature"
                    )
                )
            ),
            effectiveDateTime = dateString,
            valueQuantity = Quantity(
                value = temperature.toDoubleOrNull(),
                unit = "°C",
                system = "http://unitsofmeasure.org",
                code = "Cel"
            ),
            note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
        )
        "Weight" -> Observation(
            id = UUID.randomUUID().toString(),
            status = "final",
            category = listOf(
                CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://terminology.hl7.org/CodeSystem/observation-category",
                            code = "vital-signs",
                            display = "Vital Signs"
                        )
                    )
                )
            ),
            code = CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://loinc.org",
                        code = "29463-7",
                        display = "Body weight"
                    ),
                    Coding(
                        system = "http://snomed.info/sct",
                        code = "27113001",
                        display = "Body weight"
                    )
                )
            ),
            effectiveDateTime = dateString,
            valueQuantity = Quantity(
                value = weight.toDoubleOrNull(),
                unit = "kg",
                system = "http://unitsofmeasure.org",
                code = "kg"
            ),
            note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
        )
        "Height" -> Observation(
            id = UUID.randomUUID().toString(),
            status = "final",
            category = listOf(
                CodeableConcept(
                    coding = listOf(
                        Coding(
                            system = "http://terminology.hl7.org/CodeSystem/observation-category",
                            code = "vital-signs",
                            display = "Vital Signs"
                        )
                    )
                )
            ),
            code = CodeableConcept(
                coding = listOf(
                    Coding(
                        system = "http://loinc.org",
                        code = "8302-2",
                        display = "Body height"
                    ),
                    Coding(
                        system = "http://snomed.info/sct",
                        code = "50373000",
                        display = "Body height"
                    )
                )
            ),
            effectiveDateTime = dateString,
            valueQuantity = Quantity(
                value = height.toDoubleOrNull(),
                unit = "cm",
                system = "http://unitsofmeasure.org",
                code = "cm"
            ),
            note = if (notes.isNotBlank()) listOf(Annotation(text = notes)) else null
        )
        else -> throw IllegalArgumentException("Unknown observation type: $type")
    }
}
