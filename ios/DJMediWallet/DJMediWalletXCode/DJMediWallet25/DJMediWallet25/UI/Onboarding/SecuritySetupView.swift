//
//  SecuritySetupView.swift
//  DJMediWallet
//
//  Collects the user's passcode and biometric preferences during onboarding.
//

import SwiftUI
import LocalAuthentication

struct SecuritySetupView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    let canComplete: Bool
    let onBack: () -> Void
    
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var allowBiometrics = true
    @State private var biometricsAvailable = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Secure Your Wallet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Choose a six-digit passcode to protect access. If your device supports biometrics you can enable Face ID or Touch ID for quicker unlocks.")
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create Passcode")
                            .font(.headline)
                        SecureField("6-digit passcode", text: $passcode)
                            .keyboardType(.numberPad)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                        SecureField("Confirm passcode", text: $confirmPasscode)
                            .keyboardType(.numberPad)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    if biometricsAvailable {
                        Toggle(isOn: $allowBiometrics) {
                            Text("Enable \(biometricLabel())")
                                .fontWeight(.medium)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            HStack {
                Button(action: onBack) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                Button(action: completeSetup) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Complete Setup")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(isActionEnabled ? Color.blue : Color.gray.opacity(0.4))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(!isActionEnabled || isProcessing)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .onAppear {
            biometricsAvailable = lockManager.canUseBiometrics()
            allowBiometrics = biometricsAvailable
        }
        .onChange(of: passcode) { newValue in
            passcode = sanitized(newValue)
        }
        .onChange(of: confirmPasscode) { newValue in
            confirmPasscode = sanitized(newValue)
        }
    }
    
    private var isActionEnabled: Bool {
        canComplete && passcode.count == 6 && passcode == confirmPasscode
    }
    
    private func sanitized(_ input: String) -> String {
        String(input.filter { $0.isNumber }.prefix(6))
    }
    
    private func biometricLabel() -> String {
        switch lockManager.currentBiometryType() {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometrics"
        }
    }
    
    private func completeSetup() {
        guard isActionEnabled else { return }
        errorMessage = nil
        isProcessing = true
        let selectedBiometrics = allowBiometrics && biometricsAvailable
        Task {
            do {
                try await lockManager.completeOnboarding(passcode: passcode, enableBiometrics: selectedBiometrics)
            } catch AppLockManager.SetupError.passcodeTooShort {
                errorMessage = "Passcode must be six digits."
            } catch AppLockManager.SetupError.storageFailure(let reason) {
                errorMessage = reason
            } catch AppLockManager.SetupError.walletInitializationFailure(let reason) {
                errorMessage = "Wallet initialization failed: \(reason)"
            } catch {
                errorMessage = "Unexpected error: \(error.localizedDescription)"
            }
            isProcessing = false
        }
    }
}
