# Session Summary - October 31, 2025

## Accomplishments ✅

### Bug #1: ProfileFeedView Not Showing Like/Comment Counts - FIXED ✅

**Problem:** ProfileFeedView always showed 0 likes and 0 comments, even though data existed.

**Root Cause:** `ProfileService.fetchUserPosts()` wasn't fetching like/comment counts or `isLikedByCurrentUser` status at all. It only fetched post data and author profiles, leaving counts at their default values (0).

**Solution:**
- Updated `ProfileService.fetchUserPosts()` to fetch:
  - Like counts (via COUNT query)
  - Comment counts (via COUNT query)
  - `isLikedByCurrentUser` status (via EXISTS query)
- Mirrored the pattern from `FeedService.fetchFeed()`
- Added `currentUserId` parameter to determine like status

**Files Modified:**
- `ProfileService.swift` (lines 150-291) - Added concurrent fetching of counts
- `ProfileViewModel.swift` (line 304) - Pass currentUserId parameter
- `ProfileFeedViewModel.swift` (line 143) - Pass currentUserId parameter

**Verification:** ✅ ProfileFeedView now correctly displays like/comment counts!

---

### Bug #2: Double-Counting Likes/Comments - FIXED ✅

**Problem:**
- Liking a post in FeedView incremented count by **2** instead of 1
- Same issue with unliking, commenting
- Switching to other feed showed correct count
- Returning to original feed still showed wrong count

**Root Cause:** ViewModels were receiving their OWN notifications, causing:
```
FeedView likes post
├─ Optimistic UI: +1 like count
├─ API success
├─ Post notification
│   ├─ FeedViewModel receives own notification: +1 AGAIN (DOUBLE COUNT)
│   └─ ProfileFeedViewModel receives notification: +1
Result: FeedView = +2 ❌, ProfileFeedView = +1 ✅
```

**Solution:** Added source identification to notifications (mirroring Realtime's self-skip pattern):
1. Created `LikeNotificationPayload` and `CommentNotificationPayload` structs with `source` field
2. Added `ViewModelSource` enum (`.feedViewModel`, `.profileFeedViewModel`)
3. Added `viewModelSource` property to `FeedInteractionViewModel` protocol
4. Updated all ViewModels to skip self-notifications:
   ```swift
   guard payload.source != .feedViewModel else {
       print("⏭️ Skipping own notification")
       return
   }
   ```

**Files Modified:**
- `Notification+Extensions.swift` - Added payload structs and ViewModelSource enum
- `FeedInteractionViewModel.swift` - Added viewModelSource property
- `FeedViewModel.swift` - Added source property, updated posting & listeners
- `ProfileFeedViewModel.swift` - Added source property, updated posting & listeners
- `CommentViewModel.swift` - Added source parameter, post with source
- `CommentsView.swift` - Accept and pass source parameter
- `PostCellView.swift` - Pass viewModel.viewModelSource to CommentsView

**Verification:** ✅ Like/unlike now increments by exactly 1, no double-counting!

---

## Current Issue 🔴

### Bug #3: Comment Count Synchronization Broken

**Problem:** After attempting to fix comment deletion sync:
- Adding comments: "View all X comments" not updating correctly
- Deleting comments: "View all X comments" not updating correctly
- Opening comments sheet shows CORRECT count (data is fine, UI text is wrong)

**What Was Attempted:**
- Added `.userDidDeleteComment` notification
- Added listeners in FeedViewModel and ProfileFeedViewModel
- `CommentViewModel.deleteComment()` now posts notification

**Why It Broke:**
Likely conflict between:
1. `onCommentCountChanged()` callback (used by CommentViewModel)
2. NotificationCenter notifications (for cross-feed sync)
3. Realtime comment events (may not have self-skip logic like likes do)

**Full Analysis:** See `/BUG_TRACKING_COMMENT_COUNT_SYNC.md`

---

## Files Modified This Session

### Core Changes:
1. `Kinnect/Services/ProfileService.swift` - Fetch like/comment counts
2. `Kinnect/ViewModels/ProfileViewModel.swift` - Pass currentUserId
3. `Kinnect/ViewModels/ProfileFeedViewModel.swift` - Pass currentUserId, add source property
4. `Kinnect/ViewModels/FeedViewModel.swift` - Add source property, self-skip notifications
5. `Kinnect/ViewModels/CommentViewModel.swift` - Add source parameter, post deletion notification
6. `Kinnect/Utilities/Extensions/Notification+Extensions.swift` - Add payload structs
7. `Kinnect/Protocols/FeedInteractionViewModel.swift` - Add viewModelSource property
8. `Kinnect/Views/Feed/CommentsView.swift` - Accept source parameter
9. `Kinnect/Views/Feed/PostCellView.swift` - Pass viewModelSource

### Bug Tracking Documents:
- `BUG_TRACKING_LIKE_COMMENT_SYNC.md` - Updated with fixes and new bug
- `BUG_TRACKING_COMMENT_COUNT_SYNC.md` - NEW: Detailed analysis of Bug #3

---

## Next Session Action Items

### Priority 1: Fix Bug #3 (Comment Count Sync)

**Start with diagnostic logging:**
1. Add logging to `onCommentCountChanged` callback in CommentViewModel
2. Add logging to PostCellView callback (currently empty)
3. Run app and observe notification/callback flow

**Investigate:**
1. Does Realtime include userId in comment events?
2. Is Realtime double-counting comments (no self-skip)?
3. Is the empty callback in PostCellView causing issues?

**Possible Solutions:**
- **Solution A:** Use callback only, remove notifications for comments
- **Solution B:** Use notifications only, don't skip self-notifications
- **Solution C:** Fix Realtime self-skip for comments (mirrors likes)

See detailed investigation steps in `/BUG_TRACKING_COMMENT_COUNT_SYNC.md`

---

## What's Working Now ✅

1. **Likes:** Perfect synchronization, no double-counting ✅
2. **Unlikes:** Perfect synchronization, no double-counting ✅
3. **ProfileFeedView counts:** Shows correct like/comment counts ✅
4. **Cross-feed sync:** Likes sync perfectly between feeds ✅
5. **Post deletion:** Syncs across feeds ✅

## What's Broken 🔴

1. **Comment counts:** "View all X comments" text not updating correctly

---

## Key Learnings

### Pattern That Works (Likes):
1. **Optimistic update** in ViewModel (immediate UI feedback)
2. **Post notification** after API success (with source)
3. **Skip self-notifications** in listener (prevent double-count)
4. **Realtime self-skip** (ignore own events)

### Pattern That Needs Fixing (Comments):
Currently mixing callbacks + notifications + Realtime without proper coordination.

---

## Testing Checklist for Next Session

After fixing Bug #3:
- [ ] Add comment in FeedView → "View all X comments" updates immediately
- [ ] Add comment in ProfileFeedView → "View all X comments" updates immediately
- [ ] Delete comment in FeedView → count decrements immediately
- [ ] Delete comment in ProfileFeedView → count decrements immediately
- [ ] Cross-feed sync: Add in Feed, check in Profile ✅
- [ ] Cross-feed sync: Add in Profile, check in Feed ✅
- [ ] No double-counting when adding comments
- [ ] No double-counting when deleting comments
- [ ] Multiple rapid add/delete operations don't drift count

---

**Good work on Bug #1 and Bug #2! They're solidly fixed. Bug #3 is well-documented for pickup.**
