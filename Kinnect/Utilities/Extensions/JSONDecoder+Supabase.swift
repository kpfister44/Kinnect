//
//  JSONDecoder+Supabase.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import Foundation

extension JSONDecoder {
    /// Creates a JSONDecoder configured for Supabase responses
    /// Handles ISO8601 dates with fractional seconds and timezone info
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Supabase returns dates in these formats:
            // - "2024-10-22T12:34:56.789123+00:00" (with fractional seconds)
            // - "2024-10-22T12:34:56+00:00" (without fractional seconds)
            // - "2024-10-22T12:34:56Z" (UTC with Z)

            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // If both fail, throw error
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected date string to be ISO8601-formatted with optional fractional seconds. Got: \(dateString)"
                )
            )
        }
        return decoder
    }
}
