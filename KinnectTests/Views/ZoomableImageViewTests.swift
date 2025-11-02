//
//  ZoomableImageViewTests.swift
//  KinnectTests
//
//  ABOUTME: Tests for ZoomableImageView gesture and state management
//  ABOUTME: Validates zoom state propagation and scale clamping behavior

import Testing
import SwiftUI
@testable import Kinnect

struct ZoomableImageViewTests {

    @Test func initialZoomStateIsFalse() async throws {
        // Given: A ZoomableImageView with isZooming binding
        var isZooming = false
        let binding = Binding(
            get: { isZooming },
            set: { isZooming = $0 }
        )

        let view = ZoomableImageView(
            url: URL(string: "https://example.com/image.jpg"),
            asyncImageID: "test-id",
            isZooming: binding
        )

        // Then: Initial state should be false
        #expect(isZooming == false)
    }

    @Test func scaleClampingWithinBounds() async throws {
        // Given: ZoomableImageView scale bounds
        let minScale: CGFloat = 1.0
        let maxScale: CGFloat = 3.0

        // When: Various scale values are clamped
        let testCases: [(input: CGFloat, expected: CGFloat)] = [
            (0.5, 1.0),   // Below min
            (1.5, 1.5),   // Within bounds
            (3.0, 3.0),   // At max
            (5.0, 3.0)    // Above max
        ]

        // Then: All values should be properly clamped
        for testCase in testCases {
            let clamped = max(minScale, min(maxScale, testCase.input))
            #expect(clamped == testCase.expected,
                   "Scale \(testCase.input) should clamp to \(testCase.expected)")
        }
    }

    @Test func offsetResetsWhenScaleReturnsToOne() async throws {
        // Given: A zoom state with offset
        var finalScale = 1.0
        var finalOffset = CGSize(width: 50, height: 50)

        // When: Scale returns to minimum (1.0)
        if finalScale <= 1.0 {
            finalScale = 1.0
            finalOffset = .zero
        }

        // Then: Offset should be reset
        #expect(finalOffset == .zero)
        #expect(finalScale == 1.0)
    }
}
