import SwiftUI
import Vision
import VisionKit
import CoreLocation

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: IDCardStore
    let wristbandMode: Bool
    let presetRegion: String?

    @StateObject private var locationManager = IDCardLocationManager()

    @State private var mode: Mode = .scanner
    @State private var cardName: String = ""
    @State private var cardNumber: String = ""
    @State private var selectedCategory: String = IDCardStore.defaultCategories.first ?? "Healthcare"
    @State private var regionCode: String?
    @State private var isDefault = false
    @State private var scannedTexts: [String] = []
    @State private var availabilityMessage: String?

    enum Mode {
        case scanner
        case manual
    }

    var body: some View {
        content
            .navigationTitle(wristbandMode ? "Scan Wristband" : "Add ID Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { configureDefaults() }
            .onAppear { activateLocationIfNeeded() }
            .onChange(of: store.locationPromptsEnabled, initial: false) { _, _ in
                activateLocationIfNeeded()
            }
            .onChange(of: locationManager.detectedRegionCode, initial: false) { _, newValue in
                if regionCode == nil { regionCode = newValue }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .scanner:
            scannerContainer
        case .manual:
            manualForm
        }
    }

    private var scannerContainer: some View {
        VStack(spacing: 16) {
            if DataScannerViewController.isSupported == false || DataScannerViewController.isAvailable == false {
                unavailableView
            } else {
                if #available(iOS 17, *) {
                    ZStack(alignment: .top) {
                        IDCardScannerView(
                            recognizedDataTypes: Set([
                                .text(),
                                .barcode(symbologies: [.code128, .code39, .code93, .qr])
                            ]),
                            isScanning: true,
                            scannedBarcodeHandler: handleScannedBarcode,
                            scannedTextHandler: handleScannedText
                        )
                        .ignoresSafeArea()
                        instructionsOverlay
                    }
                } else {
                    unavailableView
                }
            }
            Button("Enter Manually") {
                mode = .manual
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom)
        }
    }

    private var instructionsOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(instructionTitle)
                .font(.headline)
                .foregroundStyle(.white)
            Text(instructionDetail)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.55))
    }

    private var unavailableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.octagon")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text("Scanner Unavailable")
                .font(.headline)
            Text(availabilityMessage ?? "DataScannerViewController is not supported or available on this device.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Enter Manually") {
                mode = .manual
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }

    private var manualForm: some View {
        Form {
            Section("Card Details") {
                TextField("Name", text: $cardName)
                    .disabled(wristbandMode)
                TextField("Number", text: $cardNumber)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(store.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .disabled(wristbandMode)
                Picker("Region", selection: Binding(
                    get: { regionCode ?? "" },
                    set: { value in regionCode = value.isEmpty ? nil : value }
                )) {
                    Text("Auto").tag("")
                    Text("United Kingdom (GB)").tag("GB")
                    Text("Jersey (JE)").tag("JE")
                    Text("Guernsey (GG)").tag("GG")
                }
                Toggle("Set as default for category", isOn: $isDefault)
                    .disabled(selectedCategory.caseInsensitiveCompare("Healthcare") != .orderedSame)
            }

            if scannedTexts.isEmpty == false {
                Section("Suggestions from scanner") {
                    ForEach(scannedTexts, id: \.self) { value in
                        Button(value) {
                            cardNumber = value
                        }
                    }
                }
            }

            Section {
                Button("Resume Scanning") { mode = .scanner }
            }
        }
    }

    private var instructionTitle: String {
        if wristbandMode { return "Scan hospital wristband" }
        switch regionCode ?? locationManager.detectedRegionCode ?? presetRegion ?? "" {
        case IDCardLocationManager.Region.unitedKingdom.rawValue:
            return "Scan NHS ID"
        case IDCardLocationManager.Region.jersey.rawValue:
            return "Scan Jersey Health ID"
        case IDCardLocationManager.Region.guernsey.rawValue:
            return "Scan Guernsey ID"
        default:
            return "Scan ID Card"
        }
    }

    private var instructionDetail: String {
        if wristbandMode {
            return "Position the wristband barcode within the frame to capture the patient ID."
        }
        switch regionCode ?? locationManager.detectedRegionCode ?? presetRegion ?? "" {
        case IDCardLocationManager.Region.unitedKingdom.rawValue:
            return "Scan your NHS Number barcode (10-digit format)."
        case IDCardLocationManager.Region.jersey.rawValue:
            return "Capture health card or demographic details for Jersey Health and Care Index."
        case IDCardLocationManager.Region.guernsey.rawValue:
            return "Scan your Social Security or local healthcare ID."
        default:
            return "Align the barcode or text within the guide."
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { saveCard() }
                .disabled(canSave == false)
        }
    }

    private var canSave: Bool {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false, trimmedNumber.isEmpty == false else { return false }
        if (regionCode ?? locationManager.detectedRegionCode ?? presetRegion) == IDCardLocationManager.Region.unitedKingdom.rawValue {
            return isValidNHSNumber(trimmedNumber)
        }
        return true
    }

    private func configureDefaults() {
        selectedCategory = store.categories.first ?? IDCardStore.defaultCategories.first ?? "Healthcare"
        if wristbandMode {
            selectedCategory = "Healthcare"
            cardName = "Jersey Patient ID"
            isDefault = true
            regionCode = presetRegion ?? "JE"
        }
        if regionCode == nil {
            regionCode = presetRegion
        }
        availabilityMessage = DataScannerViewController.isSupported ? nil : "Requires a device with A12 Bionic chip or later."
        if DataScannerViewController.isAvailable == false {
            availabilityMessage = "Camera access is required to scan ID cards. Enable it in Settings."
        }
    }

    private func activateLocationIfNeeded() {
        guard store.locationPromptsEnabled else { return }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAccess()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdating()
        default:
            break
        }
    }

    private func handleScannedBarcode(_ value: String) {
        cardNumber = value
        if wristbandMode {
            cardName = "Jersey Patient ID"
            isDefault = true
            selectedCategory = "Healthcare"
        }
    }

    private func handleScannedText(_ value: String) {
        if scannedTexts.contains(value) == false {
            scannedTexts.append(value)
            if scannedTexts.count > 10 {
                scannedTexts = Array(scannedTexts.suffix(10))
            }
        }
    }

    private func saveCard() {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let card = IDCard(
            name: trimmedName,
            number: trimmedNumber,
            category: selectedCategory,
            region: effectiveRegion,
            isDefault: isDefault && selectedCategory.caseInsensitiveCompare("Healthcare") == .orderedSame
        )
        store.upsert(card)
        dismiss()
    }

    private var effectiveRegion: String? {
        regionCode ?? locationManager.detectedRegionCode ?? presetRegion
    }

    private func isValidNHSNumber(_ number: String) -> Bool {
        let digitsOnly = number.filter { $0.isNumber }
        guard digitsOnly.count == 10 else { return false }
        var sum = 0
        for (index, character) in digitsOnly.enumerated() where index < 9 {
            guard let digit = character.wholeNumberValue else { return false }
            sum += digit * (10 - index)
        }
        let check = (11 - (sum % 11)) % 11
        guard check != 10, let checkDigit = digitsOnly.last?.wholeNumberValue else { return false }
        return check == checkDigit
    }
}
