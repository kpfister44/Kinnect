//
//  FeedView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)

                    Text("No posts yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.igTextPrimary)

                    Text("Follow people to see their posts")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("Kinnect")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FeedView()
}
