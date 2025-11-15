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
    
    private let totalSteps = 5
    
    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                .padding(.top, 32)
                .padding(.horizontal)
            
            TabView(selection: $currentStep) {
                WelcomeStep {
                    advance()
                }
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
                }
                .tag(2)
                
                PassphraseConfirmStep(passphrase: passphrase, indices: confirmationIndices, errorMessage: $passphraseError) {
                    do {
                        try lockManager.storeRecoveryPassphrase(words: passphrase)
                        passphraseError = nil
                        advance()
                    } catch {
                        passphraseError = "Unable to store passphrase. Please try again."
                    }
                } onBack: {
                    retreat()
                }
                .tag(3)
                
                SecuritySetupView(canComplete: hasAcknowledgedCompliance) {
                    retreat()
                }
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(.systemBackground))
        .onAppear { generatePassphraseIfNeeded(force: false) }
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
        }
    }
    
    private func generatePassphraseIfNeeded(force: Bool) {
        guard force || passphrase.isEmpty else { return }
        do {
            passphrase = try lockManager.generateRecoveryPassphrase()
            passphraseError = nil
            confirmationIndices.removeAll()
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
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "heart.text.square.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundColor(.blue)
            Text("Welcome to DJ Medi Wallet")
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            Text("This wallet aligns with the EU Digital Identity framework and keeps your health credentials secure on your device.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            Spacer()
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            Spacer()
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
                    if passphrase.isEmpty {
                        ProgressView("Generating secure words…")
                            .frame(maxWidth: .infinity, alignment: .center)
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
        VStack(spacing: 24) {
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
            .padding(.bottom, 24)
        }
        .onChange(of: indices) { _ in
            inputs.removeAll()
        }
        .onAppear {
            inputs.removeAll()
        }
    }
    
    private var isComplete: Bool {
        inputs.count == indices.count && indices.allSatisfy { !(inputs[$0]?.isEmpty ?? true) }
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
