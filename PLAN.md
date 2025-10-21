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

## Phase 5: Upload & Media Handling
**Goal:** Users can capture and upload photos/videos

### Tasks:
1. **Camera & Photo Picker**
   - Access camera and photo library
   - Handle permissions
   - Image/video selection UI (Instagram-style)

2. **Image Compression Edge Function**
   - Deploy Supabase Edge Function for server-side image compression
   - Generate optimized versions (thumbnail, full-size)
   - Return storage paths

3. **Media Upload Flow**
   - Capture/select photo or video
   - Add caption screen
   - Background upload to Supabase Storage
   - Progress indicator
   - Error handling

4. **UploadViewModel**
   - Manage upload state
   - Use `URLSession` background tasks
   - Create post record after successful upload
   - Handle retries on failure

5. **Post Creation**
   - Save post metadata to `posts` table
   - Link to uploaded media via `media_key`

**Deliverable:** Users can capture/select photos, add captions, and upload posts to Supabase

---

## Phase 6: Feed Implementation
**Goal:** Display posts from followed users

### Tasks:
1. **FeedService**
   - Fetch posts from followed users (SQL query with join)
   - Paginated loading (initial 20 posts, load more on scroll)
   - Fetch post metadata (author profile, like count, comments)

2. **FeedViewModel**
   - Load and cache feed data
   - Handle pull-to-refresh
   - Pagination logic
   - State management (loading, loaded, error)

3. **Post Display**
   - Render posts using Post cell component
   - Lazy image loading for photos
   - Video player for video posts
   - Signed URL fetching from Supabase Storage

4. **Feed Interactivity**
   - Scroll to top on tab re-tap
   - Smooth scrolling performance

**Deliverable:** Users see a chronological feed of posts from people they follow

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

### 🚀 Next: Phase 3 – Profile System

**What We'll Build:**
- Profile model and ProfileService for CRUD operations
- Complete ProfileView with avatar, username, stats, posts grid
- Edit profile screen with avatar upload
- Follow/Unfollow functionality
- ProfileViewModel for state management

**Prerequisites:**
- ✅ Phase 2: Authentication Flow complete
- ✅ Backend profiles table and storage bucket ready

**Status:** Ready to start after Phase 2 testing and refinement!
