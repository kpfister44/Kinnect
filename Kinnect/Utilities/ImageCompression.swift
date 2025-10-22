//
//  ImageCompression.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/22/25.
//

import UIKit

enum ImageCompression {

    // MARK: - Configuration
    static let maxDimension: CGFloat = 1080 // Reduced from 1200 for faster uploads
    static let maxFileSizeBytes: Int = 1_000_000 // 1MB target (reduced from 2MB)
    static let initialCompressionQuality: CGFloat = 0.7 // Reduced from 0.8

    // MARK: - Public Methods

    /// Compresses and resizes an image to meet storage requirements
    /// - Parameter image: The original UIImage to compress
    /// - Returns: Compressed image data, or nil if compression fails
    static func compressImage(_ image: UIImage) -> Data? {
        // Step 1: Resize image if needed
        let resizedImage = resizeImage(image, maxDimension: maxDimension)

        // Step 2: Compress to JPEG with quality adjustment
        return compressToTarget(resizedImage, maxBytes: maxFileSizeBytes)
    }

    // MARK: - Private Methods

    /// Resizes an image to fit within max dimensions while maintaining aspect ratio
    private static func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // Check if resize is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            // Landscape or square
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }

    /// Compresses image to JPEG, adjusting quality to meet size target
    private static func compressToTarget(_ image: UIImage, maxBytes: Int) -> Data? {
        var compressionQuality: CGFloat = initialCompressionQuality
        var imageData = image.jpegData(compressionQuality: compressionQuality)

        // Iteratively reduce quality if size is too large
        while let data = imageData, data.count > maxBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }

        // Ensure final size is within limit
        guard let finalData = imageData, finalData.count <= maxBytes else {
            // If still too large, return data anyway and let upload handle the error
            return imageData
        }

        return finalData
    }

    /// Get human-readable file size
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
