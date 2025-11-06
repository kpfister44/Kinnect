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
    @Published var showCacheSuccessAlert = false
    @Published var exportedDataURL: URL?

    private let authService: AuthService
    private let profileService: ProfileService
    private let settingsService: SettingsService
    private let notificationCenter: NotificationCenter
    private let invokeFunction: (String, FunctionInvokeOptions) async throws -> Data
    private let accessTokenProvider: () async -> String?

    init(
        authService: AuthService = AuthService(),
        profileService: ProfileService = ProfileService.shared,
        settingsService: SettingsService = SettingsService.shared,
        notificationCenter: NotificationCenter = .default,
        invokeFunction: @escaping (String, FunctionInvokeOptions) async throws -> Data = { functionName, options in
            try await SupabaseService.shared.client.functions.invoke(
                functionName,
                options: options
            ) { data, _ in data }
        },
        accessTokenProvider: (() async -> String?)? = nil
    ) {
        self.authService = authService
        self.profileService = profileService
        self.settingsService = settingsService
        self.notificationCenter = notificationCenter
        self.invokeFunction = invokeFunction
        self.accessTokenProvider = accessTokenProvider ?? { [authService] in
            await authService.currentSession()?.accessToken
        }
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

    func deleteAccount() async {
        guard let userId = userId else {
            errorMessage = "User ID not found"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await settingsService.deleteAccount(userId: userId)
            // Sign out will happen automatically when auth session becomes invalid
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
        }
    }

    func clearCache() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        URLCache.shared.removeAllCachedResponses()
        notificationCenter.post(name: .clearAllCaches, object: nil)

        showCacheSuccessAlert = true
    }

    func exportUserData() async {
        exportedDataURL = nil
        errorMessage = nil
        guard let userId = userId else {
            errorMessage = "User ID not found"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let accessToken = await accessTokenProvider() else {
                errorMessage = "No active session"
                return
            }

            let options = FunctionInvokeOptions(
                headers: [
                    "Authorization": "Bearer \(accessToken)"
                ],
                body: ["userId": userId.uuidString]
            )

            let data = try await invokeFunction("export-user-data", options)

            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("kinnect-data-\(userId.uuidString).json")
            try data.write(to: fileURL)

            await MainActor.run {
                exportedDataURL = fileURL
            }
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
        }
    }
}
