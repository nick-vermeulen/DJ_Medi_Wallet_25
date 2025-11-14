package com.djmediwallet.ui.viewmodels

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.djmediwallet.core.WalletManager
import com.djmediwallet.models.credential.MedicalCredential
import com.djmediwallet.models.fhir.*
import com.google.gson.Gson
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.util.*

class AddRecordViewModel : ViewModel() {
    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _saveResult = MutableStateFlow<Boolean?>(null)
    val saveResult: StateFlow<Boolean?> = _saveResult.asStateFlow()

    private val gson = Gson()

    fun saveObservation(context: Context, observation: Observation) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                val walletManager = WalletManager.getInstance(context)
                
                // Initialize wallet if needed
                if (!walletManager.isWalletInitialized()) {
                    walletManager.initializeWallet()
                }

                // Convert Observation to MedicalCredential
                val credential = MedicalCredential(
                    id = observation.id ?: UUID.randomUUID().toString(),
                    type = "Observation",
                    issuer = "Self-reported",
                    issuanceDate = Date(),
                    fhirResource = com.djmediwallet.models.credential.FHIRResource(
                        resourceType = "Observation",
                        id = observation.id,
                        data = gson.fromJson(gson.toJson(observation), Map::class.java) as Map<String, Any>
                    )
                )

                val result = walletManager.addCredential(credential)
                _saveResult.value = result.isSuccess
            } catch (e: Exception) {
                _saveResult.value = false
            } finally {
                _isSaving.value = false
            }
        }
    }

    fun saveCondition(context: Context, condition: Condition) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                val walletManager = WalletManager.getInstance(context)
                
                // Initialize wallet if needed
                if (!walletManager.isWalletInitialized()) {
                    walletManager.initializeWallet()
                }

                // Convert Condition to MedicalCredential
                val credential = MedicalCredential(
                    id = condition.id ?: UUID.randomUUID().toString(),
                    type = "Condition",
                    issuer = "Self-reported",
                    issuanceDate = Date(),
                    fhirResource = com.djmediwallet.models.credential.FHIRResource(
                        resourceType = "Condition",
                        id = condition.id,
                        data = gson.fromJson(gson.toJson(condition), Map::class.java) as Map<String, Any>
                    )
                )

                val result = walletManager.addCredential(credential)
                _saveResult.value = result.isSuccess
            } catch (e: Exception) {
                _saveResult.value = false
            } finally {
                _isSaving.value = false
            }
        }
    }

    fun saveMedication(context: Context, medication: MedicationStatement) {
        viewModelScope.launch {
            _isSaving.value = true
            try {
                val walletManager = WalletManager.getInstance(context)
                
                // Initialize wallet if needed
                if (!walletManager.isWalletInitialized()) {
                    walletManager.initializeWallet()
                }

                // Convert MedicationStatement to MedicalCredential
                val credential = MedicalCredential(
                    id = medication.id ?: UUID.randomUUID().toString(),
                    type = "MedicationStatement",
                    issuer = "Self-reported",
                    issuanceDate = Date(),
                    fhirResource = com.djmediwallet.models.credential.FHIRResource(
                        resourceType = "MedicationStatement",
                        id = medication.id,
                        data = gson.fromJson(gson.toJson(medication), Map::class.java) as Map<String, Any>
                    )
                )

                val result = walletManager.addCredential(credential)
                _saveResult.value = result.isSuccess
            } catch (e: Exception) {
                _saveResult.value = false
            } finally {
                _isSaving.value = false
            }
        }
    }
}
