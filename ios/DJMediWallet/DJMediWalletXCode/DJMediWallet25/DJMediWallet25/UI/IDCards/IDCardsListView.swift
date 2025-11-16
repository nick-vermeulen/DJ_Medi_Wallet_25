import SwiftUI

struct IDCardsListView: View {
    @ObservedObject var store: IDCardStore
    @State private var searchText: String = ""
    @State private var selectedCard: IDCard?

    var body: some View {
        List {
            if filteredCards.isEmpty {
                ContentUnavailableView(
                    "No ID Cards",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Add your first card in Settings to see it here.")
                )
            } else {
                ForEach(groupedCards.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }), id: \.self) { category in
                    if let cards = groupedCards[category] {
                        Section(category) {
                            ForEach(cards) { card in
                                Button {
                                    selectedCard = card
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(card.name)
                                                .font(.headline)
                                            Text(card.number)
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if card.isDefault {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                        Image(systemName: "barcode")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(card.isDefault ? Color.accentColor.opacity(0.1) : nil)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("ID Cards")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .sheet(item: $selectedCard) { card in
            NavigationStack {
                BarcodeDisplayView(card: card)
            }
        }
    }

    private var filteredCards: [IDCard] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return store.cards }
        return store.cards.filter { card in
            card.name.localizedCaseInsensitiveContains(trimmed) ||
            card.number.localizedCaseInsensitiveContains(trimmed) ||
            card.category.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var groupedCards: [String: [IDCard]] {
        Dictionary(grouping: filteredCards) { card in
            card.category
        }
    }
}
