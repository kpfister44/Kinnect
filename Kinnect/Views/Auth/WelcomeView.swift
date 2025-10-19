//
//  WelcomeView.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel

    var body: some View {
        ZStack {
            Color.igBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Logo Placeholder
                VStack(spacing: 16) {
                    Image(systemName: "person.2.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .foregroundColor(.igBlack)

                    Text("Kinnect")
                        .font(.system(size: 42, weight: .bold, design: .default))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.bottom, 16)

                // Tagline
                Text("Connect with your closest circle")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Sign in with Apple Button
                SignInWithAppleButton(
                    onRequest: { request in
                        viewModel.configureAppleSignInRequest(request)
                    },
                    onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignInCompletion(result)
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(8)
                .padding(.horizontal, 32)
                .padding(.bottom, 20)

                // Error Message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.igRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }

                // Privacy Notice
                Text("By continuing, you agree to our Terms and Privacy Policy")
                    .font(.system(size: 12))
                    .foregroundColor(.igTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthViewModel())
}
