//
//  FeedInteractionViewModel.swift
//  Kinnect
//
//  Protocol for ViewModels that provide feed interaction capabilities
//  Allows PostCellView to work with both FeedViewModel and ProfileFeedViewModel
//

import Foundation
import SwiftUI

@MainActor
protocol FeedInteractionViewModel: ObservableObject {
    var currentUserId: UUID { get }
    var errorMessage: String? { get set }
    var viewAppearanceID: UUID { get }

    func toggleLike(forPostID postID: UUID)
    func deletePost(_ post: Post) async
    func unfollowPostAuthor(_ post: Post) async
    func recordImageCancellation(for postID: UUID)
    func getAsyncImageID(for postID: UUID) -> String
}
