//
//  OnboardingFlowView.swift
//  DJMediWallet
//
//  Guides first-time users through ARF disclosures and security setup.
//

import SwiftUI
import Security

struct OnboardingFlowView: View {
    @EnvironmentObject private var lockManager: AppLockManager
    @State private var currentStep = 0
    @State private var hasAcknowledgedCompliance = false
    @State private var passphrase: [String] = []
    @State private var confirmationIndices: [Int] = []
    @State private var passphraseError: String?
    @State private var didConfirmPassphrase = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedRole: AppLockManager.UserProfile.Role = .patient
    @State private var profileError: String?
    @State private var hasStoredProfile = false
    
    private let totalSteps = 5
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .padding(.top, 32)
                .padding(.horizontal)
            
            TabView(selection: $currentStep) {
                WelcomeStep(
                    firstName: $firstName,
                    lastName: $lastName,
                    selectedRole: $selectedRole,
                    errorMessage: profileError,
                    onContinue: saveProfileAndAdvance
                )
                .tag(0)
                
                ComplianceStep(hasAccepted: $hasAcknowledgedCompliance) {
                    advance()
                } onBack: {
                    retreat()
                }
                .tag(1)
                
                PassphraseDisplayStep(passphrase: passphrase, errorMessage: $passphraseError) {
                    passphraseError = nil
                    generateConfirmationIndices()
                    advance()
                } onGenerate: {
                    generatePassphraseIfNeeded(force: true)
                    didConfirmPassphrase = false
                }
                .tag(2)
                
                PassphraseConfirmStep(passphrase: passphrase, indices: confirmationIndices, errorMessage: $passphraseError) {
                    do {
                        try lockManager.storeRecoveryPassphrase(words: passphrase)
                        passphraseError = nil
                        didConfirmPassphrase = true
                        advance()
                    } catch {
                        passphraseError = "Unable to store passphrase. Please try again."
                    }
                } onBack: {
                    retreat()
                }
                .tag(3)
                
                SecuritySetupView {
                    retreat()
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
        .background(Color(.systemBackground))
        .onAppear {
            applyProfileFromManager()
            generatePassphraseIfNeeded(force: false)
            didConfirmPassphrase = false
            profileError = nil
        }
        .onChange(of: currentStep) { _, newStep in
            if newStep == 2 {
                generatePassphraseIfNeeded(force: false)
            } else if newStep == 3, confirmationIndices.isEmpty {
                generateConfirmationIndices()
            }
        }
        .onChange(of: passphrase) { _, newValue in
            if !newValue.isEmpty, confirmationIndices.isEmpty {
                generateConfirmationIndices()
            }
        }
        .task {
            _ = await lockManager.loadUserProfile()
            applyProfileFromManager()
        }
    }
    
    private func advance() {
        if currentStep < totalSteps - 1 {
            if currentStep == 1 { generatePassphraseIfNeeded(force: false) }
            currentStep += 1
        }
    }
    
    private func retreat() {
        if currentStep > 0 {
            currentStep -= 1
            if currentStep == 0 {
                profileError = nil
            }
        }
    }

    private func applyProfileFromManager() {
        if let storedProfile = lockManager.userProfile {
            firstName = storedProfile.firstName
            lastName = storedProfile.lastName
            selectedRole = storedProfile.role
            hasStoredProfile = true
        } else {
            firstName = ""
            lastName = ""
            selectedRole = .patient
            hasStoredProfile = false
        }
    }

    private func saveProfileAndAdvance() {
        profileError = nil
        let consentDate = Date()
        let profile = AppLockManager.UserProfile(firstName: firstName, lastName: lastName, role: selectedRole, consentTimestamp: consentDate)
        Task {
            do {
                _ = try await lockManager.registerUserProfile(profile)
                hasStoredProfile = true
                applyProfileFromManager()
                advance()
            } catch AppLockManager.SetupError.profileIncomplete {
                profileError = "Please enter your first and last name."
            } catch AppLockManager.SetupError.storageFailure(let message) {
                profileError = message
            } catch {
                profileError = "Unable to store profile."
            }
        }
    }
    
    private func generatePassphraseIfNeeded(force: Bool) {
        guard force || passphrase.isEmpty else { return }
        do {
            passphrase = try lockManager.generateRecoveryPassphrase()
            passphraseError = nil
            confirmationIndices.removeAll()
            didConfirmPassphrase = false
        } catch {
            passphraseError = "Unable to generate passphrase."
        }
    }
    
    private func generateConfirmationIndices() {
        guard !passphrase.isEmpty else { return }
        var indices: Set<Int> = []
        while indices.count < 3 {
            if let index = try? PassphraseIndexGenerator.randomIndex(max: passphrase.count) {
                indices.insert(index)
            }
        }
        confirmationIndices = indices.sorted()
    }
}

private enum PassphraseIndexGenerator {
    static func randomIndex(max: Int) throws -> Int {
        precondition(max > 0, "max must be positive")
        var number: UInt32 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &number)
        if status != errSecSuccess { throw PassphraseError.entropyUnavailable }
        return Int(number) % max
    }
}

private struct WelcomeStep: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var selectedRole: AppLockManager.UserProfile.Role
    let errorMessage: String?
    let onContinue: () -> Void
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case firstName
        case lastName
    }
    
    private var isFormValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "heart.text.square.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 96, height: 96)
                        .foregroundColor(.blue)
                        .padding(.top, 48)
                    Text("Welcome to DJ Medi Wallet")
                        .font(.title)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    Text("Tell us who you are so we can personalise your wallet setup.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("First Name")
                                .font(.headline)
                            TextField("Enter first name", text: $firstName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)
                                .focused($focusedField, equals: .firstName)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .lastName }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Last Name")
                                .font(.headline)
                            TextField("Enter last name", text: $lastName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)
                                .focused($focusedField, equals: .lastName)
                                .submitLabel(.done)
                                .onSubmit { focusedField = nil }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Role")
                                .font(.headline)
                            Picker("Role", selection: $selectedRole) {
                                ForEach(AppLockManager.UserProfile.Role.allCases) { role in
                                    Text(role.displayName).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 32)
                }
                .padding(.horizontal)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { focusedField = nil })
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!isFormValid)
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
    }
}

private struct ComplianceStep: View {
    @Binding var hasAccepted: Bool
    let onContinue: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("EU Data Wallet ARF Compliance")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("To issue and hold credentials under the EU Architecture Reference Framework (ARF), we must confirm:")
                        .foregroundColor(.secondary)
                    ComplianceBullet("Your data stays in your local wallet unless you explicitly share it.")
                    ComplianceBullet("Credentials are issued according to EU trusted list schemas and can be revoked at any time.")
                    ComplianceBullet("We provide transparent auditing metadata that identifies this wallet as a trusted client.")
                    ComplianceBullet("Biometric or passcode protection is required before any credential operation.")
                    Toggle(isOn: $hasAccepted) {
                        Text("I have reviewed and agree to the ARF client obligations.")
                            .fontWeight(.medium)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .padding(.top, 8)
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
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasAccepted ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!hasAccepted)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

private struct PassphraseDisplayStep: View {
    let passphrase: [String]
    @Binding var errorMessage: String?
    let onContinue: () -> Void
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recovery Passphrase")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Write down these 12 words in order. This passphrase is required to regain access if you forget your passcode or lose biometric access.")
                        .foregroundColor(.secondary)
                    PassphraseWordGrid(words: passphrase)
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            HStack {
                Button(action: onGenerate) {
                    Text("Regenerate")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                }
                Button(action: onContinue) {
                    Text("I Wrote It Down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(passphrase.isEmpty ? Color.gray.opacity(0.4) : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(passphrase.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }
}

private struct PassphraseConfirmStep: View {
    let passphrase: [String]
    let indices: [Int]
    @Binding var errorMessage: String?
    let onContinue: () -> Void
    let onBack: () -> Void
    @State private var inputs: [Int: String] = [:]
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Confirm Passphrase")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Enter the words shown previously to confirm you recorded them correctly.")
                        .foregroundColor(.secondary)
                    ForEach(indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Word \(index + 1)")
                                .font(.headline)
                            TextField("Enter word", text: binding(for: index))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(10)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
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
                Button(action: validate) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isComplete ? Color.blue : Color.gray.opacity(0.4))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!isComplete)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .onChange(of: indices) { _, _ in
            inputs.removeAll()
        }
        .onAppear {
            inputs.removeAll()
        }
    }
    
    private var isComplete: Bool {
        !indices.isEmpty &&
        inputs.count == indices.count &&
        indices.allSatisfy { !(inputs[$0]?.isEmpty ?? true) }
    }
    
    private func binding(for index: Int) -> Binding<String> {
        Binding(
            get: { inputs[index] ?? "" },
            set: { inputs[index] = $0.lowercased() }
        )
    }
    
    private func validate() {
        guard isComplete else { return }
        for idx in indices {
            let expected = passphrase[idx].lowercased()
            if inputs[idx]?.trimmingCharacters(in: .whitespacesAndNewlines) != expected {
                errorMessage = "One or more words do not match."
                return
            }
        }
        errorMessage = nil
        onContinue()
    }
}

// PassphraseWordGrid defined in UI/Components

private struct ComplianceBullet: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.blue)
            Text(text)
                .foregroundColor(.secondary)
        }
    }
}
