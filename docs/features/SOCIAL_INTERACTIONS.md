# Social Interactions

**Phase 7: Likes & Comments**
**Completed:** October 23, 2025

---

## Overview

Complete like and comment system with Instagram-style UI, optimistic updates, and full database persistence. Users can like posts with a single tap and engage in conversations through comments.

---

## Architecture

### Like System

#### LikeService.swift

```swift
func toggleLike(postId: UUID, userId: UUID) async throws -> Bool
private func checkLikeExists(postId: UUID, userId: UUID) async throws -> Bool
private func insertLike(postId: UUID, userId: UUID) async throws
private func deleteLike(postId: UUID, userId: UUID) async throws
```

**Smart Toggle Logic:**
1. Check if like exists
2. If exists → Delete (unlike)
3. If not exists → Insert (like)
4. Return new state (true = liked, false = unliked)

**Error Handling:**
Custom `LikeError` enum:
- `databaseError`
- `networkError`

#### FeedViewModel Integration

```swift
func toggleLike(forPostID postID: UUID) async
```

**Optimistic UI Pattern:**
1. Store previous state
2. Update UI immediately (instant feedback)
3. Call API in background
4. On success: Keep UI state
5. On error: Revert UI + show error toast

**Benefits:**
- Instant visual feedback
- App feels responsive even on slow networks
- Graceful error recovery

### Comment System

#### CommentService.swift

```swift
func fetchComments(postId: UUID) async throws -> [Comment]
func addComment(postId: UUID, userId: UUID, body: String) async throws -> Comment
func deleteComment(commentId: UUID, userId: UUID) async throws
```

**Features:**
- Fetches comments with author profiles (via JOIN)
- Oldest-first ordering (conversation flow)
- Character limit: 2,200 (Instagram standard)
- Validation (non-empty, length check)
- Delete protection (only own comments)

#### CommentViewModel

```swift
@Published var comments: [Comment] = []
@Published var loadingState: LoadingState = .idle
@Published var newCommentText = ""
@Published var postingState: PostingState = .idle

func loadComments() async
func postComment() async
func deleteComment(_ comment: Comment) async
```

**State Management:**
- Loading states: idle, loading, loaded, error
- Posting states: idle, posting
- Character counter with limit warning
- Error handling with rollback
- Callback to update parent feed's comment count

---

## Components

### CommentsView

Instagram-style bottom sheet with:

**Navigation Bar:**
- Title: "Comments"
- Close button (X icon, top-right)

**Content Area:**
- Loading state: Spinner
- Empty state: "No comments yet. Be the first!"
- Error state: Message + retry button
- Comment list: ScrollView with LazyVStack
- Dividers between comments (0.5pt, light gray)

**Input Area (Pinned to Bottom):**
- Multi-line text field (1-6 lines, auto-expands)
- Character counter (appears when typing, e.g., "150 characters remaining")
- Red counter when at limit (2,200)
- "Post" button:
  - Blue text when enabled
  - Disabled when empty or over limit
  - Shows "Posting..." during submission
- Keyboard-aware layout (TextField auto-focuses)

### CommentCellView

Individual comment display:

- **Circular avatar** (32x32, left)
- **Username** (bold, 14pt) + comment text (normal, 14pt)
- **Relative timestamp** (e.g., "9s", "5m", "2h", "3d ago")
- **Delete button** (trash icon, red):
  - Only visible for own comments
  - Confirmation not needed (Instagram pattern)

**Layout:**
```
[Avatar] [Username comment text that wraps naturally...]
         [timestamp]                              [trash]
```

### PostCellView Integration

Added comment functionality:

- **Comment button**: Opens CommentsView sheet
- **"View all X comments" link**: Opens CommentsView sheet
- **Local comment count tracking**: Updates when sheet dismisses
- **Sheet presentation**: `.sheet(isPresented: $showingComments)`

**Comment Count Sync:**
Uses callback pattern to update parent:
```swift
CommentsView(
    postId: post.id,
    onCommentCountChanged: { newCount in
        localCommentCount = newCount
    }
)
```

---

## Database Integration

### Likes Table

```sql
CREATE TABLE likes (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);
```

**Composite Primary Key:** Prevents duplicate likes (user can only like post once).

**ON DELETE CASCADE:** Deletes likes when post is deleted.

### Comments Table

```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Fetch with Profiles:**
```sql
SELECT
  comments.*,
  profiles.username,
  profiles.avatar_url,
  profiles.full_name,
  profiles.bio,
  profiles.created_at as profile_created_at
FROM comments
JOIN profiles ON comments.user_id = profiles.user_id
WHERE post_id = $postId
ORDER BY created_at ASC
```

**Important:** Must include ALL Profile fields (including `bio`, `created_at`) to match Codable model, even if not displayed in UI.

---

## Key Features

### Optimistic UI Updates

**Like Button:**
- Toggles red heart immediately
- Updates count instantly
- API call in background
- Reverts on error

**Comments:**
- New comment appears immediately after posting
- Refreshes from server to get real data (timestamp, ID)
- Delete removes comment instantly
- Error handling with rollback

### Character Validation

**Rules:**
- Maximum: 2,200 characters (Instagram standard)
- Minimum: 1 character (non-empty)
- Real-time counter shows remaining characters
- Counter turns red when at limit
- Post button disabled when over limit

### Delete Protection

**Security Layers:**
1. **UI**: Delete button only visible for own comments
2. **Service**: Validates `userId` matches comment author
3. **RLS**: Database policy enforces user can only delete own comments

Users cannot delete others' comments at any layer.

### Profile Integration

Comments display:
- User avatars (from profiles.avatar_url)
- Usernames (from profiles.username)
- Full profile data joined in single query (performance)

### Relative Timestamps

```swift
func relativeTime(from date: Date) -> String {
    let seconds = Date().timeIntervalSince(date)

    if seconds < 60 { return "\(Int(seconds))s" }
    if seconds < 3600 { return "\(Int(seconds / 60))m" }
    if seconds < 86400 { return "\(Int(seconds / 3600))h" }
    if seconds < 604800 { return "\(Int(seconds / 86400))d" }
    return "\(Int(seconds / 604800))w"
}
```

Matches Instagram's timestamp format (e.g., "9s", "5m", "2h").

---

## Bug Fixes

### Missing Profile Fields in Comments ✅ FIXED

**Problem:** Profile decoder expected `created_at` and `bio` fields

**Solution:** Added missing fields to Supabase SELECT query:
```swift
.select("*, profiles(username, avatar_url, full_name, bio, created_at)")
```

**Result:** Comments load with full profile data

### Actor Isolation in CommentViewModel Init ✅ FIXED

**Problem:** Main actor-isolated static property `.shared` in default parameter

**Solution:** Made `commentService` optional parameter, use `?? .shared` in function body:
```swift
init(postId: UUID, commentService: CommentService? = nil) {
    self.commentService = commentService ?? .shared
}
```

**Result:** No actor isolation warnings

### Missing Combine Import ✅ FIXED

**Problem:** `ObservableObject` conformance requires Combine framework

**Solution:** Added `import Combine` to CommentViewModel

**Result:** Clean build, no errors

---

## Important Learnings

### Optimistic UI Pattern

**Best Practice:**
```swift
// 1. Store previous state
let previousState = currentState

// 2. Update UI immediately
currentState = newState

// 3. Call API
Task {
    do {
        try await apiCall()
        // Success: keep UI state
    } catch {
        // 4. Revert on error
        currentState = previousState
        showError()
    }
}
```

This creates responsive UX even on slow networks.

### Supabase Profile Joins

When fetching relationships (comments with author profiles):
- Must include **ALL** fields required by Codable model
- Missing fields cause `keyNotFound` decoding errors
- Include fields like `bio`, `created_at` even if not displayed
- Use `.select("*, profiles(field1, field2, ...)")` syntax

### Comment Count Synchronization

**Callback Pattern:**
```swift
onCommentCountChanged: @escaping (Int) -> Void
```

**Why:**
- Parent (PostCellView) needs to update count
- Child (CommentsView) knows when count changes
- Avoids full feed refresh just for count updates
- Lightweight, efficient communication

### Actor Isolation in Initializers

**Problem:** Can't reference `@MainActor` static properties in default parameters

**Solution:** Use optional parameter + nil coalescing in body:
```swift
init(param: Service? = nil) {
    self.service = param ?? .shared  // ✅ Works
}
```

---

## Testing Results

✅ **Like System:**
- Like button toggles immediately
- Red heart fill/unfill animation
- Like count updates in real-time
- Database persistence verified
- Likes survive app restart
- Error handling with UI rollback working
- Unlike works correctly

✅ **Comment System:**
- Comments load with author profiles
- Oldest-first ordering correct
- Character counter accurate
- Real-time character limit warning (red at 2,200)
- Post button disabled when over limit
- New comments appear immediately
- Comments persist to database
- Delete works (only own comments)
- Empty state displays correctly
- Loading state shows spinner

✅ **UI Integration:**
- Comment button opens sheet
- "View all X comments" opens sheet
- Comment count updates when sheet dismisses
- Sheet dismissal smooth
- Keyboard handling correct (auto-focus, dismiss on tap outside)

✅ **Edge Cases:**
- Empty comment text (Post button disabled)
- Very long comments (truncated at 2,200)
- Network errors (error toast, rollback)
- Delete own comments (works)
- Cannot delete others' comments (UI prevents, RLS enforces)

---

## Files Involved

**Service Layer:**
- `/Services/LikeService.swift`
- `/Services/CommentService.swift`

**ViewModel Layer:**
- `/ViewModels/FeedViewModel.swift` - Like integration
- `/ViewModels/CommentViewModel.swift` - Comment state management

**View Layer:**
- `/Views/Feed/PostCellView.swift` - Like button + comment sheet
- `/Views/Feed/CommentsView.swift` - Comment bottom sheet
- `/Views/Feed/CommentCellView.swift` - Individual comment
- `/Views/Feed/FeedView.swift` - Error toast for actions

**Models:**
- `/Models/Comment.swift` - Added custom initializer

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md` (Database schema, RLS policies)
- Feed system: `/docs/features/FEED_SYSTEM.md` (Like button integration)
- Profile system: `/docs/features/PROFILE_SYSTEM.md` (Avatar display patterns)

---

## Future Enhancements (Phase 9+)

- **Real-time comments**: New comments appear automatically (Supabase Realtime)
- **Reply threading**: Nested replies to comments
- **Comment likes**: Like individual comments
- **Mentions**: @username mentions in comments
- **Rich text**: Bold, italic, links in comments
- **Comment notifications**: Push notifications for new comments

---

**Status:** ✅ Complete
**Next Phase:** Following System (Phase 8)
