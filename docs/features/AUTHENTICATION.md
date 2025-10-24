# Authentication System

**Phase 2: Authentication Flow**
**Completed:** October 19-21, 2025

---

## Overview

Complete Sign in with Apple integration with username creation flow and session persistence. Provides seamless authentication experience matching Instagram's onboarding.

---

## Architecture

### AuthViewModel

Centralized authentication state management using SwiftUI's `@Published` properties.

**Auth States:**
```swift
enum AuthState {
    case unauthenticated
    case needsProfile
    case authenticated(userId: UUID)
}
```

**Key Responsibilities:**
- Sign in with Apple flow coordination
- Profile creation with username validation
- Session persistence across app launches
- Real-time auth state observation via Supabase
- Sign out functionality

---

## Components

### Views

**WelcomeView**
- Clean welcome screen with app branding and tagline
- Native `ASAuthorizationAppleIDButton` for Sign in with Apple
- Error message display
- Privacy notice

**UsernameCreationView**
- Profile creation form for first-time users
- Username field (3-20 characters, alphanumeric + underscore/period)
- Full name field
- Real-time validation feedback
- Instagram-style input fields with focus states

**TabBarView**
- Instagram-style bottom navigation with 5 tabs:
  - Feed (house icon)
  - Search (magnifying glass)
  - Upload (plus square - center)
  - Activity (heart)
  - Profile (person)

---

## Design System

### Color Extensions

Created complete Instagram-style color palette in `Color+Extensions.swift`:

```swift
// Instagram Brand Colors
static let igBlack = Color(hex: "#000000")
static let igBlue = Color(hex: "#0095F6")
static let igRed = Color(hex: "#ED4956")

// UI Colors
static let igTextSecondary = Color(hex: "#8E8E8E")
static let igBorder = Color(hex: "#DBDBDB")
static let igBackground = Color(hex: "#FAFAFA")

// System Colors
static let igLinkBlue = Color(hex: "#00376B")
```

Custom hex color initializer for easy color management:
```swift
Color(hex: "#FFFFFF")
```

---

## User Flow

1. **First Launch** → WelcomeView (Sign in with Apple button)
2. **After Sign In (New User)** → UsernameCreationView (create profile)
3. **After Profile Creation** → TabBarView (main app with 5 tabs)
4. **Subsequent Launches** → Auto-login to TabBarView
5. **Logout** → Back to WelcomeView

---

## Key Features

### Sign in with Apple Integration

**Apple Developer Portal Configuration:**
- App ID: `eg.Kinnect`
- Services ID: `eg.Kinnect.auth`
- Generated JWT signing key
- Callback URL configured

**Supabase Auth Provider Setup:**
- Apple provider enabled
- Client IDs: `eg.Kinnect.auth,eg.Kinnect` (both bundle IDs)
- JWT secret key configured
- Token audience acceptance configured

### Username Validation

**Rules:**
- 3-20 characters
- Alphanumeric plus underscore and period
- Unique across all users (checked against database)
- Real-time feedback during typing

### Session Persistence

**Auto-Login Flow:**
```swift
Task {
    await checkSession()
}
```

- Checks for existing Supabase session on app launch
- Validates profile completion
- Auto-redirects to appropriate screen
- Seamless experience (no unnecessary login prompts)

### Real-Time Auth State

Uses Supabase Auth state change listener:
```swift
client.auth.onAuthStateChange { event, session in
    // Update UI based on auth events
}
```

---

## App Architecture

### KinnectApp.swift

Main app entry point with centralized routing:

```swift
@StateObject private var authViewModel = AuthViewModel()

var body: some View {
    Group {
        switch authViewModel.authState {
        case .unauthenticated:
            WelcomeView()
        case .needsProfile:
            UsernameCreationView()
        case .authenticated:
            TabBarView()
        }
    }
    .environmentObject(authViewModel)
    .task {
        await authViewModel.checkSession()
    }
}
```

**Benefits:**
- Single source of truth for auth state
- Automatic routing based on state
- AuthViewModel accessible throughout app via `@EnvironmentObject`

---

## Bug Fixes & Refinements

### Issue: hasCompletedProfile() for New Users
**Problem:** Crash when checking profile completion for users without profiles
**Solution:** Added proper nil handling in profile fetch query
**Result:** New users correctly routed to username creation

### Issue: Audience Token Rejection
**Problem:** Supabase rejecting Apple ID tokens due to audience mismatch
**Solution:** Added both bundle IDs to Supabase Apple provider configuration
**Result:** Tokens accepted, authentication works end-to-end

---

## Testing Results

✅ **Device Testing (iPhone):**
- Sign in with Apple works end-to-end
- Username creation flow successful
- Navigation to TabBarView confirmed
- Session persistence across app restarts
- Logout functionality working
- Username validation prevents invalid characters
- Real-time validation feedback working

✅ **Database Verification:**
- Profiles created in `profiles` table
- User IDs match `auth.users` foreign key
- Unique username constraint enforced

---

## Important Learnings

### Sign in with Apple Requirements
- Requires **physical device** for testing (simulator not supported)
- Must configure **both** Apple Developer Portal and Supabase
- Bundle ID must match across all configurations
- JWT secret generation required for provider setup

### Auth State Management Pattern
- Use `@Published` properties for reactive UI updates
- Single `AuthState` enum simplifies routing logic
- Environment object pattern provides global access
- Task-based session check on app launch

### Profile Creation Flow
- Separate "needs profile" state enables smooth onboarding
- Username uniqueness check requires async validation
- Real-time validation improves UX (no submit-and-fail)

---

## Files Involved

**ViewModels:**
- `/ViewModels/AuthViewModel.swift` - Central auth state management

**Views:**
- `/Views/Auth/WelcomeView.swift` - Sign in screen
- `/Views/Auth/UsernameCreationView.swift` - Profile creation
- `/Views/Shared/TabBarView.swift` - Main navigation

**App:**
- `/KinnectApp.swift` - App entry point with routing

**Extensions:**
- `/Utilities/Extensions/Color+Extensions.swift` - Instagram color palette

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md`
- Profile system: `/docs/features/PROFILE_SYSTEM.md`

---

**Status:** ✅ Complete
**Next Phase:** Profile System (see `/docs/features/PROFILE_SYSTEM.md`)
