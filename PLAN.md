# Kinnect Implementation Plan

## Overview
Building a polished, private Instagram-style iOS app from scratch. The plan is structured in phases, each delivering a functional milestone. We'll build the foundation first, then layer features incrementally.

---

## Phase 1: Foundation & Project Setup
**Goal:** Set up the development environment and project architecture

### Tasks:
1. **Xcode Project Structure**
   - Create organized folder structure (Models, Views, ViewModels, Services, Utilities, Resources)
   - Set up MVVM architecture foundation
   - Configure build settings and app capabilities

2. **Dependency Management**
   - Add Swift Package Manager dependencies:
     - Supabase Swift SDK
     - Any image processing libraries (if needed)
   - Create `Secrets.plist` for configuration (gitignored)

3. **Supabase Backend Setup**
   - Create Supabase project
   - Set up database schema (see Phase 1b below)
   - Configure authentication providers (Sign in with Apple)
   - Create storage buckets for media (private)
   - Set up Row-Level Security (RLS) policies

4. **Core Services Layer**
   - `SupabaseService` – singleton for Supabase client configuration
   - `AuthService` – authentication operations
   - `NetworkService` – base networking utilities
   - Environment configuration manager

**Deliverable:** Project skeleton with Supabase connected, no UI yet

---

## Phase 1b: Database Schema & RLS
**Goal:** Establish the complete database foundation

### Tables to Create:
```sql
-- User profiles
profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  full_name TEXT,
  created_at TIMESTAMP DEFAULT NOW()
)

-- Following relationships
follows (
  follower UUID REFERENCES profiles(user_id),
  followee UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (follower, followee)
)

-- Posts
posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author UUID REFERENCES profiles(user_id),
  caption TEXT,
  media_key TEXT NOT NULL,  -- Supabase Storage object path
  media_type TEXT NOT NULL,  -- 'photo' or 'video'
  created_at TIMESTAMP DEFAULT NOW()
)

-- Likes
likes (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
)

-- Comments
comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
)
```

### Row-Level Security Policies:
- Users can read their own profile and profiles of people they follow
- Users can only create posts for themselves
- Users can only read posts from themselves or people they follow
- Users can like/comment on posts they can read

### Storage Buckets:
- `avatars` (private, signed URLs)
- `posts` (private, signed URLs)

**Deliverable:** Fully functional database backend with security policies tested

---

## Phase 2: Authentication Flow
**Goal:** Implement Sign in with Apple and session management

### Tasks:
1. **Sign in with Apple Integration**
   - Configure App ID in Apple Developer Portal
   - Set up Supabase Auth provider
   - Create sign-in UI (welcome screen, sign-in button)

2. **AuthViewModel**
   - Handle Sign in with Apple flow
   - Manage session state (logged in/out)
   - Store and refresh Supabase JWT tokens
   - Handle auth errors gracefully

3. **Onboarding Flow**
   - Welcome screen with app branding
   - Sign in screen
   - Username creation screen (first-time users)

4. **Session Persistence**
   - Check for existing session on app launch
   - Auto-redirect to feed if authenticated
   - Logout functionality

**Deliverable:** Users can sign in with Apple, create a username, and maintain session across app launches

---

## Phase 3: Profile System
**Goal:** Users can create and view profiles

### Tasks:
1. **Profile Model & Service**
   - `Profile` model matching database schema
   - `ProfileService` for CRUD operations

2. **Profile View**
   - Profile header (avatar, username, full name)
   - Edit profile button (for own profile)
   - Grid of user's posts (empty state initially)
   - Follow/Unfollow button (for other users' profiles)

3. **Edit Profile Screen**
   - Update avatar (photo picker + upload)
   - Edit username, full name, bio (if we add that)
   - Save changes to Supabase

4. **ProfileViewModel**
   - Fetch profile data
   - Update profile
   - Upload avatar to storage

**Deliverable:** Users can view and edit their own profile, see others' profiles

---

## Phase 4: Feed UI Foundation
**Goal:** Build the core feed interface (empty state)

### Tasks:
1. **Tab Bar Navigation**
   - Bottom tab bar with 5 tabs: Feed, Search, Upload, Activity, Profile
   - Tab bar icons (SF Symbols initially)
   - Navigation structure

2. **Feed View (Empty State)**
   - Scrollable list container
   - Empty state message ("No posts yet. Follow people to see their posts!")
   - Pull-to-refresh placeholder

3. **Post Cell Design**
   - Header: avatar, username, timestamp
   - Image/video container (full width, square aspect ratio)
   - Footer: like button, comment button, like count
   - Caption with "Read more" for long text
   - Instagram-style layout

**Deliverable:** Complete UI shell with tab navigation, empty feed ready for data

---

## Phase 5: Photo Upload & Post Creation
**Goal:** Users can select photos and create posts (photos only - videos in Phase 6)

### Tasks:
1. **Photo Picker Integration**
   - Use native PHPickerViewController for photo selection
   - Handle photo library permissions
   - Single photo selection (no multi-select yet)

2. **Image Compression**
   - Client-side image resize (max 1200x1200px)
   - JPEG compression to stay under storage limits
   - Maintain aspect ratio
   - Compression utility functions

3. **Caption Entry Screen**
   - New view: `NewPostView.swift`
   - Display selected photo preview
   - Text field for caption entry
   - Character limit (optional, 2,200 like Instagram)
   - Cancel and Share buttons

4. **PostService**
   - `uploadPhoto(image:userId:)` - Upload to Supabase Storage
   - `createPost(caption:mediaKey:userId:)` - Create post record
   - File naming: `{userId}/{postId}.jpg` in `posts` bucket
   - Error handling with retry logic

5. **UploadViewModel**
   - Manage upload flow state (idle, uploading, success, error)
   - Coordinate image upload → post creation sequence
   - Show progress indicator during upload
   - Handle errors gracefully with user feedback

6. **Update UploadView**
   - Replace placeholder with photo picker button
   - Present NewPostView after photo selection
   - Instagram-style camera/library selection

**Key Design Decisions:**
- **No Edge Function needed:** Supabase has built-in image transformation
- **Upload flow:** Select photo → Add caption → Upload image → Create post record
- **Simple progress:** Spinner with "Posting..." message (no background uploads yet)
- **Supabase Image Transformation:** Use on-the-fly resizing when displaying in feed

**Deliverable:** Users can select photos from library, add captions, and create posts. Posts appear in feed immediately after upload.

---

## Phase 6: Feed Data Integration & Video Support
**Goal:** Connect feed to real Supabase data and add video upload/playback

### Part A: Feed Data (Phase 4 UI → Real Data)
1. **FeedService**
   - Fetch posts from followed users (SQL query with joins)
   - Include author profile, like count, comment count
   - Paginated loading (initial 20 posts, load more on scroll)
   - Fetch signed URLs from Supabase Storage for images

2. **FeedViewModel**
   - Replace mock data with real Supabase queries
   - Load feed data on appear
   - Pagination logic (infinite scroll)
   - State management (loading, loaded, error, empty)
   - Cache optimization

3. **Post Display Updates**
   - Fetch and display real images using signed URLs
   - Use Supabase image transformation for optimized delivery
   - Handle image loading states and errors
   - Update like counts from database
   - Show real comment counts

### Part B: Video Support
4. **Video Upload**
   - Extend PHPicker to support video selection
   - Video compression (client-side or Edge Function)
   - Upload to `posts` bucket (50MB limit)
   - Thumbnail generation for video preview
   - File naming: `{userId}/{postId}.mp4`

5. **Video Playback**
   - Add AVPlayer to PostCellView for video posts
   - Play/pause controls
   - Mute/unmute toggle
   - Auto-play when scrolled into view (optional)
   - Handle video loading states

6. **Update PostCellView**
   - Detect `media_type` (photo vs video)
   - Show video player for video posts
   - Show image for photo posts
   - Video thumbnail with play button overlay

**Deliverable:** Users see a real feed with posts from followed users, including both photos and videos with playback support

---

## Phase 7: Social Interactions
**Goal:** Users can like and comment on posts

### Tasks:
1. **Like Functionality**
   - Like button UI (heart icon, filled when liked)
   - Optimistic UI updates
   - Save like to `likes` table
   - Update like count in real-time

2. **Comment System**
   - Comments sheet (bottom drawer, Instagram-style)
   - Display existing comments
   - Add new comment
   - Delete own comments

3. **CommentViewModel**
   - Fetch comments for a post
   - Post new comment
   - Delete comment

4. **Activity Feed (Later)**
   - Placeholder for notifications (likes, comments, follows)
   - Can be fleshed out in future phases

**Deliverable:** Users can like and comment on posts with immediate feedback

---

## Phase 8: Following System
**Goal:** Users can follow/unfollow others

### Tasks:
1. **Search/Discovery**
   - Search bar to find users by username
   - Search results list
   - Tap to view profile

2. **Follow/Unfollow**
   - Follow button on profiles
   - Update `follows` table
   - Reflect follow status immediately

3. **Followers/Following Lists**
   - View list of followers
   - View list of following
   - Tap to navigate to profile

4. **FollowService**
   - Follow/unfollow operations
   - Fetch followers/following lists

**Deliverable:** Users can discover and follow others, building their private network

---

## Phase 9: Realtime Updates
**Goal:** Feed updates in real-time when new posts are published

### Tasks:
1. **Supabase Realtime Subscription**
   - Subscribe to `posts` table changes
   - Filter for posts from followed users

2. **FeedViewModel Realtime Integration**
   - Listen for new posts
   - Insert new posts at top of feed
   - Show "New posts available" banner (tap to refresh)

3. **Push Notifications (Optional)**
   - Set up APNs certificates
   - Supabase Edge Function to send notifications
   - Trigger on new likes, comments, follows

**Deliverable:** Feed updates dynamically when friends post, optional push notifications

---

## Phase 10: Polish, Testing & Edge Cases
**Goal:** Ensure a high-quality, bug-free MVP

### Tasks:
1. **UI Polish**
   - Match Instagram's design language precisely
   - Dark mode support
   - Animations and transitions
   - Loading states and error messages
   - Empty states for all screens

2. **Accessibility**
   - VoiceOver labels
   - Dynamic Type support
   - High contrast mode

3. **Testing**
   - Unit tests for all ViewModels
   - UI tests for critical flows (auth, upload, feed, like, comment)
   - Edge case testing (network errors, empty states, large media files)

4. **Performance Optimization**
   - Image caching strategy
   - Lazy loading optimizations
   - Memory management (especially for video)

5. **Error Handling**
   - Graceful handling of all network errors
   - User-friendly error messages
   - Retry mechanisms

6. **Final Touches**
   - App icon and splash screen
   - Onboarding hints/tooltips
   - Privacy policy and terms (if needed)

**Deliverable:** Polished, production-ready MVP

---

## Future Enhancements (Post-MVP)
- **Stories** (24-hour ephemeral posts)
- **Direct Messaging** (1:1 and group chats)
- **Video improvements** (better player, scrubbing)
- **Advanced search** (hashtags, locations)
- **Saved posts** (bookmark feature)
- **Reporting & moderation tools**

---

## Recommended Tech Decisions

### Edge Functions (Minimal Use)
1. **Image Compression** ✅ Essential – reduces storage costs and improves performance
2. **Push Notifications** ✅ Essential – requires server-side APNs integration
3. **User Moderation** ✅ Optional – admin operations (ban, delete content)

Avoid edge functions for standard CRUD operations – use RLS policies instead.

### Folder Structure
```
Kinnect/
├── Models/
│   ├── Profile.swift
│   ├── Post.swift
│   ├── Comment.swift
│   └── ...
├── Views/
│   ├── Auth/
│   ├── Feed/
│   ├── Profile/
│   ├── Upload/
│   └── Shared/
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── FeedViewModel.swift
│   ├── ProfileViewModel.swift
│   └── ...
├── Services/
│   ├── SupabaseService.swift
│   ├── AuthService.swift
│   ├── FeedService.swift
│   └── ...
├── Utilities/
│   ├── Extensions/
│   ├── Constants.swift
│   └── ...
├── Resources/
│   ├── Assets.xcassets
│   ├── Secrets.plist (gitignored)
│   └── ...
└── KinnectApp.swift
```

---

## Timeline Estimate (Rough)
- **Phase 1-2:** Foundation & Auth → ~1-2 weeks
- **Phase 3-4:** Profile & Feed UI → ~1 week
- **Phase 5-6:** Upload & Feed Data → ~2 weeks
- **Phase 7-8:** Social Features → ~1-2 weeks
- **Phase 9:** Realtime → ~3-5 days
- **Phase 10:** Polish & Testing → ~1 week

**Total MVP:** 6-8 weeks (with dedicated development time)

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Image compression performance** | Test early, use edge function, optimize parameters |
| **Video upload/playback** | Start with photos only, add video in Phase 5 |
| **Realtime scaling** | Test with multiple users, monitor Supabase metrics |
| **App Store approval** | Ensure privacy policy, data handling, Sign in with Apple compliance |

---

## Current Status

### ✅ Phase 1: Foundation & Project Setup – COMPLETE

**Completed:** October 17, 2025

**What We Built:**
- ✅ Organized MVVM folder structure (Models, Services, ViewModels, Views, Utilities, Resources)
- ✅ Core models: Profile, Post, Comment, Like, Follow
- ✅ SupabaseService singleton with configuration loading
- ✅ AuthService with Sign in with Apple support (async/await)
- ✅ Utility constants and extensions (Date, View, Color)
- ✅ Secrets.plist template for configuration
- ✅ Supabase Swift SDK installed via SPM
- ✅ Complete documentation (SUPABASE_SETUP.md, SPM_SETUP.md)
- ✅ Project builds successfully

**Committed to GitHub:**
- Repository: https://github.com/kpfister44/Kinnect
- Latest commit: Fix AuthService for async Supabase SDK

---

### ✅ Backend Setup (Supabase) – COMPLETE

**Completed:** October 18, 2025

**What We Built:**
- ✅ Supabase project created (Project ID: `qfoyodqiltnpcikhpbdi`)
- ✅ Database schema: 5 tables (profiles, follows, posts, likes, comments)
- ✅ Row-Level Security (RLS) enabled with comprehensive policies
- ✅ Storage buckets created: `avatars` (2MB) and `posts` (50MB)
- ✅ Storage access policies configured
- ✅ `Secrets.plist` configured with API credentials
- ✅ Supabase Swift SDK v2.36.0 installed and verified
- ✅ Backend tested and operational

**Backend Management:**
All Supabase operations are managed via the **Supabase MCP server** (see CLAUDE.md for details and available tools).

**Note:** Sign in with Apple authentication provider configuration (Part 4) is pending and will be completed during Phase 2 implementation.

---

### ✅ Phase 2: Authentication Flow – COMPLETE

**Completed:** October 19, 2025

**What We Built:**

#### Design System
- ✅ Complete Instagram-style color palette (`Color+Extensions.swift`)
  - Exact Instagram colors with hex values: igBlack, igBlue, igRed, igTextSecondary, etc.
  - Custom hex color initializer for easy color management

#### Authentication Views
- ✅ **WelcomeView** - Clean welcome screen with:
  - App branding and tagline
  - Sign in with Apple button (native ASAuthorizationAppleIDButton)
  - Error message display
  - Privacy notice

- ✅ **UsernameCreationView** - Profile creation form with:
  - Username field (3-20 characters, alphanumeric + underscore/period)
  - Full name field
  - Real-time validation feedback
  - Instagram-style input fields with focus states

#### State Management
- ✅ **AuthViewModel** - Complete authentication state management:
  - Three auth states: `unauthenticated`, `needsProfile`, `authenticated(userId)`
  - Sign in with Apple integration
  - Profile creation with username validation and uniqueness check
  - Session persistence (auto-login on app launch)
  - Real-time auth state observation via Supabase
  - Sign out functionality
  - Proper error handling with user-friendly messages

#### Main App Structure
- ✅ **TabBarView** - Instagram-style bottom navigation with 5 tabs:
  - Feed (house icon)
  - Search (magnifying glass icon)
  - Upload (plus square icon - center)
  - Activity (heart icon)
  - Profile (person icon)

- ✅ **Placeholder Views** for all tabs:
  - FeedView - Empty state with "No posts yet" message
  - SearchView - Search bar with user discovery placeholder
  - UploadView - Camera placeholder for photo/video sharing
  - ActivityView - Notifications placeholder
  - ProfileView - Profile details placeholder with logout button

#### App Architecture
- ✅ **KinnectApp.swift** - Complete app-wide routing:
  - Centralized AuthViewModel as environment object
  - Automatic routing based on auth state
  - Smooth transitions between screens
  - Session check on app launch

**User Flow (Matches Instagram):**
1. First Launch → WelcomeView (Sign in with Apple)
2. After Sign In (New User) → UsernameCreationView
3. After Profile Creation → TabBarView (5 tabs)
4. Subsequent Launches → Auto-login to TabBarView
5. Logout → Back to WelcomeView

**Testing & Refinement:**
- ✅ Apple Developer Portal configuration for Sign in with Apple
  - Created App ID: `eg.Kinnect`
  - Created Services ID: `eg.Kinnect.auth`
  - Created signing key and generated JWT secret
- ✅ Supabase Auth provider setup for Apple
  - Configured Apple provider with Client IDs: `eg.Kinnect.auth,eg.Kinnect`
  - Added JWT secret key
- ✅ Test full authentication flow on physical device
  - Sign in with Apple works end-to-end
  - Username creation flow tested successfully
  - Navigation to TabBarView confirmed
- ✅ Bug fixes:
  - Fixed `hasCompletedProfile()` to handle new users without profiles
  - Fixed audience token acceptance in Supabase

**Phase 2 Status: ✅ COMPLETE**

**Completed:** October 21, 2025

**Committed to GitHub:**
- Repository: https://github.com/kpfister44/Kinnect
- Latest commit: Phase 2: Complete authentication flow with testing

---

### ✅ Phase 3: Profile System – COMPLETE

**Completed:** October 21, 2025

**What We Built:**

#### Database Changes
- ✅ Added `bio` field to `profiles` table via migration

#### Backend Layer
- ✅ **ProfileService.swift** - Complete service with:
  - `fetchProfile(userId:)` - Get profile data
  - `updateProfile(...)` - Update username, full name, bio, avatar
  - `uploadAvatar(image:userId:)` - Upload to Supabase Storage with compression
  - `getProfileStats(userId:)` - Fetch posts/followers/following counts

#### ViewModel Layer
- ✅ **ProfileViewModel.swift** - State management with:
  - Profile loading with parallel stats fetching
  - Profile updates with error handling
  - Avatar upload with compression
  - Stats refresh functionality

#### View Layer
- ✅ **ProfileHeaderView.swift** - Instagram-style header with:
  - Circular avatar with AsyncImage loading
  - Posts/Followers/Following stats
  - Username, full name, and bio display
  - Edit Profile button (for current user)
  - Follow button placeholder (disabled for Phase 3)

- ✅ **ProfilePostsGridView.swift** - Posts grid with:
  - 3-column Instagram-style grid layout
  - Empty state with camera icon and message
  - Placeholder cells for posts (will be populated in Phase 6)

- ✅ **ProfileView.swift** - Main profile screen with:
  - Loading, error, and success states
  - Pull-to-refresh
  - Settings menu with logout
  - Sheet presentation for EditProfileView

- ✅ **EditProfileView.swift** - Edit profile form with:
  - Photo picker integration for avatar upload
  - Username field with validation
  - Full name field
  - Bio field (150 character limit)
  - Real-time change detection
  - Save/Cancel functionality

#### Key Features Implemented
- **Full avatar upload flow** to Supabase Storage (`avatars` bucket)
- **Image compression** (2MB limit, JPEG format with quality adjustment)
- **Real-time validation** for username
- **Instagram-style UI** throughout
- **Error handling** with user-friendly messages
- **Follow button** (UI only - will be functional in Phase 8)
- **Cache-busting** for avatar URLs to prevent image caching issues

#### Important Learnings - Supabase Storage & RLS

**Storage File Organization:**
Files should be stored in user-specific folders:
- ✅ **Correct**: `{userId}/{fileName}.jpg` (e.g., `abc123/abc123.jpg`)
- ❌ **Incorrect**: `{fileName}.jpg` at root

**RLS Policy Patterns for Storage:**

For a private app with authenticated users only, use this simple pattern:
```sql
-- INSERT: Allow authenticated users to upload to bucket
CREATE POLICY "Authenticated users can upload"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- UPDATE/DELETE: Only file owners can modify
CREATE POLICY "Users can update their own files"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND owner = auth.uid());
```

**Why folder-based restrictions failed:**
- `storage.foldername(name)` and regex-based checks had issues with UUID string matching
- The `owner` field (set automatically by Supabase) is more reliable for UPDATE/DELETE
- For INSERT, trusting authenticated users + app-level folder organization works well

**Cache-Busting for Images:**
When using the same filename (e.g., `userId.jpg`), add a timestamp to force cache refresh:
```swift
let cacheBustedURL = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
```

**Date Decoding Fix:**
Supabase returns dates as ISO 8601 strings. Configure JSONDecoder:
```swift
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
```

**Supabase SDK API Changes:**
- ❌ Old: `client.database.from("table")`
- ✅ New: `client.from("table")`

#### Testing Results
- ✅ Profile loading works perfectly
- ✅ Edit profile updates username, full name, and bio
- ✅ Avatar upload with compression (handles images > 2MB)
- ✅ Avatar updates immediately (cache-busting working)
- ✅ Stats display correctly (0 posts, 0 followers, 0 following)
- ✅ Pull-to-refresh works
- ✅ Logout functionality works
- ✅ Username validation prevents invalid characters
- ✅ All views match Instagram design language

**Phase 3 Status: ✅ COMPLETE**

---

### ✅ Phase 4: Feed UI Foundation – COMPLETE

**Completed:** October 22, 2025

**What We Built:**

#### Components Created

**PostCellView.swift** - Instagram-style post cell with:
- ✅ Header section: circular avatar, username, three-dot menu
- ✅ Square 1:1 aspect ratio image container
- ✅ Action buttons: like, comment, share, bookmark (Instagram layout)
- ✅ Like count display
- ✅ Caption with username (bold) + text that wraps naturally (Instagram style)
- ✅ Caption truncation at ~100 characters with "more" button
- ✅ "View all X comments" link (when comments exist)
- ✅ Relative timestamp (e.g., "2H AGO")
- ✅ Interactive like button (toggles red, updates count)
- ✅ Expandable captions on tap

**FeedView.swift** - Main feed screen with:
- ✅ Scrollable feed using LazyVStack for performance
- ✅ Empty state: "No posts yet. Follow people to see their posts"
- ✅ Mock data with 2 sample posts for UI preview
- ✅ Smooth scrolling with hidden scroll indicators
- ✅ Dividers between posts
- ✅ Loads mock data on appear

**Post.swift Model Updates:**
- ✅ Custom initializer for creating posts manually
- ✅ Decodable initializer (`init(from decoder:)`) for Codable conformance
- ✅ Mutable relationship properties (authorProfile, likeCount, commentCount, isLikedByCurrentUser)

#### Key Design Decisions

**No Pull-to-Refresh:**
- Removed for small private network (5-20 users)
- Feed loads fresh data on app launch/tab switch (Phase 6)
- Real-time updates will auto-update feed in Phase 9
- Simpler UX appropriate for intimate network

**Caption Layout:**
- Uses Text concatenation (not HStack) for natural text flow
- Username (bold) + caption text wrap together like Instagram
- "more" button for truncated captions expands on tap

**Placeholder Images:**
- Using external URLs (picsum.photos, pravatar.cc) for Phase 4 preview
- Will be replaced with Supabase Storage signed URLs in Phase 6

#### Testing Results
- ✅ Feed displays 2 sample posts with realistic content
- ✅ Images load correctly (avatars + post images)
- ✅ Like button toggles and updates count optimistically
- ✅ Caption expansion works on tap
- ✅ All UI matches Instagram design language
- ✅ Smooth scrolling performance
- ✅ Empty state displays when no posts
- ✅ All 5 tabs navigate correctly

#### Important Learnings

**Text Concatenation for Captions:**
Using `+` operator to combine Text views creates natural wrapping:
```swift
Text(username).bold() + Text(" ") + Text(caption)
```
Better than HStack which keeps elements side-by-side.

**LazyVStack for Performance:**
- Only renders visible cells
- Essential for large feeds in production
- Enables smooth scrolling

**Codable with Custom Initializers:**
When adding custom `init()`, must manually implement `init(from decoder:)` to maintain Codable conformance.

**Phase 4 Status: ✅ COMPLETE**

---

### ✅ Phase 5: Photo Upload & Post Creation – IMPLEMENTATION COMPLETE

**Completed:** October 22, 2025

**What We Built:**

#### Components Created

**1. ImageCompression.swift** - Smart image compression utility:
- Resizes images to max 1080x1080px (Instagram standard)
- Maintains aspect ratio
- Adaptive JPEG compression (target: 1MB, max: 2MB)
- Iterative quality reduction to meet size requirements
- File size formatting helper

**2. PostService.swift** - Complete post management service:
- `createPost(image:caption:userId:)` - Full upload orchestration
- `uploadPhoto()` - Uploads to Supabase Storage `posts` bucket
- `createPostRecord()` - Creates record in `posts` table
- `getMediaURL()` - Fetches signed URLs for display
- File organization: `{userId}/{postId}.jpg`
- Comprehensive error handling with custom error types

**3. NewPostView.swift** - Instagram-style caption entry:
- Full-screen photo preview at top
- Caption text field with 2,200 character limit (Instagram standard)
- Character counter
- Small thumbnail preview next to caption
- Cancel and Share buttons in nav bar
- "Posting..." overlay during upload
- Auto-focus on caption field
- Error alerts with retry capability

**4. UploadViewModel.swift** - Upload state management:
- Manages upload flow: idle → uploading → success/error
- Coordinates PostService calls
- Error handling with user-friendly messages
- Observable state for UI updates
- Upload success tracking for auto-dismiss

**5. UploadView.swift** - Photo picker integration:
- Native PHPickerViewController (no permissions required!)
- "Select Photo" button with Instagram styling
- Sheet presentation for NewPostView
- Automatic cleanup on dismiss
- Access to current user ID from AuthViewModel

#### Upload Flow

```
1. User taps Upload tab
2. Taps "Select Photo" button
3. PHPicker appears (native iOS picker)
4. User selects photo
5. NewPostView presents with preview
6. User adds optional caption
7. User taps "Share"
8. Image compresses (~500-800 KB)
9. Uploads to Supabase Storage (posts/{userId}/{postId}.jpg)
10. Creates post record in database
11. Success → Dismisses to Upload tab
```

#### Storage & Database Structure

**Supabase Storage (posts bucket):**
```
posts/
└── {userId}/
    ├── {postId1}.jpg
    ├── {postId2}.jpg
    └── {postId3}.jpg
```

**Database (posts table):**
- id (UUID)
- author (UUID)
- caption (TEXT, nullable)
- media_key (TEXT, storage path)
- media_type (TEXT, 'photo')
- created_at (TIMESTAMP)

#### Issues Encountered & Solutions

**Issue 1: RLS Policy Blocking Uploads**
- **Problem:** Storage upload failed with "new row violates row-level security policy"
- **Root Cause:** Complex folder-based RLS policy with UUID string matching failures
- **Solution:** Simplified to same pattern as Phase 3 avatars bucket:
  ```sql
  CREATE POLICY "Authenticated users can upload posts"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'posts');
  ```
- **Lesson:** Keep storage RLS policies simple for authenticated-only apps

**Issue 2: UUID Type Mismatch**
- **Problem:** Database insert failed RLS check `auth.uid() = author`
- **Root Cause:** Sending author as String instead of UUID
- **Solution:** Changed `NewPost` struct to use UUID types directly
- **Lesson:** Match Swift types to Postgres column types exactly

**Issue 3: Upload Timeout (Simulator)**
- **Problem:** 1.8 MB uploads timing out on simulator
- **Root Cause:** iOS Simulator network throttling and QUIC protocol issues
- **Solution:**
  - Reduced compression: 1200px → 1080px
  - Lower target: 2MB → 1MB
  - Lower quality: 0.8 → 0.7
  - **Result:** ~739 KB files (but still timing out on simulator)
- **Status:** ⚠️ Pending physical device testing
- **Expected:** Should work perfectly on real device with real network

#### Key Design Decisions

**No Edge Functions:**
- Supabase has built-in image transformation (on-the-fly resizing/optimization)
- Client-side compression sufficient for upload size management
- Keeps architecture simple

**PHPicker vs Custom Picker:**
- Using native PHPickerViewController
- No Info.plist permissions needed (system-level privacy)
- Single photo selection only (Phase 5 scope)
- Can enhance with custom picker later if needed

**Sequential Upload:**
- Upload image first → Get storage path → Create database record
- Prevents orphaned database records if upload fails
- Matches Instagram's approach

**Simple Progress Indicator:**
- "Posting..." overlay with spinner
- No percentage or background uploads (Phase 5 scope)
- Can enhance in polish phase if needed

#### Testing Status

**✅ Tested on Simulator:**
- Photo picker works perfectly
- Caption entry works
- Image compression works (739 KB achieved)
- RLS policies fixed
- Database structure verified

**⚠️ Pending Physical Device Test:**
- Upload timeout on simulator (network throttling)
- Expected to work on real device with actual WiFi/cellular
- 739 KB should upload in 2-3 seconds on real network

**✅ Verified in Supabase Dashboard:**
- Storage bucket structure correct
- RLS policies working
- Database schema ready

#### Important Learnings

**Image Compression Strategy:**
- Target 1080px matches Instagram standard
- Sub-1MB files upload quickly even on slower connections
- Adaptive quality (0.7 → 0.1) ensures size limits met
- SwiftUI's UIGraphicsImageRenderer efficient for resizing

**Simulator Network Limitations:**
- Simulator is unreliable for upload testing
- QUIC protocol issues common
- Always test network operations on physical device
- Even small files can timeout on simulator

**Storage RLS Pattern:**
- Simple is better: `bucket_id = 'posts'` for authenticated users
- Avoid complex folder name parsing with UUIDs
- Trust app-level organization (user folders)
- Use `owner` field for UPDATE/DELETE policies

**Phase 5 Status: ✅ COMPLETE**

**Testing Results (iPhone 14):**
- ✅ Photo picker works perfectly
- ✅ Image compression works (742 KB achieved)
- ✅ Upload to Supabase Storage successful
- ✅ Post record creation successful
- ✅ Date decoding issue fixed with custom JSONDecoder.supabase
- ✅ Profile loading working
- ✅ End-to-end post creation flow complete

**Important Fix Applied:**
Created `JSONDecoder+Supabase.swift` extension to handle Supabase's ISO8601 dates with fractional seconds (e.g., `2024-10-22T12:34:56.789123+00:00`). This fixed both profile loading and post creation errors.

---

### ✅ Phase 6 Part A: Feed Data Integration – COMPLETE

**Completed:** October 22, 2025

**What We Built:**

✅ **FeedService.swift** - Complete feed fetching with:
- Fetches all posts (not just followed users - will implement follows in Phase 8)
- Generates signed URLs for images (1 hour expiry)
- Fetches like counts, comment counts, and like status
- Pagination support (20 posts per page)
- Embedded author profiles via Supabase joins

✅ **FeedViewModel.swift** - State management with:
- Loading states (idle, loading, loaded, error)
- `loadFeed()` - Fetches fresh data
- `loadMorePostsIfNeeded()` - Infinite scroll pagination
- `toggleLike()` - Optimistic UI updates (Phase 7 will add API calls)

✅ **FeedView.swift** - Updated feed UI:
- Loading spinner, error view with retry, empty state
- Replaced mock data with real Supabase posts
- Displays real images using signed URLs
- ForEach with explicit ID tracking

✅ **PostCellView.swift** - Real image display:
- AsyncImage with signed URLs
- Loading and error states for images
- All UI working correctly

✅ **Storage Policy Fix:**
- Changed `posts` bucket SELECT policy to allow all authenticated users
- Switched from `getPublicURL()` to `createSignedURL()` for private bucket

✅ **Post Model Updates:**
- Added `mediaURL` property for pre-fetched signed URLs

**Testing Results:**
- ✅ Feed loads real posts from Supabase
- ✅ Images display correctly using signed URLs
- ✅ Pagination ready (loads 20 posts, can load more on scroll)
- ✅ Posts ordered by most recent first
- ✅ Author profiles display with avatars
- ✅ Like button works on all posts (Bug #1 fixed - GeometryReader removed)
- ✅ Caption display works correctly (Bug #2 fixed - CaptionView extracted)

**Phase 6 Part A Status: ✅ COMPLETE - All bugs resolved, feed fully functional**

---

### ✅ Bug Fixes - Phase 6 Part A (October 22, 2025)

#### Issue #1: Like Button Not Working on Specific Posts - ✅ FIXED

**Symptom:**
- ~1 out of every 5-7 posts has a non-functional like button
- Tap gesture does not fire at all (no console logs, no SwiftUI hit detection)
- Other posts' like buttons work perfectly
- Issue persists across app restarts
- **CRITICAL**: Posts created with NEW code still exhibit the bug (not related to old code state)

**Patterns Discovered:**
- **NOT position-based** - When a problematic post is deleted, the issue moves to a different post
- **NOT data-based** - Problematic posts have identical data structure to working posts (verified in Supabase)
- **NOT code-based** - New posts created after code refactor still show the bug
- **Affects random posts** - Appears to be ~20% of posts
- **SwiftUI hit-testing failure** - Tap doesn't register at all (confirmed via debug logs)

---

**DEBUGGING ITERATIONS:**

**Iteration #1-7: Closure Capture Hypothesis (October 22, 2025)**
*Theory: SwiftUI's ForEach wasn't properly capturing closures for certain posts*

What we tried:
1. ✅ Explicit ForEach ID tracking with `id: \.id` - NO CHANGE
2. ✅ Adding `.id(post.id)` to PostCellView - NO CHANGE
3. ✅ Capturing UUID instead of Post object in closures - NO CHANGE
4. ✅ Switching from `Button` to `.onTapGesture` - NO CHANGE
5. ✅ Making closures required (`let`) instead of optional (`var`) - NO CHANGE
6. ✅ Using VStack instead of LazyVStack - NO CHANGE
7. ✅ Adding unique IDs to each button - NO CHANGE
8. ❌ Breaking body into computed properties - Caused Swift compiler "type-check" errors

**Result:** ❌ Closures were NOT the root cause

---

**Iteration #8: Caption Type-Check Error Fix (October 22, 2025)**
*Fix Bug #2 which was blocking further investigation of Bug #1*

What we did:
- Extracted complex caption Text concatenation into separate `CaptionView` struct
- Simplified ternary operators in caption display logic

**Result:** ✅ Type-check error FIXED, but like button bug persists

---

**Iteration #9: EnvironmentObject Refactor (October 22, 2025)**
*Theory: Eliminate closures entirely by passing ViewModel directly*

What we did:
- Changed PostCellView to accept `@EnvironmentObject var feedViewModel: FeedViewModel`
- Removed all closure parameters (`onLikeTapped`, `onCommentTapped`)
- Like button now directly calls `feedViewModel.toggleLike(forPostID: post.id)`
- Updated FeedView to pass `.environmentObject(viewModel)` to each cell

**Test Results:**
- ✅ Code compiles and builds successfully
- ✅ All NEW posts (created after refactor) have working like buttons
- ❌ The existing problematic post STILL has broken like button
- ❌ Debug logs confirm tap is NOT firing (SwiftUI hit-testing failure)

**Critical Discovery:** The bug is NOT related to old code state. Posts created with the new EnvironmentObject pattern still randomly exhibit the bug.

**Current Theory:** This is a **SwiftUI hit-testing/layout bug** where certain PostCellView instances have their like button's tap target obscured or incorrectly calculated. The issue is likely in the view hierarchy or layout constraints.

---

**Iteration #10: Explicit Hit-Testing with contentShape (October 22, 2025)**
*Theory: SwiftUI's hit-testing needs explicit frame and content shape*

What we did:
- Added `.frame(width: 44, height: 44)` to all action buttons (Apple's recommended minimum tap target)
- Added `.contentShape(Rectangle())` to make entire frame tappable
- Added `.allowsHitTesting(true)` to like button explicitly

**Test Results:**
- ✅ Code compiles and builds successfully
- ❌ Problematic post's like button STILL doesn't work
- ❌ No debug logs appear (tap still not firing)

**Result:** ❌ Explicit content shapes did NOT fix the issue. Reverted for better styling.

**Discovery:** The issue is NOT related to tap target size or content shape definition.

---

**Iteration #11: Replace Image+onTapGesture with Button (October 22, 2025)**
*Theory: Button has more reliable hit-testing than gesture modifiers*

What we did:
- Replaced all `Image` + `.onTapGesture` with proper SwiftUI `Button` views
- Like button: `Button { action } label: { Image(...) }`
- Applied to all action buttons (like, comment, share, bookmark)

**Test Results:**
- ✅ Code compiles and builds successfully
- ✅ Better code structure (kept for cleaner implementation)
- ❌ Problematic post's like button STILL doesn't work
- ❌ No debug logs appear (tap still not firing)

**Result:** ❌ Button vs Image+gesture does NOT affect the bug. **Keeping Button implementation for better code quality.**

**Discovery:** The issue is NOT related to tap gesture vs Button implementation.

---

**Iteration #12: Remove GeometryReader from imageView (October 22, 2025)** ✅ **BUG FIXED!**
*Theory: GeometryReader is causing hit-testing issues by expanding unpredictably*

What we did:
- **Removed GeometryReader entirely** from imageView
- Replaced with direct `.aspectRatio(1, contentMode: .fit)` on each AsyncImage phase
- Simplified layout calculation - no more dynamic geometry measurements

**Test Results:**
- ✅ Code compiles and builds successfully
- ✅✅✅ **ALL posts' like buttons now work perfectly!**
- ✅ Previously problematic post's like button now works
- ✅ All new posts work correctly
- ✅ Debug logs confirm taps are firing properly

**Result:** ✅✅✅ **BUG COMPLETELY FIXED!**

**ROOT CAUSE DISCOVERED:**
GeometryReader in the imageView was expanding and overlapping the action buttons area in ~20% of posts (likely due to timing issues with AsyncImage loading and layout calculation). This blocked hit-testing for the like button in those specific cells. Removing GeometryReader and using SwiftUI's native `.aspectRatio()` modifier resolved the layout overlap issue.

**Key Learnings:**
1. **GeometryReader can interfere with hit-testing** - It expands to fill available space in unpredictable ways
2. **AsyncImage + GeometryReader = potential layout issues** - The combination can cause timing-based layout bugs
3. **SwiftUI's native modifiers are more reliable** - `.aspectRatio()` is safer than manual geometry calculations
4. **Hit-testing failures manifest as random bugs** - The 20% failure rate was due to race conditions in layout calculation

**Final Solution:**
- Use `.aspectRatio(1, contentMode: .fit)` directly on AsyncImage phases
- Avoid GeometryReader for simple layout tasks
- Keep Button implementation (cleaner than Image + gesture)

**Files Involved:**
- `/Kinnect/Views/Feed/FeedView.swift` - ForEach and cell rendering
- `/Kinnect/Views/Feed/PostCellView.swift` - actionButtonsView (lines 121-151)
- `/Kinnect/ViewModels/FeedViewModel.swift` - toggleLike method

---

#### Issue #2: Swift Compiler "Type-Check" Error - ✅ FIXED

**Solution:** Extracted complex caption Text concatenation into separate `CaptionView` struct

**What We Did:**
- Created new `CaptionView` struct with simpler computed properties
- Broke down nested ternary operators
- Replaced inline Text concatenation with clean component

**Result:** ✅ Type-check error completely resolved

---

### 🚀 Next: Fix Known Issues, Then Phase 6 Part B

**Before moving to Part B (Video Support), need to:**
1. Resolve Swift compiler type-check error in PostCellView
2. Fix like button closure capture bug
3. Test feed thoroughly with multiple posts

**Part B: Video Support** (Pending)
- Video upload with PHPicker
- Client-side video compression
- Thumbnail generation on device
- AVPlayer for playback
- Manual play/pause controls (not auto-play)

---
