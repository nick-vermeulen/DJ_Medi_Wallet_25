//
//  PresentationHubView.swift
//  DJMediWallet25
//
//  Main entry point for scanning and responding to SD-JWT presentation requests.
//

import SwiftUI
import Combine
import UIKit

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
            .fullScreenCover(isPresented: $viewModel.isScannerPresented) {
                scannerSheet
            }
            .sheet(item: $viewModel.proximityShareState) { state in
                ProximityShareSheet(state: state)
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
        case .ready, .submitting:
            if let request = viewModel.request {
                ScrollView {
                    VStack(spacing: 16) {
                        RequestSummaryCard(request: request)
                        if viewModel.missingRecentObservationData {
                            MissingDataBanner {
                                viewModel.reset()
                            }
                        }
                        DisclosureListView(claims: $viewModel.claims)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .onReceive(viewModel.$claims) { _ in
                    if viewModel.proximityShareState != nil {
                        viewModel.clearShareState()
                    }
                }
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

                    if viewModel.missingRecentObservationData {
                        Button("Cancel Request", role: .cancel) {
                            viewModel.reset()
                        }
                        .buttonStyle(.bordered)
                        .padding(.horizontal)
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
        return "Show QR Package"
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
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

private struct MissingDataBanner: View {
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("No observations recorded in the last 24 hours.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.headline)
            .foregroundColor(.orange)

            Text("You can cancel this request and let the practitioner know that recent vitals are not available.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Cancel Request", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
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

private struct ProximityShareSheet: View {
    let state: ProximityShareState
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0

    private var currentSegment: QRPayloadSegment? {
        guard state.payloadSegments.isEmpty == false else { return nil }
        let clampedIndex = min(max(0, currentIndex), state.payloadSegments.count - 1)
        return state.payloadSegments[clampedIndex]
    }

    private var qrImage: UIImage? {
        guard let payload = currentSegment?.payload else { return nil }
        return QRCodeRenderer.image(for: payload)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    qrDisplay
                    if state.payloadSegments.count > 1 {
                        segmentControls
                    }
                    if state.disclosures.isEmpty == false {
                        disclosureSummary
                    }
                    payloadSections
                }
                .padding()
            }
            .navigationTitle("Share via QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            currentIndex = 0
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.verifierName)
                .font(.title3)
                .bold()
            if state.verifierPurpose.isEmpty == false {
                Text(state.verifierPurpose)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            Text("Ask the verifier to scan each QR code in order. The payloads stay on your device.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var qrDisplay: some View {
        if let image = qrImage, let segment = currentSegment {
            VStack(spacing: 12) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 280)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemBackground)))
                    .shadow(radius: 4)
                Text("Segment \(segment.index) of \(segment.total)")
                    .font(.subheadline)
                    .bold()
                Text("Hold steady and allow the verifier to capture this QR.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            ProgressView("Rendering QR…")
                .frame(maxWidth: .infinity)
        }
    }

    private var segmentControls: some View {
        HStack {
            Button {
                currentIndex = max(currentIndex - 1, 0)
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(currentIndex == 0)

            Spacer()

            Button {
                currentIndex = min(currentIndex + 1, state.payloadSegments.count - 1)
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(currentIndex >= state.payloadSegments.count - 1)
        }
    }

    private var disclosureSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Included Disclosures")
                .font(.headline)
            ForEach(state.disclosures) { disclosure in
                VStack(alignment: .leading, spacing: 4) {
                    Text(disclosure.title)
                        .font(.subheadline)
                        .bold()
                    Text(disclosure.detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var payloadSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            DisclosureGroup("Current QR Payload") {
                if let payload = currentSegment?.payload {
                    Text(payload)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                } else {
                    Text("No payload available.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }

            DisclosureGroup("Full Encoded Package") {
                Text(state.encodedPayload)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            DisclosureGroup("Pretty JSON") {
                Text(state.prettyJSON)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    PresentationHubView()
        .environmentObject(WalletManager.shared)
        .environmentObject(AppLockManager())
}