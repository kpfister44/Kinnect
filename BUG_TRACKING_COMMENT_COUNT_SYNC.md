# Bug Tracking: Comment Count Synchronization Issues

**Date Discovered:** October 31, 2025
**Date Fixed:** November 1, 2025
**Status:** ✅ FIXED

---

## Fix Summary (November 1, 2025)

### Root Cause
Comment counts failed to update in the current feed because:
1. **Callback mechanism was not implemented** - PostCellView had empty no-op callback
2. **Self-notifications were skipped** - But no optimistic update ever happened
3. **Realtime had no self-skip** - Caused random double-counting

This created a broken flow where the current feed never updated (no callback + self-skip notification), while other feeds updated correctly (received notifications).

### Solution Applied
Mirrored the working likes pattern exactly:

**Files Modified:**
1. **FeedInteractionViewModel.swift** - Added `updateCommentCount(for:newCount:)` method to protocol
2. **FeedViewModel.swift** - Implemented `updateCommentCount()` and added userId self-skip to realtime handlers
3. **ProfileFeedViewModel.swift** - Implemented `updateCommentCount()`
4. **PostCellView.swift** - Changed callback from empty no-op to `viewModel.updateCommentCount(for: post.id, newCount: newCount)`

**Result:** Comments now follow the exact same pattern as likes:
- ✅ Callback updates current feed immediately (optimistic)
- ✅ Notifications self-skip (already updated by callback)
- ✅ Notifications update other feeds (cross-feed sync)
- ✅ Realtime self-skips (prevents double-counting)

### Testing Results
All scenarios working:
- ✅ Add comment in FeedView → count updates immediately
- ✅ Add comment in ProfileFeedView → count updates immediately
- ✅ Delete comment in FeedView → count decrements immediately
- ✅ Delete comment in ProfileFeedView → count decrements immediately
- ✅ Cross-feed sync working (both directions)
- ✅ No double-counting in any scenario

**Console logs confirmed:**
- Callback updates happening: "✅ Updated comment count to X"
- Self-skip working: "⏭️ [ViewModel] skipping own comment notification"
- Cross-feed sync working: "📡 [ViewModel] received comment notification from [OtherViewModel]"

---

## Current State (After Bug #2 & #3 Fixes)

### What's Working ✅
- Like/unlike synchronization works perfectly (Bug #2 FIXED)
- No double-counting on likes
- Cross-feed like synchronization works in both directions

### What's Broken ❌
**Comment count synchronization is now incorrect after attempting to fix comment deletion sync**

---

## Bug Symptoms

**Before the fix attempt:**
- ✅ Adding comments: "View all X comments" updated correctly in both feeds
- ❌ Deleting comments: Count only updated in the OTHER feed, not the current feed

**After the fix attempt (Current State):**
- ❌ Adding comments: Count not updating correctly in "View all X comments" string
- ❌ Deleting comments: Count not updating correctly in "View all X comments" string
- ✅ Opening comments sheet shows correct number of comments (data is accurate)

**Key Observation:** The underlying comment data is correct, but the UI text "View all X comments" is not syncing properly.

---

## What We Changed (Session on Oct 31, 2025)

### Files Modified:

#### 1. **Notification+Extensions.swift**
**Added:**
```swift
/// Posted when user deletes a comment - used to sync comment counts across ViewModels
static let userDidDeleteComment = Notification.Name("userDidDeleteComment")
```

**Location:** Line 32-33

---

#### 2. **CommentViewModel.swift**
**Modified:** `deleteComment()` function

**Added notification posting:**
```swift
// Notify other ViewModels about comment deletion (with source to prevent self-notification)
let payload = CommentNotificationPayload(postId: postId, source: source)
NotificationCenter.default.post(name: .userDidDeleteComment, object: payload)
print("📡 Posted userDidDeleteComment notification for post: \(postId) from \(source.rawValue)")
```

**Location:** Lines 155-158

---

#### 3. **FeedViewModel.swift**
**Added listener for comment deletions:**

```swift
// Listen for comment deletions from other views
NotificationCenter.default.addObserver(
    forName: .userDidDeleteComment,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let self = self,
          let payload = notification.object as? CommentNotificationPayload else { return }

    // Skip self-notifications (already handled optimistically)
    guard payload.source != .feedViewModel else {
        print("⏭️ FeedViewModel skipping own comment deletion notification for post: \(payload.postId)")
        return
    }

    print("📡 FeedViewModel received comment deletion notification from \(payload.source.rawValue) for post: \(payload.postId)")

    // Update comment count
    if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
        self.posts[index].commentCount = max(0, self.posts[index].commentCount - 1)
        print("✅ Decremented comment count in FeedViewModel for post: \(payload.postId)")
    }

    // Update cache as well
    if let cacheIndex = self.cachedPosts.firstIndex(where: { $0.id == payload.postId }) {
        self.cachedPosts[cacheIndex].commentCount = max(0, self.cachedPosts[cacheIndex].commentCount - 1)
    }
}
```

**Location:** Lines 253-280 (inside `setupLogoutObserver()`)

---

#### 4. **ProfileFeedViewModel.swift**
**Added listener for comment deletions:**

```swift
// Listen for comment deletions from other views
NotificationCenter.default.addObserver(
    forName: .userDidDeleteComment,
    object: nil,
    queue: .main
) { [weak self] notification in
    guard let self = self,
          let payload = notification.object as? CommentNotificationPayload else { return }

    // Skip self-notifications (already handled optimistically)
    guard payload.source != .profileFeedViewModel else {
        print("⏭️ ProfileFeedViewModel skipping own comment deletion notification for post: \(payload.postId)")
        return
    }

    print("📡 ProfileFeedViewModel received comment deletion notification from \(payload.source.rawValue) for post: \(payload.postId)")

    // Update comment count
    if let index = self.posts.firstIndex(where: { $0.id == payload.postId }) {
        self.posts[index].commentCount = max(0, self.posts[index].commentCount - 1)
        print("✅ Decremented comment count in ProfileFeedViewModel for post: \(payload.postId)")
    }
}
```

**Location:** Lines 149-171 (inside `setupNotificationObservers()`)

---

## Root Cause Analysis (To Investigate)

### Hypothesis #1: Callback vs Notification Conflict
**Observation:** `CommentViewModel` uses BOTH:
1. `onCommentCountChanged()` callback (line 145 in `deleteComment()`, line 110 in `postComment()`)
2. NotificationCenter notifications (for cross-feed sync)

**Potential Issue:**
- Callback updates the LOCAL view immediately
- Notification might be ALSO updating the local view (double-counting or skipped updates)
- The self-skip logic might be preventing NECESSARY updates to the current view

**Files to check:**
- `CommentViewModel.swift` - Lines 110, 145 (callback calls)
- `PostCellView.swift` - Lines 95-97 (empty callback implementation)

---

### Hypothesis #2: Empty Callback in PostCellView
**Current Code (PostCellView.swift:95-97):**
```swift
onCommentCountChanged: { _ in
    // Comment count updates handled by notification/realtime
}
```

**Problem:** The callback does NOTHING. This means:
- When CommentViewModel calls `onCommentCountChanged(comments.count)`, nothing happens
- The post's comment count in the ViewModel is ONLY updated via notifications
- But self-notifications are SKIPPED, so the current view never updates

**Solution might be:**
Either:
1. Remove the callback entirely and rely ONLY on notifications (but don't skip self-notifications for comment count)
2. OR: Keep callback and use it to update the local post, remove notifications for comment counts

---

### Hypothesis #3: Realtime vs Notification Overlap
**Observation:** Comment counts are updated by:
1. **Optimistic UI** - `CommentViewModel` callback
2. **Notifications** - Cross-feed sync (with self-skip)
3. **Realtime** - `handleCommentInsertEvent`, `handleCommentDeleteEvent` (lines 876, 915 in FeedViewModel)

**Potential Issue:**
- Realtime handlers DON'T have self-skip logic for comments (only for likes at line 835)
- This might cause the current user's comment actions to be counted TWICE:
  - Once from callback/notification
  - Once from Realtime

**Code to check:**
```swift
// FeedViewModel.swift:876-888 - No self-skip!
private func handleCommentInsertEvent(postId: UUID) async {
    // Update posts array
    if let index = posts.firstIndex(where: { $0.id == postId }) {
        posts[index].commentCount += 1
    }
    // ...
}
```

**Compare to like handler (has self-skip):**
```swift
// FeedViewModel.swift:835-838
private func handleLikeInsertEvent(postId: UUID, userId: UUID) async {
    // Skip if current user (already handled optimistically in toggleLike)
    guard userId != currentUserId else {
        print("📡 Ignoring own like event (handled optimistically)")
        return
    }
    // ...
}
```

---

## Investigation Steps for Next Session

### Step 1: Check Console Logs
Run the app and check what notifications/events fire when commenting:

**Expected logs for "add comment":**
```
✅ Comment posted successfully
📡 Posted userDidCommentOnPost notification for post: [UUID] from [Source]
⏭️ [Source]ViewModel skipping own comment notification for post: [UUID]
📡 Comment added to post [UUID]  <-- Realtime event (POTENTIAL PROBLEM)
```

**Question:** Is Realtime ALSO incrementing the count after the optimistic update?

---

### Step 2: Add Diagnostic Logging
Add logging to see the flow:

**In CommentViewModel.swift - postComment():**
```swift
// After line 110
print("🔧 [DEBUG] Calling onCommentCountChanged with count: \(comments.count)")
onCommentCountChanged(comments.count)
```

**In PostCellView.swift - callback:**
```swift
onCommentCountChanged: { newCount in
    print("🔧 [DEBUG] PostCellView callback received newCount: \(newCount)")
    // Currently does nothing - is this the problem?
}
```

---

### Step 3: Check Realtime Comment Handlers
**Verify if Realtime needs self-skip logic like likes have:**

Current code (FeedViewModel.swift:876-888):
```swift
private func handleCommentInsertEvent(postId: UUID) async {
    // Update posts array
    if let index = posts.firstIndex(where: { $0.id == postId }) {
        posts[index].commentCount += 1
    }
    // ...
}
```

**Should it be:**
```swift
private func handleCommentInsertEvent(postId: UUID, userId: UUID) async {
    // Skip if current user (already handled optimistically)
    guard userId != currentUserId else {
        print("📡 Ignoring own comment event (handled optimistically)")
        return
    }
    // Update posts array
    if let index = posts.firstIndex(where: { $0.id == postId }) {
        posts[index].commentCount += 1
    }
    // ...
}
```

**Problem:** The Realtime subscription for comments might not include `user_id` in the payload. Need to check:
- `RealtimeService.swift` - `subscribeToCommentInserts()` method
- Does it provide userId in the event?

---

## Possible Solutions

### Solution A: Use Callback Only (Remove Notifications for Comments)
1. Remove `.userDidCommentOnPost` and `.userDidDeleteComment` notifications
2. Remove listeners in FeedViewModel/ProfileFeedViewModel
3. Implement the callback in PostCellView to directly update the post:
```swift
onCommentCountChanged: { newCount in
    // Direct update to post in parent ViewModel
    viewModel.updateCommentCount(for: post.id, newCount: newCount)
}
```
4. Add `updateCommentCount()` method to FeedInteractionViewModel protocol

**Pros:** Simpler, no notification complexity
**Cons:** Requires protocol change, more coupling

---

### Solution B: Use Notifications Only (Remove Callback, Don't Skip Self-Notifications)
1. Remove `onCommentCountChanged` callback from CommentViewModel
2. Keep notifications but DON'T skip self-notifications for comments
3. Remove optimistic updates from CommentViewModel (rely on notification)

**Pros:** Consistent with cross-feed sync
**Cons:** Slight delay in UI update (wait for API response)

---

### Solution C: Fix Realtime Self-Skip for Comments
1. Keep current notification system
2. Add self-skip logic to Realtime comment handlers (like likes have)
3. Ensure Realtime includes userId in comment events
4. Fix PostCellView callback to actually update the post

**Pros:** Mirrors the working like/unlike pattern
**Cons:** Most complex, requires Realtime changes

---

## Related Working Code (Reference)

### Likes Work Correctly - Here's How:

**FeedViewModel.swift - toggleLike():**
```swift
// Line 570-572: Optimistic update
posts[index].isLikedByCurrentUser.toggle()
posts[index].likeCount += posts[index].isLikedByCurrentUser ? 1 : -1

// Line 606-614: Post notification AFTER API success
let payload = LikeNotificationPayload(postId: postID, source: .feedViewModel)
NotificationCenter.default.post(name: .userDidLikePost, object: payload)
```

**FeedViewModel.swift - Notification Listener:**
```swift
// Line 169-172: Skip self-notifications
guard payload.source != .feedViewModel else {
    print("⏭️ FeedViewModel skipping own like notification")
    return
}
// Only other ViewModels update their counts
```

**FeedViewModel.swift - Realtime Listener:**
```swift
// Line 835-838: Skip own events
guard userId != currentUserId else {
    print("📡 Ignoring own like event (handled optimistically)")
    return
}
```

**Key Pattern:** THREE places skip self-updates:
1. Optimistic update (immediate)
2. Notification listener (skip self)
3. Realtime listener (skip self)

**Comments DON'T follow this pattern - that's the bug!**

---

## Priority: High

This regression broke working functionality. The fix needs to:
1. Restore correct comment counting
2. Maintain the fixes for Bug #1 (cross-feed sync) and Bug #2 (no double-counting)

---

## Debugging Checklist for Next Session

- [ ] Add diagnostic logging to `onCommentCountChanged` callback
- [ ] Add diagnostic logging to PostCellView callback
- [ ] Check if Realtime comment events include userId
- [ ] Verify if Realtime is double-counting comments
- [ ] Decide on Solution A, B, or C based on findings
- [ ] Test thoroughly after fix:
  - [ ] Add comment in FeedView → count updates immediately
  - [ ] Add comment in ProfileFeedView → count updates immediately
  - [ ] Delete comment in FeedView → count decrements immediately
  - [ ] Delete comment in ProfileFeedView → count decrements immediately
  - [ ] Cross-feed sync works (add in Feed, check in Profile)
  - [ ] No double-counting in any scenario

---

**Next Action:** Start with diagnostic logging to understand the exact flow of comment count updates.
