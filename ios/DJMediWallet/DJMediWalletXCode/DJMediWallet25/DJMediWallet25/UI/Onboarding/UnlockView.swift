//
//  UnlockView.swift
//  DJMediWallet
//
//  Presents biometric or passcode authentication when the wallet is locked.
//

import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @State private var passcode = ""
    @FocusState private var isPasscodeFieldFocused: Bool
    @State private var attemptedBiometricUnlock = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "lock.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .foregroundColor(.blue)
            Text("Unlock Your Wallet")
                .font(.title2)
                .fontWeight(.semibold)
            if let error = lockManager.lastErrorMessage {
                Text(error)
                    .foregroundColor(.red)
            } else {
                Text("Authenticate to access your medical credentials.")
                    .foregroundColor(.secondary)
            }
            if lockManager.biometricsEnabled {
                Button(action: triggerBiometrics) {
                    Label("Use \(biometricLabel())", systemImage: biometricIconName())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SecureField("Enter passcode", text: $passcode)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused($isPasscodeFieldFocused)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                Button(action: submitPasscode) {
                    Text("Unlock")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(passcode.count == 6 ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .disabled(passcode.count != 6)
            }
            Spacer()
        }
        .onAppear {
            isPasscodeFieldFocused = true
            attemptBiometricOnce()
        }
        .onChange(of: passcode) { newValue in
            passcode = String(newValue.filter { $0.isNumber }.prefix(6))
        }
    }
    
    private func submitPasscode() {
        lockManager.resetError()
        lockManager.unlock(withPasscode: passcode)
        passcode.removeAll()
    }
    
    private func triggerBiometrics() {
        Task {
            await lockManager.unlockWithBiometrics()
        }
    }
    
    private func attemptBiometricOnce() {
        guard lockManager.biometricsEnabled, !attemptedBiometricUnlock else { return }
        attemptedBiometricUnlock = true
        triggerBiometrics()
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

    private func biometricIconName() -> String {
        switch lockManager.currentBiometryType() {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "lock"
        }
    }
}
