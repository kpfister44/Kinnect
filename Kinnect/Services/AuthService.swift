//
//  AuthService.swift
//  Kinnect
//
//  Created by Kyle Pfister on 10/17/25.
//

import Foundation
import Supabase
import AuthenticationServices

/// Service for handling authentication operations
final class AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseService.shared.client) {
        self.client = client
    }

    // MARK: - Session Management

    /// Returns the current authenticated user's ID
    func currentUserId() async -> UUID? {
        return try? await client.auth.session.user.id
    }

    /// Returns the current session
    func currentSession() async -> Session? {
        return try? await client.auth.session
    }

    /// Check if user is authenticated
    func isAuthenticated() async -> Bool {
        return await currentSession() != nil
    }

    // MARK: - Sign In with Apple

    /// Sign in with Apple using authorization credential
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> Session {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidAppleCredential
        }

        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: tokenString
            )
        )

        return session
    }

    // MARK: - Profile Management

    /// Check if user has completed profile setup (username exists)
    func hasCompletedProfile() async throws -> Bool {
        guard let userId = await currentUserId() else {
            return false
        }

        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()

        return response.value.username.isEmpty == false
    }

    /// Create initial profile for new user
    func createProfile(userId: UUID, username: String, fullName: String?) async throws {
        struct ProfileInsert: Encodable {
            let user_id: String
            let username: String
            let full_name: String?
        }

        let profile = ProfileInsert(
            user_id: userId.uuidString,
            username: username,
            full_name: fullName
        )

        try await client
            .from("profiles")
            .insert(profile)
            .execute()
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() async throws {
        try await client.auth.signOut()
    }

    // MARK: - Session Restoration

    /// Listen to auth state changes
    func observeAuthStateChanges(handler: @escaping (AuthChangeEvent, Session?) -> Void) -> Task<Void, Never> {
        return Task {
            for await (event, session) in client.auth.authStateChanges {
                handler(event, session)
            }
        }
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case invalidAppleCredential
    case profileNotFound
    case usernameAlreadyTaken

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Failed to authenticate with Apple. Please try again."
        case .profileNotFound:
            return "Profile not found. Please complete your profile setup."
        case .usernameAlreadyTaken:
            return "This username is already taken. Please choose another."
        }
    }
}
