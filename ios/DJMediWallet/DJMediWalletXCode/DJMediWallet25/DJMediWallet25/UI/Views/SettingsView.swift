//
//  SettingsView.swift
//  DJMediWallet
//
//  User-configurable preferences for wallet security and behavior.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @State private var isResettingPassphrase = false
    @State private var presentedPassphrase: [String] = []
    @State private var passphraseError: String?
    
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
                
                Section(header: Text("Recovery"), footer: Text("Resetting your passphrase invalidates any previous recovery phrases.")) {
                    Button {
                        generatePassphraseForReset()
                    } label: {
                        Text("Reset Recovery Passphrase")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isResettingPassphrase) {
                PassphraseResetSheet(
                    passphrase: presentedPassphrase,
                    errorMessage: $passphraseError,
                    onRegenerate: generatePassphraseForReset,
                    onConfirm: {
                        do {
                            try lockManager.storeRecoveryPassphrase(words: presentedPassphrase)
                            passphraseError = nil
                            isResettingPassphrase = false
                        } catch {
                            passphraseError = "Unable to store passphrase. Please try again."
                        }
                    },
                    onCancel: {
                        isResettingPassphrase = false
                        passphraseError = nil
                    }
                )
            }
        }
    }
    
    private var lockTimeoutBinding: Binding<TimeInterval> {
        Binding(
            get: { lockManager.lockTimeout },
            set: { lockManager.updateLockTimeout(to: $0) }
        )
    }
    
    private func generatePassphraseForReset() {
        do {
            presentedPassphrase = []
            presentedPassphrase = try lockManager.generateRecoveryPassphrase()
            passphraseError = nil
            isResettingPassphrase = true
        } catch {
            passphraseError = "Unable to generate passphrase."
            isResettingPassphrase = true
        }
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

private struct PassphraseResetSheet: View {
    let passphrase: [String]
    @Binding var errorMessage: String?
    let onRegenerate: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("New Recovery Passphrase")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Write down this new 12-word passphrase and store it securely. It replaces any previous recovery phrases.")
                            .foregroundColor(.secondary)
                        if passphrase.isEmpty {
                            ProgressView("Generating secure words…")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical)
                        } else {
                            PassphraseWordGrid(words: passphrase)
                                .padding(.vertical)
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                }
                HStack {
                    Button(action: onRegenerate) {
                        Text("Regenerate")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    Button(action: onConfirm) {
                        Text("Confirm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(passphrase.isEmpty)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Reset Passphrase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onCancel)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppLockManager())
}
