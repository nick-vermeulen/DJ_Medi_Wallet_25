//
//  DJMediWalletApp.swift
//  DJMediWallet
//
//  Main app entry point for the DJ Medi Wallet iOS application
//

import SwiftUI
import SwiftData
import Combine

@main
@MainActor
struct DJMediWalletApp25: App {
    @StateObject private var walletManager: WalletManager
    @StateObject private var lockManager: AppLockManager
    @StateObject private var snomedService: SNOMEDService
    private let snomedStore: SNOMEDStore
    private let modelContainer: ModelContainer
    
    init() {
        let sharedWallet = WalletManager.shared
        let snomedStore = SNOMEDStore(persistenceURL: SNOMEDStore.defaultPersistenceURL())
        _walletManager = StateObject(wrappedValue: sharedWallet)
        _lockManager = StateObject(wrappedValue: AppLockManager(walletManager: sharedWallet))
        self.snomedStore = snomedStore
        _snomedService = StateObject(wrappedValue: SNOMEDService(store: snomedStore))
        do {
            let schema = Schema([
                ReportTemplate.self,
                ExamPreset.self
            ])
            let localConfiguration = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(
                for: schema,
                configurations: localConfiguration
            )
        } catch {
            fatalError("Failed to initialize model container: \(error.localizedDescription)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(walletManager)
                .environmentObject(lockManager)
                .environmentObject(snomedService)
                .modelContainer(modelContainer)
        }
    }
}
