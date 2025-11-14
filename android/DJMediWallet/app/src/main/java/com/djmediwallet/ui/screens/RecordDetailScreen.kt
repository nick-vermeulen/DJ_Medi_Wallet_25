package com.djmediwallet.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.djmediwallet.ui.viewmodels.RecordDetailViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RecordDetailScreen(
    recordId: String,
    onBack: () -> Unit,
    viewModel: RecordDetailViewModel = viewModel()
) {
    val context = LocalContext.current
    val recordDetail by viewModel.recordDetail.collectAsState()
    val isLoading by viewModel.isLoading.collectAsState()

    LaunchedEffect(recordId) {
        viewModel.loadRecord(context, recordId)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Record Details") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                    navigationIconContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center)
                )
            } else if (recordDetail != null) {
                RecordDetailContent(
                    detail = recordDetail!!,
                    modifier = Modifier.fillMaxSize()
                )
            } else {
                Text(
                    text = "Record not found",
                    modifier = Modifier.align(Alignment.Center),
                    style = MaterialTheme.typography.bodyLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun RecordDetailContent(
    detail: RecordDetail,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .verticalScroll(rememberScrollState())
            .padding(16.dp)
    ) {
        // Header Card
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.primaryContainer
            )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = detail.icon,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    Text(
                        text = detail.type,
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    Text(
                        text = detail.title,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Date
        DetailRow(
            label = "Date",
            value = detail.date
        )

        Divider(modifier = Modifier.padding(vertical = 8.dp))

        // Fields
        detail.fields.forEach { (label, value) ->
            DetailRow(
                label = label,
                value = value
            )
            if (detail.fields.keys.last() != label) {
                Divider(modifier = Modifier.padding(vertical = 8.dp))
            }
        }

        // SNOMED Code if present
        if (detail.snomedCode.isNotEmpty()) {
            Divider(modifier = Modifier.padding(vertical = 8.dp))
            DetailRow(
                label = "SNOMED CT Code",
                value = detail.snomedCode
            )
        }

        // Notes if present
        if (detail.notes.isNotEmpty()) {
            Spacer(modifier = Modifier.height(16.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Text(
                        text = "Notes",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = detail.notes,
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailRow(
    label: String,
    value: String
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(0.4f)
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(0.6f)
        )
    }
}

data class RecordDetail(
    val id: String,
    val type: String,
    val title: String,
    val date: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
    val fields: Map<String, String>,
    val snomedCode: String = "",
    val notes: String = ""
)
