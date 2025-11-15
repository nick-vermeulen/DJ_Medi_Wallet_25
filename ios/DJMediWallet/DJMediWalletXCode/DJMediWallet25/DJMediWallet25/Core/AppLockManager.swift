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
    @Published var lockTimeout: TimeInterval
    
    private let walletManager: WalletManager
    private let keychain: KeychainService
    private let defaults: UserDefaults
    
    private let onboardingKey = "com.djmediwallet.onboarding.completed"
    private let biometricsKey = "com.djmediwallet.biometrics.enabled"
    private let passcodeKey = "com.djmediwallet.passcode.hash"
    private let passphraseKey = "com.djmediwallet.passphrase.hash"
    private let lockTimeoutKey = "com.djmediwallet.lock.timeout"

    private var lockWorkItem: DispatchWorkItem?
    
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
        if let storedTimeout = defaults.object(forKey: lockTimeoutKey) as? Double {
            self.lockTimeout = storedTimeout
        } else {
            self.lockTimeout = 60
            defaults.set(60, forKey: lockTimeoutKey)
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

    var hasStoredPassphrase: Bool {
        keychain.contains(passphraseKey)
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
            try? keychain.delete(passphraseKey)
            throw SetupError.walletInitializationFailure(error.localizedDescription)
        }
        
        lastErrorMessage = nil
        lockState = .unlocked
        cancelAutoLock()
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
            cancelAutoLock()
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
                cancelAutoLock()
            } else {
                lastErrorMessage = "Incorrect passcode."
            }
        } catch {
            lastErrorMessage = "Unable to read stored passcode."
        }
    }
    
    func lock() {
        guard hasCompletedOnboarding else { return }
        lockWorkItem?.cancel()
        lockWorkItem = nil
        lastErrorMessage = nil
        lockState = .locked
    }
    
    func resetError() {
        lastErrorMessage = nil
    }

    func updateLockTimeout(to interval: TimeInterval) {
        lockTimeout = interval
        defaults.set(interval, forKey: lockTimeoutKey)
    }

    func scheduleAutoLock() {
        guard lockState == .unlocked else { return }
        lockWorkItem?.cancel()
        let interval = lockTimeout
        guard interval > 0 else {
            lock()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.lock()
            }
        }
        lockWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    func cancelAutoLock() {
        lockWorkItem?.cancel()
        lockWorkItem = nil
    }

    func generateRecoveryPassphrase() throws -> [String] {
        try PassphraseManager.shared.generatePassphrase()
    }

    func storeRecoveryPassphrase(words: [String]) throws {
        let normalized = PassphraseManager.shared.normalize(words)
        let hash = hash(normalized)
        try keychain.save(hash, for: passphraseKey)
    }

    func unlock(withPassphraseInput input: String) {
        let words = input
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .map { String($0).lowercased() }
        guard words.count == 12 else {
            lastErrorMessage = "Passphrase must contain 12 words."
            return
        }
        do {
            guard let stored = try keychain.read(passphraseKey) else {
                lastErrorMessage = "No recovery passphrase set."
                return
            }
            let normalized = PassphraseManager.shared.normalize(words)
            let hash = hash(normalized)
            if stored == hash {
                lastErrorMessage = nil
                lockState = .unlocked
                cancelAutoLock()
            } else {
                lastErrorMessage = "Incorrect passphrase."
            }
        } catch {
            lastErrorMessage = "Unable to verify passphrase."
        }
    }

    func resetRecoveryPassphrase() throws -> [String] {
        let passphrase = try generateRecoveryPassphrase()
        try storeRecoveryPassphrase(words: passphrase)
        return passphrase
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
