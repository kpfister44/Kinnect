# Backend Setup & Foundation

**Phase 1: Foundation & Project Setup**
**Completed:** October 17-18, 2025

---

## Overview

This document covers the initial project foundation and Supabase backend configuration for Kinnect. All backend operations are managed via the **Supabase MCP server** tools.

---

## Project Structure

### Xcode Project Organization

```
Kinnect/
├── Models/
│   ├── Profile.swift
│   ├── Post.swift
│   ├── Comment.swift
│   ├── Like.swift
│   └── Follow.swift
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

### MVVM Architecture

- **Models**: Data structures matching database schema (Codable)
- **Views**: SwiftUI views (declarative, side-effect free)
- **ViewModels**: Business logic, state management, async operations (ObservableObject)
- **Services**: API layer, database operations, backend communication

---

## Core Services Layer

### SupabaseService

Singleton service for Supabase client configuration:

```swift
SupabaseService.shared.client
```

- Loads configuration from `Secrets.plist`
- Provides centralized access to Supabase client
- Handles initialization and error cases

### AuthService

Authentication operations using Supabase Auth:

```swift
signInWithApple()
signOut()
hasCompletedProfile()
```

- Sign in with Apple integration
- Session management
- Profile completion checks

### JSONDecoder+Supabase Extension

Custom decoder for Supabase's ISO8601 date format:

```swift
let decoder = JSONDecoder.supabase
```

Handles fractional seconds in timestamps: `2024-10-22T12:34:56.789123+00:00`

---

## Dependencies

### Swift Package Manager

- **Supabase Swift SDK v2.36.0**
  - Auth, Database, Storage, Realtime modules
  - Async/await support

### Configuration

**Secrets.plist** (gitignored):
```xml
<dict>
    <key>SUPABASE_URL</key>
    <string>https://qfoyodqiltnpcikhpbdi.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>...</string>
</dict>
```

---

## Database Schema

### Tables

**profiles**
```sql
CREATE TABLE profiles (
  user_id UUID PRIMARY KEY REFERENCES auth.users,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  full_name TEXT,
  bio TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**follows**
```sql
CREATE TABLE follows (
  follower UUID REFERENCES profiles(user_id),
  followee UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (follower, followee)
);
```

**posts**
```sql
CREATE TABLE posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author UUID REFERENCES profiles(user_id),
  caption TEXT,
  media_key TEXT NOT NULL,
  media_type TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

**likes**
```sql
CREATE TABLE likes (
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  created_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);
```

**comments**
```sql
CREATE TABLE comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(user_id),
  body TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

---

## Row-Level Security (RLS)

### Profiles Table
- Users can read their own profile and profiles of people they follow
- Users can only update their own profile

### Posts Table
- Users can read posts from themselves or people they follow
- Users can only create posts for themselves
- Users can only delete their own posts

### Likes Table
- Users can read likes on visible posts
- Users can only create likes as themselves
- Users can only delete their own likes

### Comments Table
- Users can read comments on visible posts
- Users can only create comments as themselves
- Users can only delete their own comments

### Follows Table
- Users can read follows for any profile
- Users can only create follows where they are the follower
- Users can only delete their own follow relationships

---

## Storage Buckets

### avatars
- **Purpose**: Profile pictures
- **Size Limit**: 2MB per file
- **File Types**: Images only (JPEG, PNG)
- **Access**: Private with signed URLs
- **Organization**: `{userId}/{userId}.jpg`

**RLS Policies:**
```sql
-- INSERT: Authenticated users can upload
CREATE POLICY "Authenticated users can upload avatars"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');

-- UPDATE/DELETE: Only file owners
CREATE POLICY "Users can update their own avatars"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars' AND owner = auth.uid());
```

### posts
- **Purpose**: Photo and video content
- **Size Limit**: 50MB per file
- **File Types**: Images (JPEG, PNG) and videos (MP4, MOV)
- **Access**: Private with signed URLs
- **Organization**: `{userId}/{postId}.jpg` or `.mp4`

**RLS Policies:**
```sql
-- INSERT: Authenticated users can upload
CREATE POLICY "Authenticated users can upload posts"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'posts');

-- SELECT: All authenticated users can read
CREATE POLICY "Authenticated users can view posts"
ON storage.objects FOR SELECT TO authenticated
USING (bucket_id = 'posts');
```

---

## Supabase Project Details

**Project ID:** `qfoyodqiltnpcikhpbdi`
**Project URL:** `https://qfoyodqiltnpcikhpbdi.supabase.co`
**Region:** (configured in Supabase dashboard)

---

## Important Learnings

### Storage File Organization
✅ **Correct:** `{userId}/{fileName}.jpg` (user-specific folders)
❌ **Incorrect:** `{fileName}.jpg` (root level)

User-specific folders enable better organization and future policy enhancements.

### RLS Policy Patterns

**For private apps with authenticated users only:**
- Keep INSERT policies simple: `bucket_id = 'bucket_name'`
- Trust app-level folder organization
- Use `owner` field for UPDATE/DELETE (automatically set by Supabase)
- Avoid complex regex-based folder name parsing with UUIDs

### Date Decoding
Supabase returns ISO8601 dates with fractional seconds. Use `JSONDecoder.supabase` extension for all API calls.

### Supabase SDK API Updates
- ❌ Old: `client.database.from("table")`
- ✅ New: `client.from("table")`

---

## Cache-Busting for Images

When using the same filename (e.g., `{userId}.jpg`), add timestamp to force cache refresh:

```swift
let cacheBustedURL = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
```

This prevents iOS from showing stale cached images after uploads.

---

## Managing Backend with MCP Tools

All Supabase operations should use the MCP server tools:

**Database:**
- `mcp__supabase__list_tables` - View schema
- `mcp__supabase__apply_migration` - Apply schema changes (DDL)
- `mcp__supabase__execute_sql` - Run queries (DML)
- `mcp__supabase__list_migrations` - View migration history

**Monitoring:**
- `mcp__supabase__get_logs` - Debug issues (api, postgres, auth, storage)
- `mcp__supabase__get_advisors` - Security and performance checks

**Project Info:**
- `mcp__supabase__get_project` - Project details
- `mcp__supabase__get_project_url` - API URL
- `mcp__supabase__get_anon_key` - Anonymous key

---

## Testing & Verification

✅ **Project builds successfully**
✅ **Supabase client initializes correctly**
✅ **All 5 tables created with RLS enabled**
✅ **Storage buckets configured with policies**
✅ **API credentials loaded from Secrets.plist**
✅ **Backend operational and tested**

---

## Files Involved

**Core Services:**
- `/Services/SupabaseService.swift`
- `/Services/AuthService.swift`
- `/Utilities/JSONDecoder+Supabase.swift`

**Models:**
- `/Models/Profile.swift`
- `/Models/Post.swift`
- `/Models/Comment.swift`
- `/Models/Like.swift`
- `/Models/Follow.swift`

**Configuration:**
- `/Resources/Secrets.plist` (gitignored)

**Documentation:**
- `SUPABASE_SETUP.md`
- `SPM_SETUP.md`

---

**Status:** ✅ Complete
**Next Phase:** Authentication Flow (see `/docs/features/AUTHENTICATION.md`)
