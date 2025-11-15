//
//  SupabaseConfig.swift
//  DJMediWallet25
//
//  Provides configuration values required to connect to the Supabase backend.
//

import Foundation

/// Lightweight container for Supabase connection configuration.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    /// Attempts to load Supabase configuration values from the provided bundle.
    /// - Parameter bundle: The bundle to read configuration values from. Defaults to `.main`.
    /// - Returns: A configured `SupabaseConfig` instance if both URL and anon key are present and valid.
    static func load(from bundle: Bundle) -> SupabaseConfig? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "postgresql://postgres.mpaxzasbhhfigidorgle:Hackathon2025@aws-1-eu-west-1.pooler.supabase.com:5432/postgres") as? String,
              let anonKey = bundle.object(forInfoDictionaryKey: "JEbwLuq30jtct/3yta2yKN4n9bAxOAC3vzQ8PKLI/feNN93syWLw8u/Nrg7XB83dQylNIZr4kpIATXK0vIMnYg==") as? String,
              let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              let trimmedKey = anonKey.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
              let resolvedURL = URL(string: trimmedURL) else {
            return nil
        }
        return SupabaseConfig(url: resolvedURL, anonKey: trimmedKey)
    }

    /// Loads configuration values from the application bundle without relying on main-actor isolated APIs.
    static func loadDefault() -> SupabaseConfig? {
        load(from: Bundle(for: BundleMarker.self))
    }

    private final class BundleMarker: NSObject {}
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
