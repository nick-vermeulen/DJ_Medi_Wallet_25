import SwiftUI
import UIKit

struct AboutView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @EnvironmentObject private var lockManager: AppLockManager
    @State private var tapHistory: [Date] = []
    @State private var isSeedingFixtures = false
    @State private var fixtureStatus: FixtureStatus?

    private let sections: [AboutSection] = [
        AboutSection(
            title: "Our Mission",
            body: "DJ Medi Wallet empowers individuals and clinicians to hold, manage, and share verifiable health credentials securely. The app aligns with the EU European Digital Identity Wallet vision and focuses on privacy-preserving selective disclosure so you share only what is needed."),
        AboutSection(
            title: "Privacy & Compliance",
            body: "We design every workflow with GDPR and the European Digital Identity Architecture and Reference Framework in mind. Consent is explicit, revocable, and mirrored in the data you store on your device. Sensitive information remains locally encrypted unless you choose to share it."),
        AboutSection(
            title: "Security Foundations",
            body: "All secrets are protected with the system keychain and optional biometric access. Recovery passphrases are generated on-device, hashed with SHA256, and never leave your control. Auto-lock and session timeouts prevent unauthorized access."),
        AboutSection(
            title: "Open Standards",
            body: "FHIR payloads, SNOMED CT terminology, and W3C verifiable credential primitives ensure your data remains portable. QR codes are interoperable with verifiers that understand compressed FHIR bundles."),
        AboutSection(
            title: "Transparency",
            body: "DJ Medi Wallet is part of an ongoing research initiative. You can find architectural decisions and compliance notes in the in-app FAQ or in the public project documentation bundled with the app."),
        AboutSection(
            title: "Contact",
            body: "Have feedback or spotted an issue? Reach out via the support channels listed in the project README or submit a ticket through your deployment partner.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image("AboutIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 140)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 24)
                    .accessibilityHidden(true)
                    .contentShape(Rectangle())
                    .onTapGesture { handleSecretTap() }
                Text("About DJ Medi Wallet")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 8)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(section.body)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSeedingFixtures {
                ProgressView("Loading demo data…")
                    .progressViewStyle(.circular)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(item: $fixtureStatus) { status in
            Alert(
                title: Text(status.kind == .success ? "Demo Data Ready" : "Demo Load Failed"),
                message: Text(status.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func handleSecretTap() {
        let now = Date()
        tapHistory = tapHistory.filter { now.timeIntervalSince($0) < 1.2 }
        tapHistory.append(now)

        guard tapHistory.count >= 5 else { return }
        tapHistory.removeAll()

        guard lockManager.userProfile != nil else {
            fixtureStatus = FixtureStatus(kind: .failure, message: "Create your profile before loading demo data.")
            return
        }

        guard isSeedingFixtures == false else { return }

        isSeedingFixtures = true
        Task {
            await seedFixtures()
        }
    }

    private func seedFixtures() async {
        guard let profile = lockManager.userProfile else {
            await MainActor.run {
                fixtureStatus = FixtureStatus(kind: .failure, message: "Profile is required before loading demo data.")
                isSeedingFixtures = false
            }
            return
        }

        do {
            try await TestDataManager.shared.seedFixtures(for: profile.role)
            await MainActor.run {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
                fixtureStatus = FixtureStatus(kind: .success, message: "Loaded demo records for \(profile.role.displayName). Pull to refresh to see them.")
                isSeedingFixtures = false
            }
        } catch {
            await MainActor.run {
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.error)
                fixtureStatus = FixtureStatus(kind: .failure, message: error.localizedDescription)
                isSeedingFixtures = false
            }
        }
    }
}

private struct AboutSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

private struct FixtureStatus: Identifiable {
    enum Kind {
        case success
        case failure
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
