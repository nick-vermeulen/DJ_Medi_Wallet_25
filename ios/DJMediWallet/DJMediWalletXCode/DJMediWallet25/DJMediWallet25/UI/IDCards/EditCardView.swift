import SwiftUI

struct EditCardView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var store: IDCardStore
    var card: IDCard
    let presetRegion: String?

    @State private var cardName: String
    @State private var cardNumber: String
    @State private var selectedCategory: String
    @State private var regionCode: String?
    @State private var isDefault: Bool

    init(store: IDCardStore, card: IDCard, presetRegion: String?) {
        self.store = store
        self.card = card
        self.presetRegion = presetRegion
        _cardName = State(initialValue: card.name)
        _cardNumber = State(initialValue: card.number)
        _selectedCategory = State(initialValue: card.category)
        _regionCode = State(initialValue: card.region ?? presetRegion)
        _isDefault = State(initialValue: card.isDefault)
    }

    var body: some View {
        Form {
            Section("Card Details") {
                TextField("Name", text: $cardName)
                TextField("Number", text: $cardNumber)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.none)
                    .disableAutocorrection(true)
                Picker("Category", selection: $selectedCategory) {
                    ForEach(store.categories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
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
        }
        .navigationTitle("Edit Card")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .disabled(canSave == false)
        }
    }

    private var canSave: Bool {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty == false && trimmedNumber.isEmpty == false
    }

    private func save() {
        let trimmedName = cardName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNumber = cardNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = IDCard(
            id: card.id,
            name: trimmedName,
            number: trimmedNumber,
            category: selectedCategory,
            region: regionCode ?? presetRegion,
            isDefault: isDefault && selectedCategory.caseInsensitiveCompare("Healthcare") == .orderedSame
        )
        store.upsert(updated)
        dismiss()
    }
}
