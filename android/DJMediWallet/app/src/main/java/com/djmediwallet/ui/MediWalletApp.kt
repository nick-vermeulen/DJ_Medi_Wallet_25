package com.djmediwallet.ui

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.djmediwallet.ui.screens.*

sealed class Screen(val route: String, val title: String, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    object Records : Screen("records", "Records", Icons.Default.FolderSpecial)
    object Add : Screen("add", "Add", Icons.Default.Add)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MediWalletApp() {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("DJ Medi Wallet") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        },
        bottomBar = {
            NavigationBar {
                listOf(Screen.Records, Screen.Add).forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.title) },
                        label = { Text(screen.title) },
                        selected = currentDestination?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Screen.Records.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(Screen.Records.route) {
                RecordsListScreen(
                    onRecordClick = { recordId ->
                        navController.navigate("record_detail/$recordId")
                    }
                )
            }
            composable(Screen.Add.route) {
                AddRecordScreen(
                    onRecordAdded = {
                        navController.navigate(Screen.Records.route) {
                            popUpTo(Screen.Records.route) { inclusive = false }
                        }
                    }
                )
            }
            composable("record_detail/{recordId}") { backStackEntry ->
                val recordId = backStackEntry.arguments?.getString("recordId")
                if (recordId != null) {
                    RecordDetailScreen(
                        recordId = recordId,
                        onBack = { navController.popBackStack() }
                    )
                }
            }
        }
    }
}
