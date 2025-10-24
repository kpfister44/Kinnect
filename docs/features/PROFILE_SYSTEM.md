# Profile System

**Phase 3: Profile System**
**Completed:** October 21, 2025

---

## Overview

Complete user profile management with view/edit capabilities, avatar upload, and Instagram-style UI. Users can view their own profile, edit details, and view others' profiles with follow button (functional in Phase 8).

---

## Architecture

### Service Layer

**ProfileService.swift** - Complete CRUD operations:

```swift
func fetchProfile(userId: UUID) async throws -> Profile
func updateProfile(userId: UUID, username: String?, fullName: String?, bio: String?, avatarUrl: String?) async throws
func uploadAvatar(image: UIImage, userId: UUID) async throws -> String
func getProfileStats(userId: UUID) async throws -> (posts: Int, followers: Int, following: Int)
```

**Key Features:**
- Parallel stats fetching (posts, followers, following counts)
- Avatar upload with automatic compression (2MB limit)
- Validation (username format, bio length)
- Comprehensive error handling

### ViewModel Layer

**ProfileViewModel.swift** - State management:

```swift
@Published var profile: Profile?
@Published var isLoading = false
@Published var errorMessage: String?
@Published var stats: (posts: Int, followers: Int, following: Int)?
```

**Responsibilities:**
- Load profile with parallel stats query
- Update profile with optimistic UI
- Avatar upload coordination
- Error handling with user-friendly messages
- Refresh functionality

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
- Placeholder cells ready for real post data (Phase 6)

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
- Disabled in Phase 3 (functional in Phase 8)

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

---

## Files Involved

**Service Layer:**
- `/Services/ProfileService.swift`

**ViewModel Layer:**
- `/ViewModels/ProfileViewModel.swift`

**View Layer:**
- `/Views/Profile/ProfileView.swift` - Main screen
- `/Views/Profile/ProfileHeaderView.swift` - Stats + avatar + bio
- `/Views/Profile/ProfilePostsGridView.swift` - 3-column grid
- `/Views/Profile/EditProfileView.swift` - Edit form

**Utilities:**
- `/Utilities/ImageCompression.swift` - Avatar compression

---

## Related Documentation

- Backend setup: `/docs/BACKEND_SETUP.md`
- Authentication: `/docs/features/AUTHENTICATION.md`
- Upload system: `/docs/features/UPLOAD_SYSTEM.md` (for image compression patterns)

---

**Status:** ✅ Complete
**Next Phase:** Feed System (see `/docs/features/FEED_SYSTEM.md`)
