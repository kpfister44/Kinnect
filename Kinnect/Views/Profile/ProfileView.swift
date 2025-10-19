//
//  ProfileView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.igBackground
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Profile Header Placeholder
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 100, height: 100)
                            .foregroundColor(.igTextSecondary)

                        Text("Your Profile")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.igTextPrimary)

                        Text("Profile details will appear here")
                            .font(.system(size: 16))
                            .foregroundColor(.igTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    // Logout Button
                    Button(action: {
                        Task {
                            await authViewModel.signOut()
                        }
                    }) {
                        Text("Log Out")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.igRed)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.igBackgroundGray)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
