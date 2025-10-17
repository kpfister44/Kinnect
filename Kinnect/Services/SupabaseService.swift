//
//  SupabaseService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation
import Supabase

/// Singleton service for managing Supabase client instance
final class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // Load configuration from Secrets.plist
        guard let url = Self.getConfigValue(for: "SupabaseURL"),
              let key = Self.getConfigValue(for: "SupabaseAnonKey"),
              let supabaseURL = URL(string: url) else {
            fatalError("Missing Supabase configuration. Please check Secrets.plist")
        }

        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key
        )
    }

    /// Reads a value from Secrets.plist
    private static func getConfigValue(for key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = config[key] as? String,
              !value.isEmpty,
              !value.hasPrefix("YOUR_") else {
            return nil
        }
        return value
    }
}
