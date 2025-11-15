//
//  SettingsView.swift
//  DJMediWallet
//
//  User-configurable preferences for wallet security and behavior.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    
    private let lockOptions: [LockTimeoutOption] = LockTimeoutOption.all
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Security")) {
                    Picker("Auto-Lock", selection: lockTimeoutBinding) {
                        ForEach(lockOptions) { option in
                            Text(option.label).tag(option.duration)
                        }
                    }
                    .pickerStyle(.inline)
                    .accessibilityHint("Sets how long DJ Medi Wallet stays unlocked when you leave the app")
                }
                
                Section {
                    Label(lockManager.biometricsEnabled ? "Biometrics Enabled" : "Biometrics Disabled",
                          systemImage: lockManager.biometricsEnabled ? "faceid" : "lock")
                        .foregroundColor(lockManager.biometricsEnabled ? .green : .secondary)
                } footer: {
                    Text(lockManager.biometricsEnabled
                         ? "Manage Face ID or Touch ID permissions in the iOS Settings app."
                         : "Biometric authentication is currently disabled. Enable it during onboarding or from system settings.")
                }
            }
            .navigationTitle("Settings")
        }
    }
    
    private var lockTimeoutBinding: Binding<TimeInterval> {
        Binding(
            get: { lockManager.lockTimeout },
            set: { lockManager.updateLockTimeout(to: $0) }
        )
    }
}

private struct LockTimeoutOption: Identifiable {
    var id: TimeInterval { duration }
    let label: String
    let duration: TimeInterval
    
    static let all: [LockTimeoutOption] = [
        LockTimeoutOption(label: "Immediately", duration: 0),
        LockTimeoutOption(label: "30 Seconds", duration: 30),
        LockTimeoutOption(label: "1 Minute", duration: 60),
        LockTimeoutOption(label: "5 Minutes", duration: 300)
    ]
}

#Preview {
    SettingsView()
        .environmentObject(AppLockManager())
}
