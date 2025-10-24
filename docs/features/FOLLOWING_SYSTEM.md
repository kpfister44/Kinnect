# Following System

**Phase 8: User Search, Follow/Unfollow, Feed Filtering**
**Completed:** October 24, 2025

---

## Overview

Complete following system with user search, follow/unfollow operations, followers/following lists, and feed filtering. Users can now build their private network by following friends, and the feed only shows posts from followed users.

---

## Architecture

### FollowService.swift

```swift
func followUser(followerId: UUID, followeeId: UUID) async throws
func unfollowUser(followerId: UUID, followeeId: UUID) async throws
func checkFollowStatus(followerId: UUID, followeeId: UUID) async throws -> Bool
func getFollowers(userId: UUID) async throws -> [Profile]
func getFollowing(userId: UUID) async throws -> [Profile]
func getFollowingIds(userId: UUID) async throws -> [UUID]
func searchUsers(query: String) async throws -> [Profile]
```

**Key Features:**
- Follow/unfollow operations with database persistence
- Follow status checking for profile buttons
- Search users by username (case-insensitive, LIKE pattern)
- Fetch followers and following lists with profile data via JOIN
- Get following IDs efficiently for feed filtering

**Error Handling:**
Custom `FollowServiceError` enum:
- `alreadyFollowing`
- `notFollowing`
- `cannotFollowSelf`
- `userNotFound`

### SearchViewModel

```swift
@Published var searchText: String = ""
@Published var searchResults: [Profile] = []
@Published var isSearching: Bool = false
@Published var errorMessage: String?

private func setupSearchDebouncing()
private func performSearch(query: String) async
func clearSearch()
```

**Search Debouncing:**
- 300ms debounce on search input
- Automatic search as user types
- Cancel in-flight searches when new query arrives
- Real-time results update

**Pattern Used:** Combine's `debounce` operator for performance optimization

### ProfileViewModel Integration

```swift
@Published var isFollowing: Bool = false
@Published var isFollowOperationInProgress: Bool = false

private func checkFollowStatus(currentUserId: UUID, profileUserId: UUID) async
func toggleFollow(currentUserId: UUID, profileUserId: UUID) async
```

**Optimistic UI Pattern:**
1. Store previous state (follow status + follower count)
2. Update UI immediately for instant feedback
3. Execute API call in background
4. On success: Keep UI state, refresh stats from server
5. On error: Revert to previous state, show error

**Benefits:**
- Instant visual feedback (no waiting for server)
- Graceful error recovery with rollback
- Follower count updates in real-time

---

## Components

### SearchView

Instagram-style search with real-time results:

**States:**
- **Empty:** "Search for friends" placeholder when no query
- **Loading:** Spinner during search
- **Results:** List of matching users with avatars
- **No Results:** "No results found" when query matches nobody
- **Error:** Error message with icon

**Navigation:**
- Tap search result → Navigate to user's profile
- Search bar in navigation (native `.searchable()`)

**Search Behavior:**
- Searches after 300ms of inactivity (debounce)
- Case-insensitive username matching
- Returns up to 20 results
- Clears results when search bar is cleared

### UserRowView

Reusable component for displaying users in lists:

**Usage:** SearchView, FollowersListView, FollowingListView

**Layout:**
```
[Avatar] [Username]               [Follow Button]
         [Full Name]
```

**Features:**
- Circular avatar (44x44)
- Username (bold, 14pt)
- Full name (gray, 14pt) - optional
- Optional follow button
- Tappable row for navigation

**Props:**
```swift
profile: Profile
showFollowButton: Bool
isFollowing: Bool
onFollowToggle: () -> Void
```

### ProfileHeaderView Updates

**New Features:**

1. **Enabled Follow Button:**
   - Shows "Follow" (blue) or "Following" (gray)
   - Displays spinner during API call
   - Disabled during operation
   - Optimistic UI updates

2. **Tappable Stats:**
   - Tap "Followers" → Opens FollowersListView sheet
   - Tap "Following" → Opens FollowingListView sheet
   - "Posts" count remains non-tappable

**Follow Button States:**
```swift
"Follow" (blue background, white text)
  ↓ tap
"Following" (gray background, dark text)
  ↓ tap
"Follow" (back to original)
```

### FollowersListView

Bottom sheet displaying users who follow this profile:

**Features:**
- List of followers with avatars, usernames, full names
- Tap any row → Navigate to that user's profile
- Empty state: "No followers yet"
- Close button (X icon, top-right)
- Loading state with spinner
- Error state with retry button

**Data Loading:**
- Fetches on sheet open via `.task {}`
- Fetches followers from FollowService
- Profiles returned via JOIN (includes all profile fields)

### FollowingListView

Bottom sheet displaying users this profile follows:

**Identical UI to FollowersListView**

**Differences:**
- Fetches "following" instead of "followers"
- Empty state: "Not following anyone yet"
- Sheet title: "Following"

### ProfileView Updates

**New Parameters:**
```swift
let userId: UUID? // nil = current user, otherwise = specific user
```

**Computed Properties:**
```swift
private var isCurrentUser: Bool
private var profileUserId: UUID?
private var currentUserId: UUID?
```

**Follow Integration:**
- Loads follow status on profile view
- Shows "Follow" button for other users
- Shows "Edit Profile" for current user
- Passes follow callbacks to ProfileHeaderView
- Handles sheets for followers/following lists

**Sheet Management:**
```swift
@State private var showFollowersList = false
@State private var showFollowingList = false
```

---

## Feed Integration

### FeedService Updates

**Critical Change: Feed Filtering by Follows**

**Before Phase 8:**
```swift
// Fetched ALL posts from database
.select("*")
.order("created_at", ascending: false)
```

**After Phase 8:**
```swift
// Step 1: Get following IDs
let followedUserIds = try await followService.getFollowingIds(userId: currentUserId)

// Step 2: Add current user to list
var authorIds = followedUserIds
authorIds.append(currentUserId)

// Step 3: Filter posts by authors
.in("author", values: authorIds.map { $0.uuidString })
```

**Feed Logic:**
- Shows posts from followed users + own posts
- If following nobody → only shows own posts
- Efficient filtering using `.in()` operator

**Performance Considerations:**
- Single query to get following IDs
- IN clause filters posts efficiently
- No N+1 query problem

### FeedView Empty State

**Updated Empty State:**

When user follows nobody:
```
Icon: person.2.slash
Title: "Welcome to Kinnect"
Message: "Follow people to see their posts in your feed"
Hint: "Tap the search tab to find friends"
```

**Behavior:**
- Shows when `posts.isEmpty` after feed loads
- Encourages user to use search feature
- Guides user flow naturally

---

## Database Integration

### Follows Table (Already Existed)

```sql
CREATE TABLE follows (
  follower UUID REFERENCES profiles(user_id),
  followee UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (follower, followee)
);
```

**Composite Primary Key:** Prevents duplicate follows (user can only follow another user once).

**Foreign Keys:** Both reference `profiles(user_id)` for data integrity.

### Follow Relationships Query

**Get Followers with Profiles:**
```sql
SELECT follows.follower, profiles.*
FROM follows
JOIN profiles ON follows.follower = profiles.user_id
WHERE follows.followee = $userId;
```

**Get Following with Profiles:**
```sql
SELECT follows.followee, profiles.*
FROM follows
JOIN profiles ON follows.followee = profiles.user_id
WHERE follows.follower = $userId;
```

**Supabase Swift SDK Syntax:**
```swift
.select("""
    follower,
    profiles!follows_follower_fkey(
        user_id,
        username,
        avatar_url,
        full_name,
        bio,
        created_at
    )
""")
```

**Important:** Must include ALL Profile fields for Codable decoding.

### User Search Query

**Case-Insensitive Username Search:**
```sql
SELECT * FROM profiles
WHERE username ILIKE '%query%'
LIMIT 20;
```

**Supabase Swift SDK:**
```swift
.ilike("username", pattern: "%\(query)%")
.limit(20)
```

**Pattern Matching:**
- `%` = wildcard (matches any characters)
- `ILIKE` = case-insensitive LIKE
- Returns partial matches

---

## Key Features

### Real-Time Search

**Implementation:**
```swift
$searchText
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .sink { [weak self] query in
        Task { @MainActor in
            await self?.performSearch(query: query)
        }
    }
```

**Why 300ms?**
- Balance between responsiveness and performance
- Reduces unnecessary API calls
- Instagram uses similar debounce timing

### Optimistic UI Updates

**Follow Button Pattern:**
```swift
func toggleFollow() async {
    // 1. Store previous state
    let previousFollowState = isFollowing
    let previousStats = stats

    // 2. Update UI immediately
    isFollowing.toggle()
    if var currentStats = stats {
        currentStats.followersCount += isFollowing ? 1 : -1
        stats = currentStats
    }

    // 3. API call
    do {
        if isFollowing {
            try await followService.followUser(...)
        } else {
            try await followService.unfollowUser(...)
        }
        // Success: refresh stats from server
        await refreshStats(userId: profileUserId)
    } catch {
        // 4. Revert on error
        isFollowing = previousFollowState
        stats = previousStats
        errorMessage = "Failed to update follow status"
    }
}
```

**User Experience:**
- Button toggles instantly (feels responsive)
- Count updates immediately
- Small spinner shows during API call
- Graceful rollback if operation fails

### Feed Filtering Logic

**Empty Feed Detection:**
```swift
// After loading feed
if posts.isEmpty {
    // User follows nobody → show empty state
    // "Follow people to see their posts"
}
```

**Following User A:**
```
Feed shows: [User A's posts] + [Your posts]
```

**Unfollowing User A:**
```
Feed shows: [Your posts only]
```

**Following Multiple Users:**
```
Feed shows: [All followed users' posts] + [Your posts]
Sorted by: created_at DESC (newest first)
```

### Profile Stats Synchronization

**Stats Structure (Updated):**
```swift
struct ProfileStats {
    var postsCount: Int      // Changed from let to var
    var followersCount: Int   // Changed from let to var
    var followingCount: Int   // Changed from let to var
}
```

**Why `var`?**
- Allows optimistic UI updates
- Temporarily modify counts before server confirms
- Revert if operation fails

**Stats Refresh Pattern:**
```swift
// After follow/unfollow completes
await refreshStats(userId: profileUserId)
```

Ensures counts are accurate after server confirms.

---

## Security & Privacy

### Row-Level Security (RLS)

**Follows Table Policies:**
- Users can follow anyone (insert into `follows`)
- Users can unfollow anyone (delete from `follows`)
- Users can read follow relationships (for followers/following lists)

**No Security Issues Detected:**
- ✅ Security advisors check passed
- ✅ RLS policies correctly configured
- ✅ No data leakage vulnerabilities

**Self-Follow Prevention:**
- Handled at UI level (button doesn't appear on own profile)
- Can add database constraint if needed: `CHECK (follower != followee)`

### Performance Optimization Opportunities

**Advisor Recommendations (Non-Critical):**

1. **Unindexed Foreign Keys (INFO level):**
   - `comments.user_id` could benefit from index
   - `likes.user_id` could benefit from index
   - Minor performance gain for large datasets

2. **RLS Init Plan (WARN level):**
   - Replace `auth.uid()` with `(select auth.uid())`
   - Prevents re-evaluation for each row
   - Optimization for scale (not urgent for MVP)

**Note:** These are optimizations for future scale, not critical issues.

---

## Bug Fixes

### ProfileStats Mutation Error ✅ FIXED

**Problem:** Build error - "Left side of mutating operator isn't mutable: 'followersCount' is a 'let' constant"

**Cause:** `ProfileStats` struct had `let` constants, but optimistic UI needed to modify counts

**Solution:** Changed struct properties from `let` to `var`:
```swift
struct ProfileStats {
    var postsCount: Int      // was: let
    var followersCount: Int   // was: let
    var followingCount: Int   // was: let
}
```

**Location:** `ProfileService.swift:235-238`

**Result:** Optimistic updates now work correctly

---

## Important Learnings

### Supabase Foreign Key Joins

**Syntax for JOIN with foreign keys:**
```swift
.select("""
    follower,
    profiles!follows_follower_fkey(
        user_id,
        username,
        avatar_url,
        full_name,
        bio,
        created_at
    )
""")
```

**Foreign Key Naming Convention:**
- `{table}_{column}_fkey`
- Example: `follows_follower_fkey`

**Must Include All Fields:**
- Codable models require all properties
- Missing fields cause `keyNotFound` decoding errors
- Include fields even if not displayed in UI

### Search Debouncing with Combine

**Pattern:**
```swift
private var cancellables = Set<AnyCancellable>()

$searchText
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
    .removeDuplicates()
    .sink { query in
        // Perform search
    }
    .store(in: &cancellables)
```

**Why This Works:**
- `debounce`: Waits for pause in typing
- `removeDuplicates`: Prevents duplicate searches
- `sink`: Executes async search task
- `store(in:)`: Keeps subscription alive

### Feed Filtering Strategy

**Two Approaches Considered:**

**Approach 1: Complex SQL JOIN (rejected)**
```sql
SELECT posts.*
FROM posts
LEFT JOIN follows ON posts.author = follows.followee
WHERE follows.follower = $userId OR posts.author = $userId
```
- Complex to write in Supabase Swift SDK
- Hard to debug
- Performance unclear

**Approach 2: Two-Step Filter (chosen) ✅**
```swift
// Step 1: Get following IDs
let followedIds = try await getFollowingIds(userId: currentUserId)

// Step 2: Filter posts
.in("author", values: followedIds + [currentUserId])
```
- Simple and readable
- Easy to debug (see logs)
- Efficient with proper indexes
- Clear separation of concerns

### Optimistic UI Best Practices

**Always Include:**
1. Store previous state before mutating
2. Update UI immediately
3. Execute async operation
4. Refresh from server on success
5. Revert state on error
6. Show loading indicator during operation

**Example:**
```swift
let previousState = currentState
currentState = newState
do {
    try await apiCall()
    await refreshFromServer()
} catch {
    currentState = previousState
}
```

---

## Testing Results

✅ **Search Functionality:**
- Real-time search with 300ms debounce working
- Case-insensitive partial matching working
- Search results display with avatars
- Navigation to profiles working
- Empty states display correctly
- No results state working

✅ **Follow/Unfollow Operations:**
- Follow button toggles instantly
- "Follow" → "Following" state change working
- Optimistic UI updates working
- Follower count increases/decreases immediately
- Server confirmation working
- Unfollow working correctly
- Error handling with rollback working

✅ **Feed Filtering:**
- Empty state displays when following nobody
- Followed users' posts appear in feed
- Own posts always appear
- Unfollowed users' posts disappear
- Feed updates correctly after follow/unfollow
- Chronological ordering maintained

✅ **Followers/Following Lists:**
- Tappable stats open correct sheets
- Lists populate with correct users
- Navigation from lists to profiles working
- Empty states display correctly
- Close buttons working

✅ **Profile Integration:**
- Follow button shows on other users' profiles
- "Edit Profile" shows on own profile
- Follow status loads correctly
- Stats update after operations
- No self-follow option (prevented at UI level)

✅ **Edge Cases:**
- Network errors handled gracefully
- Empty search query clears results
- Rapid follow/unfollow handled correctly
- Mock user posts (without images) handled gracefully

---

## Files Involved

**Service Layer:**
- `/Services/FollowService.swift` - NEW
- `/Services/FeedService.swift` - Updated for feed filtering
- `/Services/ProfileService.swift` - Updated ProfileStats to use `var`

**ViewModel Layer:**
- `/ViewModels/SearchViewModel.swift` - NEW
- `/ViewModels/ProfileViewModel.swift` - Added follow operations

**View Layer:**
- `/Views/Shared/SearchView.swift` - Rebuilt with real functionality
- `/Views/Shared/UserRowView.swift` - NEW (reusable component)
- `/Views/Profile/ProfileView.swift` - Added follow integration + sheets
- `/Views/Profile/ProfileHeaderView.swift` - Enabled follow button + tappable stats
- `/Views/Profile/FollowersListView.swift` - NEW
- `/Views/Profile/FollowingListView.swift` - NEW
- `/Views/Feed/FeedView.swift` - Updated empty state message

**Database:**
- `/migrations/add_mock_test_users.sql` - Created mock users for testing

---

## Mock Test Data

For development/testing, 3 mock users were created:

**Alice Wonderland** (`alice_wonder`)
- 3 posts about travel and coffee
- Bio: "Adventure seeker 🌟"

**Bob Builder** (`bob_builder`)
- 2 posts about DIY projects
- Bio: "Can we fix it? Yes we can! 🔨"

**Carol Stevens** (`carol_creator`)
- 3 posts about art and design
- Bio: "Artist 🎨 | Designer"

**Note:** Mock posts have fake `media_key` paths and won't display images. This is expected - used only to test follow/feed filtering logic.

---

## Security Advisors Results

**Security Check:** ✅ PASSED
- No critical security vulnerabilities
- RLS policies correctly configured
- Follow relationships properly protected
- One non-critical auth warning (leaked password protection - not applicable for Sign in with Apple)

**Performance Check:** ℹ️ MINOR OPTIMIZATIONS AVAILABLE
- INFO: Some foreign keys could benefit from indexes (likes, comments)
- WARN: RLS policies could be optimized for scale (`auth.uid()` → `(select auth.uid())`)
- Not urgent for MVP - can be addressed in Phase 10 (Polish)

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md` (Database schema, RLS policies, follows table)
- Profile system: `/docs/features/PROFILE_SYSTEM.md` (Profile viewing patterns)
- Feed system: `/docs/features/FEED_SYSTEM.md` (Feed display patterns)
- Social interactions: `/docs/features/SOCIAL_INTERACTIONS.md` (Optimistic UI patterns)

---

## Future Enhancements (Phase 9+)

- **Real-time follow notifications:** Push notification when someone follows you
- **Follow requests:** Private accounts with follow approval
- **Mutual friends:** Show "Followed by X and Y" in search results
- **Suggested users:** Recommend people to follow based on mutual follows
- **Follow back button:** Quick "Follow Back" in followers list
- **Block/Unblock:** Prevent unwanted follows
- **Follow limits:** Rate limiting to prevent spam

---

**Status:** ✅ Complete
**Next Phase:** Real-time Updates (Phase 9)
**Build Status:** Compiles successfully, all tests passed
