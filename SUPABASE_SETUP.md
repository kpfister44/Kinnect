# Supabase Setup Guide

**✅ STATUS: COMPLETE** (Completed October 18, 2025)

This guide walks you through setting up your Supabase backend for Kinnect.

**Note:** This setup has already been completed using the Supabase MCP server. This document is kept for reference. For future Supabase operations, use the MCP tools documented in CLAUDE.md.

---

## Setup Summary

The following has been completed:
- ✅ Supabase project created (ID: `qfoyodqiltnpcikhpbdi`)
- ✅ Database schema with 5 tables and RLS policies
- ✅ Storage buckets (`avatars`, `posts`) with access policies
- ✅ `Secrets.plist` configured with API credentials
- ✅ Backend tested and verified operational
- ⏸️ Sign in with Apple configuration (pending Phase 2)

---

## Part 1: Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in or create an account
3. Click **"New Project"**
4. Fill in the details:
   - **Name:** Kinnect
   - **Database Password:** (choose a strong password and save it)
   - **Region:** Choose the closest to your users
   - **Pricing Plan:** Free tier is fine for development
5. Click **"Create new project"**
6. Wait for the project to finish setting up (~2 minutes)

---

## Part 2: Get Your API Credentials

1. Once your project is ready, go to **Settings > API** in the sidebar
2. You'll need two values:
   - **Project URL** (e.g., `https://yourproject.supabase.co`)
   - **anon public** key (under "Project API keys")
3. **Keep these handy** — you'll add them to `Secrets.plist` later

---

## Part 3: Database Schema Setup

### Step 1: Create Tables

Go to **SQL Editor** in the sidebar and run the following SQL script:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Profiles table
CREATE TABLE profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    full_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Follows table
CREATE TABLE follows (
    follower UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    followee UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (follower, followee),
    CONSTRAINT no_self_follow CHECK (follower != followee)
);

-- Posts table
CREATE TABLE posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    caption TEXT,
    media_key TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Likes table
CREATE TABLE likes (
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- Comments table
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_posts_author ON posts(author);
CREATE INDEX idx_posts_created_at ON posts(created_at DESC);
CREATE INDEX idx_follows_follower ON follows(follower);
CREATE INDEX idx_follows_followee ON follows(followee);
CREATE INDEX idx_likes_post_id ON likes(post_id);
CREATE INDEX idx_comments_post_id ON comments(post_id);
```

### Step 2: Enable Row-Level Security (RLS)

Run this SQL to enable RLS on all tables:

```sql
-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
```

### Step 3: Create RLS Policies

Run these policies to control data access:

```sql
-- Profiles: Users can read any profile, but only update their own
CREATE POLICY "Public profiles are viewable by everyone"
    ON profiles FOR SELECT
    USING (true);

CREATE POLICY "Users can insert their own profile"
    ON profiles FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = user_id);

-- Follows: Users can manage their own follows
CREATE POLICY "Users can view all follows"
    ON follows FOR SELECT
    USING (true);

CREATE POLICY "Users can follow others"
    ON follows FOR INSERT
    WITH CHECK (auth.uid() = follower);

CREATE POLICY "Users can unfollow others"
    ON follows FOR DELETE
    USING (auth.uid() = follower);

-- Posts: Users can only see posts from themselves or people they follow
CREATE POLICY "Users can view posts from followed users"
    ON posts FOR SELECT
    USING (
        auth.uid() = author OR
        EXISTS (
            SELECT 1 FROM follows
            WHERE follows.follower = auth.uid()
            AND follows.followee = posts.author
        )
    );

CREATE POLICY "Users can insert their own posts"
    ON posts FOR INSERT
    WITH CHECK (auth.uid() = author);

CREATE POLICY "Users can update their own posts"
    ON posts FOR UPDATE
    USING (auth.uid() = author);

CREATE POLICY "Users can delete their own posts"
    ON posts FOR DELETE
    USING (auth.uid() = author);

-- Likes: Users can like posts they can see
CREATE POLICY "Users can view likes on visible posts"
    ON likes FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM posts
            WHERE posts.id = likes.post_id
            AND (
                auth.uid() = posts.author OR
                EXISTS (
                    SELECT 1 FROM follows
                    WHERE follows.follower = auth.uid()
                    AND follows.followee = posts.author
                )
            )
        )
    );

CREATE POLICY "Users can like posts"
    ON likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can unlike posts"
    ON likes FOR DELETE
    USING (auth.uid() = user_id);

-- Comments: Users can comment on posts they can see
CREATE POLICY "Users can view comments on visible posts"
    ON comments FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM posts
            WHERE posts.id = comments.post_id
            AND (
                auth.uid() = posts.author OR
                EXISTS (
                    SELECT 1 FROM follows
                    WHERE follows.follower = auth.uid()
                    AND follows.followee = posts.author
                )
            )
        )
    );

CREATE POLICY "Users can create comments"
    ON comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own comments"
    ON comments FOR DELETE
    USING (auth.uid() = user_id);
```

---

## Part 4: Configure Authentication

### Enable Sign in with Apple

1. Go to **Authentication > Providers** in the sidebar
2. Find **Apple** in the list
3. Toggle it **ON**
4. You'll configure the Apple Developer Portal settings later (Phase 2)

For now, just enable it in Supabase.

---

## Part 5: Create Storage Buckets

### Step 1: Create Avatars Bucket

1. Go to **Storage** in the sidebar
2. Click **"New bucket"**
3. Settings:
   - **Name:** `avatars`
   - **Public bucket:** OFF (private)
   - **File size limit:** 2MB
   - **Allowed MIME types:** `image/jpeg, image/png`
4. Click **"Create bucket"**

### Step 2: Create Posts Bucket

1. Click **"New bucket"** again
2. Settings:
   - **Name:** `posts`
   - **Public bucket:** OFF (private)
   - **File size limit:** 50MB
   - **Allowed MIME types:** `image/jpeg, image/png, video/mp4, video/quicktime`
3. Click **"Create bucket"**

### Step 3: Set Storage Policies

Go back to **SQL Editor** and run:

```sql
-- Avatars bucket: Users can upload/update their own avatar
CREATE POLICY "Users can upload their own avatar"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'avatars' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can update their own avatar"
    ON storage.objects FOR UPDATE
    USING (
        bucket_id = 'avatars' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Anyone can view avatars"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'avatars');

-- Posts bucket: Users can upload their own posts
CREATE POLICY "Users can upload their own posts"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'posts' AND
        auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view posts from followed users"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'posts' AND
        (
            auth.uid()::text = (storage.foldername(name))[1] OR
            EXISTS (
                SELECT 1 FROM follows
                WHERE follows.follower = auth.uid()
                AND follows.followee::text = (storage.foldername(name))[1]
            )
        )
    );
```

---

## Part 6: Configure Your iOS App

### Step 1: Create Secrets.plist

1. In Xcode, navigate to `Kinnect/Resources/`
2. Duplicate `Secrets.plist.template` and rename it to `Secrets.plist`
3. Open `Secrets.plist` and replace the placeholder values:
   - `SupabaseURL`: Your Project URL from Part 2
   - `SupabaseAnonKey`: Your anon public key from Part 2

### Step 2: Add Supabase SDK (Next Step)

You'll add the Supabase Swift SDK via Swift Package Manager in Xcode.

---

## Part 7: Test Your Setup

Once you've completed all steps, you can test your setup by:

1. Opening the Supabase dashboard
2. Going to **Table Editor**
3. Verifying all tables exist: `profiles`, `follows`, `posts`, `likes`, `comments`
4. Going to **Storage**
5. Verifying both buckets exist: `avatars`, `posts`

---

## Troubleshooting

### "Error: relation does not exist"
- Make sure you ran all SQL scripts in the SQL Editor
- Check that you're connected to the correct project

### "Row-level security policy violation"
- Verify RLS is enabled on all tables
- Check that all policies were created successfully
- Make sure you're authenticated when testing

### Storage upload fails
- Verify storage policies were created
- Check bucket names match exactly: `avatars` and `posts`
- Ensure buckets are set to **private** (not public)

---

## Next Steps

Once Supabase is set up, you can:
1. Add the Supabase Swift SDK to your Xcode project
2. Test the connection in your app
3. Move on to Phase 2: Authentication Flow

**You're all set!** Your Supabase backend is ready for Kinnect.
