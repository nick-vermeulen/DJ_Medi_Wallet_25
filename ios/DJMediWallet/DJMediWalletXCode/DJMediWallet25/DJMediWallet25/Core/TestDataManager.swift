import Foundation
import OSLog

@MainActor
final class TestDataManager {
    static let shared = TestDataManager()

    private let walletManager: WalletManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "DJMediWallet25", category: "TestData")
    private let metadataKey = "debug.testdata.state"

    private struct FixtureState: Codable {
        let role: AppLockManager.UserProfile.Role
        let loadedAt: Date
    }

    private init(walletManager: WalletManager = .shared) {
        self.walletManager = walletManager
    }

    func seedFixtures(for role: AppLockManager.UserProfile.Role) async throws {
        try await walletManager.initializeWalletIfNeeded()
        let credentials = try loadFixtures(for: role)
        try await walletManager.removeAllCredentials()
        try await walletManager.importCredentials(credentials)
        try await persistState(FixtureState(role: role, loadedAt: Date()))
        notifyFixturesDidChange()
        logger.info("Seeded \(credentials.count) fixtures for role \(role.rawValue, privacy: .public)")
    }

    func handleProfileChange(from oldRole: AppLockManager.UserProfile.Role?, to newRole: AppLockManager.UserProfile.Role) async {
        guard oldRole != newRole else { return }
        do {
            try await walletManager.initializeWalletIfNeeded()
        } catch {
            logger.error("Unable to prepare wallet before clearing fixtures: \(error.localizedDescription, privacy: .public)")
        }
        guard let state = try? await loadState() else { return }
        guard state.role != newRole else { return }
        do {
            try await walletManager.removeAllCredentials()
            try await clearState()
            notifyFixturesDidChange()
            logger.info("Cleared fixtures after role switch from \(oldRole?.rawValue ?? "none", privacy: .public) to \(newRole.rawValue, privacy: .public)")
        } catch {
            logger.error("Failed to clear fixtures after role switch: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Fixture Loading

    private func loadFixtures(for role: AppLockManager.UserProfile.Role) throws -> [MedicalCredential] {
        let fileName: String
        switch role {
        case .patient:
            fileName = "PatientRecords"
        case .practitioner:
            fileName = "PractitionerTasks"
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            throw FixtureError.missingResource(fileName)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode([MedicalCredential].self, from: data)
        } catch {
            throw FixtureError.decodingFailed(error)
        }
    }

    // MARK: - Metadata State

    private func persistState(_ state: FixtureState) async throws {
        try await withCheckedThrowingContinuation { continuation in
            walletManager.storeMetadata(state, forKey: metadataKey) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadState() async throws -> FixtureState? {
        try await withCheckedThrowingContinuation { continuation in
            walletManager.loadMetadata(FixtureState.self, forKey: metadataKey) { result in
                switch result {
                case .success(let state):
                    continuation.resume(returning: state)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func clearState() async throws {
        try await withCheckedThrowingContinuation { continuation in
            walletManager.deleteMetadata(forKey: metadataKey) { result in
                switch result {
                case .success:
                    continuation.resume(returning: ())
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func activeFixtureRole() async -> AppLockManager.UserProfile.Role? {
        guard let state = await currentFixtureState() else { return nil }
        return state.role
    }

    func isFixtureSetActive(for role: AppLockManager.UserProfile.Role) async -> Bool {
        guard let activeRole = await activeFixtureRole() else { return false }
        return activeRole == role
    }

    func ensureFixturesAvailableIfNeeded(for role: AppLockManager.UserProfile.Role) async {
        guard await isFixtureSetActive(for: role) else { return }

        do {
            try await walletManager.initializeWalletIfNeeded()
            let existing = try await walletManager.getAllCredentialsAsync()
            guard existing.isEmpty else { return }

            let fixtures = try loadFixtures(for: role)
            try await walletManager.importCredentials(fixtures)
            notifyFixturesDidChange()
            logger.info("Rehydrated \(fixtures.count) fixtures for role \(role.rawValue, privacy: .public)")
        } catch {
            logger.error("Failed to rehydrate fixtures for role \(role.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func currentFixtureState() async -> FixtureState? {
        do {
            return try await loadState()
        } catch {
            logger.error("Unable to read fixture state: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func notifyFixturesDidChange() {
        NotificationCenter.default.post(name: .testDataFixturesDidChange, object: nil)
    }
}

extension TestDataManager {
    enum FixtureError: LocalizedError {
        case missingResource(String)
        case decodingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .missingResource(let name):
                return "Fixture \(name) could not be located in the app bundle."
            case .decodingFailed(let error):
                return "Unable to decode fixture: \(error.localizedDescription)"
            }
        }
    }
}

extension Notification.Name {
    static let testDataFixturesDidChange = Notification.Name("TestDataFixturesDidChange")
}
