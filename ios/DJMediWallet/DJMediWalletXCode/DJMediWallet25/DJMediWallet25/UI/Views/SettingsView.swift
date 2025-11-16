//
//  SettingsView.swift
//  DJMediWallet
//
//  User-configurable preferences for wallet security and behavior.
//

import SwiftUI
import Combine

struct SettingsView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @StateObject private var idCardStore = IDCardStore()
    @State private var isResettingPassphrase = false
    @State private var presentedPassphrase: [String] = []
    @State private var passphraseError: String?
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var storedProfile: AppLockManager.UserProfile?
    @State private var isLoadingProfile = true
    @State private var isSavingProfile = false
    @State private var profileErrorMessage: String?
    @State private var optimisticRole: AppLockManager.UserProfile.Role?
    @State private var isSwitchingRole = false
    @State private var roleSwitchError: IdentifiableError?
    @FocusState private var focusedField: Field?

    private let lockOptions: [LockTimeoutOption] = LockTimeoutOption.all

    var body: some View {
        NavigationStack {
            Form {
                informationSection
                profileSection
                idCardSection
                securitySection
                biometricsSection
                recoverySection
                legalSection
            }
            .navigationTitle("Settings")
            .disabled(isSavingProfile)
            .task { await ensureProfileLoaded() }
            .toolbar { saveToolbar }
            .toolbar { keyboardToolbar }
            .sheet(isPresented: $isResettingPassphrase) {
                PassphraseResetSheet(
                    passphrase: presentedPassphrase,
                    errorMessage: $passphraseError,
                    onRegenerate: generatePassphraseForReset,
                    onConfirm: handlePassphraseResetConfirmation,
                    onCancel: handlePassphraseResetCancellation
                )
            }
            .overlay {
                if isSwitchingRole {
                    ProgressView("Updating role…")
                        .progressViewStyle(.circular)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert(
                "Role Update Failed",
                isPresented: Binding(
                    get: { roleSwitchError != nil },
                    set: { _ in roleSwitchError = nil }
                )
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(roleSwitchError?.message ?? "An unexpected error occurred.")
            }
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section(header: Text("Profile"), footer: profileFooter) {
            if isLoadingProfile && lockManager.userProfile == nil && storedProfile == nil {
                ProgressView("Loading profile...")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                TextField("First Name", text: $firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .focused($focusedField, equals: .firstName)
                    .submitLabel(.done)
                TextField("Last Name", text: $lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                    .focused($focusedField, equals: .lastName)
                    .submitLabel(.done)

                Toggle("Practitioner Mode", isOn: practitionerToggleBinding)
                    .disabled(lockManager.userProfile == nil || isSwitchingRole)
                    .accessibilityHint(lockManager.userProfile == nil
                        ? "A stored profile is required before switching roles."
                        : "Switch between patient and practitioner features.")

                if let currentRole = optimisticRole ?? lockManager.userProfile?.role ?? storedProfile?.role {
                    Text("Current role: \(currentRole.displayName)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                } else {
                    Text("No profile is currently stored.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var securitySection: some View {
        Section(header: Text("Security")) {
            Picker("Auto-Lock", selection: lockTimeoutBinding) {
                ForEach(lockOptions) { option in
                    Text(option.label).tag(option.duration)
                }
            }
            .pickerStyle(.inline)
            .accessibilityHint("Sets how long DJ Medi Wallet stays unlocked when you leave the app")
        }
    }

    private var biometricsSection: some View {
        Section {
            Label(
                lockManager.biometricsEnabled ? "Biometrics Enabled" : "Biometrics Disabled",
                systemImage: lockManager.biometricsEnabled ? "faceid" : "lock"
            )
            .foregroundColor(lockManager.biometricsEnabled ? .green : .secondary)
        } footer: {
            Text(
                lockManager.biometricsEnabled
                ? "Manage Face ID or Touch ID permissions in the iOS Settings app."
                : "Biometric authentication is currently disabled. Enable it during onboarding or from system settings."
            )
        }
    }

    private var recoverySection: some View {
        Section(
            header: Text("Recovery"),
            footer: Text("Resetting your passphrase invalidates any previous recovery phrases.")
        ) {
            Button("Reset Recovery Passphrase", action: generatePassphraseForReset)
        }
    }

    private var informationSection: some View {
        Section(header: Text("Information"), footer: Text("Review our mission, policies, and usage guidance before adjusting sensitive settings.")) {
            NavigationLink(destination: AboutView()) {
                Label("About DJ Medi Wallet", systemImage: "info.circle")
            }
            NavigationLink(destination: FAQView()) {
                Label("FAQ & Guides", systemImage: "questionmark.circle")
            }
        }
    }

    private var idCardSection: some View {
        Section(header: Text("ID Cards"), footer: Text("Store healthcare and loyalty IDs for quick access and barcode display.")) {
            NavigationLink {
                IDCardsListView(store: idCardStore)
            } label: {
                Label("ID Card Wallet", systemImage: "wallet.pass")
            }
            NavigationLink {
                IDCardSettingsView(store: idCardStore)
            } label: {
                Label("Manage ID Cards", systemImage: "rectangle.stack.badge.person.crop")
            }
        }
    }

    private var legalSection: some View {
        Section {
            VStack(alignment: .center, spacing: 4) {
                Text("Made with Care in the Channel Islands")
                    .font(.footnote)
                Text("Using SwiftUI. Well it is the new Smalltalk!")
                    .font(.footnote)
                Text("© Lazy-Jack.com")
                    .font(.footnote)
                Text("\"So long and thanks for all the fish...\"")
                    .font(.footnote.weight(.bold)) 
                    .italic()
            }
            .font(.footnote)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)
        }
    }

    private var profileFooter: some View {
        Group {
            if let profileErrorMessage {
                Text(profileErrorMessage)
                    .foregroundColor(.red)
            } else if let storedProfile,
                      let consentDescription = consentDescription(for: storedProfile) {
                Text("Consent captured \(consentDescription). You can review your data handling options in the FAQ.")
            } else {
                Text("Provide your details so DJ Medi Wallet can tailor features for patients or practitioners.")
            }
        }
    }

    private var saveToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if isSavingProfile {
                ProgressView()
            } else {
                Button("Save", action: saveProfile)
                    .disabled(!hasProfileChanges || !isProfileValid)
            }
        }
    }

    // MARK: - Bindings

    private var lockTimeoutBinding: Binding<TimeInterval> {
        Binding(
            get: { lockManager.lockTimeout },
            set: { lockManager.updateLockTimeout(to: $0) }
        )
    }

    private var practitionerToggleBinding: Binding<Bool> {
        Binding(
            get: {
                let role = optimisticRole ?? lockManager.userProfile?.role ?? storedProfile?.role
                return role == .practitioner
            },
            set: { newValue in
                guard isSwitchingRole == false else { return }
                guard let currentRole = lockManager.userProfile?.role ?? storedProfile?.role else {
                    optimisticRole = nil
                    return
                }
                let target: AppLockManager.UserProfile.Role = newValue ? .practitioner : .patient
                guard target != currentRole else { return }
                optimisticRole = target
                performRoleSwitch(to: target)
            }
        )
    }

    // MARK: - Derived State

    private enum Field: Hashable {
        case firstName
        case lastName
    }

    private var trimmedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isProfileValid: Bool {
        !trimmedFirstName.isEmpty && !trimmedLastName.isEmpty
    }

    private var hasProfileChanges: Bool {
        guard let storedProfile else { return isProfileValid }
        return storedProfile.firstName != trimmedFirstName
            || storedProfile.lastName != trimmedLastName
    }

    // MARK: - Actions

    private func ensureProfileLoaded() async {
        guard isLoadingProfile else { return }
        await loadProfile()
    }

    private func saveProfile() {
        profileErrorMessage = nil
        guard isProfileValid else {
            profileErrorMessage = "Please enter both your first and last name."
            return
        }
        Task { await persistProfile() }
    }

    private func persistProfile() async {
        await MainActor.run {
            isSavingProfile = true
            profileErrorMessage = nil
        }
        let consentDate = storedProfile?.consentTimestamp ?? Date()
        let role = storedProfile?.role ?? lockManager.userProfile?.role ?? .patient
        let profile = AppLockManager.UserProfile(
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            role: role,
            consentTimestamp: consentDate
        )
        do {
            let updatedProfile = try await lockManager.registerUserProfile(profile)
            await MainActor.run {
                storedProfile = updatedProfile
                firstName = updatedProfile.firstName
                lastName = updatedProfile.lastName
                optimisticRole = nil
                isSavingProfile = false
            }
        } catch AppLockManager.SetupError.profileIncomplete {
            await MainActor.run {
                isSavingProfile = false
                profileErrorMessage = "Please enter both your first and last name."
            }
        } catch AppLockManager.SetupError.storageFailure(let message) {
            await MainActor.run {
                isSavingProfile = false
                profileErrorMessage = message
            }
        } catch {
            await MainActor.run {
                isSavingProfile = false
                profileErrorMessage = "Unable to update your profile. Please try again."
            }
        }
    }

    private func loadProfile() async {
        let loadedProfile = await lockManager.loadUserProfile() ?? lockManager.userProfile
        await MainActor.run {
            storedProfile = loadedProfile
            if let profile = loadedProfile {
                firstName = profile.firstName
                lastName = profile.lastName
            }
            optimisticRole = nil
            isLoadingProfile = false
        }
    }

    private func generatePassphraseForReset() {
        do {
            presentedPassphrase = try lockManager.generateRecoveryPassphrase()
            passphraseError = nil
            isResettingPassphrase = true
        } catch {
            passphraseError = "Unable to generate passphrase."
            isResettingPassphrase = true
        }
    }

    private func handlePassphraseResetConfirmation() {
        do {
            try lockManager.storeRecoveryPassphrase(words: presentedPassphrase)
            passphraseError = nil
            isResettingPassphrase = false
        } catch {
            passphraseError = "Unable to store passphrase. Please try again."
        }
    }

    private func handlePassphraseResetCancellation() {
        isResettingPassphrase = false
        passphraseError = nil
    }

    // MARK: - Helpers

    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") {
                focusedField = nil
            }
        }
    }

    private func consentDescription(for profile: AppLockManager.UserProfile) -> String? {
        Self.consentFormatter.localizedString(for: profile.consentTimestamp, relativeTo: Date())
    }

    private static let consentFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private func performRoleSwitch(to target: AppLockManager.UserProfile.Role) {
        guard isSwitchingRole == false else { return }
        guard let profile = lockManager.userProfile else {
            optimisticRole = nil
            return
        }
        guard profile.role != target else {
            optimisticRole = nil
            return
        }

        isSwitchingRole = true
        roleSwitchError = nil

        Task { @MainActor in
            defer { isSwitchingRole = false }

            var updated = profile
            updated.role = target

            do {
                _ = try await lockManager.registerUserProfile(updated)
                let refreshed = await lockManager.loadUserProfile() ?? updated
                storedProfile = refreshed
                firstName = refreshed.firstName
                lastName = refreshed.lastName
                optimisticRole = nil
            } catch {
                roleSwitchError = IdentifiableError(message: error.localizedDescription)
                optimisticRole = profile.role
            }
        }
    }
}

private struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
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
                            ProgressView("Generating secure words...")
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
