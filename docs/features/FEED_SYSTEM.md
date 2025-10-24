# Feed System

**Phase 4: Feed UI Foundation + Phase 6A: Feed Data Integration**
**Completed:** October 22, 2025

---

## Overview

Instagram-style feed with post cells displaying photos, captions, likes, and comments. Fully integrated with Supabase backend for real data fetching with signed URLs, pagination, and optimistic UI updates.

---

## Architecture

### Service Layer

**FeedService.swift** - Feed data operations:

```swift
func fetchFeed(userId: UUID, limit: Int, offset: Int) async throws -> [Post]
```

**Features:**
- Fetches all posts (not just followed users - Phase 8 will filter)
- Generates signed URLs for images (1 hour expiry)
- Fetches like counts, comment counts, and current user's like status
- Pagination support (20 posts per page)
- Embedded author profiles via Supabase joins

**SQL Query Pattern:**
```sql
SELECT
  posts.*,
  profiles.username,
  profiles.avatar_url,
  profiles.full_name,
  (SELECT COUNT(*) FROM likes WHERE post_id = posts.id) as like_count,
  (SELECT COUNT(*) FROM comments WHERE post_id = posts.id) as comment_count,
  EXISTS(SELECT 1 FROM likes WHERE post_id = posts.id AND user_id = $userId) as is_liked
FROM posts
JOIN profiles ON posts.author = profiles.user_id
ORDER BY created_at DESC
```

### ViewModel Layer

**FeedViewModel.swift** - State management:

```swift
@Published var posts: [Post] = []
@Published var loadingState: LoadingState = .idle
@Published var errorMessage: String?

enum LoadingState {
    case idle, loading, loaded, error
}
```

**Key Methods:**
- `loadFeed()` - Fetches fresh feed data
- `loadMorePostsIfNeeded(currentPost:)` - Infinite scroll pagination
- `toggleLike(forPostID:)` - Optimistic UI updates (Phase 7 adds API calls)

---

## Components

### PostCellView

Instagram-style post cell with:

**Header Section:**
- Circular avatar (32x32)
- Username (bold, 14pt)
- Three-dot menu button (disabled in current phase)

**Image Section:**
- Square 1:1 aspect ratio container
- AsyncImage with signed URLs
- Loading spinner (ProgressView)
- Error state (placeholder icon)
- Full width, no padding

**Action Buttons:**
- Like button (heart icon, toggles red)
- Comment button (speech bubble)
- Share button (paper plane, disabled)
- Bookmark button (right-aligned, disabled)
- 44pt tap targets (Apple's recommended minimum)

**Engagement Section:**
- Like count (bold, e.g., "42 likes")
- Caption: Username (bold) + caption text (wraps naturally)
- Caption truncation at ~100 characters with "more" button
- "View all X comments" link (when comments > 0)
- Relative timestamp (e.g., "2H AGO")

### CaptionView

Extracted component for caption display:

```swift
struct CaptionView: View {
    let username: String
    let caption: String?
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
}
```

**Features:**
- Natural text wrapping (Text concatenation, not HStack)
- Truncation with "more" button
- Tap to expand full caption

### FeedView

Main feed screen:

- ScrollView with LazyVStack (performance optimization)
- Loading state (spinner)
- Error state (message + retry button)
- Empty state ("No posts yet. Follow people to see their posts")
- Dividers between posts (0.5pt, light gray)
- Hidden scroll indicators

**No Pull-to-Refresh:**
Intentionally removed for small private network (5-20 users). Feed loads fresh data on app launch/tab switch. Real-time updates will auto-refresh in Phase 9.

---

## Image Display

### Signed URLs

All images use Supabase Storage signed URLs (1 hour expiry):

```swift
let signedURL = try await client.storage
    .from("posts")
    .createSignedURL(path: mediaKey, expiresIn: 3600)
```

**Benefits:**
- Private bucket security maintained
- Automatic expiration (no stale URLs)
- Pre-fetched during feed load (no per-cell API calls)

### AsyncImage Integration

```swift
AsyncImage(url: URL(string: post.mediaURL ?? "")) { phase in
    switch phase {
    case .success(let image):
        image.resizable().aspectRatio(1, contentMode: .fit)
    case .failure:
        placeholderIcon
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}
```

**Key Decision:** Using `.aspectRatio(1, contentMode: .fit)` directly on AsyncImage phases instead of GeometryReader (see bug fix below).

---

## Pagination

### Infinite Scroll

FeedViewModel tracks pagination state:

```swift
private var currentPage = 0
private let pageSize = 20
private var hasMorePosts = true

func loadMorePostsIfNeeded(currentPost: Post) {
    guard hasMorePosts, loadingState == .loaded else { return }

    if posts.last?.id == currentPost.id {
        Task { await loadFeed(loadMore: true) }
    }
}
```

**Trigger:**
FeedView checks if user scrolled to last post:

```swift
.onAppear {
    viewModel.loadMorePostsIfNeeded(currentPost: post)
}
```

---

## Important Bug Fixes

### GeometryReader Hit-Testing Issue ✅ FIXED

**Symptom:**
~20% of posts had non-functional like buttons. Taps didn't register at all (no console logs, no visual feedback). Other posts worked perfectly. Issue persisted across app restarts and affected random posts.

**Root Cause:**
GeometryReader in `imageView` was expanding unpredictably and overlapping the action buttons area below it. This blocked SwiftUI's hit-testing for the like button in certain cells, likely due to timing issues with AsyncImage loading creating a race condition.

**Solution:**
1. Removed GeometryReader from imageView completely
2. Used `.aspectRatio(1, contentMode: .fit)` directly on each AsyncImage phase
3. Let SwiftUI handle layout natively without manual geometry calculations

**Result:** ✅ All posts' like buttons now work perfectly!

**Key Insight:** GeometryReader + AsyncImage can cause timing-based layout bugs where the reader expands to fill space before the image loads, causing overlap issues. SwiftUI's native `.aspectRatio()` modifier is more reliable.

**Location:** `PostCellView.swift` - `imageView` computed property

### Caption Type-Check Error ✅ FIXED

**Problem:** Swift compiler "type-check" errors with complex Text concatenation and nested ternary operators.

**Solution:** Extracted caption logic into separate `CaptionView` struct with simpler computed properties.

**Result:** Clean compilation, better code organization.

---

## Design Decisions

### No Pull-to-Refresh

**Rationale:** Kinnect is for small private networks (5-20 users). Feed loads fresh data on app launch and tab switches. Real-time updates (Phase 9) will auto-update the feed. Pull-to-refresh adds complexity without significant UX benefit for intimate networks.

### Caption Layout Pattern

Using Text concatenation (not HStack) for natural wrapping:

```swift
Text(username).bold() + Text(" ") + Text(caption)
```

This creates Instagram-style caption where username and text wrap together naturally.

### LazyVStack for Performance

Only renders visible cells, essential for smooth scrolling with large feeds.

### Optimistic UI Updates

Like button toggles immediately before API call (Phase 7 adds persistence). Provides instant feedback even on slow networks.

---

## Testing Results

✅ **Feed Loading:**
- Real posts load from Supabase
- Images display correctly using signed URLs
- Author profiles show (avatar, username)
- Like counts and comment counts accurate
- Posts ordered by most recent first

✅ **Pagination:**
- Initial load: 20 posts
- Infinite scroll triggers correctly
- No duplicate posts loaded

✅ **UI Interactions:**
- Like button works on ALL posts (bug fixed)
- Caption expansion/collapse works
- "View all X comments" tappable (opens CommentsView in Phase 7)
- Smooth scrolling performance

✅ **Edge Cases:**
- Empty state displays when no posts
- Error state shows retry button
- Loading spinner during fetch
- Handles missing captions (nil)
- Handles posts with 0 likes/comments

---

## Post Model

```swift
struct Post: Identifiable, Codable {
    let id: UUID
    let author: UUID
    let caption: String?
    let mediaKey: String
    let mediaType: String
    let createdAt: Date

    // Relationships (set by FeedService)
    var authorProfile: Profile?
    var likeCount: Int = 0
    var commentCount: Int = 0
    var isLikedByCurrentUser: Bool = false
    var mediaURL: String? // Pre-fetched signed URL
}
```

**Important:** Mutable relationship properties allow FeedViewModel to update counts optimistically without refetching entire feed.

---

## Files Involved

**Service Layer:**
- `/Services/FeedService.swift`

**ViewModel Layer:**
- `/ViewModels/FeedViewModel.swift`

**View Layer:**
- `/Views/Feed/FeedView.swift` - Main feed screen
- `/Views/Feed/PostCellView.swift` - Individual post cell
- `/Views/Feed/CaptionView.swift` - Caption component

**Models:**
- `/Models/Post.swift`

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md`
- Upload system: `/docs/features/UPLOAD_SYSTEM.md` (creates posts)
- Social interactions: `/docs/features/SOCIAL_INTERACTIONS.md` (likes/comments)

---

## Future Enhancements (Phase 9+)

- Real-time updates (new posts appear automatically)
- Follow filtering (show only followed users' posts)
- Video playback support (Phase 6 Part B)
- Post menu (delete, report, etc.)

---

**Status:** ✅ Complete
**Next Phase:** Upload System (see `/docs/features/UPLOAD_SYSTEM.md`)
