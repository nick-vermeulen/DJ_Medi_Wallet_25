//
//  RecordsListView.swift
//  DJMediWallet
//
//  View for displaying list of medical records
//

import SwiftUI

struct RecordsListView: View {
    @EnvironmentObject var walletManager: WalletManager
    @State private var records: [RecordItem] = []
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var errorMessage: String?
    @State private var isPresentingAddRecord = false

    var body: some View {
        NavigationStack {
            listContent
                .navigationTitle("DJ Medi Wallet")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if !records.isEmpty {
                            EditButton()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresentingAddRecord = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .task {
                    guard !hasLoadedOnce else { return }
                    hasLoadedOnce = true
                    await refreshRecords()
                }
                .refreshable {
                    await refreshRecords()
                }
                .sheet(isPresented: $isPresentingAddRecord) {
                    AddRecordView {
                        Task { await refreshRecords() }
                    }
                    .environmentObject(walletManager)
                }
                .alert("Error", isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }

    private var listContent: some View {
        List {
            if isLoading && records.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading records…")
                        Spacer()
                    }
                }
            } else if records.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.secondary)
                        Text("No Medical Records")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Add a record to get started.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                }
                .listRowSeparator(.hidden)
            } else {
                Section {
                    ForEach(records) { record in
                        NavigationLink(destination: RecordDetailView(record: record)) {
                            RecordRow(record: record)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteRecord(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteRecords)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func refreshRecords() async {
        await MainActor.run {
            if records.isEmpty {
                isLoading = true
            }
        }

        if !walletManager.isWalletInitialized() {
            await withCheckedContinuation { continuation in
                walletManager.initializeWallet { _ in
                    continuation.resume()
                }
            }
        }

        await withCheckedContinuation { continuation in
            walletManager.getAllCredentials { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let credentials):
                        records = credentials.map { RecordItem(from: $0) }
                    case .failure(let error):
                        records = []
                        errorMessage = "Unable to load records: \(error.localizedDescription)"
                    }
                    isLoading = false
                    continuation.resume()
                }
            }
        }
    }

    private func deleteRecords(at offsets: IndexSet) {
        let items = offsets.map { (index: $0, record: records[$0]) }
        records.remove(atOffsets: offsets)

        for item in items {
            walletManager.deleteCredential(id: item.record.id) { result in
                if case .failure(let error) = result {
                    DispatchQueue.main.async {
                        records.insert(item.record, at: min(item.index, records.count))
                        errorMessage = "Could not delete record: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func deleteRecord(_ record: RecordItem) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        deleteRecords(at: IndexSet(integer: index))
    }
}

struct RecordRow: View {
    let record: RecordItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.iconName)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.type)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(record.title)
                    .font(.headline)
                
                Text(record.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(record.date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
        /*    Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption) -   NJV Removed as the Navigation Link > is included by default when you use Navigation Link */
        }
        .padding(.vertical, 4)
    }
}

struct RecordItem: Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let date: String
    let iconName: String
    let credential: MedicalCredential
    
    init(from credential: MedicalCredential) {
        self.id = credential.id
        self.credential = credential
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        self.date = dateFormatter.string(from: credential.issuanceDate)
        
        // Determine icon based on type
        if credential.type.contains("Observation") {
            self.iconName = "heart.text.square.fill"
        } else if credential.type.contains("Condition") {
            self.iconName = "cross.case.fill"
        } else if credential.type.contains("Medication") {
            self.iconName = "pills.fill"
        } else {
            self.iconName = "doc.fill"
        }
        
        // Parse FHIR resource for title and description
        if let fhirResource = credential.fhirResource,
           let data = fhirResource.data {
            
            switch fhirResource.resourceType {
            case "Observation":
                if let code = data["code"] as? [String: Any],
                   let text = code["text"] as? String {
                    self.type = "Vital Signs / Observation"
                    self.title = text
                } else {
                    self.type = "Observation"
                    self.title = "Observation"
                }
                
                // Extract value
                if let valueQuantity = data["valueQuantity"] as? [String: Any],
                   let value = valueQuantity["value"] as? Double,
                   let unit = valueQuantity["unit"] as? String {
                    self.description = "\(value) \(unit)"
                } else if let components = data["component"] as? [[String: Any]], !components.isEmpty {
                    let values = components.compactMap { component -> String? in
                        guard let valueQty = component["valueQuantity"] as? [String: Any],
                              let value = valueQty["value"] as? Double,
                              let unit = valueQty["unit"] as? String else {
                            return nil
                        }
                        return "\(value) \(unit)"
                    }
                    self.description = values.joined(separator: " / ")
                } else {
                    self.description = "No value"
                }
                
            case "Condition":
                if let code = data["code"] as? [String: Any],
                   let text = code["text"] as? String {
                    self.type = "Diagnosis / Condition"
                    self.title = text
                } else {
                    self.type = "Condition"
                    self.title = "Condition"
                }
                
                if let severity = data["severity"] as? [String: Any],
                   let coding = severity["coding"] as? [[String: Any]],
                   let display = coding.first?["display"] as? String {
                    self.description = display
                } else {
                    self.description = "Unknown severity"
                }
                
            case "MedicationStatement":
                if let medication = data["medicationCodeableConcept"] as? [String: Any],
                   let text = medication["text"] as? String {
                    self.type = "Medication"
                    self.title = text
                } else {
                    self.type = "Medication"
                    self.title = "Medication"
                }
                
                if let dosage = data["dosage"] as? [[String: Any]],
                   let text = dosage.first?["text"] as? String {
                    self.description = text
                } else {
                    self.description = "Unknown dosage"
                }
                
            default:
                self.type = credential.type
                self.title = credential.type
                self.description = credential.issuer
            }
        } else {
            self.type = credential.type
            self.title = credential.type
            self.description = credential.issuer
        }
    }
}

#Preview {
    RecordsListView()
        .environmentObject(WalletManager.shared)
}
