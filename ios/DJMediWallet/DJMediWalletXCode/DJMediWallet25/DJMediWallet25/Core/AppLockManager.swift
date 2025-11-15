//
//  AppLockManager.swift
//  DJMediWallet
//
//  Coordinates onboarding, biometric, and passcode authentication flows.
//

import Foundation
import Combine
import LocalAuthentication
import CryptoKit

@MainActor
final class AppLockManager: ObservableObject {
    enum LockState: Equatable {
        case onboarding
        case locked
        case unlocked
    }
    
    enum SetupError: Error {
        case passcodeTooShort
        case storageFailure(String)
        case walletInitializationFailure(String)
    }
    
    @Published private(set) var lockState: LockState
    @Published var lastErrorMessage: String?
    
    private let walletManager: WalletManager
    private let keychain: KeychainService
    private let defaults: UserDefaults
    
    private let onboardingKey = "com.djmediwallet.onboarding.completed"
    private let biometricsKey = "com.djmediwallet.biometrics.enabled"
    private let passcodeKey = "com.djmediwallet.passcode.hash"
    
    init(
        walletManager: WalletManager? = nil,
        keychain: KeychainService = KeychainService(),
        defaults: UserDefaults = .standard
    ) {
        self.walletManager = walletManager ?? WalletManager.shared
        self.keychain = keychain
        self.defaults = defaults
        
        if defaults.bool(forKey: onboardingKey) {
            self.lockState = .locked
        } else {
            self.lockState = .onboarding
        }
    }
    
    var hasCompletedOnboarding: Bool {
        defaults.bool(forKey: onboardingKey)
    }
    
    var biometricsEnabled: Bool {
        defaults.bool(forKey: biometricsKey)
    }
    
    var hasStoredPasscode: Bool {
        keychain.contains(passcodeKey)
    }
    
    func canUseBiometrics() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func currentBiometryType() -> LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }
    
    func completeOnboarding(passcode: String, enableBiometrics: Bool) async throws {
        guard passcode.count >= 6 else {
            throw SetupError.passcodeTooShort
        }
        
    let hashed = hash(passcode)
        do {
            try keychain.save(hashed, for: passcodeKey)
        } catch {
            throw SetupError.storageFailure("Unable to store passcode securely")
        }
        
        defaults.set(true, forKey: onboardingKey)
        defaults.set(enableBiometrics && canUseBiometrics(), forKey: biometricsKey)
        
        do {
            try await initializeWalletIfNeeded()
        } catch {
            defaults.set(false, forKey: onboardingKey)
            try? keychain.delete(passcodeKey)
            throw SetupError.walletInitializationFailure(error.localizedDescription)
        }
        
        lastErrorMessage = nil
        lockState = .unlocked
    }
    
    func unlockWithBiometrics() async {
        guard biometricsEnabled else { return }
        lastErrorMessage = nil
        let result = await withCheckedContinuation { continuation in
            walletManager.authenticateUser { res in
                continuation.resume(returning: res)
            }
        }
        switch result {
        case .success:
            lockState = .unlocked
        case .failure:
            lastErrorMessage = "Biometric authentication failed."
        }
    }
    
    func unlock(withPasscode passcode: String) {
        do {
            guard let storedData = try keychain.read(passcodeKey) else {
                lastErrorMessage = "Passcode not set."
                return
            }
            let provided = hash(passcode)
            if storedData == provided {
                lastErrorMessage = nil
                lockState = .unlocked
            } else {
                lastErrorMessage = "Incorrect passcode."
            }
        } catch {
            lastErrorMessage = "Unable to read stored passcode."
        }
    }
    
    func lock() {
        guard hasCompletedOnboarding else { return }
        lastErrorMessage = nil
        lockState = .locked
    }
    
    func resetError() {
        lastErrorMessage = nil
    }
    
    private func initializeWalletIfNeeded() async throws {
        guard !walletManager.isWalletInitialized() else { return }
        try await withCheckedThrowingContinuation { continuation in
            walletManager.initializeWallet { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func hash(_ passcode: String) -> Data {
        let trimmed = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(trimmed.utf8))
        return Data(digest)
    }
}
