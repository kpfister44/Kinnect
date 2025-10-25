//
//  NewPostsBanner.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/24/25.
//

import SwiftUI

/// Banner notification that appears at the top of the feed when new posts are available
/// Instagram-style design with tap-to-refresh functionality
struct NewPostsBanner: View {
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 16))

                Text(count == 1 ? "1 new post" : "\(count) new posts")
                    .font(.system(size: 14, weight: .semibold))

                Text("•")
                    .font(.system(size: 14))

                Text("Tap to view")
                    .font(.system(size: 14))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.igBlue)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: count)
    }
}

// MARK: - Preview

#Preview("Single Post") {
    VStack {
        NewPostsBanner(count: 1) {
            print("Banner tapped!")
        }
        Spacer()
    }
    .background(Color.igBackground)
}

#Preview("Multiple Posts") {
    VStack {
        NewPostsBanner(count: 5) {
            print("Banner tapped!")
        }
        Spacer()
    }
    .background(Color.igBackground)
}
