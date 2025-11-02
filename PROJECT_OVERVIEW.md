# Kinnect - Project Overview

A private, Instagram-style iOS app for sharing photos and videos with close family and friends.

---

## What is Kinnect?

**Kinnect** is a private social photo sharing app designed for intimate circles — not the public internet. It replicates the look and feel of Instagram but strips away ads, algorithms, and public access.

**Core Features (MVP):**
- User Authentication via Sign in with Apple
- Photo & Video Upload (capture or select from library)
- Feed showing posts from followed users (chronological)
- Like & Comment System for social interaction
- Profile View displaying user posts and metadata
- Activity notifications for likes, comments, and new posts
- Pinch-to-zoom on post images for detail viewing

**Goal:** Simplicity and privacy — a beautiful, familiar experience for small groups of trusted people.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | Swift + SwiftUI (iOS 17+) |
| **Backend** | Supabase (PostgreSQL + Auth + Storage + Realtime) |
| **Authentication** | Sign in with Apple (via Supabase Auth) |
| **Storage** | Supabase Storage (private buckets + signed URLs) |
| **Realtime** | Supabase Realtime API |
| **Architecture** | MVVM (Model-View-ViewModel) |
| **Testing** | Swift Testing + XCTest UI Tests |

---

## Architecture

**Pattern:** MVVM using SwiftUI

**Core ViewModels:**
- `AuthViewModel` – Authentication state and Sign in with Apple flow
- `FeedViewModel` – Post feed fetching and rendering
- `ProfileViewModel` – User profile and post history
- `UploadViewModel` – Camera capture and background uploads
- `CommentViewModel` – Comment management
- `ActivityViewModel` – Activity notifications

**Key Design Decisions:**
- Media uploads use `URLSession` background tasks to Supabase signed URLs
- Supabase iOS SDK for all backend communication
- Realtime subscriptions for live feed updates
- Optimistic UI patterns for likes/comments
- SwiftUI views are declarative and side-effect free
- ViewModels handle all business logic and async operations

**Detailed Architecture:** See `/docs/BACKEND_SETUP.md`

---

## Database Schema

**5 core tables with Row-Level Security (RLS):**

| Table | Purpose |
|-------|---------|
| `profiles` | User profile information (username, avatar_url, full_name) |
| `follows` | Following relationships between users |
| `posts` | Photo/video posts with media_key, caption, author |
| `likes` | Post likes (composite primary key: post_id, user_id) |
| `comments` | Post comments with body text |

**Additional tables:**
- `activities` – Activity notifications for likes, comments, follows

**Storage Buckets:**
- `avatars` – Profile pictures (2MB limit, images only)
- `posts` – Media content (50MB limit, images & videos)

**RLS Security:**
- Users can read posts from themselves or people they follow
- Users can create posts only for themselves
- Users can like/comment on visible posts
- Media files require signed URL access only

**Full Schema:** See `/docs/BACKEND_SETUP.md`

---

## Supabase Backend

**Project ID:** `qfoyodqiltnpcikhpbdi`

**Status:** Fully configured and operational
- ✅ Database: 5 tables + RLS policies
- ✅ Storage: 2 private buckets
- ✅ iOS SDK: v2.36.0 installed
- ✅ Configuration: `Secrets.plist`

**Supabase MCP Tools:** All backend operations (migrations, queries, logs, advisors, edge functions) use Supabase MCP server tools. See `/docs/BACKEND_SETUP.md` for complete MCP tools reference.

### Guidelines for Backend Changes

1. **Always use MCP tools** – Never manually edit the Supabase dashboard when automation is available
2. **Use migrations for schema changes** – Apply all DDL changes via `mcp__supabase__apply_migration`
3. **Test with advisors** – Run `mcp__supabase__get_advisors` after schema changes to check for security issues
4. **Monitor logs** – Use `mcp__supabase__get_logs` to debug backend issues
5. **Document changes** – Update relevant docs when backend features are added

### Edge Functions

Use **Supabase Edge Functions** (TypeScript) sparingly for privileged server tasks:
- Signed URL generation
- Push notification dispatch
- Admin operations (e.g., user moderation)

Deploy with `mcp__supabase__deploy_edge_function`

---

## Design Principles

**Visual Style:** Replicate Instagram's UI/UX as closely as possible

**Layout:**
- Bottom tab bar: Feed, Search, Upload (center), Activity, Profile
- Full-width image cards with username, avatar, likes, comments
- Rounded avatars and square media aspect ratios (1:1)

**Color & Typography:**
- Minimalist: White background, dark text, subtle gray dividers
- Typography: SF Pro (Apple San Francisco)
- Instagram color palette for consistency

**Interactions:**
- Subtle animations (fades and springs)
- Native feel mimicking Instagram transitions
- Responsive and intuitive

**Accessibility:**
- System font scaling (Dynamic Type)
- Dark Mode support
- VoiceOver labels for all interactive elements

**Goal:** If a user opened Kinnect by accident, it should look like Instagram — but behave like a private, ad-free version.

---

## Feature Documentation

Detailed documentation for implemented features:

### Core Infrastructure
**`/docs/BACKEND_SETUP.md`** – Foundation & Supabase Configuration
- Complete database schema and RLS policies
- Supabase SDK setup and services layer
- Storage buckets configuration
- MCP tools reference

### Feature Implementations

**`/docs/features/AUTHENTICATION.md`** – Sign in with Apple
- AuthViewModel, session management, user onboarding flow

**`/docs/features/PROFILE_SYSTEM.md`** – User Profiles
- Profile viewing/editing, avatar upload, stats display, cache-busting patterns

**`/docs/features/FEED_SYSTEM.md`** – Post Feed Display
- Feed rendering, signed URLs, pagination, infinite scroll

**`/docs/features/UPLOAD_SYSTEM.md`** – Photo Upload & Post Creation
- PHPicker integration, image compression, NewPostView

**`/docs/features/SOCIAL_INTERACTIONS.md`** – Likes & Comments
- Optimistic UI patterns, CommentsView bottom sheet, character validation

**`/docs/features/FOLLOWING_SYSTEM.md`** – User Search & Follow/Unfollow
- Real-time search with debouncing, follow relationships, feed filtering

**`/docs/features/REALTIME_UPDATES.md`** – Live Feed Updates
- Supabase Realtime channels, "New posts available" banner, subscription lifecycle

**`/docs/features/ACTIVITY_SYSTEM.md`** – Activity Tab (Notifications)
- Activity notifications, badge counts, database triggers, grouping

**`/docs/features/POST_MENU_ACTIONS.md`** – Post Menu Actions
- Delete posts, unfollow from feed, three-dot menu, optimistic UI with rollback

**`/docs/features/PROFILE_FEED_NAVIGATION.md`** – Profile Feed Navigation
- ProfileFeedViewModel, scroll-to-post, Instagram-style grid → feed navigation

**`/docs/features/IMAGE_ZOOM.md`** – Pinch-to-Zoom Images
- ZoomableImageView component, gesture handling, scroll blocking, AsyncImage compatibility

---

## Development Guidelines

### Code Organization
- Keep code modular using MVVM
- SwiftUI views remain declarative and side-effect free
- ViewModels handle business logic, state, and async operations

### Backend Operations
- Always use Supabase MCP tools for backend changes
- Apply schema changes via `mcp__supabase__apply_migration`
- Run `mcp__supabase__get_advisors` after schema changes
- Monitor with `mcp__supabase__get_logs` for debugging


### SwiftUI Best Practices

**AsyncImage Patterns:**
- Always use `.aspectRatio()` directly on AsyncImage phases, never wrap in GeometryReader
- Track cancelled image loads and regenerate identifiers on view reappear (see `/docs/TROUBLESHOOTING.md`)
- Use cache-busting query parameters for force-refresh scenarios

**Sheet Presentation:**
- Prefer `.sheet(item:)` over `.sheet(isPresented:)` to avoid race conditions
- Use identifiable wrappers for non-Identifiable types
- Ensure single atomic state variable controls sheet presentation

**Optimistic UI:**
- Update local state immediately for user actions (likes, comments, follows)
- Always implement rollback logic in case of server errors
- See `/docs/features/SOCIAL_INTERACTIONS.md` for patterns

---

## Security & Privacy

- **Private, invite-only** with Sign in with Apple
- **Row-Level Security (RLS)** enforced on all tables – never bypass
- **Private media storage** with signed URL access only – never expose direct URLs
- **No public endpoints** – all access authenticated via Supabase JWTs
- **No tracking, ads, or algorithmic feeds**

### Security Best Practices

- **Input validation** – Validate user input in both client and backend (RLS policies)
- **Avoid security vulnerabilities:**
  - No SQL injection (use parameterized queries via Supabase SDK)
  - No XSS (sanitize user-generated content)
  - No command injection
  - Follow OWASP top 10 guidelines

---

## Common Issues

**See `/docs/TROUBLESHOOTING.md` for detailed solutions to:**
- PhotosPicker sheet presentation race condition (FIXED)
- Like button not working on random posts / GeometryReader hit-testing (FIXED)
- Avatar upload failure in simulator / iCloud Photo Library error (MITIGATED)
- Feed/profile images missing after tab switch / AsyncImage cancellation (FIXED)

**Key Takeaways:**
- Use `.sheet(item:)` not `.sheet(isPresented:)` for atomic state
- Avoid GeometryReader with AsyncImage – use `.aspectRatio()` directly
- Track cancelled image loads and regenerate on view reappear
- Simulator has limitations with iCloud photos

---

## Workflow

### Starting Work
1. Read this `PROJECT_OVERVIEW.md` for project context
2. Check relevant feature docs in `/docs/features/`
3. Review `/docs/TROUBLESHOOTING.md` for known issues

### During Development
- Follow MVVM architecture strictly
- Keep SwiftUI views declarative
- Use services layer for all Supabase interactions
- Implement optimistic UI for user actions
- Add rollback logic for error cases

### Before Completion
- Test on simulator AND physical device (photo features especially)
- Run `mcp__supabase__get_advisors` if you changed the database schema
- Check for security vulnerabilities
- Update documentation if you added a major feature

---

## Quick Reference

**Project Location:** `/Users/kyle.pfister/Kinnect`
**Supabase Project ID:** `qfoyodqiltnpcikhpbdi`
**iOS Target:** iOS 17+
**Supabase SDK:** v2.36.0

**Key Files:**
- `Secrets.plist` – Supabase credentials
- Services layer: `AuthService.swift`, `FeedService.swift`, `PostService.swift`, etc.
- ViewModels: `AuthViewModel.swift`, `FeedViewModel.swift`, `ProfileViewModel.swift`, etc.

**Built with Swift, SwiftUI, and Supabase.**
