//
//  RecordsListView.swift
//  DJMediWallet
//
//  View for displaying list of medical records
//

import SwiftUI
import Combine

struct RecordsListView: View {
    @EnvironmentObject var walletManager: WalletManager
    @EnvironmentObject private var lockManager: AppLockManager
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
                    _ = await lockManager.loadUserProfile()
                    await refreshRecords()
                }
                .refreshable {
                    await lockManager.loadUserProfile()
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
        .onReceive(NotificationCenter.default.publisher(for: .testDataFixturesDidChange)) { _ in
            Task {
                _ = await lockManager.loadUserProfile()
                await refreshRecords()
            }
        }
    }

    private var listContent: some View {
        List {
            if let profile = lockManager.userProfile {
                Section {
                    ProfileGreetingView(profile: profile)
                        .listRowSeparator(.hidden)
                }
            }
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

        do {
            try await walletManager.initializeWalletIfNeeded()

            let profile = lockManager.userProfile
            let fixturesActive: Bool
            if let role = profile?.role {
                fixturesActive = await TestDataManager.shared.isFixtureSetActive(for: role)
            } else {
                fixturesActive = false
            }

            var fetchedCredentials: [MedicalCredential] = []
            var alreadyLoaded = false

            if let profile,
               fixturesActive == false,
               let idString = profile.externalUserId,
               let patientId = UUID(uuidString: idString) {
                do {
                    fetchedCredentials = try await walletManager.syncPatientRecordsFromSupabase(patientId: patientId)
                    alreadyLoaded = true
                } catch let error as SupabaseService.ServiceError {
                    switch error {
                    case .misconfigured:
                        // Fall back to local cache when Supabase isn't configured.
                        fetchedCredentials = try await walletManager.getAllCredentialsAsync()
                        alreadyLoaded = true
                    case .notAuthenticated, .invalidUserIdentifier:
                        fetchedCredentials = try await walletManager.getAllCredentialsAsync()
                        alreadyLoaded = true
                        await MainActor.run {
                            errorMessage = "Sign in to Supabase to refresh your records."
                        }
                    case .requestFailed(let message):
                        fetchedCredentials = try await walletManager.getAllCredentialsAsync()
                        alreadyLoaded = true
                        await MainActor.run {
                            errorMessage = "Could not sync from Supabase: \(message)"
                        }
                    }
                }
            }

            if !alreadyLoaded {
                if fixturesActive, let role = profile?.role {
                    await TestDataManager.shared.ensureFixturesAvailableIfNeeded(for: role)
                }
                // If we didn't already populate credentials from Supabase, ensure local cache is loaded.
                fetchedCredentials = try await walletManager.getAllCredentialsAsync()
            }

            let filteredCredentials = filterCredentials(fetchedCredentials, for: profile?.role)

            await MainActor.run {
                records = filteredCredentials.map { RecordItem(from: $0) }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                records = []
                isLoading = false
                errorMessage = "Unable to load records: \(error.localizedDescription)"
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

    private func filterCredentials(_ credentials: [MedicalCredential], for role: AppLockManager.UserProfile.Role?) -> [MedicalCredential] {
        guard let role else { return credentials }
        switch role {
        case .patient:
            return credentials.filter { credential in
                let resourceType = credential.fhirResource?.resourceType
                let resourceIsTask = resourceType?.caseInsensitiveCompare("Task") == .orderedSame
                let typeIndicatesTask = credential.type.localizedCaseInsensitiveContains("task")
                return resourceIsTask == false && typeIndicatesTask == false
            }
        case .practitioner:
            return credentials
        }
    }
}

private struct ProfileGreetingView: View {
    let profile: AppLockManager.UserProfile
    
    private static let dateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hello, \(profile.firstName)")
                .font(.title2)
                .fontWeight(.semibold)
            HStack(spacing: 8) {
                Image(systemName: iconName(for: profile.role))
                    .foregroundColor(.white)
                Text(profile.role.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(profile.role == .patient ? Color.blue : Color.green)
            .foregroundColor(.white)
            .clipShape(Capsule())
            Text("Consent captured \(relativeConsentDate)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
    }
    
    private var relativeConsentDate: String {
        Self.dateFormatter.localizedString(for: profile.consentTimestamp, relativeTo: Date())
    }
    
    private func iconName(for role: AppLockManager.UserProfile.Role) -> String {
        switch role {
        case .patient:
            return "person.fill"
        case .practitioner:
            return "stethoscope"
        }
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
        } else if credential.type.contains("Task") {
            self.iconName = "stethoscope"
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

                let formatQuantity: ([String: Any]) -> String? = { quantity in
                    let numericValue: Double?
                    if let number = quantity["value"] as? NSNumber {
                        numericValue = number.doubleValue
                    } else {
                        numericValue = quantity["value"] as? Double
                    }
                    guard let numericValue else { return nil }
                    if let unit = quantity["unit"] as? String, unit.isEmpty == false {
                        return "\(numericValue) \(unit)"
                    }
                    return "\(numericValue)"
                }

                if let valueQuantity = data["valueQuantity"] as? [String: Any],
                   let formatted = formatQuantity(valueQuantity) {
                    self.description = formatted
                } else if let valueString = data["valueString"] as? String, valueString.isEmpty == false {
                    self.description = valueString
                } else if let valueBoolean = data["valueBoolean"] as? Bool {
                    self.description = valueBoolean ? "Yes" : "No"
                } else if let components = data["component"] as? [[String: Any]], !components.isEmpty {
                    let values = components.compactMap { component -> String? in
                        if let valueQty = component["valueQuantity"] as? [String: Any],
                           let formatted = formatQuantity(valueQty) {
                            return formatted
                        }
                        if let valueString = component["valueString"] as? String, valueString.isEmpty == false {
                            return valueString
                        }
                        if let valueBoolean = component["valueBoolean"] as? Bool {
                            return valueBoolean ? "Yes" : "No"
                        }
                        return nil
                    }
                    self.description = values.isEmpty ? "No value" : values.joined(separator: " / ")
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
                
            case "Task":
                self.type = "Task Request"
                if let summary = data["description"] as? String, summary.isEmpty == false {
                    self.title = summary
                } else {
                    self.title = credential.type
                }

                if let patient = (data["for"] as? [String: Any])?["display"] as? String, patient.isEmpty == false {
                    self.description = patient
                } else if let location = (data["location"] as? [String: Any])?["display"] as? String, location.isEmpty == false {
                    self.description = location
                } else {
                    self.description = credential.issuer
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
