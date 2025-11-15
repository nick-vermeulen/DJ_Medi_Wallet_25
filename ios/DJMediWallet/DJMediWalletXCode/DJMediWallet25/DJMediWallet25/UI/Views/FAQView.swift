import SwiftUI

struct FAQView: View {
    private let topics: [FAQTopic] = [
        FAQTopic(
            title: "Getting Started",
            questions: [
                FAQEntry(
                    question: "How do I add my first medical record?",
                    answer: "Tap the plus button on the Records tab, choose the credential type, and enter the requested FHIR data. The wallet validates required fields and stores the credential locally once you confirm."),
                FAQEntry(
                    question: "How do I present a credential?",
                    answer: "Open the record, review the details, and use the share or QR options provided. For QR-based payloads, present the code to a verifier that supports FHIR bundle ingestion."),
                FAQEntry(
                    question: "How do I keep my wallet secure?",
                    answer: "Set a strong passcode during onboarding, enable biometrics, and choose an auto-lock window that fits your usage. You can refresh your recovery passphrase from Settings whenever you need a new backup.")
            ]
        ),
        FAQTopic(
            title: "Self-Sovereign Identity & Data Wallets",
            questions: [
                FAQEntry(
                    question: "What is self-sovereign identity?",
                    answer: "Self-sovereign identity (SSI) lets you control digital proofs about yourself without relying on a central authority to hold them. DJ Medi Wallet stores verifiable credentials on your device and only discloses claims you approve."),
                FAQEntry(
                    question: "How does DJ Medi Wallet handle GDPR and consent?",
                    answer: "Your data stays encrypted on-device. Sharing requires an explicit action, and every presentation flow records the verifier, the purpose, and the fields you agreed to disclose. You may revoke consent by deleting credentials or declining future requests."),
                FAQEntry(
                    question: "How do SSI wallets work with health data?",
                    answer: "Health credentials follow the FHIR standard and use SNOMED CT terminology. When you share a credential, the app packages only the necessary entries, minimizing exposure while remaining interoperable with healthcare verifiers.")
            ]
        ),
        FAQTopic(
            title: "Using the App Day-to-Day",
            questions: [
                FAQEntry(
                    question: "Can I sync records across devices?",
                    answer: "Supabase sync is optional and requires authenticating with your deployment. When offline, everything continues to work because the wallet persists data locally."),
                FAQEntry(
                    question: "How do I regenerate my recovery passphrase?",
                    answer: "Go to Settings > Recovery and choose Reset Recovery Passphrase. Write down the newly generated 12-word phrase to regain access if you lose your device."),
                FAQEntry(
                    question: "What happens if a verifier asks for more data than I am comfortable sharing?",
                    answer: "You can decline the request or share a subset if the verifier accepts selective disclosure. The wallet shows you exactly which claims will be released before you confirm.")
            ]
        ),
        FAQTopic(
            title: "Troubleshooting",
            questions: [
                FAQEntry(
                    question: "My QR code is not scanning. What should I do?",
                    answer: "Ensure your screen brightness is high and the verifier supports compressed FHIR payloads. You can also copy the JSON bundle from the QR detail screen and share it through a secure channel."),
                FAQEntry(
                    question: "I forgot my passcode. Can I regain access?",
                    answer: "Restore your wallet using the 12-word recovery passphrase. Without it, the encrypted data cannot be recovered, ensuring your information remains protected."),
                FAQEntry(
                    question: "How do I submit feedback?",
                    answer: "Use the contact instructions in the About page or the deployment partner portal. Include diagnostic details only if you are comfortable sharing them."),
            ]
        )
    ]

    var body: some View {
        List {
            ForEach(topics) { topic in
                Section(header: Text(topic.title)) {
                    ForEach(topic.questions) { question in
                        FAQRow(entry: question)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("FAQ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQTopic: Identifiable {
    let id = UUID()
    let title: String
    let questions: [FAQEntry]
}

private struct FAQEntry: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

private struct FAQRow: View {
    let entry: FAQEntry
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(entry.answer)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.vertical, 4)
        } label: {
            Text(entry.question)
                .font(.headline)
        }
        .accessibilityHint("Double tap to expand and read the answer")
    }
}

#Preview {
    NavigationStack {
        FAQView()
    }
}
