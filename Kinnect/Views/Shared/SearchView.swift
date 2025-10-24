//
//  SearchView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                if viewModel.searchText.isEmpty {
                    // Empty state - no search query
                    emptySearchState
                } else if viewModel.isSearching {
                    // Loading state
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else if let errorMessage = viewModel.errorMessage {
                    // Error state
                    errorStateView(message: errorMessage)
                } else if viewModel.searchResults.isEmpty {
                    // No results state
                    noResultsState
                } else {
                    // Results list
                    searchResultsList
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search users")
        }
    }

    // MARK: - Empty Search State

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.igTextSecondary)

            Text("Search for friends")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.igTextPrimary)

            Text("Find and follow your friends")
                .font(.system(size: 16))
                .foregroundColor(.igTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - No Results State

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.igTextSecondary)

            Text("No results found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.igTextPrimary)

            Text("Try searching for a different username")
                .font(.system(size: 14))
                .foregroundColor(.igTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Error State

    private func errorStateView(message: String) -> some View {
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
        }
        .padding()
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { profile in
                    NavigationLink {
                        ProfileView(userId: profile.id)
                    } label: {
                        UserRowView(
                            profile: profile,
                            showFollowButton: false, // We'll show follow button in ProfileView
                            isFollowing: false,
                            onFollowToggle: {}
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    if profile.id != viewModel.searchResults.last?.id {
                        Divider()
                            .padding(.leading, 72) // Align with text, not avatar
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AuthViewModel())
}
