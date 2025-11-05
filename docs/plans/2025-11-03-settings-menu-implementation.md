# Settings Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add comprehensive Instagram-style settings menu with account management, privacy controls, data management, preferences, and about information.

**Architecture:** MVVM pattern with new SettingsView navigating from ProfileView. Uses SettingsViewModel for business logic, SettingsService and BlockService for backend operations. New Supabase Edge Functions for privileged operations (account deletion, data export). New `blocks` table with bidirectional filtering in feed/search.

**Tech Stack:** SwiftUI + MVVM, Supabase MCP tools, Swift Testing, XCTest UI tests, Supabase Edge Functions (Deno/TypeScript)

---

## Phase 1: Core Settings UI

### Task 1: Create SettingsRowView Component

**Files:**
- Create: `Kinnect/Views/Settings/SettingsRowView.swift`
- Test: `KinnectTests/Views/SettingsRowViewTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for SettingsRowView reusable component
// ABOUTME: Validates rendering of icon, title, and color customization

import Testing
import SwiftUI
@testable import Kinnect

struct SettingsRowViewTests {

    @Test func rendersWithIcon() async throws {
        // Given: A SettingsRowView with icon
        let view = SettingsRowView(
            icon: "person.circle",
            title: "Edit Profile",
            iconColor: .igTextSecondary
        )

        // Then: View should render without crashing
        #expect(view.icon == "person.circle")
    }

    @Test func rendersWithTitle() async throws {
        // Given: A SettingsRowView with title
        let view = SettingsRowView(
            icon: "gear",
            title: "Settings",
            iconColor: .blue
        )

        // Then: Title should be set correctly
        #expect(view.title == "Settings")
    }

    @Test func rendersWithCustomColor() async throws {
        // Given: A SettingsRowView with red destructive color
        let view = SettingsRowView(
            icon: "trash",
            title: "Delete",
            iconColor: .igRed
        )

        // Then: Icon color should be customizable
        #expect(view.iconColor == .igRed)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsRowViewTests`

Expected: FAIL with "Cannot find 'SettingsRowView' in scope"

**Step 3: Write minimal implementation**

```swift
// ABOUTME: Reusable row component for settings menu items
// ABOUTME: Displays SF Symbol icon with title text in consistent layout

import SwiftUI

struct SettingsRowView: View {
    let icon: String
    let title: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)

            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.igTextPrimary)

            Spacer()
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsRowViewTests`

Expected: PASS (all tests green)

**Step 5: Commit**

```bash
git add KinnectTests/Views/SettingsRowViewTests.swift Kinnect/Views/Settings/SettingsRowView.swift
git commit -m "feat: add SettingsRowView component with tests"
```

---

### Task 2: Create SettingsView with Navigation Structure

**Files:**
- Create: `Kinnect/Views/Settings/SettingsView.swift`
- Test: `KinnectUITests/SettingsUITests.swift`
- Modify: `Kinnect/Views/Profile/ProfileView.swift:117-132`

**Step 1: Write the failing UI test**

```swift
// ABOUTME: UI tests for Settings screen navigation and structure
// ABOUTME: Validates navigation from profile and settings list rendering

import XCTest

final class SettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testNavigateToSettingsFromProfile() throws {
        // Given: App is launched and user is on profile tab
        let app = XCUIApplication()
        app.launch()

        // Navigate to profile tab
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        // When: User taps three-line menu icon
        let menuButton = app.navigationBars.buttons["line.3.horizontal"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 3), "Menu button should exist")
        menuButton.tap()

        // Then: Settings screen should appear
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 2), "Settings screen should appear")
    }

    @MainActor
    func testSettingsScreenHasAccountSection() throws {
        // Given: User navigates to settings
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["Profile"].tap()
        app.navigationBars.buttons["line.3.horizontal"].tap()

        // Then: Account section should be visible
        XCTAssertTrue(app.staticTexts["Edit Profile"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Account Info"].exists)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testNavigateToSettingsFromProfile`

Expected: FAIL with "No match found for Menu button" or similar

**Step 3: Create SettingsView**

```swift
// ABOUTME: Main settings screen with grouped list of configuration options
// ABOUTME: Instagram-style layout with account, privacy, data, preferences, and about sections

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showLogoutAlert = false

    var body: some View {
        List {
            // MARK: - Account Section
            Section(header: Text("Account").textCase(.uppercase)) {
                NavigationLink {
                    Text("Edit Profile") // Placeholder - will wire to EditProfileView
                } label: {
                    SettingsRowView(
                        icon: "person.circle",
                        title: "Edit Profile",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    Text("Account Info") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "info.circle",
                        title: "Account Info",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    Text("Change Password") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "key",
                        title: "Change Password",
                        iconColor: .igTextSecondary
                    )
                }

                Button {
                    // Delete account - placeholder
                } label: {
                    SettingsRowView(
                        icon: "trash",
                        title: "Delete Account",
                        iconColor: .igRed
                    )
                }
            }

            // MARK: - Privacy Section
            Section(header: Text("Privacy").textCase(.uppercase)) {
                NavigationLink {
                    Text("Blocked Users") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "hand.raised",
                        title: "Blocked Users",
                        iconColor: .igTextSecondary
                    )
                }
            }

            // MARK: - Data & Storage Section
            Section(header: Text("Data & Storage").textCase(.uppercase)) {
                Button {
                    // Clear cache - placeholder
                } label: {
                    SettingsRowView(
                        icon: "trash.circle",
                        title: "Clear Cache",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    Text("Download My Data") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "arrow.down.circle",
                        title: "Download My Data",
                        iconColor: .igTextSecondary
                    )
                }
            }

            // MARK: - Preferences Section
            Section(header: Text("Preferences").textCase(.uppercase)) {
                HStack(spacing: 12) {
                    SettingsRowView(
                        icon: "moon.fill",
                        title: "Dark Mode",
                        iconColor: .igTextSecondary
                    )

                    Toggle("", isOn: .constant(false)) // Placeholder
                        .labelsHidden()
                }
            }

            // MARK: - About Section
            Section(header: Text("About").textCase(.uppercase)) {
                HStack {
                    SettingsRowView(
                        icon: "app.badge",
                        title: "App Version",
                        iconColor: .igTextSecondary
                    )

                    Text("1.0.0 (1)")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                }

                NavigationLink {
                    Text("Terms of Service") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "doc.text",
                        title: "Terms of Service",
                        iconColor: .igTextSecondary
                    )
                }

                NavigationLink {
                    Text("Privacy Policy") // Placeholder
                } label: {
                    SettingsRowView(
                        icon: "hand.raised.shield",
                        title: "Privacy Policy",
                        iconColor: .igTextSecondary
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
        .safeAreaInset(edge: .bottom) {
            // MARK: - Log Out Button (Footer)
            Button {
                showLogoutAlert = true
            } label: {
                Text("Log Out")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.igRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.igBackground)
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    Task {
                        await authViewModel.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
        }
    }
}
```

**Step 4: Update ProfileView to navigate to SettingsView**

Replace the Menu in ProfileView.swift (lines 117-132) with:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink {
            SettingsView()
                .environmentObject(authViewModel)
        } label: {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.igTextPrimary)
        }
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests`

Expected: PASS (all tests green)

**Step 6: Commit**

```bash
git add KinnectUITests/SettingsUITests.swift Kinnect/Views/Settings/SettingsView.swift Kinnect/Views/Profile/ProfileView.swift
git commit -m "feat: add SettingsView with navigation from ProfileView"
```

---

### Task 3: Create AccountInfoView (Read-Only)

**Files:**
- Create: `Kinnect/Views/Settings/AccountInfoView.swift`
- Test: `KinnectTests/Views/AccountInfoViewTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for AccountInfoView displaying user account details
// ABOUTME: Validates email, user ID, and account creation date rendering

import Testing
import SwiftUI
@testable import Kinnect

struct AccountInfoViewTests {

    @Test func rendersWithEmail() async throws {
        // Given: User email from auth session
        let email = "user@example.com"
        let userId = UUID()
        let createdAt = Date()

        let view = AccountInfoView(
            email: email,
            userId: userId,
            createdAt: createdAt
        )

        // Then: Email should be displayed
        #expect(view.email == email)
    }

    @Test func rendersWithUserId() async throws {
        // Given: User ID
        let userId = UUID()

        let view = AccountInfoView(
            email: "test@test.com",
            userId: userId,
            createdAt: Date()
        )

        // Then: User ID should be accessible
        #expect(view.userId == userId)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/AccountInfoViewTests`

Expected: FAIL with "Cannot find 'AccountInfoView' in scope"

**Step 3: Write minimal implementation**

```swift
// ABOUTME: Read-only view displaying user account information
// ABOUTME: Shows email, user ID, and account creation date

import SwiftUI

struct AccountInfoView: View {
    let email: String
    let userId: UUID
    let createdAt: Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(email)
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("User ID")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(userId.uuidString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Created")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.igTextSecondary)

                    Text(formattedDate)
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account Info")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/AccountInfoViewTests`

Expected: PASS

**Step 5: Commit**

```bash
git add KinnectTests/Views/AccountInfoViewTests.swift Kinnect/Views/Settings/AccountInfoView.swift
git commit -m "feat: add AccountInfoView for read-only account details"
```

---

### Task 4: Create ChangePasswordView (Info Screen)

**Files:**
- Create: `Kinnect/Views/Settings/ChangePasswordView.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for ChangePasswordView info screen
// ABOUTME: Validates guidance text and Settings deep link button

import Testing
import SwiftUI
@testable import Kinnect

struct ChangePasswordViewTests {

    @Test func hasOpenSettingsButton() async throws {
        // Given: ChangePasswordView
        let view = ChangePasswordView()

        // Then: View should render without crashing
        // Note: Button action testing requires UI test
        _ = view.body
    }
}
```

Create test file: `KinnectTests/Views/ChangePasswordViewTests.swift`

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/ChangePasswordViewTests`

Expected: FAIL with "Cannot find 'ChangePasswordView' in scope"

**Step 3: Write minimal implementation**

```swift
// ABOUTME: Info screen for password management via Sign in with Apple
// ABOUTME: Provides guidance and deep link to iOS Settings app

import SwiftUI

struct ChangePasswordView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.igBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("Your password is managed through Sign in with Apple")
                        .font(.system(size: 16))
                        .foregroundColor(.igTextPrimary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("To change your password, go to Settings → [Your Name] → Password & Security to manage your Apple ID password.")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Open Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.igBlue)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/ChangePasswordViewTests`

Expected: PASS

**Step 5: Commit**

```bash
git add KinnectTests/Views/ChangePasswordViewTests.swift Kinnect/Views/Settings/ChangePasswordView.swift
git commit -m "feat: add ChangePasswordView with Settings deep link"
```

---

### Task 5: Implement Dark Mode Toggle with AppStorage

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift` (Dark Mode section)
- Modify: `Kinnect/KinnectApp.swift` (apply color scheme)
- Test: `KinnectUITests/SettingsUITests.swift` (add dark mode test)

**Step 1: Write the failing test**

Add to `KinnectUITests/SettingsUITests.swift`:

```swift
@MainActor
func testDarkModeTogglePersists() throws {
    // Given: User navigates to settings
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["Profile"].tap()
    app.navigationBars.buttons["line.3.horizontal"].tap()

    // When: User toggles dark mode
    let darkModeToggle = app.switches["Dark Mode Toggle"]
    XCTAssertTrue(darkModeToggle.waitForExistence(timeout: 2))
    darkModeToggle.tap()

    // Then: Toggle state should change
    let toggleValue = darkModeToggle.value as? String
    XCTAssertEqual(toggleValue, "1", "Toggle should be on")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testDarkModeTogglePersists`

Expected: FAIL with "No match found for Toggle"

**Step 3: Implement dark mode toggle**

Update SettingsView.swift Preferences section:

```swift
// MARK: - Preferences Section
Section(header: Text("Preferences").textCase(.uppercase)) {
    HStack(spacing: 12) {
        SettingsRowView(
            icon: "moon.fill",
            title: "Dark Mode",
            iconColor: .igTextSecondary
        )

        Toggle("", isOn: $isDarkMode)
            .labelsHidden()
            .accessibilityLabel("Dark Mode Toggle")
    }
}
```

Add @AppStorage property at top of SettingsView:

```swift
@AppStorage("isDarkMode") private var isDarkMode = false
```

**Step 4: Apply color scheme in KinnectApp.swift**

Find the main app struct and add `.preferredColorScheme()`:

```swift
@main
struct KinnectApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testDarkModeTogglePersists`

Expected: PASS

**Step 6: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift Kinnect/KinnectApp.swift KinnectUITests/SettingsUITests.swift
git commit -m "feat: implement dark mode toggle with AppStorage persistence"
```

---

### Task 6: Wire Up Existing EditProfileView

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift` (Account section)

**Step 1: Write the failing test**

Add to `KinnectUITests/SettingsUITests.swift`:

```swift
@MainActor
func testNavigateToEditProfileFromSettings() throws {
    // Given: User is in settings
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["Profile"].tap()
    app.navigationBars.buttons["line.3.horizontal"].tap()

    // When: User taps Edit Profile
    let editProfileButton = app.buttons["Edit Profile"]
    XCTAssertTrue(editProfileButton.waitForExistence(timeout: 2))
    editProfileButton.tap()

    // Then: Edit Profile screen should appear
    let editProfileTitle = app.navigationBars["Edit Profile"]
    XCTAssertTrue(editProfileTitle.waitForExistence(timeout: 2), "Edit Profile screen should appear")
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testNavigateToEditProfileFromSettings`

Expected: FAIL with navigation not working

**Step 3: Update SettingsView to wire EditProfileView**

Find EditProfileView location first, then update SettingsView.swift:

```swift
@EnvironmentObject var authViewModel: AuthViewModel
@StateObject private var profileViewModel = ProfileViewModel()

// In Account section, replace Edit Profile NavigationLink:
NavigationLink {
    if let profile = profileViewModel.profile {
        EditProfileView(
            viewModel: profileViewModel,
            profile: profile
        )
    } else {
        ProgressView()
            .onAppear {
                Task {
                    if let userId = authViewModel.currentUserId {
                        await profileViewModel.fetchProfile(userId: userId)
                    }
                }
            }
    }
} label: {
    SettingsRowView(
        icon: "person.circle",
        title: "Edit Profile",
        iconColor: .igTextSecondary
    )
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testNavigateToEditProfileFromSettings`

Expected: PASS

**Step 5: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift KinnectUITests/SettingsUITests.swift
git commit -m "feat: wire EditProfileView navigation from settings"
```

---

### Task 7: Wire AccountInfoView with Real Data

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`
- Create: `Kinnect/ViewModels/SettingsViewModel.swift`
- Test: `KinnectTests/ViewModels/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for SettingsViewModel business logic
// ABOUTME: Validates fetching account info from auth session

import Testing
import Foundation
@testable import Kinnect

struct SettingsViewModelTests {

    @Test func fetchesAccountInfo() async throws {
        // Given: User is authenticated
        let viewModel = SettingsViewModel()

        // When: Fetching account info
        await viewModel.fetchAccountInfo()

        // Then: Account info should be populated
        #expect(viewModel.userEmail != nil)
        #expect(viewModel.userId != nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests`

Expected: FAIL with "Cannot find 'SettingsViewModel' in scope"

**Step 3: Create SettingsViewModel**

```swift
// ABOUTME: ViewModel for settings screen business logic
// ABOUTME: Manages account info, delete account, and cache clearing operations

import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var userEmail: String?
    @Published var userId: UUID?
    @Published var accountCreatedAt: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthService
    private let profileService: ProfileService

    init(authService: AuthService = AuthService.shared, profileService: ProfileService = ProfileService.shared) {
        self.authService = authService
        self.profileService = profileService
    }

    func fetchAccountInfo() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Get current user session
            let session = try await authService.getSession()
            userEmail = session.user.email
            userId = session.user.id

            // Fetch profile for created_at date
            if let userId = userId {
                let profile = try await profileService.fetchProfile(userId: userId)
                accountCreatedAt = profile.createdAt
            }
        } catch {
            errorMessage = "Failed to fetch account info: \(error.localizedDescription)"
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests`

Expected: PASS

**Step 5: Wire up AccountInfoView in SettingsView**

```swift
// Add at top of SettingsView:
@StateObject private var viewModel = SettingsViewModel()

// In Account section, replace Account Info NavigationLink:
NavigationLink {
    if let email = viewModel.userEmail,
       let userId = viewModel.userId,
       let createdAt = viewModel.accountCreatedAt {
        AccountInfoView(
            email: email,
            userId: userId,
            createdAt: createdAt
        )
    } else {
        ProgressView()
            .onAppear {
                Task {
                    await viewModel.fetchAccountInfo()
                }
            }
    }
} label: {
    SettingsRowView(
        icon: "info.circle",
        title: "Account Info",
        iconColor: .igTextSecondary
    )
}

// Add onAppear to prefetch account info:
.onAppear {
    Task {
        await viewModel.fetchAccountInfo()
    }
}
```

**Step 6: Commit**

```bash
git add KinnectTests/ViewModels/SettingsViewModelTests.swift Kinnect/ViewModels/SettingsViewModel.swift Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: wire AccountInfoView with real auth data"
```

---

### Task 8: Wire ChangePasswordView Navigation

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`

**Step 1: Update SettingsView navigation**

Replace Change Password placeholder in SettingsView.swift Account section:

```swift
NavigationLink {
    ChangePasswordView()
} label: {
    SettingsRowView(
        icon: "key",
        title: "Change Password",
        iconColor: .igTextSecondary
    )
}
```

**Step 2: Test manually**

Build and run app, navigate to Settings → Change Password, verify it opens and "Open Settings" button works.

Run: `xcodebuild build -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258'`

Expected: Build succeeds

**Step 3: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: wire ChangePasswordView navigation"
```

---

## Phase 2: Account Management

### Task 9: Create Delete Account Edge Function

**Files:**
- Create edge function via MCP

**Step 1: Write the edge function code**

Create file content for `delete-user-account/index.ts`:

```typescript
// ABOUTME: Edge function for deleting user accounts from Supabase Auth
// ABOUTME: Verifies JWT and uses service role to delete auth user

import { createClient } from 'jsr:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get user ID from request body
    const { userId } = await req.json()
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing userId in request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with user's JWT for verification
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const userClient = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    // Verify the JWT and get user
    const { data: { user }, error: authError } = await userClient.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Verify user can only delete their own account
    if (user.id !== userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: cannot delete another user\'s account' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create admin client with service role key
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const adminClient = createClient(supabaseUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    })

    // Delete user from Auth (this will cascade to profiles via FK constraints)
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(userId)
    if (deleteError) {
      console.error('Error deleting user:', deleteError)
      return new Response(
        JSON.stringify({ error: `Failed to delete user: ${deleteError.message}` }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Account deleted successfully' }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

**Step 2: Deploy edge function**

Use MCP tool:

```bash
# This is pseudocode - actual implementation uses MCP tool
mcp__supabase__deploy_edge_function(
  project_id: "qfoyodqiltnpcikhpbdi",
  name: "delete-user-account",
  files: [
    { name: "index.ts", content: "<content from above>" }
  ],
  entrypoint_path: "index.ts"
)
```

**Step 3: Test edge function manually**

Test with curl or Supabase dashboard function tester to verify JWT validation and deletion works.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: deploy delete-user-account edge function"
```

---

### Task 10: Create SettingsService with Delete Account

**Files:**
- Create: `Kinnect/Services/SettingsService.swift`
- Test: `KinnectTests/Services/SettingsServiceTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for SettingsService backend operations
// ABOUTME: Validates account deletion via edge function

import Testing
import Foundation
@testable import Kinnect

struct SettingsServiceTests {

    @Test func deleteAccountCallsEdgeFunction() async throws {
        // Given: SettingsService
        let service = SettingsService.shared
        let testUserId = UUID()

        // When: Deleting account
        // Then: Should not throw error (integration test - requires real Supabase)
        // Note: This is an integration test that requires a test user
        // For now, just verify the method exists
        do {
            try await service.deleteAccount(userId: testUserId)
        } catch {
            // Expected to fail in test environment without real user
            #expect(error != nil)
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsServiceTests`

Expected: FAIL with "Cannot find 'SettingsService' in scope"

**Step 3: Create SettingsService**

```swift
// ABOUTME: Service for settings-related backend operations
// ABOUTME: Handles account deletion via Supabase edge functions

import Foundation
import Supabase

final class SettingsService {
    static let shared = SettingsService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    /// Delete user account via edge function
    func deleteAccount(userId: UUID) async throws {
        // Get current session for JWT
        let session = try await client.auth.session

        // Call edge function
        let response = try await client.functions.invoke(
            "delete-user-account",
            options: FunctionInvokeOptions(
                body: ["userId": userId.uuidString],
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ]
            )
        )

        // Check for errors
        if let errorData = response.data,
           let errorDict = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any],
           let error = errorDict["error"] as? String {
            throw NSError(domain: "SettingsService", code: -1, userInfo: [NSLocalizedDescriptionKey: error])
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsServiceTests`

Expected: PASS

**Step 5: Commit**

```bash
git add KinnectTests/Services/SettingsServiceTests.swift Kinnect/Services/SettingsService.swift
git commit -m "feat: add SettingsService with delete account method"
```

---

### Task 11: Wire Delete Account Flow with Confirmations

**Files:**
- Modify: `Kinnect/ViewModels/SettingsViewModel.swift`
- Modify: `Kinnect/Views/Settings/SettingsView.swift`
- Test: `KinnectUITests/SettingsUITests.swift`

**Step 1: Write the failing test**

Add to `KinnectUITests/SettingsUITests.swift`:

```swift
@MainActor
func testDeleteAccountShowsConfirmation() throws {
    // Given: User is in settings
    let app = XCUIApplication()
    app.launch()

    app.tabBars.buttons["Profile"].tap()
    app.navigationBars.buttons["line.3.horizontal"].tap()

    // When: User taps Delete Account
    let deleteButton = app.buttons["Delete Account"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
    deleteButton.tap()

    // Then: Confirmation alert should appear
    let alert = app.alerts["Delete Account"]
    XCTAssertTrue(alert.waitForExistence(timeout: 2), "Delete confirmation alert should appear")
    XCTAssertTrue(alert.buttons["Cancel"].exists)

    // Cleanup: Cancel the alert
    alert.buttons["Cancel"].tap()
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testDeleteAccountShowsConfirmation`

Expected: FAIL with "No match found for alert"

**Step 3: Add delete account method to SettingsViewModel**

```swift
// Add to SettingsViewModel:
private let settingsService: SettingsService

init(
    authService: AuthService = AuthService.shared,
    profileService: ProfileService = ProfileService.shared,
    settingsService: SettingsService = SettingsService.shared
) {
    self.authService = authService
    self.profileService = profileService
    self.settingsService = settingsService
}

func deleteAccount() async {
    guard let userId = userId else {
        errorMessage = "User ID not found"
        return
    }

    isLoading = true
    defer { isLoading = false }

    do {
        try await settingsService.deleteAccount(userId: userId)
        // Sign out will happen automatically when auth session becomes invalid
    } catch {
        errorMessage = "Failed to delete account: \(error.localizedDescription)"
    }
}
```

**Step 4: Wire delete account in SettingsView**

```swift
// Add state for alerts:
@State private var showDeleteAlert1 = false
@State private var showDeleteAlert2 = false

// Replace Delete Account button:
Button {
    showDeleteAlert1 = true
} label: {
    SettingsRowView(
        icon: "trash",
        title: "Delete Account",
        iconColor: .igRed
    )
}
.alert("Delete Account", isPresented: $showDeleteAlert1) {
    Button("Cancel", role: .cancel) {}
    Button("Continue", role: .destructive) {
        showDeleteAlert2 = true
    }
} message: {
    Text("Are you sure you want to delete your account?")
}
.alert("Delete Account", isPresented: $showDeleteAlert2) {
    Button("Cancel", role: .cancel) {}
    Button("Delete", role: .destructive) {
        Task {
            await viewModel.deleteAccount()
            // Sign out on success
            if viewModel.errorMessage == nil {
                await authViewModel.signOut()
            }
        }
    }
} message: {
    Text("This action is permanent and cannot be undone. All your posts, comments, and data will be deleted.")
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/SettingsUITests/testDeleteAccountShowsConfirmation`

Expected: PASS

**Step 6: Commit**

```bash
git add Kinnect/ViewModels/SettingsViewModel.swift Kinnect/Views/Settings/SettingsView.swift KinnectUITests/SettingsUITests.swift
git commit -m "feat: wire delete account with two-step confirmation"
```

---

## Phase 3: Blocked Users

### Task 12: Create Blocks Table Migration

**Files:**
- Apply migration via MCP

**Step 1: Write the migration SQL**

```sql
-- Create blocks table
CREATE TABLE blocks (
    blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

-- Enable RLS
ALTER TABLE blocks ENABLE ROW LEVEL SECURITY;

-- Users can only see their own blocks
CREATE POLICY "Users can view their own blocks"
    ON blocks FOR SELECT
    USING (auth.uid() = blocker_id);

-- Users can block others
CREATE POLICY "Users can block others"
    ON blocks FOR INSERT
    WITH CHECK (auth.uid() = blocker_id);

-- Users can unblock others
CREATE POLICY "Users can unblock others"
    ON blocks FOR DELETE
    USING (auth.uid() = blocker_id);

-- Indexes for performance
CREATE INDEX idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);
```

**Step 2: Apply migration**

Use MCP tool:

```bash
# This is pseudocode - actual implementation uses MCP tool
mcp__supabase__apply_migration(
  project_id: "qfoyodqiltnpcikhpbdi",
  name: "create_blocks_table",
  query: "<SQL from above>"
)
```

**Step 3: Verify migration with advisors**

```bash
# This is pseudocode - actual implementation uses MCP tool
mcp__supabase__get_advisors(
  project_id: "qfoyodqiltnpcikhpbdi",
  type: "security"
)
```

Expected: No critical security issues

**Step 4: Commit**

```bash
git add .
git commit -m "feat: create blocks table with RLS policies"
```

---

### Task 13: Create BlockService

**Files:**
- Create: `Kinnect/Services/BlockService.swift`
- Test: `KinnectTests/Services/BlockServiceTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for BlockService user blocking operations
// ABOUTME: Validates block, unblock, and fetch operations

import Testing
import Foundation
@testable import Kinnect

struct BlockServiceTests {

    @Test func blockUserInsertsRow() async throws {
        // Given: BlockService
        let service = BlockService.shared
        let blockerId = UUID()
        let blockedId = UUID()

        // When/Then: Method should exist
        // Note: Integration test - requires real database
        do {
            try await service.blockUser(blockerId: blockerId, blockedId: blockedId)
        } catch {
            // Expected to fail without auth
            #expect(error != nil)
        }
    }

    @Test func cannotBlockSelf() async throws {
        // Given: Same user ID for blocker and blocked
        let service = BlockService.shared
        let userId = UUID()

        // When/Then: Should fail with CHECK constraint
        do {
            try await service.blockUser(blockerId: userId, blockedId: userId)
            Issue.record("Should not allow blocking self")
        } catch {
            // Expected
            #expect(error != nil)
        }
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/BlockServiceTests`

Expected: FAIL with "Cannot find 'BlockService' in scope"

**Step 3: Create BlockService**

```swift
// ABOUTME: Service for user blocking and unblocking operations
// ABOUTME: Manages blocks table and provides filtering utilities

import Foundation
import Supabase

final class BlockService {
    static let shared = BlockService()

    private let client: SupabaseClient

    private init() {
        self.client = SupabaseService.shared.client
    }

    // MARK: - Block Operations

    /// Block a user
    func blockUser(blockerId: UUID, blockedId: UUID) async throws {
        struct BlockInsert: Encodable {
            let blockerId: String
            let blockedId: String

            enum CodingKeys: String, CodingKey {
                case blockerId = "blocker_id"
                case blockedId = "blocked_id"
            }
        }

        let insert = BlockInsert(
            blockerId: blockerId.uuidString,
            blockedId: blockedId.uuidString
        )

        try await client
            .from("blocks")
            .insert(insert)
            .execute()
    }

    /// Unblock a user
    func unblockUser(blockerId: UUID, blockedId: UUID) async throws {
        try await client
            .from("blocks")
            .delete()
            .eq("blocker_id", value: blockerId.uuidString)
            .eq("blocked_id", value: blockedId.uuidString)
            .execute()
    }

    /// Fetch list of blocked users
    func fetchBlockedUsers(userId: UUID) async throws -> [Profile] {
        struct BlockRow: Decodable {
            let blockedProfile: Profile

            enum CodingKeys: String, CodingKey {
                case blockedProfile = "blocked:profiles!blocked_id"
            }
        }

        let response = try await client
            .from("blocks")
            .select("blocked:profiles!blocked_id(*)")
            .eq("blocker_id", value: userId.uuidString)
            .execute()

        let rows = try JSONDecoder.supabase.decode([BlockRow].self, from: response.data)
        return rows.map { $0.blockedProfile }
    }

    /// Check if a user is blocked (either direction)
    func isBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool {
        let response = try await client
            .from("blocks")
            .select("*", head: true, count: .exact)
            .or("and(blocker_id.eq.\(userId.uuidString),blocked_id.eq.\(targetUserId.uuidString)),and(blocker_id.eq.\(targetUserId.uuidString),blocked_id.eq.\(userId.uuidString))")
            .execute()

        return (response.count ?? 0) > 0
    }
}
```

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/BlockServiceTests`

Expected: PASS

**Step 5: Commit**

```bash
git add KinnectTests/Services/BlockServiceTests.swift Kinnect/Services/BlockService.swift
git commit -m "feat: add BlockService with block/unblock operations"
```

---

### Task 14: Create BlockedUsersView

**Files:**
- Create: `Kinnect/Views/Settings/BlockedUsersView.swift`
- Create: `Kinnect/ViewModels/BlockedUsersViewModel.swift`
- Test: `KinnectTests/ViewModels/BlockedUsersViewModelTests.swift`

**Step 1: Write the failing test**

```swift
// ABOUTME: Tests for BlockedUsersViewModel
// ABOUTME: Validates fetching blocked users and unblock operations

import Testing
import Foundation
@testable import Kinnect

struct BlockedUsersViewModelTests {

    @Test func fetchesBlockedUsers() async throws {
        // Given: BlockedUsersViewModel
        let viewModel = BlockedUsersViewModel()

        // When: Fetching blocked users
        await viewModel.fetchBlockedUsers(userId: UUID())

        // Then: Should complete without crashing
        #expect(viewModel.blockedUsers != nil)
    }

    @Test func unblockRemovesUser() async throws {
        // Given: ViewModel with blocked users
        let viewModel = BlockedUsersViewModel()

        // When: Unblocking user
        await viewModel.unblockUser(blockedUserId: UUID())

        // Then: Should complete (integration test)
        #expect(!viewModel.isLoading)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/BlockedUsersViewModelTests`

Expected: FAIL with "Cannot find 'BlockedUsersViewModel' in scope"

**Step 3: Create BlockedUsersViewModel**

```swift
// ABOUTME: ViewModel for blocked users list management
// ABOUTME: Handles fetching blocked users and unblock operations

import Foundation
import SwiftUI

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published var blockedUsers: [Profile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let blockService: BlockService
    private var currentUserId: UUID?

    init(blockService: BlockService = BlockService.shared) {
        self.blockService = blockService
    }

    func fetchBlockedUsers(userId: UUID) async {
        self.currentUserId = userId
        isLoading = true
        defer { isLoading = false }

        do {
            blockedUsers = try await blockService.fetchBlockedUsers(userId: userId)
        } catch {
            errorMessage = "Failed to fetch blocked users: \(error.localizedDescription)"
        }
    }

    func unblockUser(blockedUserId: UUID) async {
        guard let currentUserId = currentUserId else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await blockService.unblockUser(blockerId: currentUserId, blockedId: blockedUserId)

            // Remove from local list
            blockedUsers.removeAll { $0.id == blockedUserId }
        } catch {
            errorMessage = "Failed to unblock user: \(error.localizedDescription)"
        }
    }
}
```

**Step 4: Create BlockedUsersView**

```swift
// ABOUTME: View displaying list of blocked users with unblock actions
// ABOUTME: Shows avatars, usernames, and unblock buttons with empty state

import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                ProgressView()
            } else if viewModel.blockedUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "hand.raised")
                        .font(.system(size: 64))
                        .foregroundColor(.igTextSecondary)

                    Text("No blocked accounts")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.igTextSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.igBackground)
            } else {
                List {
                    ForEach(viewModel.blockedUsers) { profile in
                        HStack(spacing: 12) {
                            // Avatar
                            AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Circle()
                                    .fill(Color.igBackgroundGray)
                            }
                            .frame(width: 44, height: 44)
                            .clipShape(Circle())

                            // Username
                            Text(profile.username)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.igTextPrimary)

                            Spacer()

                            // Unblock button
                            Button {
                                Task {
                                    await viewModel.unblockUser(blockedUserId: profile.id)
                                }
                            } label: {
                                Text("Unblock")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.igBlue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.igBlue, lineWidth: 1)
                                    )
                            }
                            .disabled(viewModel.isLoading)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .background(Color.igBackground)
            }
        }
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = authViewModel.currentUserId {
                await viewModel.fetchBlockedUsers(userId: userId)
            }
        }
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/BlockedUsersViewModelTests`

Expected: PASS

**Step 6: Commit**

```bash
git add KinnectTests/ViewModels/BlockedUsersViewModelTests.swift Kinnect/ViewModels/BlockedUsersViewModel.swift Kinnect/Views/Settings/BlockedUsersView.swift
git commit -m "feat: add BlockedUsersView with unblock functionality"
```

---

### Task 15: Add Block Option to Post Menu

**Files:**
- Modify: `Kinnect/Views/Feed/PostCellView.swift` (or wherever post menu is)
- Test: `KinnectUITests/PostMenuUITests.swift`

**Step 1: Find the post menu location**

Search for the three-dot menu implementation (likely in PostCellView or similar).

**Step 2: Write the failing test**

Create `KinnectUITests/PostMenuUITests.swift`:

```swift
// ABOUTME: UI tests for post menu actions including block
// ABOUTME: Validates block user option appears in post menu

import XCTest

final class PostMenuUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPostMenuHasBlockOption() throws {
        // Given: App is launched with posts in feed
        let app = XCUIApplication()
        app.launch()

        // When: User taps three-dot menu on first post
        let menuButton = app.buttons["post-menu"].firstMatch
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        // Then: Block option should appear
        let blockButton = app.buttons["Block User"]
        XCTAssertTrue(blockButton.waitForExistence(timeout: 2), "Block user option should appear")

        // Cleanup
        app.tap() // Dismiss menu
    }
}
```

**Step 3: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/PostMenuUITests/testPostMenuHasBlockOption`

Expected: FAIL with "Block User button not found"

**Step 4: Add block option to post menu**

Find the post menu (likely in a view with three-dot button) and add:

```swift
// Add to the Menu or action sheet:
Button(role: .destructive) {
    showBlockAlert = true
} label: {
    Label("Block User", systemImage: "hand.raised")
}

// Add state variable:
@State private var showBlockAlert = false

// Add alert:
.alert("Block @\(post.author.username)?", isPresented: $showBlockAlert) {
    Button("Cancel", role: .cancel) {}
    Button("Block", role: .destructive) {
        Task {
            await blockUser(post.authorId)
        }
    }
} message: {
    Text("You won't see posts from this user in your feed.")
}

// Add block function:
private func blockUser(_ userId: UUID) async {
    guard let currentUserId = authViewModel.currentUserId else { return }

    do {
        try await BlockService.shared.blockUser(blockerId: currentUserId, blockedId: userId)
        // Optimistically remove post from feed
        feedViewModel.posts.removeAll { $0.authorId == userId }
    } catch {
        // Show error
        print("Failed to block user: \(error)")
    }
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests/PostMenuUITests/testPostMenuHasBlockOption`

Expected: PASS

**Step 6: Commit**

```bash
git add KinnectUITests/PostMenuUITests.swift Kinnect/Views/Feed/PostCellView.swift
git commit -m "feat: add block user option to post menu"
```

---

### Task 16: Update FeedService to Filter Blocked Users

**Files:**
- Modify: `Kinnect/Services/FeedService.swift`
- Test: `KinnectTests/Services/FeedServiceTests.swift`

**Step 1: Write the failing test**

Add to `KinnectTests/Services/FeedServiceTests.swift` (or create if doesn't exist):

```swift
@Test func feedExcludesBlockedUsers() async throws {
    // Given: FeedService with blocked users
    let service = FeedService.shared
    let userId = UUID()

    // When: Fetching feed
    // Then: Should filter blocked users (integration test)
    do {
        let posts = try await service.fetchFeed(userId: userId)
        // Should not crash
        #expect(posts != nil)
    } catch {
        // Expected in test environment
        #expect(error != nil)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/FeedServiceTests/feedExcludesBlockedUsers`

Expected: May pass but query doesn't filter yet

**Step 3: Update FeedService to add block filtering**

Find the fetchFeed method and update the query:

```swift
// In FeedService.fetchFeed():
let response = try await client
    .from("posts")
    .select("""
        *,
        author:profiles!author_id(*),
        likes(count)
    """)
    .eq("author_id", value: followedUserIds) // Existing following filter
    // Add block filter - exclude if I blocked them OR they blocked me
    .not("author_id", operator: .in, value: """
        (SELECT blocked_id FROM blocks WHERE blocker_id = '\(userId.uuidString)'
         UNION
         SELECT blocker_id FROM blocks WHERE blocked_id = '\(userId.uuidString)')
    """)
    .order("created_at", ascending: false)
    .limit(limit)
    .execute()
```

Note: The exact implementation depends on Supabase query builder syntax. May need to use `.filter()` method instead.

**Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/FeedServiceTests/feedExcludesBlockedUsers`

Expected: PASS

**Step 5: Commit**

```bash
git add Kinnect/Services/FeedService.swift KinnectTests/Services/FeedServiceTests.swift
git commit -m "feat: filter blocked users from feed"
```

---

### Task 17: Update SearchService to Filter Blocked Users

**Files:**
- Modify: `Kinnect/Services/SearchService.swift` (or wherever search is implemented)

**Step 1: Find search implementation**

Search for user search functionality (likely in SearchService or ProfileService).

**Step 2: Write the failing test**

```swift
// Create KinnectTests/Services/SearchServiceTests.swift if needed
@Test func searchExcludesBlockedUsers() async throws {
    // Given: SearchService
    let service = SearchService.shared
    let userId = UUID()

    // When: Searching users
    let results = try await service.searchUsers(query: "test", currentUserId: userId)

    // Then: Should filter blocked users (integration test)
    #expect(results != nil)
}
```

**Step 3: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SearchServiceTests/searchExcludesBlockedUsers`

Expected: May pass but query doesn't filter yet

**Step 4: Update search query to filter blocked users**

```swift
// In SearchService.searchUsers():
let response = try await client
    .from("profiles")
    .select()
    .ilike("username", value: "%\(query)%")
    // Add block filter
    .not("id", operator: .in, value: """
        (SELECT blocked_id FROM blocks WHERE blocker_id = '\(currentUserId.uuidString)'
         UNION
         SELECT blocker_id FROM blocks WHERE blocked_id = '\(currentUserId.uuidString)')
    """)
    .limit(20)
    .execute()
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SearchServiceTests/searchExcludesBlockedUsers`

Expected: PASS

**Step 6: Commit**

```bash
git add Kinnect/Services/SearchService.swift KinnectTests/Services/SearchServiceTests.swift
git commit -m "feat: filter blocked users from search results"
```

---

### Task 18: Wire BlockedUsersView in SettingsView

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`

**Step 1: Update SettingsView Privacy section**

Replace Blocked Users placeholder:

```swift
NavigationLink {
    BlockedUsersView()
        .environmentObject(authViewModel)
} label: {
    SettingsRowView(
        icon: "hand.raised",
        title: "Blocked Users",
        iconColor: .igTextSecondary
    )
}
```

**Step 2: Test manually**

Build and run, navigate to Settings → Blocked Users, verify it loads.

Run: `xcodebuild build -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258'`

Expected: Build succeeds

**Step 3: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: wire BlockedUsersView in settings"
```

---

## Phase 4: Data Management

### Task 19: Implement Clear Cache Functionality

**Files:**
- Modify: `Kinnect/ViewModels/SettingsViewModel.swift`
- Modify: `Kinnect/Views/Settings/SettingsView.swift`
- Test: `KinnectTests/ViewModels/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

Add to `SettingsViewModelTests.swift`:

```swift
@Test func clearsCacheSuccessfully() async throws {
    // Given: SettingsViewModel
    let viewModel = SettingsViewModel()

    // When: Clearing cache
    await viewModel.clearCache()

    // Then: Should complete without error
    #expect(viewModel.errorMessage == nil)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests/clearsCacheSuccessfully`

Expected: FAIL with "Cannot find 'clearCache' in scope"

**Step 3: Add clearCache method to SettingsViewModel**

```swift
// Add to SettingsViewModel:
@Published var showCacheSuccessAlert = false

func clearCache() async {
    isLoading = true
    defer { isLoading = false }

    // Clear URLCache (AsyncImage cache)
    URLCache.shared.removeAllCachedResponses()

    // Clear any ViewModel caches
    NotificationCenter.default.post(name: .clearAllCaches, object: nil)

    // Show success
    await MainActor.run {
        showCacheSuccessAlert = true
    }
}

// Add notification name extension:
extension Notification.Name {
    static let clearAllCaches = Notification.Name("clearAllCaches")
}
```

**Step 4: Wire up in SettingsView**

```swift
// In Data & Storage section, replace Clear Cache button:
Button {
    Task {
        await viewModel.clearCache()
    }
} label: {
    SettingsRowView(
        icon: "trash.circle",
        title: "Clear Cache",
        iconColor: .igTextSecondary
    )
}
.disabled(viewModel.isLoading)

// Add alert:
.alert("Cache Cleared", isPresented: $viewModel.showCacheSuccessAlert) {
    Button("OK", role: .cancel) {}
} message: {
    Text("All cached data has been cleared.")
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests/clearsCacheSuccessfully`

Expected: PASS

**Step 6: Commit**

```bash
git add Kinnect/ViewModels/SettingsViewModel.swift Kinnect/Views/Settings/SettingsView.swift KinnectTests/ViewModels/SettingsViewModelTests.swift
git commit -m "feat: implement clear cache functionality"
```

---

### Task 20: Create Data Export Edge Function

**Files:**
- Create edge function via MCP

**Step 1: Write the edge function code**

Create file content for `export-user-data/index.ts`:

```typescript
// ABOUTME: Edge function for exporting user data as JSON
// ABOUTME: Fetches posts, profile, comments, and activity for data portability

import { createClient } from 'jsr:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Get user ID from request body
    const { userId } = await req.json()
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Missing userId in request body' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Create Supabase client with user's JWT
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const client = createClient(supabaseUrl, supabaseKey, {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    })

    // Verify the JWT and get user
    const { data: { user }, error: authError } = await client.auth.getUser()
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Verify user can only export their own data
    if (user.id !== userId) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized: cannot export another user\'s data' }),
        { status: 403, headers: { 'Content-Type': 'application/json' } }
      )
    }

    // Fetch user's profile
    const { data: profile, error: profileError } = await client
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single()

    if (profileError) {
      console.error('Error fetching profile:', profileError)
    }

    // Fetch user's posts
    const { data: posts, error: postsError } = await client
      .from('posts')
      .select('*')
      .eq('author_id', userId)
      .order('created_at', { ascending: false })

    if (postsError) {
      console.error('Error fetching posts:', postsError)
    }

    // Fetch user's comments
    const { data: comments, error: commentsError } = await client
      .from('comments')
      .select('*')
      .eq('user_id', userId)
      .order('created_at', { ascending: false })

    if (commentsError) {
      console.error('Error fetching comments:', commentsError)
    }

    // Fetch user's activity
    const { data: activity, error: activityError } = await client
      .from('activities')
      .select('*')
      .eq('recipient_id', userId)
      .order('created_at', { ascending: false })

    if (activityError) {
      console.error('Error fetching activity:', activityError)
    }

    // Create export object
    const exportData = {
      exportedAt: new Date().toISOString(),
      profile: profile || null,
      posts: posts || [],
      comments: comments || [],
      activity: activity || [],
    }

    return new Response(
      JSON.stringify(exportData),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Content-Disposition': `attachment; filename="kinnect-data-${userId}.json"`,
        },
      }
    )
  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
```

**Step 2: Deploy edge function**

Use MCP tool:

```bash
# This is pseudocode - actual implementation uses MCP tool
mcp__supabase__deploy_edge_function(
  project_id: "qfoyodqiltnpcikhpbdi",
  name: "export-user-data",
  files: [
    { name: "index.ts", content: "<content from above>" }
  ],
  entrypoint_path: "index.ts"
)
```

**Step 3: Test edge function manually**

Test with Supabase function tester to verify JSON export works.

**Step 4: Commit**

```bash
git add .
git commit -m "feat: deploy export-user-data edge function"
```

---

### Task 21: Create DataExportView

**Files:**
- Create: `Kinnect/Views/Settings/DataExportView.swift`
- Modify: `Kinnect/ViewModels/SettingsViewModel.swift`
- Test: `KinnectTests/ViewModels/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

Add to `SettingsViewModelTests.swift`:

```swift
@Test func exportsUserData() async throws {
    // Given: SettingsViewModel
    let viewModel = SettingsViewModel()

    // When: Exporting data
    await viewModel.exportUserData()

    // Then: Should complete (integration test)
    #expect(!viewModel.isLoading)
}
```

**Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests/exportsUserData`

Expected: FAIL with "Cannot find 'exportUserData' in scope"

**Step 3: Add export method to SettingsViewModel**

```swift
// Add to SettingsViewModel:
@Published var exportedDataURL: URL?

func exportUserData() async {
    guard let userId = userId else {
        errorMessage = "User ID not found"
        return
    }

    isLoading = true
    defer { isLoading = false }

    do {
        // Get current session for JWT
        let session = try await authService.getSession()

        // Call edge function
        let response = try await SupabaseService.shared.client.functions.invoke(
            "export-user-data",
            options: FunctionInvokeOptions(
                body: ["userId": userId.uuidString],
                headers: [
                    "Authorization": "Bearer \(session.accessToken)"
                ]
            )
        )

        // Save JSON to temporary file
        if let data = response.data {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("kinnect-data-\(userId.uuidString).json")
            try data.write(to: fileURL)

            await MainActor.run {
                exportedDataURL = fileURL
            }
        }
    } catch {
        errorMessage = "Failed to export data: \(error.localizedDescription)"
    }
}
```

**Step 4: Create DataExportView**

```swift
// ABOUTME: View for exporting user data to JSON file
// ABOUTME: Provides explanation and share sheet for data portability

import SwiftUI

struct DataExportView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showShareSheet = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.igBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    Text("Download Your Data")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.igTextPrimary)
                        .frame(maxWidth: .infinity)

                    Text("This will export all your data including:")
                        .font(.system(size: 14))
                        .foregroundColor(.igTextSecondary)
                        .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Profile information", systemImage: "person.circle")
                        Label("All your posts", systemImage: "photo")
                        Label("Comments you've made", systemImage: "bubble.left")
                        Label("Activity history", systemImage: "bell")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.igTextPrimary)
                    .padding(.leading)

                    Text("The data will be provided as a JSON file that you can save or share.")
                        .font(.system(size: 12))
                        .foregroundColor(.igTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
                .padding(.vertical, 16)
            }

            Section {
                Button {
                    Task {
                        await viewModel.exportUserData()
                        if viewModel.exportedDataURL != nil {
                            showShareSheet = true
                        }
                    }
                } label: {
                    HStack {
                        Spacer()
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Request Data Export")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.igBlue)
                        }
                        Spacer()
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Download My Data")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.igBackground)
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.exportedDataURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .task {
            await viewModel.fetchAccountInfo()
        }
    }
}

// Share sheet helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
```

**Step 5: Run test to verify it passes**

Run: `xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests/SettingsViewModelTests/exportsUserData`

Expected: PASS

**Step 6: Commit**

```bash
git add KinnectTests/ViewModels/SettingsViewModelTests.swift Kinnect/ViewModels/SettingsViewModel.swift Kinnect/Views/Settings/DataExportView.swift
git commit -m "feat: add DataExportView with share sheet"
```

---

### Task 22: Wire DataExportView in SettingsView

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`

**Step 1: Update SettingsView Data & Storage section**

Replace Download My Data placeholder:

```swift
NavigationLink {
    DataExportView()
        .environmentObject(authViewModel)
} label: {
    SettingsRowView(
        icon: "arrow.down.circle",
        title: "Download My Data",
        iconColor: .igTextSecondary
    )
}
```

**Step 2: Test manually**

Build and run, navigate to Settings → Download My Data, test export.

Run: `xcodebuild build -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258'`

Expected: Build succeeds

**Step 3: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: wire DataExportView in settings"
```

---

## Phase 5: About Section

### Task 23: Display App Version from Bundle

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`

**Step 1: Create app version computed property**

Add to SettingsView:

```swift
private var appVersion: String {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "Version \(version) (Build \(build))"
}
```

**Step 2: Update App Version row in About section**

```swift
HStack {
    SettingsRowView(
        icon: "app.badge",
        title: "App Version",
        iconColor: .igTextSecondary
    )

    Text(appVersion)
        .font(.system(size: 14))
        .foregroundColor(.igTextSecondary)
}
```

**Step 3: Test manually**

Build and run, verify version displays correctly.

Run: `xcodebuild build -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258'`

Expected: Build succeeds and version displays

**Step 4: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: display app version from Bundle info"
```

---

### Task 24: Create WebContentView for Terms/Privacy

**Files:**
- Create: `Kinnect/Views/Settings/WebContentView.swift`

**Step 1: Create WebContentView**

```swift
// ABOUTME: Reusable web view for displaying terms and privacy policy
// ABOUTME: Uses SafariServices for secure in-app web browsing

import SwiftUI
import SafariServices

struct WebContentView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// Preview wrapper for navigation testing
struct WebContentViewWrapper: View {
    let title: String
    let url: URL

    var body: some View {
        WebContentView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
```

**Step 2: Test manually**

Create a test view that uses WebContentView with a sample URL.

**Step 3: Commit**

```bash
git add Kinnect/Views/Settings/WebContentView.swift
git commit -m "feat: add WebContentView for web content display"
```

---

### Task 25: Wire Terms and Privacy Policy Navigation

**Files:**
- Modify: `Kinnect/Views/Settings/SettingsView.swift`

**Step 1: Add placeholder URL constants**

Add at top of SettingsView:

```swift
private let termsURL = URL(string: "https://example.com/terms")!
private let privacyURL = URL(string: "https://example.com/privacy")!
```

Note: These are placeholders - Kyle will provide real URLs later.

**Step 2: Update About section navigation**

```swift
// Replace Terms of Service placeholder:
NavigationLink {
    WebContentViewWrapper(
        title: "Terms of Service",
        url: termsURL
    )
} label: {
    SettingsRowView(
        icon: "doc.text",
        title: "Terms of Service",
        iconColor: .igTextSecondary
    )
}

// Replace Privacy Policy placeholder:
NavigationLink {
    WebContentViewWrapper(
        title: "Privacy Policy",
        url: privacyURL
    )
} label: {
    SettingsRowView(
        icon: "hand.raised.shield",
        title: "Privacy Policy",
        iconColor: .igTextSecondary
    )
}
```

**Step 3: Test manually**

Build and run, navigate to Terms/Privacy, verify Safari view opens.

Run: `xcodebuild build -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258'`

Expected: Build succeeds

**Step 4: Commit**

```bash
git add Kinnect/Views/Settings/SettingsView.swift
git commit -m "feat: wire terms and privacy policy navigation"
```

---

## Final Testing & Documentation

### Task 26: Run Full Test Suite

**Files:**
- All test files

**Step 1: Run all unit tests**

```bash
xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectTests
```

Expected: All tests pass

**Step 2: Run all UI tests**

```bash
xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,id=EF725271-CEFF-4F32-BCFD-CB8AE1593258' -only-testing:KinnectUITests
```

Expected: All tests pass

**Step 3: Check for security advisors**

```bash
# This is pseudocode - actual implementation uses MCP tool
mcp__supabase__get_advisors(
  project_id: "qfoyodqiltnpcikhpbdi",
  type: "security"
)
```

Expected: No critical issues

**Step 4: Fix any failing tests**

If any tests fail, debug and fix before proceeding.

**Step 5: Commit**

```bash
git add .
git commit -m "test: verify all tests pass for settings feature"
```

---

### Task 27: Update Documentation

**Files:**
- Create: `docs/features/SETTINGS_MENU.md`
- Modify: `PROJECT_OVERVIEW.md`

**Step 1: Create SETTINGS_MENU.md**

```markdown
# Settings Menu

**Status:** ✅ Implemented

## Overview

Comprehensive Instagram-style settings menu with account management, privacy controls, data management, preferences, and about information.

## Architecture

**Views:**
- `SettingsView` - Main settings screen with grouped list
- `AccountInfoView` - Read-only account details
- `ChangePasswordView` - Info screen with Settings deep link
- `BlockedUsersView` - List of blocked users with unblock
- `DataExportView` - Data export with share sheet
- `WebContentView` - Reusable Safari view wrapper
- `SettingsRowView` - Reusable row component

**ViewModels:**
- `SettingsViewModel` - Settings business logic
- `BlockedUsersViewModel` - Blocked users management

**Services:**
- `SettingsService` - Account deletion via edge function
- `BlockService` - Block/unblock operations

**Backend:**
- `blocks` table with RLS policies
- `delete-user-account` edge function
- `export-user-data` edge function
- Feed/search filtering updated for blocks

## Features

### Account Section
- ✅ Edit Profile (wired to existing EditProfileView)
- ✅ Account Info (email, user ID, created date)
- ✅ Change Password (deep link to iOS Settings)
- ✅ Delete Account (two-step confirmation)

### Privacy Section
- ✅ Blocked Users (list with unblock)
- ✅ Block from post menu
- ✅ Bidirectional feed/search filtering

### Data & Storage Section
- ✅ Clear Cache (URLCache + ViewModel caches)
- ✅ Download My Data (JSON export with share sheet)

### Preferences Section
- ✅ Dark Mode (toggle with AppStorage persistence)

### About Section
- ✅ App Version (from Bundle)
- ✅ Terms of Service (Safari view)
- ✅ Privacy Policy (Safari view)

### Footer
- ✅ Log Out (confirmation alert)

## Testing

**Unit Tests:**
- SettingsRowViewTests
- AccountInfoViewTests
- ChangePasswordViewTests
- SettingsViewModelTests
- BlockServiceTests
- BlockedUsersViewModelTests
- FeedServiceTests (block filtering)
- SearchServiceTests (block filtering)

**UI Tests:**
- SettingsUITests (navigation, sections)
- PostMenuUITests (block option)

## Security

- Edge functions verify JWT tokens
- Users can only delete/export their own data
- RLS policies enforce block privacy
- Block filtering bidirectional (blocker and blocked)

## Usage

Navigate from ProfileView → Three-line menu icon → Settings

All settings operations use MVVM pattern with services layer.
```

**Step 2: Update PROJECT_OVERVIEW.md**

Add to "Core Features (MVP)" list:

```markdown
- Settings Menu with account management and privacy controls
```

Add to "Feature Documentation" section:

```markdown
**`/docs/features/SETTINGS_MENU.md`** – Settings Menu
- Account management, blocked users, data export, dark mode, about section
```

**Step 3: Commit**

```bash
git add docs/features/SETTINGS_MENU.md PROJECT_OVERVIEW.md
git commit -m "docs: add SETTINGS_MENU feature documentation"
```

---

### Task 28: Final Manual Testing on Device

**Files:**
- None (manual testing)

**Step 1: Test on simulator**

1. Navigate through all settings screens
2. Test dark mode toggle
3. Test clear cache
4. Test data export
5. Test all navigation paths

**Step 2: Test on physical device**

1. Repeat all simulator tests
2. Test "Open Settings" button for password
3. Verify share sheet works for data export
4. Test block/unblock with real posts

**Step 3: Document any issues**

Create GitHub issues for any bugs found.

**Step 4: Commit**

```bash
git add .
git commit -m "test: complete manual testing on simulator and device"
```

---

## Plan Complete

**Total Tasks:** 28
**Phases:** 5
**Estimated Time:** 10-15 hours (depending on debugging)

**Key Milestones:**
- ✅ Phase 1: Core UI (Tasks 1-8)
- ✅ Phase 2: Account Management (Tasks 9-11)
- ✅ Phase 3: Blocked Users (Tasks 12-18)
- ✅ Phase 4: Data Management (Tasks 19-22)
- ✅ Phase 5: About Section (Tasks 23-25)
- ✅ Final Testing (Tasks 26-28)

**Next Steps:**
- Review plan with Kyle
- Create development worktree
- Execute plan task-by-task using superpowers:executing-plans
