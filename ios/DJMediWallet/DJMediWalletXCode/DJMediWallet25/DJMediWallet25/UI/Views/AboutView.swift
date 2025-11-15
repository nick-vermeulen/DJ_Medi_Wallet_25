import SwiftUI

struct AboutView: View {
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
    }
}

private struct AboutSection: Identifiable {
    let id = UUID()
    let title: String
    let body: String
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
