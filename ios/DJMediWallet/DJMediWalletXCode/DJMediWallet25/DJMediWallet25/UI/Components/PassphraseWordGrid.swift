//
//  PassphraseWordGrid.swift
//  DJMediWallet
//
//  Reusable grid for displaying recovery passphrase words.
//

import SwiftUI

struct PassphraseWordGrid: View {
    let words: [String]
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(words.indices, id: \.self) { index in
                HStack {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(words[index])
                        .font(.headline)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(10)
            }
        }
    }
}
