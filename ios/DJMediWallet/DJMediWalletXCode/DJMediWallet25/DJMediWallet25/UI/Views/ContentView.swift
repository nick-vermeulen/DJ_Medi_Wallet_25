//
//  ContentView.swift
//  DJMediWallet
//
//  Main navigation view
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @EnvironmentObject private var walletManager: WalletManager
    
    private var currentRole: AppLockManager.UserProfile.Role {
        lockManager.userProfile?.role ?? .patient
    }

    var body: some View {
        TabView {
            RecordsListView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            PresentationHubView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
                .tabItem {
                    Label("Present", systemImage: "person.wave.2")
                }

            if lockManager.userProfile?.role == .practitioner {
                CaptureTaskView()
                    .environmentObject(walletManager)
                    .environmentObject(lockManager)
                    .tabItem {
                        Label("Capture", systemImage: "qrcode.viewfinder")
                    }
            }

            SettingsView()
                .environmentObject(lockManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .id(currentRole)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppLockManager())
        .environmentObject(WalletManager.shared)
}
