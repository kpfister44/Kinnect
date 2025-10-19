//
//  ActivityView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct ActivityView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    Image(systemName: "bell.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.igTextSecondary)

                    Text("No activity yet")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.igTextPrimary)

                    Text("Likes, comments, and follows will appear here")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding()
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ActivityView()
}
