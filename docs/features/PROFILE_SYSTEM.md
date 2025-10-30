# Profile System

**Phase 3: Profile System (with Phase 10 enhancements)**
**Completed:** October 21, 2025 (Grid functionality added October 25, 2025)

---

## Overview

Complete user profile management with view/edit capabilities, avatar upload, posts grid display, and Instagram-style UI. Users can view their own profile, edit details, view others' profiles with follow button (functional in Phase 8), and tap posts to view details.

---

## Architecture

### Service Layer

**ProfileService.swift** - Complete CRUD operations:

```swift
func fetchProfile(userId: UUID) async throws -> Profile
func updateProfile(userId: UUID, username: String?, fullName: String?, bio: String?, avatarUrl: String?) async throws
func uploadAvatar(image: UIImage, userId: UUID) async throws -> String
func getProfileStats(userId: UUID) async throws -> (posts: Int, followers: Int, following: Int)
func fetchUserPosts(userId: UUID, limit: Int = 100, offset: Int = 0) async throws -> [Post]
```

**Key Features:**
- Parallel stats fetching (posts, followers, following counts)
- User posts fetching with signed URLs for grid display
- Avatar upload with automatic compression (2MB limit)
- Validation (username format, bio length)
- Comprehensive error handling

### ViewModel Layer

**ProfileViewModel.swift** - State management:

```swift
@Published var profile: Profile?
@Published var posts: [Post] = []
@Published var isLoading = false
@Published var errorMessage: String?
@Published var stats: (posts: Int, followers: Int, following: Int)?
```

**Responsibilities:**
- Load profile with parallel stats and posts query
- Update profile with optimistic UI
- Avatar upload coordination
- Error handling with user-friendly messages
- Refresh functionality
- Attach author profile to posts for detail view display

---

## Components

### ProfileHeaderView

Instagram-style profile header displaying:

- **Circular avatar** (80x80) with AsyncImage loading
- **Stats row**: Posts / Followers / Following (tappable)
- **Username** (bold, 16pt)
- **Full name** (14pt)
- **Bio** (14pt, secondary color, multi-line)
- **Edit Profile button** (for current user, full-width rounded)
- **Follow button** (for other users, disabled in Phase 3)

### ProfilePostsGridView

3-column Instagram-style grid:

- LazyVGrid with 3 equal columns
- Square aspect ratio (1:1)
- Minimal spacing (1pt)
- Empty state: camera icon + "No posts yet"
- Real post images loaded via AsyncImage with signed URLs
- NavigationLink on each cell to PostDetailView
- Loading states (spinner) and error states (exclamation icon)
- Video play icon overlay for video posts

### PostDetailView

Full-screen post detail (Instagram-style):

- Displays single post in feed-style layout
- Author header (avatar + username)
- Full-size image with AsyncImage
- Like/comment action buttons (functional)
- Caption with expand/collapse for long text
- Like count display
- "View all X comments" button (opens CommentsView sheet)
- Timestamp display
- **Lazy-loading**: Fetches like count, comment count, and "is liked" status on appear
- **Optimistic UI**: Like button updates instantly, reverts on error
- **NavigationStack integration**: Accessed via grid cell taps

### ProfileView

Main profile screen with:

- ScrollView with profile header + posts grid
- Loading state (spinner)
- Error state (message + retry button)
- Pull-to-refresh
- Settings menu (gear icon) with logout
- Sheet presentation for EditProfileView

### EditProfileView

Profile editing form with:

- **Avatar picker**: PhotosPicker integration, circular preview
- **Username field**: Real-time validation
- **Full name field**
- **Bio field**: 150 character limit with counter
- **Save button**: Enabled only when changes detected
- **Cancel button**: Dismisses without saving
- Loading overlay during save ("Updating profile...")
- Error alerts with retry capability

---

## Database Changes

### Added Bio Field

Migration applied to add `bio` column:

```sql
ALTER TABLE profiles ADD COLUMN bio TEXT;
```

---

## Avatar Upload Flow

1. User taps avatar in EditProfileView
2. PhotosPicker presents (no permissions needed)
3. User selects image
4. Image compresses (target: 2MB, JPEG format)
5. Uploads to `avatars/{userId}/{userId}.jpg`
6. Returns public URL with cache-busting timestamp
7. Updates `profiles.avatar_url` in database
8. UI refreshes with new avatar

### Image Compression

```swift
ImageCompression.compressImage(
    image,
    maxSizeInBytes: 2_000_000, // 2MB
    compressionQuality: 0.8
)
```

**Strategy:**
- Adaptive quality reduction (0.8 → 0.1) to meet size limit
- Maintains aspect ratio
- JPEG format for universal compatibility

### Cache-Busting

Adds timestamp to URL to force iOS cache refresh:

```swift
avatarUrl + "?t=\(Int(Date().timeIntervalSince1970))"
```

**Critical for UX:** Without this, iOS shows stale cached avatar even after upload.

---

## Storage Configuration

### avatars Bucket

- **Size limit**: 2MB per file
- **File types**: Images only (JPEG, PNG)
- **Access**: Private with signed URLs
- **Organization**: `{userId}/{userId}.jpg`

### RLS Policies

```sql
-- INSERT: All authenticated users can upload
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- UPDATE/DELETE: Only file owner
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND owner = auth.uid());
```

**Key Insight:** Keep policies simple. Trust app-level folder organization rather than complex regex-based path validation.

---

## Key Features

### Stats Display

Fetches and displays:
- **Posts**: Count of user's posts
- **Followers**: Count of users following this user
- **Following**: Count of users this user follows

Queries run in parallel for performance.

### Username Validation

**Rules:**
- 3-20 characters
- Alphanumeric plus underscore and period
- Real-time feedback (red text on invalid)
- Uniqueness checked on save (not real-time to reduce API calls)

### Bio Character Limit

- **Maximum**: 150 characters (Instagram standard)
- **Counter**: Shows remaining characters (e.g., "150 characters remaining")
- **Validation**: Enforced in UI and backend

### Follow Button

- UI implemented in ProfileHeaderView
- Shows "Follow" for other users
- Fully functional in Phase 8 with optimistic updates

### Posts Grid Display

**Fetching Posts:**
- Fetches all posts for a specific user (ordered newest first)
- Generates signed URLs for each post's media
- Default limit: 100 posts
- Runs in parallel with profile and stats fetching for performance

**Grid Cell Interaction:**
- Tap any post → Navigate to PostDetailView
- Shows loading spinner while image loads
- Shows error icon if image fails to load
- Video posts show play icon overlay (top-right corner)

**Detail View Loading:**
- Shows post immediately with image and caption
- Lazy-loads like count, comment count, and like status in background
- All interactions work: like, comment, expand caption
- Comments open in bottom sheet (consistent with feed)

---

## Important Learnings

### Storage RLS Patterns

**What Worked:**
- Simple INSERT policy: `bucket_id = 'avatars'`
- Trust app-level folder organization (`{userId}/...`)
- Use `owner` field for UPDATE/DELETE (auto-set by Supabase)

**What Didn't Work:**
- Complex regex-based folder name validation
- String matching on UUID paths (unreliable)

### Date Decoding

Supabase returns ISO8601 with fractional seconds. Must use:

```swift
let decoder = JSONDecoder.supabase
```

This applies `.iso8601` strategy automatically.

### Supabase SDK Changes

**Updated API:**
- ❌ Old: `client.database.from("profiles")`
- ✅ New: `client.from("profiles")`

### Cache-Busting is Critical

Without timestamp query param, iOS aggressively caches images. Users would see old avatars even after successful uploads. Always append `?t=timestamp` to image URLs when using same filename.

### Posts Grid Integration

**Key Decision:** Posts grid loads data from ProfileService, not FeedService:
- FeedService filters posts by followed users (for feed display)
- ProfileService fetches all posts for a specific user (for profile grid)
- Both services generate signed URLs for media display
- PostDetailView fetches fresh like/comment counts (not from grid cache)

**Performance:**
- Profile load fetches profile, stats, and posts in parallel
- Grid uses LazyVGrid for efficient scrolling
- Images load asynchronously with proper loading states
- Detail view lazy-loads interaction counts for faster initial display

---

## Testing Results

✅ **Profile Loading:**
- Profile data fetches correctly
- Stats display accurately (0 posts, 0 followers, 0 following initially)
- Avatar displays with proper AsyncImage loading states

✅ **Profile Editing:**
- Username, full name, bio update successfully
- Real-time validation working
- Changes persist to database
- UI updates immediately

✅ **Avatar Upload:**
- PhotosPicker integration works
- Image compression handles large files (>2MB → <2MB)
- Upload to Supabase Storage succeeds
- Cache-busting ensures fresh image display
- Avatar updates immediately after upload

✅ **Error Handling:**
- Invalid username shows error
- Failed uploads show retry option
- Network errors display user-friendly messages

✅ **Instagram-Style UI:**
- Matches Instagram design language
- Smooth transitions and animations
- Proper loading states
- Empty states with helpful messages

✅ **Posts Grid Display (Added October 25, 2025):**
- Posts load correctly from Supabase
- Images display with signed URLs (1 hour expiry)
- Grid shows all user posts in 3-column layout
- Empty state shows "No Posts Yet" with camera icon

✅ **Post Detail View:**
- Grid cells are tappable and navigate to detail view
- Detail view shows full post with like/comment functionality
- Like button works with optimistic updates
- Comments open in bottom sheet
- Caption expands/collapses for long text
- All counts are accurate and update live

---

## Files Involved

**Service Layer:**
- `/Services/ProfileService.swift`

**ViewModel Layer:**
- `/ViewModels/ProfileViewModel.swift`

**View Layer:**
- `/Views/Profile/ProfileView.swift` - Main screen
- `/Views/Profile/ProfileHeaderView.swift` - Stats + avatar + bio
- `/Views/Profile/ProfilePostsGridView.swift` - 3-column grid with navigation
- `/Views/Profile/PostDetailView.swift` - Full-screen post detail view
- `/Views/Profile/EditProfileView.swift` - Edit form

**Utilities:**
- `/Utilities/ImageCompression.swift` - Avatar compression

**Dependencies:**
- LikeService.swift - Like operations for detail view
- CommentService.swift - Comment operations for detail view

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md`
- Authentication: `/docs/features/AUTHENTICATION.md`
- Upload system: `/docs/features/UPLOAD_SYSTEM.md` (for image compression patterns)

---

**Status:** ✅ Complete (Including posts grid and detail view)
**Next Phase:** Feed System (see `/docs/features/FEED_SYSTEM.md`)

---

## Update History

**October 21, 2025** - Initial profile system implementation (Phase 3)
- Profile viewing and editing
- Avatar upload
- Stats display
- Follow button UI (functional in Phase 8)

**October 25, 2025** - Posts grid and detail view (Phase 10 enhancement)
- Added `fetchUserPosts` to ProfileService
- ProfileViewModel loads posts in parallel with profile/stats
- ProfilePostsGridView displays real images from Supabase
- PostDetailView for full-screen post viewing
- Like/comment functionality in detail view
- Navigation from grid to detail view

**October 30, 2025** - Cross-view synchronization fixes
- ProfileViewModel now listens for `.userDidDeletePost` notification
- ProfileViewModel now listens for `.userDidCreatePost` notification
- Profile grid updates immediately when posts are created or deleted from any view
- No app restart needed for grid to stay synchronized with other views
