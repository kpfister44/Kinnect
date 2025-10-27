# Kinnect

A private, Instagram-style iOS app for sharing photos and videos with close family and friends.

---

## Project Overview

**Kinnect** is a private social photo sharing app designed for intimate circles — not the public internet. It replicates the look and feel of Instagram but strips away ads, algorithms, and public access. Users can upload photos and videos, view a feed of posts from people they follow, and interact through likes and comments.

The goal is **simplicity and privacy**: a beautiful, familiar experience tailored for small groups of trusted people.

---

## Core Features (MVP)

- **User Authentication** via Sign in with Apple
- **Photo & Video Upload** — capture or select from library
- **Feed** showing posts from followed users (chronological)
- **Like & Comment System** for social interaction
- **Profile View** displaying user posts and metadata
- **Push Notifications** (optional) for new likes, comments, and posts
- **Future Enhancements:**
  - Stories (24-hour ephemeral posts)
  - Basic direct messaging

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Swift + SwiftUI (iOS 17+) |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Storage** | Supabase Storage (private bucket + signed URLs) |
| **Authentication** | Sign in with Apple (via Supabase Auth) |
| **Realtime Updates** | Supabase Realtime API |
| **Testing** | Swift Testing + XCTest UI Tests |
| **Local Caching** | iOS file system + optional SwiftData |
| **Hosting** | Supabase managed instance (no custom server) |

---

## Architecture

**Pattern:** MVVM (Model-View-ViewModel) using SwiftUI

### Core Modules

- **`AuthViewModel`** – manages authentication state and Sign in with Apple flow
- **`FeedViewModel`** – fetches and renders the post feed
- **`UploadViewModel`** – handles camera capture and background uploads
- **`ProfileViewModel`** – manages user profile and post history

### Key Design Decisions

- **Media Uploads:** `URLSession` background tasks upload to Supabase signed URLs
- **Data Source:** Supabase PostgreSQL accessed via Supabase iOS SDK
- **Realtime Updates:** Subscribe to new posts via Supabase Realtime
- **Testing:** Unit tests cover ViewModels; UI tests validate feed rendering, upload flow, and auth state

---

## Database Schema (Simplified)

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

### Row-Level Security (RLS)

- Users can **read posts** from themselves or people they follow
- Users can **create posts** only for themselves
- Users can **like/comment** on visible posts
- Media files are stored in a **private bucket** with signed URL access only

---

## Security & Privacy

- **Private, invite-only app** with Sign in with Apple
- **Row-Level Security (RLS)** enforced on all database tables
- **Media stored privately** using Supabase Storage with signed URL access
- **No public endpoints** — all access authenticated via Supabase JWTs
- **No tracking, ads, or algorithmic feeds** — user privacy is paramount

---

## Design Principles

**Visual Style:** Replicate Instagram's UI and UX as closely as possible

### Layout & Navigation

- **Bottom tab bar** with:
  - Feed
  - Search (optional for later phases)
  - Upload (center button)
  - Activity
  - Profile
- **Full-width image cards** with username, avatar, likes, and comments
- **Rounded avatars** and uniform media aspect ratios

### Color & Typography

- **Minimalist color scheme:**
  - White background
  - Dark text (primary labels)
  - Subtle gray dividers and secondary text
- **Typography:** Apple San Francisco (SF Pro)
- **Layout:** Spacious, clean, mirroring Instagram's design language

### Animations & Interactions

- **Subtle animations:** Fades and springs for navigation and state changes
- **Native feel:** Mimic Instagram's transitions (e.g., like animation, comment slide-in)
- **Consistency:** Every interaction should feel intuitive and responsive

### Accessibility

- Follow iOS **system font scaling** (Dynamic Type)
- Support **Dark Mode** preferences
- Provide **VoiceOver labels** for all interactive elements

### Goal

If a user opened Kinnect by accident, it should **look like Instagram** — but behave like a private, ad-free version for their close circle.

---

## Development Guidelines

### Code Organization

- **Keep code modular** using MVVM
- **SwiftUI views** should remain declarative and side-effect free
- **ViewModels** handle business logic, state management, and async operations

### Testing

- Write **unit tests** for all ViewModels
- Write **UI tests** for critical user flows (auth, upload, feed)
- Add new features incrementally and test thoroughly

### Backend Logic

- Use **Supabase Edge Functions** (TypeScript) sparingly for privileged server tasks:
  - Signed URL generation
  - Push notification dispatch
  - Admin operations (e.g., user moderation)

### Priorities

1. **Simplicity** — avoid over-engineering
2. **Privacy** — never compromise user data
3. **Reliability** — ensure smooth, bug-free experiences

---

## Supabase Backend Management

### IMPORTANT: Using the Supabase MCP Server

**For all Supabase backend interactions, you MUST use the Supabase MCP server tools.**

The Supabase MCP server is configured and provides direct access to the Supabase backend via MCP tools. All database operations, migrations, storage management, and configuration should be done through these tools.

### Available MCP Tools for Supabase:

**Project Management:**
- `mcp__supabase__list_projects` - List all Supabase projects
- `mcp__supabase__get_project` - Get project details
- `mcp__supabase__get_project_url` - Get API URL
- `mcp__supabase__get_anon_key` - Get anonymous API key

**Database Operations:**
- `mcp__supabase__list_tables` - List all tables in schemas
- `mcp__supabase__apply_migration` - Apply database migrations (DDL operations)
- `mcp__supabase__execute_sql` - Execute raw SQL queries
- `mcp__supabase__list_migrations` - List all migrations

**TypeScript Type Generation:**
- `mcp__supabase__generate_typescript_types` - Generate TypeScript types from schema

**Monitoring & Debugging:**
- `mcp__supabase__get_logs` - Get service logs (api, postgres, auth, storage, etc.)
- `mcp__supabase__get_advisors` - Get security and performance recommendations

**Edge Functions:**
- `mcp__supabase__list_edge_functions` - List all Edge Functions
- `mcp__supabase__get_edge_function` - Get Edge Function code
- `mcp__supabase__deploy_edge_function` - Deploy Edge Function

### Backend Setup Status

The Supabase backend is **fully configured and operational**:

✅ **Project:** Active Supabase project (`qfoyodqiltnpcikhpbdi`)
✅ **Database:** 5 tables with Row-Level Security enabled
  - `profiles` - User profile information
  - `follows` - Following relationships
  - `posts` - Photo/video posts
  - `likes` - Post likes
  - `comments` - Post comments

✅ **Storage:** 2 private buckets configured
  - `avatars` - Profile pictures (2MB limit, images only)
  - `posts` - Media content (50MB limit, images & videos)

✅ **Security:** Complete RLS policies implemented
✅ **iOS SDK:** Supabase Swift SDK v2.36.0 installed
✅ **Configuration:** `Secrets.plist` contains API credentials

### Project ID

The active Supabase project ID is: **`qfoyodqiltnpcikhpbdi`**

Use this project ID when calling Supabase MCP tools.

### Guidelines for Backend Changes

1. **Always use MCP tools** - Never manually edit the Supabase dashboard when automation is available
2. **Use migrations for schema changes** - Apply all DDL changes via `mcp__supabase__apply_migration`
3. **Test with advisors** - Run `mcp__supabase__get_advisors` after schema changes to check for security issues
4. **Monitor logs** - Use `mcp__supabase__get_logs` to debug backend issues
5. **Document changes** - Update PLAN.md when backend features are added

---

## Feature Documentation

Detailed documentation for completed features is available in `/docs/`. Reference these documents when working on related functionality:

### Core Infrastructure

**`/docs/BACKEND_SETUP.md`** - Foundation & Supabase Configuration
- Project structure and MVVM architecture
- Supabase SDK setup and services layer
- Database schema (all 5 tables)
- Row-Level Security policies
- Storage buckets (avatars, posts)
- MCP tools reference

**When to reference:** Backend changes, database migrations, storage operations, RLS policy updates

---

### Feature Implementations

**`/docs/features/AUTHENTICATION.md`** - Sign in with Apple Flow
- AuthViewModel and auth state management
- WelcomeView, UsernameCreationView, TabBarView
- Session persistence and routing
- Instagram color palette

**When to reference:** Auth-related changes, user onboarding, session management

---

**`/docs/features/PROFILE_SYSTEM.md`** - User Profiles
- ProfileService, ProfileViewModel
- Profile viewing and editing
- Avatar upload with compression
- Stats display (posts/followers/following)
- Cache-busting for images

**When to reference:** Profile features, avatar handling, user stats, image compression patterns

---

**`/docs/features/FEED_SYSTEM.md`** - Post Feed Display
- FeedService, FeedViewModel
- PostCellView, CaptionView
- Signed URLs for images
- Pagination and infinite scroll
- GeometryReader hit-testing bug fix

**When to reference:** Feed functionality, post display, pagination, AsyncImage patterns, hit-testing issues

---

**`/docs/features/UPLOAD_SYSTEM.md`** - Photo Upload & Post Creation
- PostService, UploadViewModel
- PHPicker integration
- Image compression strategy
- NewPostView (caption entry)
- PhotosPicker race condition bug fix

**When to reference:** Upload functionality, image compression, photo selection, sheet presentation issues

---

**`/docs/features/SOCIAL_INTERACTIONS.md`** - Likes & Comments
- LikeService, CommentService, CommentViewModel
- Optimistic UI patterns
- CommentsView (bottom sheet)
- Character limits and validation
- Comment count synchronization

**When to reference:** Likes, comments, optimistic updates, bottom sheets, character validation

---

**`/docs/features/FOLLOWING_SYSTEM.md`** - User Search & Follow/Unfollow
- UserSearchService, FollowService
- Real-time search with debouncing
- Follow/unfollow with optimistic UI
- Followers/Following lists
- Feed filtering by followed users

**When to reference:** User search, follow relationships, follower lists, feed filtering

---

**`/docs/features/REALTIME_UPDATES.md`** - Live Feed Updates
- RealtimeService with Supabase channels
- "New posts available" banner
- Real-time like/comment count updates
- Optimistic UI patterns (no double-counting)
- Clean subscription lifecycle

**When to reference:** Realtime subscriptions, live updates, subscription management

---

**`/docs/features/ACTIVITY_SYSTEM.md`** - Activity Tab (Notifications)
- ActivityService, ActivityViewModel
- Database triggers for auto-creation
- Activity grouping (likes on same post)
- Real-time badge updates
- Mark as read functionality
- Navigation to profiles

**When to reference:** Activity notifications, badge counts, activity grouping, database triggers

---

**`/docs/features/POST_MENU_ACTIONS.md`** - Post Menu Actions (Delete & Unfollow)
- PostService delete methods with CASCADE cleanup
- FeedViewModel delete/unfollow with optimistic UI
- Context-aware three-dot menu (delete own posts, unfollow others)
- PostCellView and PostDetailView integration
- Confirmation dialogs with error handling

**When to reference:** Post deletion, unfollowing from feed, three-dot menu, optimistic UI with rollback

---

## Common Issues & Solutions

### PhotosPicker Sheet Presentation Race Condition

**Symptom:** First photo upload after app launch fails - PhotosPicker dismisses but NewPostView sheet doesn't present. UI "zooms out" briefly. Works correctly on subsequent attempts.

**Root Cause:** The `onChange` handler fires multiple times on first launch, causing a race condition between PhotosPicker dismissal and sheet presentation.

**Solution:**
1. Add `isProcessingImage` flag to prevent duplicate processing
2. Add guard clauses with proper early returns
3. Use explicit `MainActor.run` for all state updates
4. Add 0.5 second delay to ensure PhotosPicker fully dismisses before presenting sheet

**Location:** `UploadView.swift` - `.onChange(of: selectedItem)` handler

---

### Like Button Not Working on Random Posts (GeometryReader Hit-Testing Issue)

**Symptom:** Approximately 20% of posts have non-functional like buttons. Taps don't register at all (no console logs, no visual feedback). Other posts work perfectly. Issue persists across app restarts and affects random posts regardless of data or position.

**Root Cause:** GeometryReader in `imageView` was expanding unpredictably and overlapping the action buttons area below it. This blocked SwiftUI's hit-testing for the like button in certain cells, likely due to timing issues with AsyncImage loading and layout calculation creating a race condition.

**Solution:**
1. Remove GeometryReader from imageView completely
2. Use `.aspectRatio(1, contentMode: .fit)` directly on each AsyncImage phase instead
3. Let SwiftUI handle layout natively without manual geometry calculations

**Key Insight:** GeometryReader + AsyncImage can cause timing-based layout bugs where the reader expands to fill space before the image loads, causing overlap issues. SwiftUI's native `.aspectRatio()` modifier is more reliable for simple square aspect ratio constraints.

**Location:** `PostCellView.swift` - `imageView` computed property

---


**Built with Swift, SwiftUI, and Supabase.**
