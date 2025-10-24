//
//  SearchViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var searchText: String = ""
    @Published var searchResults: [Profile] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let followService: FollowService
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(followService: FollowService = FollowService.shared) {
        self.followService = followService

        // Set up search debouncing
        setupSearchDebouncing()
    }

    // MARK: - Search Debouncing

    /// Set up automatic search with 300ms debounce
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search Operations

    /// Perform search with current query
    private func performSearch(query: String) async {
        // Cancel any in-flight search
        searchTask?.cancel()

        // Clear results if query is empty
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isSearching = false
            errorMessage = nil
            return
        }

        searchTask = Task {
            isSearching = true
            errorMessage = nil

            do {
                let results = try await followService.searchUsers(query: query)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                self.searchResults = results
                print("✅ Search completed: \(results.count) results")
            } catch {
                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                self.errorMessage = "Search failed. Please try again."
                self.searchResults = []
                print("❌ Search error: \(error)")
            }

            isSearching = false
        }

        await searchTask?.value
    }

    // MARK: - Clear Search

    /// Clear search results and query
    func clearSearch() {
        searchText = ""
        searchResults = []
        errorMessage = nil
        searchTask?.cancel()
    }
}
