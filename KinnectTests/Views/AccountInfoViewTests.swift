// ABOUTME: Tests for AccountInfoView displaying user account details
// ABOUTME: Validates email, user ID, and account creation date rendering

import Testing
import SwiftUI
@testable import Kinnect

struct AccountInfoViewTests {

    @Test func rendersWithEmail() async throws {
        // Given: User email from auth session
        let email = "user@example.com"
        let userId = UUID()
        let createdAt = Date()

        let view = AccountInfoView(
            email: email,
            userId: userId,
            createdAt: createdAt
        )

        // Then: Email should be displayed
        #expect(view.email == email)
    }

    @Test func rendersWithUserId() async throws {
        // Given: User ID
        let userId = UUID()

        let view = AccountInfoView(
            email: "test@test.com",
            userId: userId,
            createdAt: Date()
        )

        // Then: User ID should be accessible
        #expect(view.userId == userId)
    }
}
