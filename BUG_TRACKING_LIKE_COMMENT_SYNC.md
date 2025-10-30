# Bug Tracking: Like/Comment Synchronization Issues

**Date Discovered:** October 30, 2025
**Status:** 🔴 Active - Needs Fix

---

## Bug #1: ProfileFeedView Not Receiving Like/Comment Updates from FeedView

### Symptom:
- ✅ FeedView correctly receives and displays likes/comments from ProfileFeedView
- ❌ ProfileFeedView does NOT receive or display likes/comments from FeedView
- User must close/reopen app to see updates in ProfileFeedView

### Current State:
**Implemented (October 30, 2025):**
- ✅ Added `.userDidLikePost`, `.userDidUnlikePost`, `.userDidCommentOnPost` notifications
- ✅ FeedViewModel posts notifications after like/unlike/comment
- ✅ ProfileFeedViewModel posts notifications after like/unlike/comment
- ✅ CommentViewModel posts notification after comment
- ✅ FeedViewModel listens for notifications (lines 159-230)
- ✅ ProfileFeedViewModel listens for notifications (lines 71-127)

**Problem:**
ProfileFeedViewModel listeners are set up correctly but NOT receiving notifications from FeedView.

### Root Cause (To Investigate):
Possible causes:
1. ProfileFeedView might not be instantiated/listening when FeedView posts notification
2. ProfileFeedView may be getting deallocated before receiving notifications
3. Notification observers may not be persisting across view lifecycle
4. Main thread queueing issue

### Priority:
High - Affects UX consistency across views

---

## Bug #2: Double-Liking in FeedView (and sometimes ProfileFeedView)

### Symptom:
When liking a post, the like count increments by **2** instead of **1**. This happens in:
- FeedView: Consistently
- ProfileFeedView: Sometimes

### Console Logs (FeedView Double-Like):

```
❤️ Toggling like on post 4B397180-3346-42CC-9FCF-9EDFB1FD45CF for user 69E9169A-9DAF-49D2-AA23-B834805C1F6E
❤️ Like - adding like to database
✅ Like inserted successfully
✅ Like toggled successfully: liked
📡 FeedViewModel received like notification for post: 4B397180-3346-42CC-9FCF-9EDFB1FD45CF
✅ Updated like in FeedViewModel for post: 4B397180-3346-42CC-9FCF-9EDFB1FD45CF
📡 ProfileFeedViewModel received like notification for post: 4B397180-3346-42CC-9FCF-9EDFB1FD45CF
✅ Updated like in ProfileFeedViewModel for post: 4B397180-3346-42CC-9FCF-9EDFB1FD45CF
📡 Posted userDidLikePost notification for post: 4B397180-3346-42CC-9FCF-9EDFB1FD45CF
📡 Ignoring own like event (handled optimistically)
```

### Root Cause Analysis:

**The Issue: Self-Notification Double-Count**

1. **FeedViewModel.toggleLike() execution flow:**
   - Line 498-499: **Optimistic update** - `posts[index].likeCount += 1` (FIRST increment)
   - Line 509-513: Async API call succeeds
   - Line 531-537: **Posts notification** - `NotificationCenter.default.post(name: .userDidLikePost, object: postID)`

2. **FeedViewModel listener receives its OWN notification:**
   - Lines 159-182: Listener triggered by notification
   - Line 173: `posts[index].likeCount += 1` (SECOND increment - **DOUBLE COUNT**)

3. **Why this happens:**
   - The ViewModel that POSTS the notification also LISTENS to it
   - No guard clause to skip self-notifications
   - NotificationCenter delivers to ALL observers, including the sender

### Expected Flow vs. Actual Flow:

**Expected (Correct):**
```
FeedView likes post
├─ Optimistic UI: +1 like count (FeedViewModel only)
├─ API success
├─ Post notification
└─ ProfileFeedView receives notification: +1 like count (ProfileFeedViewModel only)
Result: FeedView = +1, ProfileFeedView = +1 ✅
```

**Actual (Bug):**
```
FeedView likes post
├─ Optimistic UI: +1 like count (FeedViewModel)
├─ API success
├─ Post notification
│   ├─ FeedViewModel receives own notification: +1 like count AGAIN
│   └─ ProfileFeedViewModel receives notification: +1 like count
Result: FeedView = +2 ❌, ProfileFeedView = +1 ✅
```

### Why Realtime Doesn't Have This Problem:

**Realtime handlers ALREADY have self-skip logic:**

```swift
// FeedViewModel.swift:701-703 (like insert handler)
guard userId != currentUserId else {
    print("📡 Ignoring own like event (handled optimistically)")
    return
}
```

Realtime skips current user's actions because they're handled optimistically. We need the SAME pattern for NotificationCenter.

---

## Solution: Skip Self-Notifications

### Pattern to Implement:

**Option 1: Pass ViewModel ID in notification object (Recommended)**

Change notification to include source ViewModel identifier:

```swift
// When posting notification
struct LikeNotification {
    let postId: UUID
    let sourceViewModel: String // "FeedViewModel", "ProfileFeedViewModel"
}

NotificationCenter.default.post(
    name: .userDidLikePost,
    object: LikeNotification(postId: postID, sourceViewModel: "FeedViewModel")
)

// When listening
NotificationCenter.default.addObserver(...) { [weak self] notification in
    guard let self = self,
          let likeNotif = notification.object as? LikeNotification,
          likeNotif.sourceViewModel != "FeedViewModel" // Skip if from self
    else { return }

    // Update like count...
}
```

**Option 2: Track in-progress like operations (Alternative)**

```swift
// Add to ViewModel
private var inProgressLikes: Set<UUID> = []

// In toggleLike()
inProgressLikes.insert(postID)
// ... API call ...
inProgressLikes.remove(postID)

// In listener
guard !inProgressLikes.contains(postId) else { return }
```

---

## Files Affected:

**Modified (October 30, 2025):**
- `Kinnect/Utilities/Extensions/Notification+Extensions.swift` - Added notifications
- `Kinnect/ViewModels/FeedViewModel.swift` - Posts and listens to notifications
- `Kinnect/ViewModels/ProfileFeedViewModel.swift` - Posts and listens to notifications
- `Kinnect/ViewModels/CommentViewModel.swift` - Posts comment notification

**Need to Fix:**
- `Kinnect/ViewModels/FeedViewModel.swift` - Add self-skip logic to listeners
- `Kinnect/ViewModels/ProfileFeedViewModel.swift` - Add self-skip logic to listeners
- Potentially create `LikeNotification`, `CommentNotification` structs for notification payloads

---

## Testing Checklist (After Fix):

### Like Synchronization:
- [ ] Like in FeedView → ProfileFeedView updates immediately
- [ ] Like in ProfileFeedView → FeedView updates immediately
- [ ] Like count increments by exactly 1 (not 2)
- [ ] Unlike decrements by exactly 1 (not 2)

### Comment Synchronization:
- [ ] Comment in FeedView → ProfileFeedView "view all X comments" updates
- [ ] Comment in ProfileFeedView → FeedView "view all X comments" updates
- [ ] Comment count increments by exactly 1

### No Double-Counting:
- [ ] Like in FeedView: count += 1 only
- [ ] Like in ProfileFeedView: count += 1 only
- [ ] Unliking reverses correctly without going negative
- [ ] Multiple rapid likes/unlikes don't cause count drift

### Console Logs Should Show:
```
✅ Like toggled successfully: liked
📡 Posted userDidLikePost notification for post: [UUID]
📡 ProfileFeedViewModel received like notification (skipped own notification)
✅ Updated like in ProfileFeedViewModel for post: [UUID]
```

NOT:
```
📡 FeedViewModel received like notification (should be skipped!)
✅ Updated like in FeedViewModel (DOUBLE COUNT)
```

---

## Priority:

**Bug #1 (ProfileFeedView not receiving updates):** High - UX consistency issue
**Bug #2 (Double-liking):** Critical - Data integrity issue (incorrect counts)

**Recommended Order:**
1. Fix Bug #2 first (double-counting is more severe)
2. Then investigate Bug #1 (may be related to Bug #2 fix)

---

## Related Issues:

- ✅ **Fixed (October 30):** Post deletion synchronization (Bug #5)
- ✅ **Fixed (October 30):** Post creation synchronization
- 🔴 **Active:** Like/comment synchronization issues (this document)

---

**Next Session Action Items:**
1. Implement self-skip logic for NotificationCenter observers (Option 1 recommended)
2. Test that ProfileFeedView properly receives notifications after fix
3. Verify no double-counting in any scenario
4. Update this document with fix details and mark as resolved
