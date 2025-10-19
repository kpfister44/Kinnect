//
//  AuthViewModel.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/19/25.
//

import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var authState: AuthState = .unauthenticated
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Private Properties

    private let authService: AuthService
    private var authStateTask: Task<Void, Never>?

    // MARK: - Initialization

    init(authService: AuthService = AuthService()) {
        self.authService = authService
        observeAuthStateChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State

    enum AuthState {
        case unauthenticated
        case needsProfile
        case authenticated(userId: UUID)
    }

    // MARK: - Session Management

    /// Check current authentication status on app launch
    func checkAuthStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            guard await authService.isAuthenticated() else {
                authState = .unauthenticated
                isLoading = false
                return
            }

            // Check if user has completed profile setup
            let hasProfile = try await authService.hasCompletedProfile()

            if hasProfile {
                if let userId = await authService.currentUserId() {
                    authState = .authenticated(userId: userId)
                } else {
                    authState = .unauthenticated
                }
            } else {
                authState = .needsProfile
            }
        } catch {
            errorMessage = "Failed to check authentication status"
            authState = .unauthenticated
        }

        isLoading = false
    }

    // MARK: - Sign In with Apple

    /// Configure Apple Sign In request
    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handle Apple Sign In completion
    func handleAppleSignInCompletion(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        do {
            let authorization = try result.get()

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                throw AuthError.invalidAppleCredential
            }

            // Sign in with Supabase
            _ = try await authService.signInWithApple(credential: credential)

            // Check if profile exists
            let hasProfile = try await authService.hasCompletedProfile()

            if hasProfile {
                if let userId = await authService.currentUserId() {
                    authState = .authenticated(userId: userId)
                } else {
                    throw AuthError.profileNotFound
                }
            } else {
                // Need to create profile
                authState = .needsProfile
            }
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            authState = .unauthenticated
        } catch {
            errorMessage = "Sign in failed. Please try again."
            authState = .unauthenticated
        }

        isLoading = false
    }

    // MARK: - Profile Creation

    /// Create user profile after successful authentication
    func createProfile(username: String, fullName: String) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let userId = await authService.currentUserId() else {
                throw AuthError.profileNotFound
            }

            // Validate username
            guard isValidUsername(username) else {
                throw NSError(domain: "", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Username must be 3-20 characters (letters, numbers, underscore, or period)"
                ])
            }

            // Create profile
            try await authService.createProfile(
                userId: userId,
                username: username.lowercased(),
                fullName: fullName.isEmpty ? nil : fullName
            )

            // Update state to authenticated
            authState = .authenticated(userId: userId)
        } catch {
            // Check if username is already taken (Supabase unique constraint error)
            if error.localizedDescription.contains("duplicate") ||
               error.localizedDescription.contains("unique") {
                errorMessage = "Username is already taken. Please choose another."
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Sign Out

    /// Sign out current user
    func signOut() async {
        do {
            try await authService.signOut()
            authState = .unauthenticated
            errorMessage = nil
        } catch {
            errorMessage = "Failed to sign out. Please try again."
        }
    }

    // MARK: - Auth State Observation

    private func observeAuthStateChanges() {
        authStateTask = authService.observeAuthStateChanges { [weak self] event, session in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch event {
                case .signedIn:
                    // User signed in - check if profile exists
                    if let session = session {
                        do {
                            let hasProfile = try await self.authService.hasCompletedProfile()
                            if hasProfile {
                                self.authState = .authenticated(userId: session.user.id)
                            } else {
                                self.authState = .needsProfile
                            }
                        } catch {
                            self.authState = .unauthenticated
                        }
                    }

                case .signedOut:
                    self.authState = .unauthenticated

                case .tokenRefreshed:
                    // Session refreshed, maintain current state
                    break

                default:
                    break
                }
            }
        }
    }

    // MARK: - Validation

    private func isValidUsername(_ username: String) -> Bool {
        let usernameRegex = "^[a-zA-Z0-9_.]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
}
