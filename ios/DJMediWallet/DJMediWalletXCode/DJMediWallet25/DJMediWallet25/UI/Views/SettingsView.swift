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
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: AppLockManager.UserProfile.Role = .patient
    @State private var storedProfile: AppLockManager.UserProfile?
    @State private var isLoadingProfile = true
    @State private var isSavingProfile = false
    @State private var profileErrorMessage: String?
    @State private var roleConfirmationPending = false
    @State private var pendingRole: AppLockManager.UserProfile.Role?
    @State private var shouldPersistAfterRoleConfirmation = false
    @State private var roleChangeConfirmed = false
    
    private let lockOptions: [LockTimeoutOption] = LockTimeoutOption.all
    
    var body: some View {
        NavigationStack {
            Form {
                profileSection
                securitySection
                biometricsSection
                recoverySection
            }
            .navigationTitle("Settings")
            .disabled(isSavingProfile)
            .task {
                guard isLoadingProfile else { return }
                await loadProfile()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSavingProfile {
                        ProgressView()
                    } else {
                        Button("Save", action: saveProfile)
                            .disabled(!hasProfileChanges || !isProfileValid)
                    }
                }
            }
            .confirmationDialog(
                "Confirm Role Change",
                isPresented: $roleConfirmationPending,
                presenting: pendingRole
            ) { role in
                Button("Switch to \(role.displayName)", role: .destructive) {
                    selectedRole = role
                    roleChangeConfirmed = true
                    if shouldPersistAfterRoleConfirmation {
                        Task { await persistProfile() }
                    }
                    shouldPersistAfterRoleConfirmation = false
                    pendingRole = nil
                }
                Button("Cancel", role: .cancel) {
                    if shouldPersistAfterRoleConfirmation {
                        selectedRole = storedProfile?.role ?? .patient
                    }
                    shouldPersistAfterRoleConfirmation = false
                    pendingRole = nil
                }
            } message: { role in
                Text("Switching to the \(role.displayName) experience changes how data is presented. Confirm to proceed.")
            }
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
            || storedProfile.role != selectedRole
    }
    
    private var profileSection: some View {
        Section(header: Text("Profile"), footer: profileFooter) {
            if isLoadingProfile && storedProfile == nil {
                ProgressView("Loading profile…")
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                TextField("First Name", text: $firstName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                TextField("Last Name", text: $lastName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(false)
                Picker("Role", selection: roleSelectionBinding) {
                    ForEach(AppLockManager.UserProfile.Role.allCases) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(.segmented)
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
            Label(lockManager.biometricsEnabled ? "Biometrics Enabled" : "Biometrics Disabled",
                  systemImage: lockManager.biometricsEnabled ? "faceid" : "lock")
                .foregroundColor(lockManager.biometricsEnabled ? .green : .secondary)
        } footer: {
            Text(lockManager.biometricsEnabled
                 ? "Manage Face ID or Touch ID permissions in the iOS Settings app."
                 : "Biometric authentication is currently disabled. Enable it during onboarding or from system settings.")
        }
    }

    private var recoverySection: some View {
        Section(header: Text("Recovery"), footer: Text("Resetting your passphrase invalidates any previous recovery phrases.")) {
            Button {
                generatePassphraseForReset()
            } label: {
                Text("Reset Recovery Passphrase")
            }
        }
    }

    private var profileFooter: some View {
        Group {
            if let profileErrorMessage {
                Text(profileErrorMessage)
                    .foregroundColor(.red)
            } else if let storedProfile,
                      let consentDescription = consentDescription(for: storedProfile) {
                Text("Consent captured \(consentDescription).")
            } else {
                Text("Provide your details so DJ Medi Wallet can tailor features for patients or practitioners.")
            }
        }
    }
    
    private var roleSelectionBinding: Binding<AppLockManager.UserProfile.Role> {
        Binding(
            get: { selectedRole },
            set: { newRole in
                guard newRole != selectedRole else { return }
                if storedProfile == nil {
                    selectedRole = newRole
                } else {
                    pendingRole = newRole
                    roleConfirmationPending = true
                }
            }
        )
    }
    
    private func consentDescription(for profile: AppLockManager.UserProfile) -> String? {
        Self.consentFormatter.localizedString(for: profile.consentTimestamp, relativeTo: Date())
    }
    
    private static let consentFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    private func saveProfile() {
        profileErrorMessage = nil
        guard isProfileValid else {
            profileErrorMessage = "Please enter both your first and last name."
            return
        }
        if storedProfile != nil && selectedRole != storedProfile?.role {
            roleConfirmationPending = true
            pendingRole = selectedRole
        } else {
            Task { await persistProfile() }
        }
    }
    
    private func persistProfile() async {
        await MainActor.run {
            isSavingProfile = true
            profileErrorMessage = nil
        }
        let consentDate = storedProfile?.consentTimestamp ?? Date()
        let profile = AppLockManager.UserProfile(
            firstName: trimmedFirstName,
            lastName: trimmedLastName,
            role: selectedRole,
            consentTimestamp: consentDate
        )
        do {
            let updatedProfile = try await lockManager.registerUserProfile(profile)
            await MainActor.run {
                storedProfile = updatedProfile
                firstName = updatedProfile.firstName
                lastName = updatedProfile.lastName
                selectedRole = updatedProfile.role
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
            self.storedProfile = loadedProfile
            if let profile = loadedProfile {
                self.firstName = profile.firstName
                self.lastName = profile.lastName
                self.selectedRole = profile.role
            }
            self.isLoadingProfile = false
        }
    }
    
    private func generatePassphraseForReset() {
        do {
            presentedPassphrase = []
            presentedPassphrase = try lockManager.generateRecoveryPassphrase()
            passphraseError = nil
            isResettingPassphrase = true
        } catch {
                if storedProfile == nil {
                    selectedRole = newRole
                    roleChangeConfirmed = true
                } else {
                    pendingRole = newRole
                    roleConfirmationPending = true
                    shouldPersistAfterRoleConfirmation = false
                    roleChangeConfirmed = false
                }
}

private struct LockTimeoutOption: Identifiable {
    var id: TimeInterval { duration }
    let label: String
    let duration: TimeInterval
    
    static let all: [LockTimeoutOption] = [
        LockTimeoutOption(label: "Immediately", duration: 0),
                shouldPersistAfterRoleConfirmation = false
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
                    roleChangeConfirmed = false
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
                self.roleChangeConfirmed = false
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
