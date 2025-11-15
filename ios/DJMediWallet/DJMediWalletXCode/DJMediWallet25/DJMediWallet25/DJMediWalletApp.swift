//
//  DJMediWalletApp.swift
//  DJMediWallet
//
//  Main app entry point for the DJ Medi Wallet iOS application
//

import SwiftUI
import SwiftData

@main
@MainActor
struct DJMediWalletApp25: App {
    @StateObject private var walletManager: WalletManager
    @StateObject private var lockManager: AppLockManager
    private let modelContainer: ModelContainer
    
    init() {
        let sharedWallet = WalletManager.shared
        _walletManager = StateObject(wrappedValue: sharedWallet)
        _lockManager = StateObject(wrappedValue: AppLockManager(walletManager: sharedWallet))
        do {
            modelContainer = try ModelContainer(for: ReportTemplate.self, ExamPreset.self, SNOMEDConcept.self)
        } catch {
            fatalError("Failed to initialize model container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
                .modelContainer(modelContainer)
        }
    }
}
