//
//  OnboardingFlowView.swift
//  DJMediWallet
//
//  Guides first-time users through ARF disclosures and security setup.
//

import SwiftUI

struct OnboardingFlowView: View {
    @State private var currentStep = 0
    @State private var hasAcknowledgedCompliance = false
    
    private let totalSteps = 3
    
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
                
                SecuritySetupView(canComplete: hasAcknowledgedCompliance) {
                    retreat()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color(.systemBackground))
    }
    
    private func advance() {
        if currentStep < totalSteps - 1 {
            currentStep += 1
        }
    }
    
    private func retreat() {
        if currentStep > 0 {
            currentStep -= 1
        }
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
