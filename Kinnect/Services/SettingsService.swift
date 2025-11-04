// ABOUTME: Service for settings-related backend operations
// ABOUTME: Handles account deletion via Supabase edge functions

import Foundation
import Supabase

final class SettingsService {
    static let shared = SettingsService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    /// Delete user account via edge function
    func deleteAccount(userId: UUID) async throws {
        // Get current session for JWT
        let session = try await client.auth.session

        // Call edge function - will throw if edge function returns error
        try await client.functions.invoke(
            "delete-user-account",
            options: FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ],
                body: ["userId": userId.uuidString]
            )
        )
    }
}
