# Kinnect Implementation Plan

## Overview
Building a polished, private Instagram-style iOS app from scratch. This plan tracks progress and defines the roadmap for upcoming features.

---

## Current Status (October 24, 2025)

### ✅ Completed Phases (1-9)

**Phase 1: Foundation & Project Setup** → See `/docs/BACKEND_SETUP.md`
- MVVM architecture, Supabase SDK, core services
- Database schema (5 tables), RLS policies, storage buckets

**Phase 2: Authentication Flow** → See `/docs/features/AUTHENTICATION.md`
- Sign in with Apple, username creation, session persistence
- Instagram-style color palette and design system

**Phase 3: Profile System** → See `/docs/features/PROFILE_SYSTEM.md`
- View/edit profiles, avatar upload, stats display
- Profile header, posts grid, edit form

**Phase 4: Feed UI Foundation + Phase 6A: Feed Data Integration** → See `/docs/features/FEED_SYSTEM.md`
- Instagram-style feed with PostCellView
- Real Supabase data, signed URLs, pagination
- GeometryReader hit-testing bug fixed

**Phase 5: Photo Upload & Post Creation** → See `/docs/features/UPLOAD_SYSTEM.md`
- PHPicker integration, image compression
- Caption entry, Supabase Storage upload
- PhotosPicker race condition bug fixed

**Phase 7: Social Interactions (Likes & Comments)** → See `/docs/features/SOCIAL_INTERACTIONS.md`
- Like system with optimistic UI updates
- Comment system with bottom sheet UI
- Full database persistence

**Phase 8: Following System** → See `/docs/features/FOLLOWING_SYSTEM.md`
- User search with real-time results (300ms debounce)
- Follow/unfollow with optimistic UI updates
- Followers/Following lists with tappable stats
- Feed filtering (only shows followed users' posts)
- ProfileStats mutation fix
- Security advisors check passed

**Phase 9: Realtime Updates** → See `/docs/features/REALTIME_UPDATES.md`
- Supabase Realtime subscriptions for posts, likes, comments
- Instagram-style "New posts available" banner
- Real-time like/comment count updates from other users
- Optimistic updates for current user (no double-counting)
- Clean subscription lifecycle management

---

## ✅ Phase 9: Realtime Updates (COMPLETE)

**Goal:** Feed updates in real-time when new posts are published

**Status:** ✅ Complete - All features working and tested

### ✅ Completed Features
1. **Supabase Realtime Subscription**
   - ✅ Enabled Realtime on posts, likes, comments tables
   - ✅ Created RealtimeService with channel management
   - ✅ Subscribed to INSERT/DELETE events using async sequences

2. **FeedViewModel Realtime Integration**
   - ✅ Listen for new posts with filtering
   - ✅ Show "New posts available" banner (Instagram-style)
   - ✅ Real-time like count updates (from other users)
   - ✅ Real-time comment count updates
   - ✅ Banner tap triggers refresh + scroll to top
   - ✅ Optimistic updates for current user (no double-counting)

3. **UI Components**
   - ✅ NewPostsBanner component with slide-in animation
   - ✅ FeedView integration with ZStack overlay
   - ✅ Subscription lifecycle (setup/cleanup on appear/disappear)

### 🐛 Issues Fixed
1. **Async sequence error handling** - Added `for try await` with do-catch blocks
2. **AnyJSON serialization crash** - Switched to direct dictionary access via `.value`
3. **Double-counting bug** - Filter out current user's events (already handled optimistically)

### ✅ Tested Successfully
- ✅ New post banner appears when followed users post
- ✅ Banner tap refreshes feed and scrolls to top
- ✅ Like counts update in real-time from other users
- ✅ Unlike events decrement counts correctly
- ✅ Own actions handled optimistically (no realtime duplication)
- ✅ Clean subscription lifecycle (no memory leaks)

### ❌ Deferred to Future Phases
- **Push Notifications** - Requires APNs setup, Edge Functions (Phase 10+)
- **Comment realtime updates in CommentsView** - Currently only count updates in feed

**Documentation:** See `/docs/features/REALTIME_UPDATES.md` for complete implementation details

---

## Phase 6 Part B: Video Support (Deferred)

**Goal:** Add video upload and playback capabilities

**Rationale for Deferring:** Video support has been moved after core social features (Phases 7-9) to prioritize the fundamental user experience. This is an "Instagram for close friends" app where photos are primary and video is an enhancement.

### Tasks
1. **Video Upload**
   - Extend PHPicker to support video selection
   - Video compression (client-side using AVAssetExportSession)
   - Upload to `posts` bucket (50MB limit)
   - Thumbnail generation for video preview

2. **Video Playback**
   - Add AVPlayer to PostCellView for video posts
   - Play/pause controls, mute/unmute toggle
   - Manual playback (no auto-play)

3. **Update PostCellView**
   - Detect `media_type` (photo vs video)
   - Show video player for video posts
   - Video thumbnail with play button overlay

**Key Challenges:**
- Video compression can be device-specific and complex
- AVPlayer memory management requires careful handling
- Balancing quality vs 50MB storage limit

---

## Phase 10: Polish, Testing & Edge Cases

**Goal:** Ensure a high-quality, bug-free MVP

### Tasks
1. **UI Polish**
   - Match Instagram's design language precisely
   - Dark mode support
   - Animations and transitions
   - Empty states for all screens

2. **Accessibility**
   - VoiceOver labels
   - Dynamic Type support
   - High contrast mode

3. **Testing**
   - Unit tests for all ViewModels
   - UI tests for critical flows
   - Edge case testing

4. **Performance Optimization**
   - Image caching strategy
   - Lazy loading optimizations
   - Memory management

5. **Error Handling**
   - Graceful handling of all network errors
   - User-friendly error messages
   - Retry mechanisms

6. **Final Touches**
   - App icon and splash screen
   - Onboarding hints/tooltips
   - Privacy policy and terms (if needed)

---

## Future Enhancements (Post-MVP)

- **Stories** (24-hour ephemeral posts)
- **Direct Messaging** (1:1 and group chats)
- **Video improvements** (better player, scrubbing)
- **Advanced search** (hashtags, locations)
- **Saved posts** (bookmark feature)
- **Reporting & moderation tools**

---

## Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Realtime scaling** | Test with multiple users, monitor Supabase metrics |
| **App Store approval** | Ensure privacy policy, data handling, Sign in with Apple compliance |
| **Video upload/playback** | Start with photos only, add video after core features validated |
| **Network reliability** | Implement retry logic, offline state indicators |

---

## Recommended Tech Decisions

### Edge Functions (Minimal Use)
1. **Push Notifications** ✅ Essential – requires server-side APNs integration
2. **User Moderation** ✅ Optional – admin operations (ban, delete content)

Avoid edge functions for standard CRUD operations – use RLS policies instead.

### Folder Structure

See `/docs/BACKEND_SETUP.md` for complete project structure.

**Key Patterns:**
- MVVM separation: Models, Views, ViewModels, Services
- Feature-based organization in Views folder
- Shared utilities and extensions
- Gitignored Secrets.plist for configuration

---

## Development Workflow

### When Working on Features

1. **Check existing documentation** - See `/docs/` for completed features
2. **Use Supabase MCP tools** - All backend operations via MCP
3. **Follow MVVM architecture** - Maintain separation of concerns
4. **Test on physical device** - Especially for auth, uploads, and network operations
5. **Run advisors after DB changes** - `mcp__supabase__get_advisors` for security checks
6. **Update this plan** - Mark phases complete, add learnings

### Code Style

- SwiftUI views: Declarative, side-effect free
- ViewModels: Handle business logic, async operations
- Services: Backend communication, data transformation
- Instagram design language: Match colors, spacing, animations

---

**Last Updated:** October 24, 2025
**Current Phase:** Phase 9 Complete ✅ (Realtime Updates)
**Next Milestone:** Phase 10 (Polish, Testing & Edge Cases) or Phase 6B (Video Support)
