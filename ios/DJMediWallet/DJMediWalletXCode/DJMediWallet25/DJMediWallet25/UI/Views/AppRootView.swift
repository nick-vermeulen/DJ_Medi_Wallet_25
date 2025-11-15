//
//  AppRootView.swift
//  DJMediWallet
//
//  Entry view that decides between onboarding, lock screen, and main content.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            switch lockManager.lockState {
            case .onboarding:
                NavigationStack {
                    OnboardingFlowView()
                }
            case .locked:
                NavigationStack {
                    UnlockView()
                }
            case .unlocked:
                ContentView()
            }
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active:
                lockManager.cancelAutoLock()
            case .inactive, .background:
                lockManager.scheduleAutoLock()
            @unknown default:
                break
            }
        }
    }
}
