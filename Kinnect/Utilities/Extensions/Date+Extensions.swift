//
//  Date+Extensions.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation

extension Date {
    /// Returns a human-readable time ago string (e.g., "2h ago", "5d ago")
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Returns ISO8601 string representation
    func toISO8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
