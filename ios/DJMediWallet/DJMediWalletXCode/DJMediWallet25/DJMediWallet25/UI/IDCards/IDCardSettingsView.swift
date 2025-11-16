import SwiftUI
import CoreLocation

struct IDCardSettingsView: View {
    @ObservedObject var store: IDCardStore
    @StateObject private var locationManager = IDCardLocationManager()

    @State private var showingAddCard = false
    @State private var showingEditCard: IDCard?
    @State private var newCategoryName = ""
    @State private var showingWristbandScanner = false

    var body: some View {
        List {
            addCardSection
            categoriesSection
            manageCardsSection
            locationSection
            jerseySection
        }
        .navigationTitle("Manage ID Cards")
        .sheet(isPresented: $showingAddCard) {
            NavigationStack {
                AddCardView(store: store, wristbandMode: false, presetRegion: locationManager.detectedRegionCode)
            }
        }
        .sheet(item: $showingEditCard) { card in
            NavigationStack {
                EditCardView(store: store, card: card, presetRegion: locationManager.detectedRegionCode)
            }
        }
        .sheet(isPresented: $showingWristbandScanner) {
            NavigationStack {
                AddCardView(store: store, wristbandMode: true, presetRegion: "JE")
            }
        }
        .task { activateLocationIfNeeded() }
        .onChange(of: store.locationPromptsEnabled, initial: false) { _, _ in
            activateLocationIfNeeded()
        }
    }

    private var addCardSection: some View {
        Section {
            Button {
                showingAddCard = true
            } label: {
                Label("Add Card", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderless)
        }
    }

    private var categoriesSection: some View {
        Section("Categories") {
            ForEach(store.categories, id: \.self) { category in
                let count = store.cards(in: category).count
                HStack {
                    Text(category)
                    Spacer()
                    Text("\(count)")
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.removeCategory(category)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            HStack {
                TextField("New Category", text: $newCategoryName)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                Button("Add") {
                    store.addCategory(newCategoryName)
                    newCategoryName = ""
                }
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var manageCardsSection: some View {
        Section("Manage Cards") {
            if store.cards.isEmpty {
                Text("No cards stored yet. Add your first card to manage it here.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.categories, id: \.self) { category in
                    let cards = store.cards(in: category)
                    if !cards.isEmpty {
                        DisclosureGroup(category) {
                            ForEach(cards) { card in
                                Button {
                                    showingEditCard = card
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name)
                                            Text(card.number)
                                                .font(.footnote.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if card.isDefault {
                                            Label("Default", systemImage: "star.fill")
                                                .labelStyle(.iconOnly)
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        store.delete(card)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var locationSection: some View {
        Section("Location-based Prompts") {
            Toggle("Enable Location for Healthcare IDs", isOn: $store.locationPromptsEnabled)
                .toggleStyle(.switch)
            HStack {
                Text("Detected region")
                Spacer()
                Text(locationSummary)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var jerseySection: some View {
        Section("Jersey Hospital") {
            if locationManager.detectedRegionCode == IDCardLocationManager.Region.jersey.rawValue {
                Button {
                    showingWristbandScanner = true
                } label: {
                    Label("Scan Wristband", systemImage: "barcode.viewfinder")
                }
            } else {
                Text("Enable location or travel to Jersey to access wristband scanning.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var locationSummary: String {
        guard store.locationPromptsEnabled else { return "Disabled" }
        return locationManager.detectedRegionCode ?? "Unknown"
    }

    private func activateLocationIfNeeded() {
        guard store.locationPromptsEnabled else {
            locationManager.stopUpdating()
            return
        }
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAccess()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdating()
        default:
            break
        }
    }
}
