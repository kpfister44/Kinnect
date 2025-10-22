//
//  KinnectApp.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import SwiftUI

@main
struct KinnectApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authViewModel)
                .task {
                    await authViewModel.checkAuthStatus()
                }
        }
    }
}

/// Root view that handles authentication routing
struct RootView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            switch authViewModel.authState {
            case .unauthenticated:
                WelcomeView()
                    .transition(.opacity)

            case .needsProfile:
                UsernameCreationView()
                    .transition(.opacity)

            case .authenticated(let userId):
                TabBarView(currentUserId: userId)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.authState)
    }
}

// MARK: - AuthState Equatable Conformance
extension AuthViewModel.AuthState: Equatable {
    static func == (lhs: AuthViewModel.AuthState, rhs: AuthViewModel.AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unauthenticated, .unauthenticated):
            return true
        case (.needsProfile, .needsProfile):
            return true
        case (.authenticated(let lhsId), .authenticated(let rhsId)):
            return lhsId == rhsId
        default:
            return false
        }
    }
}
