//
//  DJMediWalletApp.swift
//  DJMediWallet
//
//  Main app entry point for the DJ Medi Wallet iOS application
//

import SwiftUI

@main
struct DJMediWalletApp: App {
    @StateObject private var walletManager = WalletManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(walletManager)
        }
    }
}
