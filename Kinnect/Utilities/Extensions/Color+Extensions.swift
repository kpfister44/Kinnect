//
//  Color+Extensions.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import SwiftUI

extension Color {
    // MARK: - Instagram-style Colors

    // Primary Colors
    static let igBackground = Color.white
    static let igBlack = Color.black

    // Text Colors
    static let igTextPrimary = Color.black
    static let igTextSecondary = Color(hex: "8E8E8E")
    static let igTextTertiary = Color(hex: "C7C7C7")

    // UI Colors
    static let igBorderGray = Color(hex: "DBDBDB")
    static let igSeparator = Color(hex: "EFEFEF")
    static let igBackgroundGray = Color(hex: "FAFAFA")

    // Accent Colors
    static let igBlue = Color(hex: "3897F0")
    static let igLightBlue = Color(hex: "E0F1FF")

    // Action Colors
    static let igRed = Color(hex: "ED4956") // For likes/errors
    static let igGreen = Color(hex: "00C853") // For success states

    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
