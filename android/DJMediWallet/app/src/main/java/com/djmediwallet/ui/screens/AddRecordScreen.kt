package com.djmediwallet.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.djmediwallet.ui.components.*
import com.djmediwallet.ui.viewmodels.AddRecordViewModel

enum class RecordType {
    OBSERVATION,
    CONDITION,
    MEDICATION
}

@Composable
fun AddRecordScreen(
    onRecordAdded: () -> Unit,
    viewModel: AddRecordViewModel = viewModel()
) {
    val context = LocalContext.current
    var selectedType by remember { mutableStateOf(RecordType.OBSERVATION) }
    val isSaving by viewModel.isSaving.collectAsState()
    val saveResult by viewModel.saveResult.collectAsState()

    LaunchedEffect(saveResult) {
        if (saveResult == true) {
            onRecordAdded()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        Text(
            text = "Add Medical Record",
            style = MaterialTheme.typography.headlineSmall,
            modifier = Modifier.padding(bottom = 16.dp)
        )

        RecordTypeSelector(
            selectedType = selectedType,
            onTypeSelected = { selectedType = it },
            modifier = Modifier.padding(bottom = 24.dp)
        )

        when (selectedType) {
            RecordType.OBSERVATION -> {
                ObservationForm(
                    onSave = { observation ->
                        viewModel.saveObservation(context, observation)
                    },
                    isSaving = isSaving
                )
            }
            RecordType.CONDITION -> {
                ConditionForm(
                    onSave = { condition ->
                        viewModel.saveCondition(context, condition)
                    },
                    isSaving = isSaving
                )
            }
            RecordType.MEDICATION -> {
                MedicationForm(
                    onSave = { medication ->
                        viewModel.saveMedication(context, medication)
                    },
                    isSaving = isSaving
                )
            }
        }

        if (saveResult == false) {
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Failed to save record. Please try again.",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodyMedium
            )
        }
    }
}

@Composable
private fun RecordTypeSelector(
    selectedType: RecordType,
    onTypeSelected: (RecordType) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = "Record Type",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            RecordTypeChip(
                label = "Vital Signs",
                icon = Icons.Default.MonitorHeart,
                isSelected = selectedType == RecordType.OBSERVATION,
                onClick = { onTypeSelected(RecordType.OBSERVATION) },
                modifier = Modifier.weight(1f)
            )
            RecordTypeChip(
                label = "Diagnosis",
                icon = Icons.Default.HealthAndSafety,
                isSelected = selectedType == RecordType.CONDITION,
                onClick = { onTypeSelected(RecordType.CONDITION) },
                modifier = Modifier.weight(1f)
            )
            RecordTypeChip(
                label = "Medication",
                icon = Icons.Default.Medication,
                isSelected = selectedType == RecordType.MEDICATION,
                onClick = { onTypeSelected(RecordType.MEDICATION) },
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RecordTypeChip(
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    FilterChip(
        selected = isSelected,
        onClick = onClick,
        label = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall
                )
            }
        },
        modifier = modifier
    )
}
