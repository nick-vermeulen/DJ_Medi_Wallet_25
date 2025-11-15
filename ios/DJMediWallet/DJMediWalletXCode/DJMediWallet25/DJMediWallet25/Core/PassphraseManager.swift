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
}

/// Responsible for creating pronounceable, high-entropy passphrases
struct PassphraseManager {
    static let shared = PassphraseManager()
    private let wordCount = 12
    private let dictionarySize = PassphraseDictionary.words.count
    
    func generatePassphrase(wordCount: Int = 12) throws -> [String] {
        guard wordCount > 0 else { throw PassphraseError.invalidWordCount }
        let words = PassphraseDictionary.words
        var result: [String] = []
        for _ in 0..<wordCount {
            let index = try randomIndex(max: dictionarySize)
            result.append(words[index])
        }
        return result
    }
    
    func normalize(_ words: [String]) -> String {
        words.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func randomIndex(max: Int) throws -> Int {
        var number: UInt32 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &number)
        guard status == errSecSuccess else { throw PassphraseError.entropyUnavailable }
        return Int(number) % max
    }
}

private enum PassphraseDictionary {
    private static let consonants = [
        "b", "c", "d", "f", "g", "h", "k", "l",
        "m", "n", "p", "r", "s", "t", "v", "z"
    ]
    private static let vowels = ["a", "e", "i", "o", "u", "y", "ae", "io"]
    
    static let words: [String] = {
        var list: [String] = []
        list.reserveCapacity(4096)
        for c1 in consonants {
            for v1 in vowels {
                for c2 in consonants {
                    for v2 in vowels {
                        let word = c1 + v1 + c2 + v2
                        list.append(word)
                    }
                }
            }
        }
        return list
    }()
}
