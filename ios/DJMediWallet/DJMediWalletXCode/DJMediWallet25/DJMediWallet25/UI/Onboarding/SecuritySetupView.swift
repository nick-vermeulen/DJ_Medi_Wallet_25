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
    let onBack: () -> Void
    
    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var allowBiometrics = true
    @State private var biometricsAvailable = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isShowingErrorAlert = false
    @FocusState private var focusedField: FocusableField?

    private enum FocusableField {
        case passcode
        case confirm
    }
    
    var body: some View {
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
                        .focused($focusedField, equals: .passcode)
                    SecureField("Confirm passcode", text: $confirmPasscode)
                        .keyboardType(.numberPad)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .confirm)
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
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            actionBar
        }
        .onAppear {
            biometricsAvailable = lockManager.canUseBiometrics()
            allowBiometrics = biometricsAvailable
        }
        .onChange(of: passcode) { _, newValue in
            passcode = sanitized(newValue)
        }
        .onChange(of: confirmPasscode) { _, newValue in
            confirmPasscode = sanitized(newValue)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
        .alert("Passcode Issue", isPresented: $isShowingErrorAlert) {
            Button("OK", role: .cancel) {
                focusedField = .passcode
            }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }
    
    private var isActionEnabled: Bool {
        passcode.count == 6 && passcode == confirmPasscode && !isProcessing
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

    private func clearError() {
        errorMessage = nil
        isShowingErrorAlert = false
    }

    private func presentError(_ message: String) {
        errorMessage = message
        isShowingErrorAlert = true
        focusedField = .passcode
    }
    
    private func completeSetup() {
        guard isActionEnabled else { return }
        clearError()
        isProcessing = true
        focusedField = nil
        let selectedBiometrics = allowBiometrics && biometricsAvailable
        Task { @MainActor in
            defer { isProcessing = false }
            do {
                try await lockManager.completeOnboarding(passcode: passcode, enableBiometrics: selectedBiometrics)
            } catch AppLockManager.SetupError.passcodeTooShort {
                presentError("Passcode must be six digits.")
            } catch AppLockManager.SetupError.passcodeTooWeak {
                presentError("Passcode is too easy to guess. Choose a less predictable combination.")
            } catch AppLockManager.SetupError.storageFailure(let reason) {
                presentError(reason)
            } catch AppLockManager.SetupError.walletInitializationFailure(let reason) {
                presentError("Wallet initialization failed: \(reason)")
            } catch AppLockManager.SetupError.profileIncomplete {
                presentError("Please provide your name and role before completing setup.")
            } catch {
                presentError("Unexpected error: \(error.localizedDescription)")
            }
        }
    }

    private var actionBar: some View {
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
            .disabled(!isActionEnabled)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
}
