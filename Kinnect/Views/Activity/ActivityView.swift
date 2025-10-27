//
//  ActivityView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/26/25.
//

import SwiftUI

struct ActivityView: View {
    // MARK: - Environment
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var activityViewModel: ActivityViewModel

    // For navigation
    @State private var navigationPath = NavigationPath()

    // Current user ID (passed in)
    let currentUserId: UUID

    // MARK: - Initialization
    init(currentUserId: UUID) {
        self.currentUserId = currentUserId
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                switch activityViewModel.state {
                case .idle, .loading:
                    loadingView
                case .loaded:
                    if activityViewModel.groupedActivities.isEmpty {
                        emptyStateView
                    } else {
                        activitiesListView
                    }
                case .error:
                    errorView
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.igBackground)
            .toolbar {
                if !activityViewModel.groupedActivities.isEmpty && activityViewModel.unreadCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all read") {
                            Task {
                                await activityViewModel.markAllAsRead()
                            }
                        }
                        .font(.system(size: 14))
                    }
                }
            }
            .task {
                await activityViewModel.loadActivities()
                await activityViewModel.setupRealtimeSubscriptions()
            }
            .onDisappear {
                Task {
                    await activityViewModel.cleanupRealtimeSubscriptions()
                }
            }
            .refreshable {
                await activityViewModel.refreshActivities()
            }
            .navigationDestination(for: UUID.self) { userId in
                ProfileView(userId: userId)
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.igBlue)

                Text("Loading activities...")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bell.slash")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(.igTextSecondary)

                Text("No Activity Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.igTextPrimary)

                Text("When someone likes or comments on your posts, you'll see it here")
                    .font(.system(size: 16))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding()
        }
    }

    // MARK: - Error View
    private var errorView: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .foregroundColor(.igRed)

                Text("Couldn't load activities")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.igTextPrimary)

                if let errorMessage = activityViewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    Task {
                        await activityViewModel.refreshActivities()
                    }
                } label: {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.igBlue)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
            .padding()
        }
    }

    // MARK: - Activities List
    private var activitiesListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(activityViewModel.groupedActivities) { groupedActivity in
                    VStack(spacing: 0) {
                        ActivityRowView(
                            groupedActivity: groupedActivity,
                            onTap: {
                                handleActivityTap(groupedActivity)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await activityViewModel.deleteActivity(groupedActivity)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }

                        Divider()
                            .background(Color.igSeparator)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Activity Handling

    private func handleActivityTap(_ groupedActivity: GroupedActivityItem) {
        // Mark all activities in group as read
        Task {
            await activityViewModel.markGroupedActivityAsRead(groupedActivity)
        }

        // Navigate based on activity type
        switch groupedActivity.activityType {
        case .like, .comment:
            // For now, navigate to the first actor's profile
            // TODO: In future, fetch Post and navigate to PostDetailView
            if let actor = groupedActivity.primaryActor {
                navigationPath.append(actor.id)
                print("📍 Navigating to profile: \(actor.username)")
            }
        case .follow:
            // Navigate to follower's profile
            if let actor = groupedActivity.primaryActor {
                navigationPath.append(actor.id)
                print("📍 Navigating to profile: \(actor.username)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ActivityView(currentUserId: UUID())
        .environmentObject(AuthViewModel())
}
