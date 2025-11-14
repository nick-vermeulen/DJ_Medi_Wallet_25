package com.djmediwallet.ui.viewmodels

import android.content.Context
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.djmediwallet.core.WalletManager
import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.ui.screens.RecordDetail
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

class RecordDetailViewModel : ViewModel() {
    private val _recordDetail = MutableStateFlow<RecordDetail?>(null)
    val recordDetail: StateFlow<RecordDetail?> = _recordDetail.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    fun loadRecord(context: Context, recordId: String) {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val walletManager = WalletManager.getInstance(context)
                val result = walletManager.getCredential(recordId)
                
                result.onSuccess { credential ->
                    _recordDetail.value = credential.toRecordDetail()
                }.onFailure {
                    _recordDetail.value = null
                }
            } catch (e: Exception) {
                _recordDetail.value = null
            } finally {
                _isLoading.value = false
            }
        }
    }
}

private fun MedicalCredential.toRecordDetail(): RecordDetail {
    val dateFormat = SimpleDateFormat("MMM dd, yyyy 'at' hh:mm a", Locale.US)
    val dateString = dateFormat.format(issuanceDate)

    val icon = when {
        type.contains("Observation", ignoreCase = true) -> Icons.Default.MonitorHeart
        type.contains("Condition", ignoreCase = true) -> Icons.Default.HealthAndSafety
        type.contains("Medication", ignoreCase = true) -> Icons.Default.Medication
        else -> Icons.Default.Description
    }

    val gson = Gson()
    val resourceMap = fhirResource?.data ?: emptyMap()

    return when (fhirResource?.resourceType) {
        "Observation" -> parseObservationDetail(id, dateString, icon, resourceMap)
        "Condition" -> parseConditionDetail(id, dateString, icon, resourceMap)
        "MedicationStatement" -> parseMedicationDetail(id, dateString, icon, resourceMap)
        else -> RecordDetail(
            id = id,
            type = type,
            title = "Unknown Record",
            date = dateString,
            icon = icon,
            fields = emptyMap()
        )
    }
}

private fun parseObservationDetail(
    id: String,
    dateString: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    resourceMap: Map<*, *>
): RecordDetail {
    val code = (resourceMap["code"] as? Map<*, *>)
        ?.get("text") as? String ?: "Observation"
    
    val fields = mutableMapOf<String, String>()
    
    // Check for single value
    val valueQuantity = resourceMap["valueQuantity"] as? Map<*, *>
    if (valueQuantity != null) {
        val value = valueQuantity["value"]
        val unit = valueQuantity["unit"] ?: ""
        fields["Value"] = "$value $unit"
    }
    
    // Check for components (e.g., blood pressure)
    val components = resourceMap["component"] as? List<*>
    components?.forEach { component ->
        val compMap = component as? Map<*, *>
        val compCode = ((compMap?.get("code") as? Map<*, *>)
            ?.get("coding") as? List<*>)
            ?.firstOrNull()
            ?.let { (it as? Map<*, *>)?.get("display") as? String }
            ?: "Value"
        
        val valueQty = compMap?.get("valueQuantity") as? Map<*, *>
        if (valueQty != null) {
            val value = valueQty["value"]
            val unit = valueQty["unit"] ?: ""
            fields[compCode] = "$value $unit"
        }
    }
    
    val status = resourceMap["status"] as? String
    if (status != null) {
        fields["Status"] = status.capitalize(Locale.US)
    }
    
    val notes = ((resourceMap["note"] as? List<*>)
        ?.firstOrNull() as? Map<*, *>)
        ?.get("text") as? String ?: ""
    
    return RecordDetail(
        id = id,
        type = "Vital Signs / Observation",
        title = code,
        date = dateString,
        icon = icon,
        fields = fields,
        notes = notes
    )
}

private fun parseConditionDetail(
    id: String,
    dateString: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    resourceMap: Map<*, *>
): RecordDetail {
    val code = (resourceMap["code"] as? Map<*, *>)
        ?.get("text") as? String ?: "Condition"
    
    val snomedCode = ((resourceMap["code"] as? Map<*, *>)
        ?.get("coding") as? List<*>)
        ?.firstOrNull()
        ?.let { (it as? Map<*, *>)?.get("code") as? String }
        ?: ""
    
    val fields = mutableMapOf<String, String>()
    
    val clinicalStatus = ((resourceMap["clinicalStatus"] as? Map<*, *>)
        ?.get("coding") as? List<*>)
        ?.firstOrNull()
        ?.let { (it as? Map<*, *>)?.get("display") as? String }
    if (clinicalStatus != null) {
        fields["Clinical Status"] = clinicalStatus
    }
    
    val severity = ((resourceMap["severity"] as? Map<*, *>)
        ?.get("coding") as? List<*>)
        ?.firstOrNull()
        ?.let { (it as? Map<*, *>)?.get("display") as? String }
    if (severity != null) {
        fields["Severity"] = severity
    }
    
    val onsetDate = resourceMap["onsetDateTime"] as? String
    if (onsetDate != null) {
        fields["Onset Date"] = onsetDate.substring(0, 10)
    }
    
    val notes = ((resourceMap["note"] as? List<*>)
        ?.firstOrNull() as? Map<*, *>)
        ?.get("text") as? String ?: ""
    
    return RecordDetail(
        id = id,
        type = "Diagnosis / Condition",
        title = code,
        date = dateString,
        icon = icon,
        fields = fields,
        snomedCode = snomedCode,
        notes = notes
    )
}

private fun parseMedicationDetail(
    id: String,
    dateString: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    resourceMap: Map<*, *>
): RecordDetail {
    val medication = (resourceMap["medicationCodeableConcept"] as? Map<*, *>)
        ?.get("text") as? String ?: "Medication"
    
    val snomedCode = ((resourceMap["medicationCodeableConcept"] as? Map<*, *>)
        ?.get("coding") as? List<*>)
        ?.firstOrNull()
        ?.let { (it as? Map<*, *>)?.get("code") as? String }
        ?: ""
    
    val fields = mutableMapOf<String, String>()
    
    val status = resourceMap["status"] as? String
    if (status != null) {
        fields["Status"] = status.capitalize(Locale.US)
    }
    
    val dosage = ((resourceMap["dosage"] as? List<*>)
        ?.firstOrNull() as? Map<*, *>)
        ?.get("text") as? String
    if (dosage != null) {
        fields["Dosage"] = dosage
    }
    
    val route = (((resourceMap["dosage"] as? List<*>)
        ?.firstOrNull() as? Map<*, *>)
        ?.get("route") as? Map<*, *>)
        ?.let { ((it["coding"] as? List<*>)
            ?.firstOrNull() as? Map<*, *>)
            ?.get("display") as? String }
    if (route != null) {
        fields["Route"] = route
    }
    
    val effectiveDate = resourceMap["effectiveDateTime"] as? String
    if (effectiveDate != null) {
        fields["Start Date"] = effectiveDate.substring(0, 10)
    }
    
    val notes = ((resourceMap["note"] as? List<*>)
        ?.firstOrNull() as? Map<*, *>)
        ?.get("text") as? String ?: ""
    
    return RecordDetail(
        id = id,
        type = "Medication",
        title = medication,
        date = dateString,
        icon = icon,
        fields = fields,
        snomedCode = snomedCode,
        notes = notes
    )
}
