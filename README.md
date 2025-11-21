# Kinnect

A private, Instagram-style iOS social photo sharing application designed for intimate circles of family and friends. Built with SwiftUI and Supabase, Kinnect delivers familiar social features with a privacy-first approach—no ads, no algorithms, no public access.

---

## Overview

Social media shouldn't mean sacrificing privacy for connection. Kinnect replicates Instagram's intuitive UI/UX while prioritizing what matters: sharing moments with the people closest to you. With real-time updates, intelligent caching, and a clean architecture, Kinnect demonstrates production-quality iOS development from authentication through deployment.

---

## Features

- **Authentication**: Secure sign-in with Apple integration including custom username creation flow
- **Photo & Video Sharing**: Camera capture or library selection with background upload support
- **Real-Time Feed**: Chronological feed with live updates using Supabase Realtime v2—new posts appear instantly with Instagram-style "new posts available" banner
- **Social Interactions**: Like and comment on posts with optimistic UI updates and rollback on error
- **Following System**: Discover and follow users with real-time search (300ms debouncing) and instant follow/unfollow
- **Activity Notifications**: Instagram-style activity tab showing likes, comments, and new followers with badge counts
- **Profile Management**: User profiles with avatar upload, bio editing, and post grid layouts
- **Privacy Controls**: Bidirectional user blocking with automatic feed and search filtering
- **Performance**: Intelligent caching system delivering 60x faster load times (3s → <50ms) with 45-minute TTL
- **Pinch-to-Zoom**: Gesture-based image zoom (1x-3x scale) with scroll blocking and smooth interactions

---

## Screenshots

*Coming soon: Feed view, Profile view, Upload flow, Activity notifications*

---

## Key Technical Highlights

### Intelligent Caching System
In-memory cache with 45-minute TTL achieves **60x performance improvement** (3 seconds → <50 ms) for repeated views. Multi-user profile caching, optimistic updates synchronized with real-time events, and automatic cache invalidation on logout ensure data consistency while maximizing responsiveness.

### Real-Time Updates
Built on Supabase Realtime v2 using Swift async sequences (not callbacks), the real-time system features separate async tasks for each event stream (posts, likes, comments), event filtering to prevent double-counting with optimistic updates, and clean subscription lifecycle management. The "new posts available" banner provides Instagram-style UX for live content updates.

### MVVM Architecture with Comprehensive Testing
Strict MVVM separation keeps views declarative while ViewModels handle all business logic. Services layer abstracts backend communication for testability. **16 test files** cover services, view models, and UI flows using Swift Testing framework and XCTest, following Test-Driven Development practices documented throughout the codebase.

---

## Tech Stack

### Frontend
- **Language**: Swift (iOS 17+)
- **Framework**: SwiftUI with async/await and structured concurrency
- **Architecture**: MVVM (Model-View-ViewModel) with protocol-oriented design
- **State Management**: Combine framework with @Published properties and ObservableObject
- **Concurrency**: Swift structured concurrency with Task groups and proper cancellation handling

### Backend
- **BaaS**: Supabase (PostgreSQL + Auth + Storage + Realtime)
- **Database**: PostgreSQL with Row-Level Security (RLS) policies enforced on all tables
- **Authentication**: Sign in with Apple via Supabase Auth (JWT-based)
- **Storage**: S3-compatible private buckets with signed URL access (1-hour expiry)
- **Real-Time**: WebSocket-based Realtime v2 with async sequence support
- **SDK**: Supabase Swift SDK v2.36.0

### Testing
- **Unit Tests**: Swift Testing framework for services and view models
- **UI Tests**: XCTest UI automation for critical user flows
- **Coverage**: 16 test files covering services layer, view models, and integration tests

### Dependencies (Swift Package Manager)
- Supabase Swift SDK v2.36.0 (Auth, Database, Storage, Realtime)
- Apple Swift Crypto
- Apple Swift HTTP Types
- PointFree Swift Clocks, Concurrency Extras

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         SwiftUI Views                        │
│            (Declarative UI, User Interactions)              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                        View Models                           │
│     (State Management, Business Logic, Optimistic UI)       │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                       Services Layer                         │
│        (API Communication, Data Transformation)             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                      Supabase Backend                        │
│    (PostgreSQL, Auth, Storage, Realtime WebSockets)         │
└─────────────────────────────────────────────────────────────┘
```

### Architecture Principles
- **Strict MVVM Separation**: Views are purely declarative; all logic lives in ViewModels
- **Services Layer Abstraction**: Backend communication isolated for testability and maintainability
- **Protocol-Oriented Design**: Shared behavior via protocols (e.g., `FeedInteractionViewModel`)
- **Dependency Injection**: ViewModels accept service dependencies for easy mocking in tests
- **Optimistic UI**: Immediate local updates with automatic rollback on server errors
- **Task-Based Concurrency**: Structured concurrency with proper cancellation and error handling

---

## Project Structure

```
Kinnect/
├── Models/                          # Codable data models
│   ├── Profile.swift
│   ├── Post.swift
│   ├── Comment.swift
│   ├── Like.swift
│   ├── Follow.swift
│   └── Activity.swift
│
├── Views/                           # SwiftUI views (declarative UI)
│   ├── Auth/                       # Authentication flow
│   ├── Feed/                       # Feed, post cells, comments
│   ├── Profile/                    # Profile views and editing
│   ├── Upload/                     # Photo picker and post creation
│   ├── Activity/                   # Notifications list
│   ├── Settings/                   # Settings and account management
│   └── Shared/                     # Tab bar, search, reusable components
│
├── ViewModels/                      # Business logic and state management
│   ├── AuthViewModel.swift         # Authentication state
│   ├── FeedViewModel.swift         # Feed logic, caching, real-time
│   ├── ProfileViewModel.swift      # Profile data with multi-user cache
│   ├── UploadViewModel.swift       # Photo upload coordination
│   ├── CommentViewModel.swift      # Comment CRUD operations
│   ├── ActivityViewModel.swift     # Activity notifications
│   ├── SearchViewModel.swift       # User search with debouncing
│   └── SettingsViewModel.swift     # Settings management
│
├── Services/                        # Backend communication layer
│   ├── SupabaseService.swift      # Singleton client configuration
│   ├── AuthService.swift          # Sign in with Apple flow
│   ├── FeedService.swift          # Feed fetching with pagination
│   ├── PostService.swift          # Post CRUD operations
│   ├── ProfileService.swift       # Profile data management
│   ├── LikeService.swift          # Like/unlike operations
│   ├── CommentService.swift       # Comment CRUD
│   ├── FollowService.swift        # Follow relationships
│   ├── ActivityService.swift      # Activity notifications
│   ├── RealtimeService.swift      # WebSocket subscriptions
│   ├── BlockService.swift         # User blocking
│   └── SettingsService.swift      # Account settings
│
├── Utilities/                       # Helper utilities and extensions
│   ├── Extensions/
│   │   ├── Color+Extensions.swift      # Instagram color palette
│   │   ├── Date+Extensions.swift       # Relative date formatting
│   │   └── View+Extensions.swift       # Custom view modifiers
│   ├── Constants.swift
│   └── ImageCompression.swift
│
├── Protocols/                       # Shared protocols
│   └── FeedInteractionViewModel.swift # Protocol for shared feed logic
│
└── Resources/
    ├── Assets.xcassets
    └── Secrets.plist (gitignored)   # Supabase credentials
```

---

## Quick Start

### Prerequisites
- **Xcode 15+** with iOS 17+ SDK
- **Supabase Account** (free tier works)
- **Apple Developer Account** for Sign in with Apple testing

### Setup

1. **Clone the repository**
   ```sh
   git clone https://github.com/kpfister44/Kinnect.git
   cd Kinnect
   ```

2. **Configure Supabase Backend**

   See [BACKEND_SETUP.md](BACKEND_SETUP.md) for detailed instructions on:
   - Creating Supabase project
   - Setting up database schema and RLS policies
   - Configuring storage buckets
   - Enabling Realtime subscriptions

3. **Add Supabase Credentials**

   Create `Kinnect/Resources/Secrets.plist`:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>SUPABASE_URL</key>
       <string>your-project-url.supabase.co</string>
       <key>SUPABASE_ANON_KEY</key>
       <string>your-anon-key</string>
   </dict>
   </plist>
   ```

4. **Open in Xcode**
   ```sh
   open Kinnect.xcodeproj
   ```

5. **Configure Signing & Capabilities**
   - Select your development team
   - Enable Sign in with Apple capability

6. **Build and Run**
   - Select target device/simulator
   - Press `⌘R` to build and run

---

## Testing

### Run Unit Tests
```sh
# From command line
xcodebuild test -scheme Kinnect -destination 'platform=iOS Simulator,name=iPhone 15'

# Or in Xcode: ⌘U
```

### Run UI Tests
```sh
xcodebuild test -scheme KinnectUITests -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Test Coverage
- **16 test files** covering services, view models, and UI flows
- Unit tests for business logic and API layer
- Integration tests for view interactions
- UI tests for critical user flows (auth, posting, interactions)

---

## Documentation

Comprehensive documentation is available in the repository:

- **[PROJECT_OVERVIEW.md](PROJECT_OVERVIEW.md)**: Complete technical reference (300+ lines)
- **[BACKEND_SETUP.md](BACKEND_SETUP.md)**: Supabase configuration guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**: Common issues and solutions
- **Feature Documentation** (15+ guides): Detailed implementation docs for each major feature
- **Bug Investigation Logs**: Root cause analysis and solutions for complex issues

---

## Contact

**Kyle Pfister**
GitHub: [@kpfister44](https://github.com/kpfister44)
