//
//  PresentationHubView.swift
//  DJMediWallet25
//
//  Main entry point for scanning and responding to SD-JWT presentation requests.
//

import SwiftUI

struct PresentationHubView: View {
    @EnvironmentObject private var walletManager: WalletManager
    @StateObject private var viewModel = PresentationViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                content

                if case .submitting = viewModel.status {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Preparing presentation…")
                        .padding()
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .navigationTitle("Present")
            .toolbar { toolbarContent }
            .sheet(isPresented: $viewModel.isScannerPresented) {
                scannerSheet
            }
            .alert(item: $viewModel.alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.status {
        case .idle, .loading, .error(_):
            EmptyStateView(status: viewModel.status) {
                viewModel.beginScan()
            }
        case .ready, .submitting, .submitted:
            if let request = viewModel.request {
                ScrollView {
                    VStack(spacing: 16) {
                        RequestSummaryCard(request: request)

                        if case .submitted(let receipt) = viewModel.status {
                            SubmissionReceiptBanner(receipt: receipt)
                        }

                        DisclosureListView(claims: $viewModel.claims)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            } else {
                EmptyStateView(status: .idle) {
                    viewModel.beginScan()
                }
            }
        }
    }

    private var actionBar: some View {
        Group {
            if let request = viewModel.request {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal)

                    Button {
                        Task {
                            await viewModel.submit(walletManager: walletManager)
                        }
                    } label: {
                        Text(buttonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .disabled(!viewModel.canSubmit)

                    if case .submitted = viewModel.status {
                        Button("Scan Another Request") {
                            viewModel.reset()
                            viewModel.beginScan()
                        }
                        .padding(.bottom, 12)
                    }
                }
                .background(.regularMaterial)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.metadata.verifierDisplayName)
                            .font(.subheadline)
                            .bold()
                        Text(request.metadata.purpose)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding([.top, .leading], 16)
                }
            }
        }
    }

    private var buttonTitle: String {
        if case .submitted = viewModel.status {
            return "Resend Presentation"
        }
        return "Share Presentation"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                if case .submitted = viewModel.status {
                    viewModel.reset()
                }
                viewModel.beginScan()
            } label: {
                Label("Scan", systemImage: "qrcode.viewfinder")
            }
        }

        ToolbarItem(placement: .cancellationAction) {
            if viewModel.request != nil {
                Button("Clear") {
                    viewModel.reset()
                }
            }
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            ZStack {
                QRScannerView { result in
                    viewModel.handleScanResult(result, walletManager: walletManager)
                }

                VStack(spacing: 16) {
                    Text("Align the verifier QR code")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Your wallet will decrypt the request and show the data being asked for.")
                        .multilineTextAlignment(.center)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelScan()
                    }
                }
            }
            .navigationTitle("Scan Request")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Subviews

private struct EmptyStateView: View {
    let status: PresentationViewModel.Status
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 54))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .bold()
                Text(subtitle)
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Button(action: onScan) {
                Label("Scan Verification Request", systemImage: "camera.viewfinder")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var title: String {
        switch status {
        case .error(_):
            return "Something went wrong"
        default:
            return "Ready to present"
        }
    }

    private var subtitle: String {
        switch status {
        case .error(_):
            return "Try scanning the verifier QR code again or contact the health provider."
        case .loading:
            return "Decrypting the verifier request…"
        default:
            return "Scan the verifier's QR code to see which health data they need and approve selective disclosure."
        }
    }
}

private struct RequestSummaryCard: View {
    let request: SDJWTPresentationRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verifier")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(request.metadata.verifierDisplayName)
                .font(.title3)
                .bold()

            if let purpose = request.metadata.purpose.isEmpty ? nil : request.metadata.purpose {
                Text(purpose)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let audience = request.metadata.audience {
                    LabeledContent("Audience") {
                        Text(audience)
                    }
                }
                if let nonce = request.metadata.nonce {
                    LabeledContent("Nonce") {
                        Text(nonce)
                    }
                }
                if let expiry = request.metadata.expiry {
                    LabeledContent("Expires") {
                        Text(expiry, style: .relative)
                    }
                }
                LabeledContent("Response Endpoint") {
                    Text(request.metadata.responseURI.absoluteString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

private struct SubmissionReceiptBanner: View {
    let receipt: PresentationSubmissionReceipt

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.white)
                .font(.title3)
                .padding(10)
                .background(Circle().fill(Color.green))

            VStack(alignment: .leading, spacing: 4) {
                Text("Presentation sent")
                    .font(.headline)
                if let receivedAt = receipt.receivedAt {
                    Text("Verifier acknowledged at \(receivedAt, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let submissionId = receipt.submissionId {
                    Text("Submission ID: \(submissionId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.15)))
    }
}

private struct DisclosureListView: View {
    @Binding var claims: [PresentationDisclosureClaim]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach($claims) { $claim in
                PresentationDisclosureClaimView(claim: $claim)
            }
        }
    }
}

private struct PresentationDisclosureClaimView: View {
    @Binding var claim: PresentationDisclosureClaim

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(claim.claim.displayName)
                        .font(.headline)
                    if let description = claim.claim.description, description.isEmpty == false {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Toggle(isOn: includeBinding) {
                    Text(claim.isRequired ? "Required" : "Share")
                        .font(.caption)
                        .foregroundColor(claim.isRequired ? .secondary : .primary)
                }
                .toggleStyle(.switch)
                .disabled(claim.isRequired || claim.options.isEmpty)
            }

            if claim.options.isEmpty {
                Text("No credential available to satisfy this claim.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } else {
                Picker("Credential", selection: selectionBinding) {
                    ForEach(claim.options) { option in
                        Text(option.title)
                            .tag(Optional(option.id))
                    }
                }
                .pickerStyle(.menu)
                .disabled(claim.include == false)

                if let selected = claim.selectedOption {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(selected.subtitle, systemImage: "doc.text")
                        Label(selected.valueSummary, systemImage: "list.bullet")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var includeBinding: Binding<Bool> {
        Binding<Bool>(
            get: { claim.include },
            set: { newValue in
                guard claim.isRequired == false else { return }
                claim.include = newValue
            }
        )
    }

    private var selectionBinding: Binding<String?> {
        Binding<String?>(
            get: { claim.selectedOptionId },
            set: { newValue in
                claim.selectedOptionId = newValue
                if claim.selectedOptionId == nil, let first = claim.options.first {
                    claim.selectedOptionId = first.id
                }
            }
        )
    }
}

#Preview {
    PresentationHubView()
        .environmentObject(WalletManager.shared)
        .environmentObject(AppLockManager())
}