# Settings Menu Design

**Created:** November 3, 2025
**Status:** Approved

---

## Overview

Add a comprehensive settings menu to Kinnect, accessible from the profile tab. The current profile menu only contains a logout option. This design expands it into a full Instagram-style settings screen with account management, privacy controls, data management, preferences, and about information.

**Design Approach:** Full navigation (like Instagram) - replace the current Menu with a NavigationLink that pushes SettingsView onto the navigation stack.

---

## Navigation & Structure

### ProfileView Changes

**Current Implementation (ProfileView.swift:117-132):**
- Three-line menu icon in toolbar
- Contains single "Log Out" option

**New Implementation:**
- Replace `Menu` with `NavigationLink` to `SettingsView`
- Keep the same three-line icon (`line.3.horizontal`)
- Push full-screen settings view onto navigation stack

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.igTextPrimary)
        }
    }
}
```

### SettingsView Structure

**New File:** `Views/Settings/SettingsView.swift`

Instagram-style grouped list with sections:

1. **Account** - Profile and account management
2. **Privacy** - Blocking and privacy controls
3. **Data & Storage** - Cache and data export
4. **Preferences** - App preferences (dark mode)
5. **About** - App info and legal
6. **Footer** - Log out button

**Visual Style:**
- List style: `.listStyle(.insetGrouped)` for iOS Settings appearance
- Background: `.igBackground`
- Navigation title: "Settings" (inline mode)
- Each row: Icon (SF Symbol) + Label + Chevron (navigation) or Toggle (switches)

---

## Settings Categories

### 1. Account Section

#### Edit Profile
- **Icon:** `person.circle`
- **Action:** Navigate to existing `EditProfileView`
- **Implementation:** Reuse existing component, just wire up NavigationLink

#### Account Info
- **Icon:** `info.circle`
- **Action:** Navigate to new `AccountInfoView`
- **Content (read-only):**
  - Email address from Sign in with Apple (Supabase auth session)
  - User ID (useful for support/debugging)
  - Account created date (from profiles.created_at)

#### Change Password
- **Icon:** `key`
- **Action:** Navigate to new `ChangePasswordView`
- **Content:**
  - Info screen explaining: "Your password is managed through Sign in with Apple"
  - "Open Settings" button → Opens iOS Settings via `UIApplication.openSettingsURLString`
  - Guidance text: "Go to Settings → [Your Name] → Password & Security to manage your Apple ID password"

#### Delete Account
- **Icon:** `trash` (red color)
- **Action:** Two-step confirmation alert
  - Alert 1: "Are you sure you want to delete your account?"
  - Alert 2: "This action is permanent and cannot be undone. All your posts, comments, and data will be deleted."
- **Implementation:**
  - Call `SettingsViewModel.deleteAccount()`
  - Backend: `SettingsService.deleteAccount(userId:)`
  - Deletes user's posts (cascade via FK constraints)
  - Deletes profile row
  - Calls Supabase Edge Function to delete auth user (requires admin privileges)
  - On success: Sign out user, return to WelcomeView

---

### 2. Privacy Section

#### Blocked Users
- **Icon:** `hand.raised`
- **Action:** Navigate to new `BlockedUsersView`
- **Content:**
  - List of blocked users (avatar + username + "Unblock" button)
  - Empty state: "No blocked accounts"
- **Backend:**
  - New `blocks` table (see Backend Changes section)
  - New `BlockService` with block/unblock/fetch operations
  - Feed and search filtering to exclude blocked users (both directions)

---

### 3. Data & Storage Section

#### Clear Cache
- **Icon:** `trash.circle`
- **Action:** Immediate action (with success alert/toast)
- **Implementation:**
  - Clear AsyncImage cache: `URLCache.shared.removeAllCachedResponses()`
  - Clear any ViewModel cached data
  - Show success confirmation

#### Download My Data
- **Icon:** `arrow.down.circle`
- **Action:** Navigate to new `DataExportView`
- **Content:**
  - "Request Data Export" button
  - Explanation text about what's included
- **Implementation:**
  - New Supabase Edge Function generates JSON export
  - Includes: User's posts, profile data, comments, activity
  - Uses iOS share sheet to save/share the JSON file

---

### 4. Preferences Section

#### Dark Mode
- **Icon:** `moon.fill`
- **Action:** SwiftUI Toggle directly in row
- **Implementation:**
  - Use `@AppStorage("userColorScheme")` to persist preference
  - Values: "light", "dark", "system"
  - Update app's `.preferredColorScheme()` modifier
  - Toggle shows current state

---

### 5. About Section

#### App Version (Read-Only)
- **Icon:** `app.badge`
- **Display:** Version string on right side (no navigation)
- **Format:** "Version 1.0.0 (Build 1)"
- **Source:** `Bundle.main.infoDictionary` for version and build number

#### Terms of Service
- **Icon:** `doc.text`
- **Action:** Navigate to new `WebContentView` (reusable component)
- **Content:** Loads terms URL in WKWebView or SafariView
- **MVP:** Link to externally hosted terms (or local markdown)

#### Privacy Policy
- **Icon:** `hand.raised.shield`
- **Action:** Navigate to `WebContentView` with privacy policy URL
- **Implementation:** Same component as Terms, different URL

---

### 6. Footer Section

#### Log Out
- **Style:** Full-width button below list sections
- **Color:** Destructive red (like Instagram)
- **Action:** Confirmation alert → "Are you sure you want to log out?"
- **Implementation:**
  - Call existing `authViewModel.signOut()`
  - Same logic as current ProfileView logout
  - Return to WelcomeView

---

## Backend Changes

### 1. New `blocks` Table

**Migration:** Create table via `mcp__supabase__apply_migration`

```sql
CREATE TABLE blocks (
    blocker_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id),
    CHECK (blocker_id != blocked_id)
);

-- RLS Policies
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

-- Index for performance
CREATE INDEX idx_blocks_blocker ON blocks(blocker_id);
CREATE INDEX idx_blocks_blocked ON blocks(blocked_id);
```

### 2. New `SettingsService.swift`

**Location:** `Services/SettingsService.swift`

**Methods:**
- `deleteAccount(userId: UUID)` - Delete user profile and cascade
- Calls Edge Function for auth user deletion (needs service role key)

### 3. New `BlockService.swift`

**Location:** `Services/BlockService.swift`

**Methods:**
- `blockUser(blockerId: UUID, blockedId: UUID)`
- `unblockUser(blockerId: UUID, blockedId: UUID)`
- `fetchBlockedUsers(userId: UUID) -> [Profile]` - Returns list of blocked user profiles
- `isBlocked(userId: UUID, targetUserId: UUID) -> Bool` - Check if blocked (either direction)

### 4. Feed/Search Filtering Updates

**Affected Services:**
- `FeedService.swift` - Exclude blocked users from feed
- `SearchService.swift` - Exclude blocked users from search results

**Filtering Logic:**
- Exclude posts where author is blocked by current user
- Exclude posts where current user is blocked by author (bidirectional)
- Use LEFT JOIN on blocks table to filter efficiently

### 5. Edge Functions

#### `delete-user-account`
- **Purpose:** Delete user from Supabase Auth (requires admin privileges)
- **Input:** `{ userId: string }`
- **Process:**
  1. Verify requesting user matches userId
  2. Use service role key to call `auth.admin.deleteUser(userId)`
  3. Return success/error
- **Security:** Verify JWT, ensure user can only delete their own account

#### `export-user-data`
- **Purpose:** Generate JSON export of user's data
- **Input:** `{ userId: string }`
- **Process:**
  1. Fetch user's profile
  2. Fetch all posts (with media URLs)
  3. Fetch all comments
  4. Fetch all activity notifications
  5. Generate JSON file
  6. Return download URL or JSON directly
- **Security:** Verify JWT, ensure user can only export their own data

---

## UI/UX Details

### Settings Row Component

Create reusable `SettingsRowView` component for consistency:

```swift
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

### Color Palette

- **Background:** `.igBackground` (from existing Color+Extensions)
- **Text Primary:** `.igTextPrimary`
- **Text Secondary:** `.igTextSecondary`
- **Destructive:** `.igRed`
- **Icon Colors:** `.igTextSecondary` (default), `.igRed` (delete)

### Transitions & Navigation

- Push/pop transitions (default NavigationStack behavior)
- Consistent back button behavior
- No custom animations needed - native feels right

---

## Implementation Notes

### Phase 1: Core Settings UI
- Create `SettingsView` with all sections
- Wire up navigation from ProfileView
- Implement SettingsRowView component
- Add Account Info screen (read-only)
- Add Change Password info screen
- Implement Dark Mode toggle with AppStorage

### Phase 2: Account Management
- Create `SettingsViewModel`
- Create `SettingsService`
- Implement delete account Edge Function
- Wire up delete account flow with confirmations
- Test auth cleanup

### Phase 3: Blocked Users
- Create `blocks` table migration
- Create `BlockService`
- Create `BlockedUsersView`
- Update FeedService to filter blocked users
- Update SearchService to filter blocked users
- Add block/unblock UI to user profiles

### Phase 4: Data Management
- Implement Clear Cache functionality
- Create data export Edge Function
- Create `DataExportView`
- Implement share sheet for export

### Phase 5: About Section
- Create `WebContentView` component
- Add Terms of Service content/URL
- Add Privacy Policy content/URL
- Display app version from Bundle

### Testing Considerations
- Test delete account flow thoroughly (can't undo!)
- Test blocked users filtering in feed and search
- Test dark mode persistence across app restarts
- Test all navigation paths (deep linking, back button behavior)
- Test edge cases: blocking yourself (prevented), deleting account while uploads in progress

### Security Considerations
- Edge Functions must verify JWT tokens
- Users can only delete their own accounts
- Users can only export their own data
- RLS policies on blocks table enforce privacy
- Blocked user filtering must work bidirectionally

---

## Success Criteria

**User Can:**
- ✅ Access settings from profile tab via three-line icon
- ✅ View account information (email, user ID, created date)
- ✅ Manage password via iOS Settings deep link
- ✅ Delete their account with proper warnings
- ✅ Block/unblock users and never see their content
- ✅ Clear app cache
- ✅ Download their data as JSON
- ✅ Toggle dark mode and have it persist
- ✅ View app version, terms, and privacy policy
- ✅ Log out from settings screen

**Technical:**
- ✅ All settings operations use MVVM pattern
- ✅ Backend changes use migrations (not manual edits)
- ✅ Edge Functions properly secured with JWT verification
- ✅ Blocked users completely filtered from feed/search
- ✅ Dark mode preference persists across app restarts
- ✅ Delete account properly cleans up all user data

---

**Next Steps:** Create implementation plan and set up development worktree.
