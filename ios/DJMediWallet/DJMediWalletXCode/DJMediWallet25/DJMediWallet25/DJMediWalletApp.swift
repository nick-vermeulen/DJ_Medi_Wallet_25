//
//  DJMediWalletApp.swift
//  DJMediWallet
//
//  Main app entry point for the DJ Medi Wallet iOS application
//

import SwiftUI

@main
@MainActor
struct DJMediWalletApp25: App {
    @StateObject private var walletManager: WalletManager
    @StateObject private var lockManager: AppLockManager
    
    init() {
        let sharedWallet = WalletManager.shared
        _walletManager = StateObject(wrappedValue: sharedWallet)
        _lockManager = StateObject(wrappedValue: AppLockManager(walletManager: sharedWallet))
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
        }
    }
}
