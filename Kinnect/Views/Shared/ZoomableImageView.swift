//
//  ZoomableImageView.swift
//  Kinnect
//
//  ABOUTME: Reusable zoomable image component with pinch-to-zoom and pan gestures
//  ABOUTME: Communicates zoom state to parent views to block scrolling during zoom

import SwiftUI

struct ZoomableImageView: View {
    // MARK: - Properties
    let url: URL?
    let asyncImageID: String
    let onImageFailure: ((Error) -> Void)?
    @Binding var isZooming: Bool

    // MARK: - Gesture State
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero

    // MARK: - Constants
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 3.0

    // MARK: - Initialization
    init(
        url: URL?,
        asyncImageID: String,
        isZooming: Binding<Bool>,
        onImageFailure: ((Error) -> Void)? = nil
    ) {
        self.url = url
        self.asyncImageID = asyncImageID
        self._isZooming = isZooming
        self.onImageFailure = onImageFailure
    }

    // MARK: - Body
    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.igSeparator)
                    .overlay(ProgressView().tint(.igTextSecondary))
                    .aspectRatio(1, contentMode: .fit)

            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                    .scaleEffect(finalScale * currentScale)
                    .offset(
                        x: finalOffset.width + currentOffset.width,
                        y: finalOffset.height + currentOffset.height
                    )

            case .failure(let error):
                Rectangle()
                    .fill(Color.igSeparator)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(.igTextSecondary)
                            Text("Failed to load")
                                .font(.system(size: 12))
                                .foregroundColor(.igTextSecondary)
                        }
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .onAppear {
                        onImageFailure?(error)
                    }

            @unknown default:
                Rectangle()
                    .fill(Color.igSeparator)
                    .aspectRatio(1, contentMode: .fit)
            }
        }
        .id(asyncImageID)
        .contentShape(Rectangle())
        .simultaneousGesture(
            zoomGesture.simultaneously(with: panGesture)
        )
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = value

                if !isZooming {
                    isZooming = true
                }
            }
            .onEnded { value in
                let newScale = finalScale * currentScale
                finalScale = max(minScale, min(maxScale, newScale))
                currentScale = 1.0

                if finalScale <= minScale {
                    finalScale = minScale
                    finalOffset = .zero
                    currentOffset = .zero
                    isZooming = false
                } else {
                    isZooming = true
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard finalScale > minScale else { return }
                currentOffset = value.translation
            }
            .onEnded { value in
                guard finalScale > minScale else { return }

                finalOffset.width += value.translation.width
                finalOffset.height += value.translation.height
                currentOffset = .zero
            }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isZooming = false

    return VStack {
        Text("isZooming: \(isZooming ? "true" : "false")")
            .padding()

        ZoomableImageView(
            url: URL(string: "https://picsum.photos/600/600"),
            asyncImageID: "preview-image",
            isZooming: $isZooming
        )
        .padding()
    }
}
