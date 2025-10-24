//
//  FollowingListView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import SwiftUI

/// View displaying list of users that a user is following
struct FollowingListView: View {
    let userId: UUID
    @State private var following: [Profile] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private let followService = FollowService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else if following.isEmpty {
                    emptyStateView
                } else {
                    followingList
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.igTextPrimary)
                    }
                }
            }
            .task {
                await loadFollowing()
            }
        }
    }

    // MARK: - Following List

    private var followingList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(following) { profile in
                    NavigationLink {
                        ProfileView(userId: profile.id)
                    } label: {
                        UserRowView(
                            profile: profile,
                            showFollowButton: false, // Navigate to profile to see follow button
                            isFollowing: false,
                            onFollowToggle: {}
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    if profile.id != following.last?.id {
                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.igTextSecondary)

            Text("Not following anyone yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Text("When this account follows people, they'll appear here")
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.red)

            Text("Something went wrong")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await loadFollowing()
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadFollowing() async {
        isLoading = true
        errorMessage = nil

        do {
            let fetchedFollowing = try await followService.getFollowing(userId: userId)
            self.following = fetchedFollowing
        } catch {
            print("❌ Failed to load following: \(error)")
            errorMessage = "Failed to load following. Please try again."
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    FollowingListView(userId: UUID())
}
