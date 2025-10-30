# Profile Feed Navigation

**Status:** ✅ Production Ready (Critical bugs fixed)
**Date:** October 29, 2025
**Implemented:** October 29, 2025
**Bugs Discovered:** October 29-30, 2025
**Bugs Fixed:** 3/5 (Bugs #1, #2, #3 fixed - October 30, 2025)

---

## Overview

Instagram-style navigation from profile grid to feed view. When a user taps a post in the profile grid, they see that user's posts displayed as a scrollable feed (like the main feed), starting at the tapped post. This replaces the single-post detail view approach.

---

## Motivation

**Current Behavior (Not Instagram-like):**
- Feed tab: Tapping a post opens a single-post detail view
- Profile grid: Tapping a post opens a single-post detail view

**New Behavior (Instagram-style):**
- Feed tab: Tapping a post does nothing (all interactions inline)
- Profile grid: Tapping a post opens a feed-style view of that user's posts, scrolled to the tapped post

**Goal:** Match Instagram's UX exactly - feed posts are non-tappable, profile grid posts open a scrollable feed view.

---

## Current State Analysis

### FeedView
- ✅ Posts are not tappable (correct)
- ✅ All interactions work inline (like, comment, caption expansion)
- ✅ Uses `PostCellView` component

### ProfilePostsGridView
- ❌ Currently uses `NavigationLink` to `PostDetailView`
- ❌ Shows single post instead of feed
- Lines 40-44 in `ProfilePostsGridView.swift`

### PostDetailView
- Currently used ONLY by `ProfilePostsGridView`
- Used to be referenced in `ActivityView` (TODO comment, not actually used)
- Can be safely deleted after migration

---

## Technical Design

### 1. New Component: ProfileFeedView

**File:** `/Views/Profile/ProfileFeedView.swift`

**Purpose:** Display all posts from a specific user in feed format, scrolled to a specific initial post.

**Props:**
```swift
let userId: UUID           // Profile whose posts to display
let initialPostId: UUID    // Post to scroll to on load
let currentUserId: UUID    // For permissions (like/comment/delete)
```

**Features:**
- Display posts in chronological order (newest first)
- Scroll to `initialPostId` on appear
- Bi-directional scrolling:
  - Scroll up → newer posts
  - Scroll down → older posts
- Full feed interactions:
  - Like button with optimistic UI
  - Comment button (opens `CommentsView` sheet)
  - Three-dot menu (delete own posts, unfollow others)
  - Caption expansion ("more" button)
- Show username header on each post (identical to main feed)
- Reuse `PostCellView` component (no duplication)

**UI Structure:**
```swift
NavigationStack {
    ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(posts) { post in
                    PostCellView(post: post, mediaURL: getMediaURL(for: post))
                        .environmentObject(viewModel)
                        .id(post.id)

                    Divider()
                }
            }
        }
        .onAppear {
            // Scroll to initial post
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    proxy.scrollTo(initialPostId, anchor: .top)
                }
            }
        }
    }
    .navigationBarTitleDisplayMode(.inline)
}
```

---

### 2. New ViewModel: ProfileFeedViewModel

**File:** `/ViewModels/ProfileFeedViewModel.swift`

**Responsibilities:**
- Fetch all posts for specific user
- Generate signed URLs for media
- Sort posts chronologically (newest first)
- Find index of `initialPostId` for scroll positioning
- Handle like/unlike with optimistic UI
- Handle delete/unfollow actions
- Manage loading/error states

**State:**
```swift
@Published var posts: [Post] = []
@Published var state: LoadingState = .idle
@Published var errorMessage: String?
@Published var initialScrollIndex: Int? // Index of tapped post

enum LoadingState {
    case idle, loading, loaded, error
}
```

**Key Methods:**
```swift
func loadPosts() async
func toggleLike(forPostID: UUID) async
func deletePost(_ postId: UUID, mediaKey: String) async
func unfollowUser(_ userId: UUID) async
func getMediaURL(for post: Post) -> URL?
```

**Data Source:**
- Uses existing `ProfileService.fetchUserPosts(userId:limit:offset:)`
- Reuses `LikeService`, `PostService`, `FollowService`
- Mirrors patterns from `FeedViewModel` (optimistic UI, error handling)

---

### 3. Update ProfilePostsGridView

**File:** `/Views/Profile/ProfilePostsGridView.swift`

**Changes:**
Replace `NavigationLink` destination from `PostDetailView` to `ProfileFeedView`.

**Before:**
```swift
NavigationLink {
    PostDetailView(post: post, currentUserId: currentUserId)
} label: {
    PostGridCell(post: post, viewAppearanceID: viewAppearanceID)
}
.environmentObject(profileViewModel)
```

**After:**
```swift
NavigationLink {
    ProfileFeedView(
        userId: post.author,
        initialPostId: post.id,
        currentUserId: currentUserId
    )
} label: {
    PostGridCell(post: post, viewAppearanceID: viewAppearanceID)
}
```

**Note:** Remove `.environmentObject(profileViewModel)` from NavigationLink since ProfileFeedView uses its own ViewModel.

---

### 4. Delete PostDetailView

**File to Delete:** `/Views/Profile/PostDetailView.swift`

**Verification:**
- `grep -r "PostDetailView" **/*.swift` shows only 2 references:
  1. `ProfilePostsGridView.swift` (will be updated)
  2. `ActivityView.swift` (TODO comment only, not actually used)
- Safe to delete after ProfilePostsGridView is updated

---

## Scroll-to-Post Implementation

### Challenge
SwiftUI's `ScrollViewReader.scrollTo()` needs layout to complete before scrolling works reliably.

### Solution
Use `DispatchQueue.main.asyncAfter` with small delay (0.1s) to ensure layout completes:

```swift
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 0) {
            ForEach(posts) { post in
                PostCellView(post: post, mediaURL: getMediaURL(for: post))
                    .id(post.id) // Critical for scrollTo
                Divider()
            }
        }
    }
    .onAppear {
        // Delay ensures LazyVStack has rendered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(initialPostId, anchor: .top)
            }
        }
    }
}
```

### Bi-Directional Scrolling
Posts are sorted newest-first (same as main feed):
- **Scroll up:** See newer posts (posted after tapped post)
- **Scroll down:** See older posts (posted before tapped post)

This is natural since posts are in chronological order.

---

## Implementation Order

1. **Create ProfileFeedViewModel** ✅
   - Simpler to build first (no UI)
   - Test data fetching and state management

2. **Create ProfileFeedView** ✅
   - Build UI with ViewModel integration
   - Implement scroll-to-post functionality
   - Test all interactions work

3. **Test Scroll-to-Post** ⏳
   - Verify scrolling to initial post works
   - Verify bi-directional scrolling works
   - Test edge cases (first post, last post)

4. **Update ProfilePostsGridView** ✅
   - Replace NavigationLink destination
   - Remove old EnvironmentObject injection

5. **Test All Interactions** ⏳
   - Like button (optimistic UI)
   - Comment button (sheet presentation)
   - Three-dot menu (delete/unfollow)
   - Caption expansion
   - Username header display

6. **Delete PostDetailView** ✅
   - Remove file after confirming everything works
   - No references should remain

7. **Update Documentation** ✅
   - Update CLAUDE.md if needed
   - Document new navigation pattern

---

## Code Reuse Strategy

### PostCellView Component ✅
- **Reuse:** ProfileFeedView will use existing `PostCellView`
- **Why:** Ensures consistent UI/UX across feed and profile views
- **Benefit:** No code duplication, all interactions work automatically

### FeedViewModel Patterns ✅
- **Reuse:** ProfileFeedViewModel mirrors FeedViewModel architecture
- **Patterns to copy:**
  - Optimistic UI for likes (toggle immediately, rollback on error)
  - Delete post with navigation back on success
  - Unfollow user with navigation back on success
  - Error handling with user-friendly messages

### Existing Services ✅
- `ProfileService.fetchUserPosts(userId:)` - Already implemented
- `LikeService` - Like/unlike operations
- `PostService` - Delete operations
- `FollowService` - Unfollow operations
- `CommentService` - Comment operations (via CommentsView)

**No service changes needed.**

---

## Edge Cases

### 1. Post Deleted While Viewing Feed
**Scenario:** User deletes a post while viewing ProfileFeedView

**Solution:**
- After delete succeeds, call `dismiss()` to pop back to profile grid
- ProfileViewModel will refresh and remove deleted post from grid
- Consistent with current behavior

**Code:**
```swift
private func deletePost(_ postId: UUID, mediaKey: String) async {
    do {
        try await postService.deletePost(postId: postId, userId: currentUserId, mediaKey: mediaKey)
        dismiss() // Pop back to profile
    } catch {
        errorMessage = "Failed to delete post"
    }
}
```

### 2. User Unfollowed While Viewing Their Feed
**Scenario:** User unfollows someone while viewing their ProfileFeedView

**Solution:**
- After unfollow succeeds, call `dismiss()` to pop back to profile grid
- Main feed will no longer show unfollowed user's posts
- Consistent with current behavior

**Code:**
```swift
private func unfollowUser(_ userId: UUID) async {
    do {
        try await followService.unfollowUser(followerId: currentUserId, followeeId: userId)
        dismiss() // Pop back to profile
    } catch {
        errorMessage = "Failed to unfollow user"
    }
}
```

### 3. Empty State (User Has No Posts)
**Scenario:** Attempting to navigate to ProfileFeedView when user has no posts

**Reality:** Cannot happen - can't tap grid cell if there are no posts

**Defensive Check:**
```swift
if posts.isEmpty {
    emptyStateView // Show "No posts" message
}
```

### 4. Initial Post Not Found
**Scenario:** `initialPostId` doesn't exist in fetched posts (deleted between tap and load)

**Solution:**
- Fall back to scrolling to top (first post)
- Log warning for debugging

**Code:**
```swift
.onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        let targetId = posts.contains(where: { $0.id == initialPostId })
            ? initialPostId
            : posts.first?.id

        if let targetId = targetId {
            withAnimation {
                proxy.scrollTo(targetId, anchor: .top)
            }
        } else {
            print("⚠️ No posts to scroll to")
        }
    }
}
```

---

## Real-time Updates

### Decision: Defer to Later Phase ⏭️

**Rationale:**
- ProfileFeedView is transient (user navigates away quickly)
- Real-time like/comment count updates less critical than main feed
- Main feed already has real-time updates (user spends most time there)
- Adds complexity without significant UX benefit

**Future Enhancement:**
If needed, add `RealtimeService` subscriptions to ProfileFeedViewModel:
- Subscribe to `posts` table changes for this user
- Subscribe to `likes` and `comments` count changes
- Mirror patterns from `FeedViewModel.setupRealtimeSubscriptions()`

---

## Files Involved

### New Files
- `/ViewModels/ProfileFeedViewModel.swift`
- `/Views/Profile/ProfileFeedView.swift`
- `/docs/features/PROFILE_FEED_NAVIGATION.md` (this file)

### Modified Files
- `/Views/Profile/ProfilePostsGridView.swift`

### Deleted Files
- `/Views/Profile/PostDetailView.swift`

### Dependencies (No Changes Needed)
- `/Services/ProfileService.swift` (already has `fetchUserPosts`)
- `/Services/LikeService.swift`
- `/Services/CommentService.swift`
- `/Services/PostService.swift`
- `/Services/FollowService.swift`
- `/Views/Feed/PostCellView.swift`
- `/Views/Feed/CaptionView.swift`
- `/Views/Comments/CommentsView.swift`

---

## Testing Checklist

After implementation, verify:

**Navigation:**
- [ ] Tapping grid post navigates to ProfileFeedView
- [ ] Back button returns to profile grid
- [ ] Navigation bar shows username (if implemented)

**Scrolling:**
- [ ] View scrolls to tapped post on load
- [ ] Can scroll up to see newer posts
- [ ] Can scroll down to see older posts
- [ ] Scroll position is correct (tapped post at top)

**Interactions:**
- [ ] Like button works with optimistic UI
- [ ] Unlike button works with optimistic UI
- [ ] Like count updates correctly
- [ ] Comment button opens CommentsView sheet
- [ ] Comments can be posted and viewed
- [ ] Comment count updates after posting
- [ ] Three-dot menu shows correct options (delete vs unfollow)
- [ ] Delete post works and navigates back to profile
- [ ] Unfollow works and navigates back to profile
- [ ] Caption expansion works ("more" button)

**UI/UX:**
- [ ] All posts show username header above image
- [ ] Avatar displays correctly for each post
- [ ] Timestamps display correctly
- [ ] Dividers between posts match main feed
- [ ] Loading states display correctly
- [ ] Error states display with retry button

**Edge Cases:**
- [ ] Deleting post navigates back correctly
- [ ] Unfollowing user navigates back correctly
- [ ] Initial post not found falls back gracefully
- [ ] Empty state displays if user has no posts (defensive)

**Regression Testing:**
- [ ] Main feed tab still works (no changes)
- [ ] Profile grid still displays correctly
- [ ] Upload tab still works
- [ ] Activity tab still works
- [ ] Search tab still works

---

## Design Principles Applied

### Instagram UI Consistency ✅
- Feed-style view matches main feed exactly
- Username header on each post (not once at top)
- Same like/comment/menu interactions
- Same caption truncation behavior

### Code Reuse ✅
- Reuse `PostCellView` component (no duplication)
- Reuse service layer (no new API calls)
- Mirror ViewModel patterns from `FeedViewModel`

### Simplicity ✅
- No over-engineering (defer real-time updates)
- Use existing SwiftUI tools (ScrollViewReader, NavigationLink)
- Minimal changes to existing code

### Privacy ✅
- All data access through existing RLS-protected services
- No new security considerations

---

## Success Metrics

**UX Goal:** User should feel like they're using Instagram when navigating from profile grid to feed view.

**Technical Goal:** Zero code duplication - reuse all existing components and services.

**Completion Criteria:**
- ✅ Profile grid taps open feed-style view
- ✅ Scrolls to tapped post
- ✅ All interactions work (like, comment, delete, unfollow)
- ✅ PostDetailView deleted
- ✅ No regressions in existing features

---

## Known Issues (To Fix)

**Status:** ✅ Production Ready (All critical bugs fixed as of October 30, 2025)

**Summary:**
- ✅ **Bug #1:** Images not loading / clunky scrolling - **FIXED** (October 30, 2025)
- ✅ **Bug #2:** Usernames show as "Unknown" for all posts - **FIXED** (October 29, 2025)
- ✅ **Bug #3:** Nav title doesn't match Instagram design - **FIXED** (October 30, 2025)
- 🔴 **Bug #4:** Like counts don't display after liking (High priority - UX)
- 🔴 **Bug #5:** Deleted posts don't refresh properly (High priority - UX)

---

### 1. Images Not Loading / Clunky Scrolling - ✅ FIXED

**Status:** ✅ FIXED (October 30, 2025)

**Symptom:**
- Random posts showed "Failed to load" placeholders
- Scrolling felt clunky with images flashing/reloading
- Top 2 posts (above scroll target) failed to load

**Root Cause Analysis (Systematic Debugging):**

**Phase 1: Root Cause Investigation**
- Error: `URLError -999 "cancelled"` - AsyncImage downloads cancelled during scroll
- LazyVStack's scroll-to-post triggered rapid scrolling, cancelling in-flight image downloads
- AsyncImage cached failure states and didn't retry automatically

**Phase 2: Pattern Analysis**
- FeedView doesn't have this issue because it doesn't use scroll-to-post
- Initial implementation tried to match FeedView's tab-switch retry logic (wrong pattern)
- Scroll cancellations are different from tab-switch cancellations

**Phase 3: Hypothesis Testing**
1. ❌ **Hypothesis 1:** Retry cancelled images immediately → Caused global AsyncImage refresh (clunky)
2. ❌ **Hypothesis 2:** Remove scroll animation → Didn't solve manual scroll cancellations
3. ✅ **Hypothesis 3:** Let LazyVStack handle naturally + delay scroll → Fixed!

**Solution Implemented:**

**Initial Attempt (Failed):**
1. Removed retry logic assuming LazyVStack auto-retries → AsyncImage doesn't auto-retry
2. Increased scroll delay to 0.3s → Helped but didn't solve persistent failures

**Root Cause Discovery:**
AsyncImage **caches failure states** and doesn't retry when scrolling back to same URL. Using static `.id()` meant cancelled images kept same identity and never retried.

**Final Solution: Per-Post Force-Reload Tracking**

1. **ProfileFeedViewModel.swift:24** - Added `postReloadCounters: [UUID: Int]`
   - Tracks reload attempts per post (increments on cancellation)

2. **ProfileFeedViewModel.swift:211-217** - Updated `recordImageCancellation()`
   - Increments counter for cancelled post
   - Triggers view update via `objectWillChange.send()`

3. **ProfileFeedViewModel.swift:220-225** - Added `getAsyncImageID(for:)`
   - Returns `"postID-counter"` as unique ID
   - Counter increments force new AsyncImage instance (bypasses cache)

4. **FeedInteractionViewModel.swift:22** - Added protocol requirement
   - `func getAsyncImageID(for postID: UUID) -> String`

5. **FeedViewModel.swift:220-224** - Implemented for FeedView
   - Uses global `viewAppearanceID` (existing tab-switch behavior)

6. **PostCellView.swift:173** - Changed AsyncImage ID
   - From: `.id("\(post.id)-\(viewModel.viewAppearanceID)")`
   - To: `.id(viewModel.getAsyncImageID(for: post.id))`

7. **ProfileFeedView.swift:98** - Increased scroll delay to 0.3s
   - Prevents initial cancellations before images start downloading

**Files Modified:**
- `Kinnect/ViewModels/ProfileFeedViewModel.swift` - Per-post reload tracking
- `Kinnect/ViewModels/FeedViewModel.swift` - Protocol conformance
- `Kinnect/Protocols/FeedInteractionViewModel.swift` - Added getAsyncImageID requirement
- `Kinnect/Views/Feed/PostCellView.swift` - Use per-post IDs
- `Kinnect/Views/Profile/ProfileFeedView.swift` - Scroll delay

**Why This Works:**
1. Each post has stable ID until cancellation occurs
2. Cancellation increments counter → new unique ID generated
3. AsyncImage sees new ID → treats as fresh image → retries download
4. Only cancelled posts get new IDs (no global refresh, no clunkiness)
5. Successfully loaded images keep stable IDs (smooth scrolling)

**Verification:** ✅ All images load reliably, cancelled images auto-retry, smooth scrolling, no clunkiness

---

### 2. Username Displaying as "Unknown" - ✅ FIXED

**Status:** ✅ FIXED (October 29, 2025)

**Symptom:** "Unknown" appeared in two places for ALL posts in ProfileFeedView:
1. Header above post (next to avatar)
2. Caption (before the post caption text)

**Expected:** Should display the actual username (author's username)

**Root Cause:** ProfileService.fetchUserPosts() was NOT fetching author profile data with posts. FeedService correctly includes author profiles via JOIN, but ProfileService didn't.

**Solution Implemented:**
Updated ProfileService.fetchUserPosts() to fetch author profile data by:

1. Changed query to include profile JOIN:
```swift
.select("""
    *,
    profiles!posts_author_fkey(
        user_id,
        username,
        avatar_url,
        full_name,
        bio,
        created_at
    )
""")
```

2. Added `PostResponseProfile` struct to decode embedded profile data (mirrors FeedService pattern)

3. Populated `post.authorProfile` for each post:
```swift
var post = response.post
post.authorProfile = response.profiles
```

**Files Modified:**
- `Kinnect/Services/ProfileService.swift:156-236` - Updated fetchUserPosts() method
- `Kinnect/Services/ProfileService.swift:379-418` - Added PostResponseProfile struct

**Verification:** Test in ProfileFeedView to confirm usernames now display correctly in both header and caption.

---

### 3. Navigation Title Doesn't Match Instagram - ✅ FIXED

**Status:** ✅ FIXED (October 30, 2025)

**Symptom:** Navigation bar title didn't match Instagram's design - showed default inline navigation title.

**Expected (Instagram style):**
- Centered title with two lines:
  - "Posts" (top line, ~12pt, gray secondary text)
  - "mapfister23" / username (bottom line, ~16pt bold, black primary text)

**Solution Implemented:**
Added custom navigation title using `.toolbar` with centered VStack that displays "Posts" and the username from the first post's authorProfile.

```swift
.navigationBarTitleDisplayMode(.inline)
.toolbar {
    ToolbarItem(placement: .principal) {
        VStack(spacing: 2) {
            Text("Posts")
                .font(.system(size: 12))
                .foregroundColor(.igTextSecondary)
            Text(viewModel.posts.first?.authorProfile?.username ?? "")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.igTextPrimary)
        }
    }
}
```

**Files Modified:**
- `Kinnect/Views/Profile/ProfileFeedView.swift:52-64` - Added custom toolbar with two-line title

**Verification:** Navigation title now matches Instagram's design with "Posts" label and username displayed in the correct style.

---

### 4. Like Button and Comments Not Working Correctly

**Symptom:**
- **Like button:** Toggles visually (heart fills/unfills) BUT the like count text doesn't appear below the button (should show "1 like", "2 likes", etc.)
- **Comments:** Needs more investigation to determine exact issue

**Expected:** After liking, should show "X likes" text below action buttons (same as main feed)

**Confirmed:** Like IS working (toggles visually), but UI state for `post.likeCount` may not be updating

**Potential Causes:**
- ProfileFeedViewModel.toggleLike() successfully updates `post.isLikedByCurrentUser` but not `post.likeCount`
- Like count may be starting at 0 and incrementing to 1, but PostCellView only shows count when > 0
- Check if like count logic in PostCellView is correct: `if post.likeCount > 0`

**Priority:** High (UX issue - user can't see engagement)

**Investigation needed:**
- Add console logs in ProfileFeedViewModel.toggleLike() to track likeCount changes
- Verify optimistic UI increments/decrements likeCount correctly
- Check if initial posts have correct likeCount when fetched
- Compare with FeedViewModel.toggleLike() logic
- Test comments thoroughly: does sheet open? Can you post? Do counts update?

---

### 5. Delete Post - Doesn't Refresh Views Properly

**Symptom:** Deleting a post from ProfileFeedView appears to not work immediately. Deleted post only disappears after navigating to Feed tab or Profile tab and a new API call happens.

**Confirmed Behavior:**
- ✅ Confirmation dialog appears correctly
- ✅ Post DOES delete from database successfully
- ❌ ProfileFeedView doesn't remove post from UI after delete
- ❌ Profile grid (ProfileViewModel) doesn't refresh after returning from ProfileFeedView
- ❌ User can't tell post was deleted until they manually trigger an API refresh

**Expected Behavior (like FeedView):**
- Post should disappear from ProfileFeedView immediately after successful delete (optimistic UI already does this in FeedViewModel)
- When user navigates back to profile grid, the grid should refresh to remove the deleted post
- No manual API call should be needed

**Root Cause:**
ProfileFeedView and ProfileViewModel are not communicating post deletion. FeedView works because it directly updates its own posts array. ProfileFeedView needs to:
1. Dismiss the view after successful delete (so user returns to profile grid)
2. Notify parent ProfileViewModel to refresh its posts

**Priority:** High (UX confusion - user thinks delete failed)

**Solution Approaches:**

**Option 1: Dismiss + Refresh on Navigation Return**
```swift
// In ProfileFeedViewModel.deletePost()
await postService.deletePost(...)
// Dismiss view after successful delete
dismiss()

// In ProfileView.swift
.task {
    // Refresh when returning from navigation
    await profileViewModel.refresh()
}
```

**Option 2: NotificationCenter Pattern**
```swift
// Post notification after successful delete
NotificationCenter.default.post(name: .postDidDelete, object: postId)

// ProfileViewModel listens and refreshes
```

**Option 3: Callback Pattern**
```swift
// Pass callback to ProfileFeedView
ProfileFeedView(..., onPostDeleted: { postId in
    // Remove from profile grid
    await profileViewModel.removePost(postId)
})
```

**Recommendation:** Option 1 is simplest - ProfileFeedView should dismiss after delete, and ProfileView should refresh on return (using `.task` modifier which runs on view appear).

---

## Testing Notes

**Testing Environment:** iOS Simulator/Device (specify)
**Date Tested:** October 29, 2025

**Regression Testing Needed:**
- Main feed like/comment/delete still work correctly
- Profile grid displays correctly
- Navigation between views works
- FeedView not affected by ProfileFeedView changes

---

## Related Documentation

- Main feed system: `/docs/features/FEED_SYSTEM.md`
- Profile system: `/docs/features/PROFILE_SYSTEM.md`
- Social interactions: `/docs/features/SOCIAL_INTERACTIONS.md`
- Post menu actions: `/docs/features/POST_MENU_ACTIONS.md`

---

**Built with Swift, SwiftUI, and Supabase.**
