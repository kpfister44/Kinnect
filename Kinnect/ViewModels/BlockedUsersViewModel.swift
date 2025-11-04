// ABOUTME: ViewModel for blocked users list management
// ABOUTME: Handles fetching blocked users and unblock operations

import Foundation
import SwiftUI
import Combine

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [Profile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let blockService: BlockService
    private var currentUserId: UUID?

    init(blockService: BlockService = BlockService.shared) {
        self.blockService = blockService
    }

    func fetchBlockedUsers(userId: UUID) async {
        self.currentUserId = userId
        isLoading = true
        defer { isLoading = false }

        do {
            blockedUsers = try await blockService.fetchBlockedUsers(userId: userId)
        } catch {
            errorMessage = "Failed to fetch blocked users: \(error.localizedDescription)"
        }
    }

    func unblockUser(blockedUserId: UUID) async {
        guard let currentUserId = currentUserId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await blockService.unblockUser(blockerId: currentUserId, blockedId: blockedUserId)

            // Remove from local list
            blockedUsers.removeAll { $0.id == blockedUserId }
        } catch {
            errorMessage = "Failed to unblock user: \(error.localizedDescription)"
        }
    }
}
