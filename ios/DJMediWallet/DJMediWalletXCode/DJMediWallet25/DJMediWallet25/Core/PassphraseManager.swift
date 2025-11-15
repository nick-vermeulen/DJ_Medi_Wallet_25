//
//  PassphraseManager.swift
//  DJMediWallet
//
//  Generates recovery passphrases using a high-entropy deterministic dictionary.
//

import Foundation
import Security

enum PassphraseError: Error {
    case entropyUnavailable
    case invalidWordCount
    case dictionaryTooSmall
}

/// Responsible for creating pronounceable, high-entropy passphrases
struct PassphraseManager {
    static let shared = PassphraseManager()
    
    func generatePassphrase(wordCount: Int = 12) throws -> [String] {
        guard wordCount > 0 else { throw PassphraseError.invalidWordCount }
        let words = PassphraseDictionary.words
        let dictionarySize = words.count
        guard dictionarySize > 0 else { throw PassphraseError.entropyUnavailable }
        guard dictionarySize >= wordCount else { throw PassphraseError.dictionaryTooSmall }
        var selectedIndices: [Int] = []
        var uniqueIndices = Set<Int>()
        while selectedIndices.count < wordCount {
            let index = try randomIndex(max: dictionarySize)
            if uniqueIndices.insert(index).inserted {
                selectedIndices.append(index)
            }
        }
        return selectedIndices.map { words[$0] }
    }
    
    func normalize(_ words: [String]) -> String {
        words.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func randomIndex(max: Int) throws -> Int {
        precondition(max > 0, "Dictionary must contain at least one word")
        var number: UInt32 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &number)
        guard status == errSecSuccess else { throw PassphraseError.entropyUnavailable }
        return Int(number) % max
    }
}

private enum PassphraseDictionary {
    private final class PassphraseBundleMarker {}
    
    static let words: [String] = {
        let bundleCandidates: [Bundle] = [
            Bundle.main,
            Bundle(for: PassphraseBundleMarker.self)
        ]
        for bundle in bundleCandidates {
            if let url = bundle.url(forResource: "passphrase_wordlist", withExtension: "txt"),
               let contents = try? String(contentsOf: url, encoding: .utf8) {
                let candidates = contents
                    .split(whereSeparator: { $0.isWhitespace })
                    .map { String($0).lowercased() }
                    .filter { !$0.isEmpty }
                if !candidates.isEmpty {
                    return candidates
                }
            }
        }
        // Fallback list (subset of BIP39 words) if resource not available
        return [
            "apple", "balance", "capture", "define", "eager", "fabric",
            "galaxy", "harbor", "icon", "jazz", "kernel", "liberty",
            "magnet", "nature", "oasis", "paddle", "quality", "radar",
            "saddle", "talent", "umbrella", "vacuum", "whisper", "yonder",
            "zephyr"
        ]
    }()
}
