//
//  DJMediWalletApp.swift
//  DJMediWallet
//
//  Main app entry point for the DJ Medi Wallet iOS application
//

import SwiftUI

@main
struct DJMediWalletApp25: App {
    @StateObject private var walletManager = WalletManager.shared
    @StateObject private var lockManager = AppLockManager()
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
        }
    }
}
