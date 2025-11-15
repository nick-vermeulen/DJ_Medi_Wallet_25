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
import Supabase

@MainActor
final class AppLockManager: ObservableObject {
    struct UserProfile: Codable, Equatable {
        enum Role: String, Codable, CaseIterable, Identifiable {
            case patient
            case practitioner
            
            var id: String { rawValue }
            
            var displayName: String {
                switch self {
                case .patient:
                    return "Patient"
                case .practitioner:
                    return "Practitioner"
                }
            }
        }
        
    var firstName: String
    var lastName: String
    var role: Role
    var consentTimestamp: Date
    var externalUserId: String?
        
        var normalizedFirstName: String {
            firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var normalizedLastName: String {
            lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        init(firstName: String, lastName: String, role: Role, consentTimestamp: Date = Date(), externalUserId: String? = nil) {
            self.firstName = firstName
            self.lastName = lastName
            self.role = role
            self.consentTimestamp = consentTimestamp
            self.externalUserId = externalUserId
        }
        
        private enum CodingKeys: String, CodingKey {
            case firstName
            case lastName
            case role
            case consentTimestamp
            case externalUserId
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            firstName = try container.decode(String.self, forKey: .firstName)
            lastName = try container.decode(String.self, forKey: .lastName)
            role = try container.decode(Role.self, forKey: .role)
            consentTimestamp = try container.decodeIfPresent(Date.self, forKey: .consentTimestamp) ?? Date()
            externalUserId = try container.decodeIfPresent(String.self, forKey: .externalUserId)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(firstName, forKey: .firstName)
            try container.encode(lastName, forKey: .lastName)
            try container.encode(role, forKey: .role)
            try container.encode(consentTimestamp, forKey: .consentTimestamp)
            try container.encodeIfPresent(externalUserId, forKey: .externalUserId)
        }
    }
    
    private enum ProfileStorageKey {
        static let metadata = "user_profile"
        static let legacyDefaults = "com.djmediwallet.user.profile"
    }
    
    enum LockState: Equatable {
        case onboarding
        case locked
        case unlocked
    }
    
    enum SetupError: Error {
        case passcodeTooShort
        case passcodeTooWeak
        case storageFailure(String)
        case walletInitializationFailure(String)
        case profileIncomplete
    }
    
    @Published private(set) var lockState: LockState
    @Published var lastErrorMessage: String?
    @Published var lockTimeout: TimeInterval
    @Published private(set) var userProfile: UserProfile?
    
    private let walletManager: WalletManager
    private let keychain: KeychainService
    private let defaults: UserDefaults
    
    private let onboardingKey = "com.djmediwallet.onboarding.completed"
    private let biometricsKey = "com.djmediwallet.biometrics.enabled"
    private let passcodeKey = "com.djmediwallet.passcode.hash"
    private let passphraseKey = "com.djmediwallet.passphrase.hash"
    private let lockTimeoutKey = "com.djmediwallet.lock.timeout"
    private static let weakPasscodeCandidates: Set<String> = [
        "000000", "111111", "222222", "333333", "444444", "555555",
        "666666", "777777", "888888", "999999", "123456", "234567",
        "345678", "456789", "012345", "543210", "654321", "765432",
        "876543", "987654", "121212", "131313", "141414", "123123",
        "321321", "135791"
    ]

    private var lockWorkItem: DispatchWorkItem?
    private var supabaseAuthTask: Task<Void, Never>?
    
    init(
        walletManager: WalletManager? = nil,
        keychain: KeychainService? = nil,
        defaults: UserDefaults? = nil
    ) {
        let resolvedDefaults = defaults ?? .standard
        self.walletManager = walletManager ?? WalletManager.shared
        self.keychain = keychain ?? KeychainService()
        self.defaults = resolvedDefaults
        self.userProfile = AppLockManager.decodeLegacyProfile(from: resolvedDefaults)
        if resolvedDefaults.bool(forKey: onboardingKey) {
            self.lockState = .locked
        } else {
            self.lockState = .onboarding
        }
        if let storedTimeout = resolvedDefaults.object(forKey: lockTimeoutKey) as? Double {
            self.lockTimeout = storedTimeout
        } else {
            self.lockTimeout = 60
            resolvedDefaults.set(60, forKey: lockTimeoutKey)
        }
        Task { [weak self] in
            guard let self else { return }
            _ = await self.loadUserProfile()
        }

        configureSupabaseAuthMonitoring()
    }

    deinit {
        supabaseAuthTask?.cancel()
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
        guard !isWeakPasscode(passcode) else {
            throw SetupError.passcodeTooWeak
        }
        guard userProfile != nil else {
            throw SetupError.profileIncomplete
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

    func registerUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        let trimmedFirst = profile.normalizedFirstName
        let trimmedLast = profile.normalizedLastName
        guard !trimmedFirst.isEmpty, !trimmedLast.isEmpty else {
            throw SetupError.profileIncomplete
        }
        let consentDate = profile.consentTimestamp
        var cleanedProfile = UserProfile(firstName: trimmedFirst, lastName: trimmedLast, role: profile.role, consentTimestamp: consentDate, externalUserId: profile.externalUserId)

        if cleanedProfile.externalUserId == nil {
            if let supabaseId = try? await SupabaseService.shared.currentUserId() {
                cleanedProfile.externalUserId = supabaseId.uuidString
            }
        }
        do {
            try await storeProfileMetadata(cleanedProfile)
            persistProfileToDefaults(cleanedProfile)
            userProfile = cleanedProfile
            return cleanedProfile
        } catch let error as WalletError {
            throw SetupError.storageFailure(error.localizedDescription)
        } catch {
            throw SetupError.storageFailure("Unable to store profile securely")
        }
    }
    
    @discardableResult
    func loadUserProfile() async -> UserProfile? {
        do {
            if let profile = try await loadProfileMetadata() {
                persistProfileToDefaults(profile)
                userProfile = profile
                return profile
            }
        } catch {
            // Fallback to defaults-only profile when metadata is unavailable
        }
        if let legacy = AppLockManager.decodeLegacyProfile(from: defaults) {
            userProfile = legacy
            return legacy
        }
        return nil
    }
    
    func clearUserProfile() async {
        await withCheckedContinuation { continuation in
            walletManager.deleteMetadata(forKey: ProfileStorageKey.metadata) { _ in
                continuation.resume()
            }
        }
        defaults.removeObject(forKey: ProfileStorageKey.legacyDefaults)
        userProfile = nil
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

    private func isWeakPasscode(_ passcode: String) -> Bool {
        if AppLockManager.weakPasscodeCandidates.contains(passcode) {
            return true
        }

        let digits = passcode.compactMap { $0.wholeNumberValue }
        guard digits.count == passcode.count else { return true }

        if Set(digits).count == 1 {
            return true
        }

        let pairs = zip(digits, digits.dropFirst())
        let isAscending = pairs.allSatisfy { $1 == $0 + 1 }
        let isDescending = pairs.allSatisfy { $1 == $0 - 1 }
        if isAscending || isDescending {
            return true
        }

        if digits.count >= 2 {
            let first = digits[0]
            let second = digits[1]
            if first != second {
                var isAlternating = true
                for index in 0..<digits.count {
                    let expected = index % 2 == 0 ? first : second
                    if digits[index] != expected {
                        isAlternating = false
                        break
                    }
                }
                if isAlternating {
                    return true
                }
            }
        }

        if digits.count == 6 {
            let firstHalf = Array(digits.prefix(3))
            let secondHalf = Array(digits.suffix(3))
            if firstHalf == secondHalf {
                return true
            }
        }

        return false
    }

    private func configureSupabaseAuthMonitoring() {
        supabaseAuthTask?.cancel()
        supabaseAuthTask = Task.detached { [weak self] in
            do {
                let stream = try await SupabaseService.shared.authStateChangeStream()
                for await change in stream {
                    await self?.processSupabaseAuthEvent(event: change.event, session: change.session)
                }
            } catch {
                // Ignore configuration errors until Supabase is available.
            }
        }
    }

    @MainActor
    private func processSupabaseAuthEvent(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn, .tokenRefreshed, .userUpdated, .mfaChallengeVerified:
            guard let session else { return }
            await handleSupabaseSession(session)
        case .signedOut, .userDeleted:
            await handleSupabaseSignOut()
        case .passwordRecovery:
            break
        }
    }

    @MainActor
    private func handleSupabaseSession(_ session: Session) async {
        let supabaseUserId = session.user.id
        await persistExternalUserIdIfNeeded(supabaseUserId)
        do {
            _ = try await walletManager.syncPatientRecordsFromSupabase(patientId: supabaseUserId)
            if let message = lastErrorMessage, message.contains("Supabase") {
                lastErrorMessage = nil
            }
        } catch {
            lastErrorMessage = "Unable to refresh records from Supabase: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handleSupabaseSignOut() async {
        guard var profile = userProfile, profile.externalUserId != nil else { return }
        profile.externalUserId = nil
        do {
            try await storeProfileMetadata(profile)
            persistProfileToDefaults(profile)
            userProfile = profile
        } catch {
            lastErrorMessage = "Unable to clear Supabase link: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func persistExternalUserIdIfNeeded(_ identifier: UUID) async {
        let externalIdentifier = identifier.uuidString
        guard var profile = userProfile else { return }
        guard profile.externalUserId != externalIdentifier else { return }

        profile.externalUserId = externalIdentifier

        do {
            try await storeProfileMetadata(profile)
            persistProfileToDefaults(profile)
            userProfile = profile
        } catch {
            lastErrorMessage = "Unable to store Supabase link: \(error.localizedDescription)"
        }
    }

    private func storeProfileMetadata(_ profile: UserProfile) async throws {
        try await withCheckedThrowingContinuation { continuation in
            walletManager.storeMetadata(profile, forKey: ProfileStorageKey.metadata) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func loadProfileMetadata() async throws -> UserProfile? {
        try await withCheckedThrowingContinuation { continuation in
            walletManager.loadMetadata(UserProfile.self, forKey: ProfileStorageKey.metadata) { result in
                switch result {
                case .success(let profile):
                    continuation.resume(returning: profile)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func persistProfileToDefaults(_ profile: UserProfile) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(profile) {
            defaults.set(data, forKey: ProfileStorageKey.legacyDefaults)
        }
    }
    
    private static func decodeLegacyProfile(from defaults: UserDefaults) -> UserProfile? {
        guard let data = defaults.data(forKey: ProfileStorageKey.legacyDefaults) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UserProfile.self, from: data)
    }
}
