//
//  UploadView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct UploadView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)

                    Text("Share a moment")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.igTextPrimary)

                    Text("Take a photo or video to share")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    UploadView()
}
