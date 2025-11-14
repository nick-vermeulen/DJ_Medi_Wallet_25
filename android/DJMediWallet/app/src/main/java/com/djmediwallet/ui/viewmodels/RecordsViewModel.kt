package com.djmediwallet.ui.viewmodels

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.djmediwallet.core.WalletManager
import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.ui.screens.RecordItem
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class RecordsViewModel : ViewModel() {
    private val _records = MutableStateFlow<List<RecordItem>>(emptyList())
    val records: StateFlow<List<RecordItem>> = _records.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun loadRecords(context: Context) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val walletManager = WalletManager.getInstance(context)
                
                // Initialize wallet if needed
                if (!walletManager.isWalletInitialized()) {
                    walletManager.initializeWallet()
                }

                val result = walletManager.getAllCredentials()
                result.onSuccess { credentials ->
                    _records.value = credentials.map { it.toRecordItem() }
                }.onFailure {
                    _records.value = emptyList()
                }
            } catch (e: Exception) {
                _records.value = emptyList()
            } finally {
                _isLoading.value = false
            }
        }
    }
}

private fun MedicalCredential.toRecordItem(): RecordItem {
    val dateFormat = SimpleDateFormat("MMM dd, yyyy", Locale.US)
    val dateString = dateFormat.format(issuanceDate)

    val icon = when {
        type.contains("Observation", ignoreCase = true) -> Icons.Default.MonitorHeart
        type.contains("Condition", ignoreCase = true) -> Icons.Default.HealthAndSafety
        type.contains("Medication", ignoreCase = true) -> Icons.Default.Medication
        else -> Icons.Default.Description
    }

    // Parse FHIR resource to get title and description
    val (title, description) = try {
        val gson = Gson()
        val resourceMap = fhirResource?.data ?: emptyMap()
        
        when (fhirResource?.resourceType) {
            "Observation" -> {
                val code = (resourceMap["code"] as? Map<*, *>)
                    ?.get("text") as? String ?: "Observation"
                val value = extractObservationValue(resourceMap)
                Pair(code, value)
            }
            "Condition" -> {
                val code = (resourceMap["code"] as? Map<*, *>)
                    ?.get("text") as? String ?: "Condition"
                val severity = ((resourceMap["severity"] as? Map<*, *>)
                    ?.get("coding") as? List<*>)
                    ?.firstOrNull()
                    ?.let { (it as? Map<*, *>)?.get("display") as? String }
                    ?: "Unknown severity"
                Pair(code, severity)
            }
            "MedicationStatement" -> {
                val medication = (resourceMap["medicationCodeableConcept"] as? Map<*, *>)
                    ?.get("text") as? String ?: "Medication"
                val dosage = ((resourceMap["dosage"] as? List<*>)
                    ?.firstOrNull() as? Map<*, *>)
                    ?.get("text") as? String ?: "Unknown dosage"
                Pair(medication, dosage)
            }
            else -> Pair(type, issuer)
        }
    } catch (e: Exception) {
        Pair(type, issuer)
    }

    return RecordItem(
        id = id,
        type = type,
        title = title,
        description = description,
        date = dateString,
        icon = icon
    )
}

private fun extractObservationValue(resourceMap: Map<*, *>): String {
    return try {
        val valueQuantity = resourceMap["valueQuantity"] as? Map<*, *>
        if (valueQuantity != null) {
            val value = valueQuantity["value"]
            val unit = valueQuantity["unit"] ?: ""
            "$value $unit"
        } else {
            val components = resourceMap["component"] as? List<*>
            if (components != null && components.isNotEmpty()) {
                components.mapNotNull { component ->
                    val compMap = component as? Map<*, *>
                    val valueQty = compMap?.get("valueQuantity") as? Map<*, *>
                    if (valueQty != null) {
                        val value = valueQty["value"]
                        val unit = valueQty["unit"] ?: ""
                        "$value $unit"
                    } else null
                }.joinToString(" / ")
            } else {
                "No value"
            }
        }
    } catch (e: Exception) {
        "No value"
    }
}
