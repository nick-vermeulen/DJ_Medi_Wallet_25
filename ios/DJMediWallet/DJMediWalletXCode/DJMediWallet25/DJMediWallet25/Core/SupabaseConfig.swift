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
    /// - Parameter bundle: The bundle to read configuration values from.
    /// - Returns: A configured `SupabaseConfig` instance if both URL and anon key are present and valid.
    static func load(from bundle: Bundle) -> SupabaseConfig? {
        let infoPlistURL = (bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let infoPlistAnonKey = (bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        let environment = ProcessInfo.processInfo.environment
        let environmentURL = environment["SUPABASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let environmentAnonKey = environment["SUPABASE_ANON_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

        guard let urlString = infoPlistURL ?? environmentURL,
              let anonKey = infoPlistAnonKey ?? environmentAnonKey,
              let resolvedURL = URL(string: urlString) else {
            return nil
        }

        return SupabaseConfig(url: resolvedURL, anonKey: anonKey)
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
