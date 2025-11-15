//
//  ContentView.swift
//  DJMediWallet
//
//  Main navigation view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var walletManager: WalletManager
    
    var body: some View {
        TabView {
            RecordsListView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            SettingsView()
                .environmentObject(lockManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppLockManager())
        .environmentObject(WalletManager.shared)
}
