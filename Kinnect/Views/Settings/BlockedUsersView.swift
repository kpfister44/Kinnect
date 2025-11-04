// ABOUTME: View displaying list of blocked users with unblock actions
// ABOUTME: Shows avatars, usernames, and unblock buttons with empty state

import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                ProgressView()
            } else if viewModel.blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 64))
                        .foregroundColor(.igTextSecondary)

                    Text("No blocked accounts")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.igTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.igBackground)
            } else {
                List {
                    ForEach(viewModel.blockedUsers) { profile in
                        HStack(spacing: 12) {
                            // Avatar
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.igBackgroundGray)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            // Username
                            Text(profile.username)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.igTextPrimary)

                            Spacer()

                            // Unblock button
                            Button {
                                Task {
                                    await viewModel.unblockUser(blockedUserId: profile.id)
                                }
                            } label: {
                                Text("Unblock")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igBlue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.igBlue, lineWidth: 1)
                                    )
                            }
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .background(Color.igBackground)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard case .authenticated(let userId) = authViewModel.authState else { return }
            await viewModel.fetchBlockedUsers(userId: userId)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}
