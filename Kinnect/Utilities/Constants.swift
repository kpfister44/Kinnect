//
//  Constants.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation
import SwiftUI

enum Constants {
    // MARK: - App Configuration
    enum App {
        static let name = "Kinnect"
        static let bundleId = "com.kinnect.app"
    }

    // MARK: - Layout
    enum Layout {
        static let postAspectRatio: CGFloat = 1.0 // Square posts like Instagram
        static let avatarSize: CGFloat = 32
        static let largeAvatarSize: CGFloat = 88
        static let cornerRadius: CGFloat = 8
        static let buttonHeight: CGFloat = 44
    }

    // MARK: - Spacing
    enum Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Animation
    enum Animation {
        static let standard = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
    }

    // MARK: - Feed
    enum Feed {
        static let postsPerPage = 20
        static let maxCaptionLines = 3
    }

    // MARK: - Upload
    enum Upload {
        static let maxImageSize: Int = 10_000_000 // 10MB
        static let maxVideoSize: Int = 100_000_000 // 100MB
        static let maxCaptionLength = 2200
        static let jpegCompressionQuality: CGFloat = 0.8
    }

    // MARK: - Storage Buckets
    enum Storage {
        static let avatarsBucket = "avatars"
        static let postsBucket = "posts"
    }
}
