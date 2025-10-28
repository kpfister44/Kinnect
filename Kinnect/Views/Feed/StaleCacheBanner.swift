//
//  StaleCacheBanner.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/27/25.
//

import SwiftUI

/// Banner displayed when feed cache is stale (>5 minutes old)
/// User can tap to refresh feed with fresh data
struct StaleCacheBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                Text("Tap to refresh")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.9))
        }
        .buttonStyle(PlainButtonStyle())
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.3), value: true)
    }
}

#Preview {
    VStack(spacing: 0) {
        StaleCacheBanner {
            print("Banner tapped")
        }

        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
