// ABOUTME: ViewModel for settings screen business logic
// ABOUTME: Manages account info, delete account, and cache clearing operations

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var userEmail: String?
    @Published var userId: UUID?
    @Published var accountCreatedAt: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let profileService: ProfileService

    init(authService: AuthService = AuthService(), profileService: ProfileService = ProfileService.shared) {
        self.authService = authService
        self.profileService = profileService
    }

    func fetchAccountInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get current user session
            guard let session = await authService.currentSession() else {
                errorMessage = "No active session"
                return
            }

            userEmail = session.user.email
            userId = session.user.id

            // Fetch profile for created_at date
            if let userId = userId {
                let profile = try await profileService.fetchProfile(userId: userId)
                accountCreatedAt = profile.createdAt
            }
        } catch {
            errorMessage = "Failed to fetch account info: \(error.localizedDescription)"
        }
    }
}
