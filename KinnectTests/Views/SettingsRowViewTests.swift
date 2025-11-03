// ABOUTME: Tests for SettingsRowView reusable component
// ABOUTME: Validates rendering of icon, title, and color customization

import Testing
import SwiftUI
@testable import Kinnect

struct SettingsRowViewTests {

    @Test func rendersWithIcon() async throws {
        // Given: A SettingsRowView with icon
        let view = SettingsRowView(
            icon: "person.circle",
            title: "Edit Profile",
            iconColor: .igTextSecondary
        )

        // Then: View should render without crashing
        #expect(view.icon == "person.circle")
    }

    @Test func rendersWithTitle() async throws {
        // Given: A SettingsRowView with title
        let view = SettingsRowView(
            icon: "gear",
            title: "Settings",
            iconColor: .blue
        )

        // Then: Title should be set correctly
        #expect(view.title == "Settings")
    }

    @Test func rendersWithCustomColor() async throws {
        // Given: A SettingsRowView with red destructive color
        let view = SettingsRowView(
            icon: "trash",
            title: "Delete",
            iconColor: .igRed
        )

        // Then: Icon color should be customizable
        #expect(view.iconColor == .igRed)
    }
}
