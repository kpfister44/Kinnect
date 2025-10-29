# Bug Tracking: Tab Switch During API Load Causes Image Failures

**Bug ID:** TAB-SWITCH-001
**Severity:** High → ✅ **RESOLVED**
**Status:** Fixed (Iteration 5 - October 28, 2025)
**Reported:** October 28, 2025
**Platform:** iOS (Physical Device & Simulator)

---

## Problem Statement

### Symptom
When a user switches away from the Feed or Profile tab while the initial API call is in progress (loading indicator visible), and then returns to the tab, the images show "Failed to load" placeholders instead of rendering correctly.

### Expected Behavior
- Images should load successfully even if the user switches tabs during the initial fetch
- Cache should store complete data and serve it on subsequent visits

### Actual Behavior
- Images display "Failed to load" error state
- Console shows signed URL generation was cancelled (Code=-999)
- Cache stores incomplete/partial data (only 3/17 posts instead of full set)

---

## Root Cause Analysis

### Initial Investigation
From the first set of console logs provided by user:

```
✅ Fetched 17 posts
⚠️ Failed to process post [...]: Code=-999 "cancelled"
[14 cancellation errors for signed URL generation]
✅ Processed 3 posts with full data
💾 Cache updated with 3 posts  ← THE PROBLEM
```

**Diagnosis:**
1. Feed fetches 17 posts successfully from database
2. Begins generating signed URLs for each post (network calls to Supabase Storage)
3. User switches tabs ~1 second later
4. SwiftUI cancels the Task
5. URLSession tasks get cancelled (Code -999)
6. Only 3 posts completed their signed URL generation before cancellation
7. Cache stores incomplete data (3 posts instead of 17)
8. On return: Cache serves instantly → AsyncImage tries to load from missing URLs → "Failed to load"

---

## Iteration History

### ❌ Iteration 1: Detached Task + Completion Guard (Service Layer)
**Date:** October 28, 2025
**Approach:** Option 4 from solution analysis

**Implementation:**
- Wrapped signed URL generation in `Task.detached` in `FeedService.fetchFeed()`
- Added `withThrowingTaskGroup` for concurrent processing with 10-second timeout
- Added validation: Only return posts if ALL are fully processed
- Added `FeedServiceError.incompleteData` error case

**Code Changes:**
- `/Kinnect/Services/FeedService.swift`: Lines 73-172
- `/Kinnect/Services/ProfileService.swift`: Lines 179-221
- Added `withTimeout()` helper function
- Added cache validation to `FeedViewModel.updateCache()` and `ProfileViewModel.updateCache()`

**Result:** ❌ FAILED
- Feed rejected legitimate 404 errors (test posts with missing files)
- Error: "Only loaded 12 of 18 posts. Please try again."
- Too strict validation prevented any feed from loading

**Logs:**
```
⚠️ Only processed 12/18 posts - throwing error to prevent partial cache
❌ Failed to load feed: incompleteData(processed: 12, total: 18)
```

---

### ❌ Iteration 2: Relaxed Validation (Allow Partial Results)
**Date:** October 28, 2025
**Approach:** Keep detached tasks but allow partial feeds (handle 404s gracefully)

**Implementation:**
- Removed strict validation requiring 100% success
- Allow posts to fail for legitimate reasons (404, network errors)
- Keep detached tasks to survive tab switches
- Only cache posts that have valid mediaURLs

**Code Changes:**
- `/Kinnect/Services/FeedService.swift`: Removed `incompleteData` error, allowed partial results
- `/Kinnect/Services/ProfileService.swift`: Same changes
- Cache validation guards remain in ViewModels

**Result:** ❌ FAILED
- Feed loads successfully (13/19 posts)
- Cache stores 13 valid posts
- **But images still show "Failed to load" on UI**
- Detached task in Service layer completes, but ViewModel doesn't receive results

**Logs:**
```
⚠️ Processed 13/19 posts (6 failed)
💾 Cache updated with 13 posts (all have valid mediaURLs)
✅ Feed loaded: 13 total posts
✅ Loaded feed from cache (age: 2s, stale: false)
```

**Analysis:**
Even though Service layer completes successfully, the **ViewModel's Task that awaits it gets cancelled** when user switches tabs. So ViewModel never receives completed posts to update UI.

---

### ❌ Iteration 3: Detached Tasks in ViewModels (Prevent ViewModel Cancellation)
**Date:** October 28, 2025
**Approach:** Add detached tasks at ViewModel layer to prevent fetch cancellation

**Implementation:**
- Wrapped `feedService.fetchFeed()` call in `Task.detached` in `FeedViewModel.fetchPosts()`
- Added `CancellationError` handling
- Ensures cache gets updated even if view disappears
- Applied same pattern to `ProfileViewModel.fetchFreshProfile()`

**Code Changes:**
- `/Kinnect/ViewModels/FeedViewModel.swift`: Lines 227-279
- `/Kinnect/ViewModels/ProfileViewModel.swift`: Lines 160-205
- Both layers now use detached tasks (Service + ViewModel)

**Result:** ❌ STILL FAILING
- Service layer completes: `✅ Processed 13/19 posts (6 failed)`
- Cache updates: `💾 Cache updated with 13 posts (all have valid mediaURLs)`
- Cache loads on return: `✅ Loaded feed from cache (age: 7s, stale: false)`
- **Images still show "Failed to load" on UI**

**Logs:**
```
✅ Processed 13/19 posts (6 failed)
💾 Cache updated with 13 posts (all have valid mediaURLs)
✅ Feed loaded: 13 total posts
✅ Loaded feed from cache (age: 7s, stale: false)
```

**Current Status:**
- Backend fetch: ✅ Working
- Cache storage: ✅ Working
- Cache retrieval: ✅ Working
- **UI rendering: ❌ BROKEN**

The cache contains valid posts with mediaURLs, but AsyncImage is not rendering them. Possible causes:
1. AsyncImage cache issue
2. View not re-rendering when posts array updates from cache
3. mediaURLs becoming stale/invalid between cache and render
4. SwiftUI state update timing issue

---

## Technical Details

### Architecture Layers Involved
1. **Service Layer** (`FeedService`, `ProfileService`) - Fetches data and generates signed URLs
2. **ViewModel Layer** (`FeedViewModel`, `ProfileViewModel`) - Manages state and caching
3. **View Layer** (`FeedView`, `ProfileView`, `PostCellView`) - Renders UI with AsyncImage

### Key Code Locations
- Feed fetch: `FeedService.swift:29-106`
- Profile fetch: `ProfileService.swift:156-222`
- Feed caching: `FeedViewModel.swift:153-170`
- Profile caching: `ProfileViewModel.swift:86-107`
- Image display: `PostCellView.swift` (AsyncImage usage)

### Cache System Details
- **Type:** In-memory cache (dictionary-based)
- **TTL:** 45 minutes (matches signed URL 1-hour expiry)
- **Storage:** `FeedViewModel.cachedPosts` (array), `ProfileViewModel.profileCache` (dictionary by UUID)
- **Validation:** Only caches posts with valid `mediaURL` values

---

### ✅ Iteration 4: Force AsyncImage Reload with `.id()` Modifier (SUCCESSFUL)
**Date:** October 28, 2025
**Approach:** Add `.id()` modifier to all AsyncImage instances to force recreation when view reappears

**Root Cause Confirmed:**
AsyncImage's internal URLSession tasks get cancelled during tab switch, and AsyncImage caches the failure state. When user returns, AsyncImage shows the cached "failed to load" state and doesn't retry downloading the valid URLs from cache.

**Implementation:**
1. **Added viewAppearanceID to ViewModels:**
   - `FeedViewModel`: `@Published var viewAppearanceID = UUID()`
   - `ProfileViewModel`: `@Published var viewAppearanceID = UUID()`

2. **Applied `.id()` modifier to all AsyncImage instances:**
   - `PostCellView`: Post images + avatars → `.id("\(post.id)-\(viewModel.viewAppearanceID)")`
   - `ProfilePostsGridView/PostGridCell`: Grid images → `.id("\(post.id)-\(viewAppearanceID)")`
   - `ProfileHeaderView`: Profile avatar → `.id("\(profile.id)-avatar-\(viewAppearanceID)")`

3. **Reset viewAppearanceID on view appearance:**
   - `FeedView`: `.onAppear { viewModel.viewAppearanceID = UUID() }`
   - `ProfileView`: `.onAppear { viewModel.viewAppearanceID = UUID() }`

**Why This Works:**
SwiftUI's `.id()` modifier forces view identity changes. When viewAppearanceID changes (new UUID on each .onAppear), SwiftUI treats the AsyncImage as a completely new view instance, destroying the old one with its cached failure state and creating a fresh instance that will attempt to download the image.

**Result:** ✅ **FIXED**
- Backend fetch completes even during tab switch (detached tasks work)
- Cache stores valid posts with mediaURLs
- User returns to tab → `.onAppear` generates new UUID
- AsyncImage recreates with new `.id()` → downloads images successfully
- No more "Failed to load" placeholders

**Code Changes:**
- `/Kinnect/ViewModels/FeedViewModel.swift`: Added viewAppearanceID property
- `/Kinnect/ViewModels/ProfileViewModel.swift`: Added viewAppearanceID property
- `/Kinnect/Views/Feed/FeedView.swift`: Reset viewAppearanceID in .onAppear
- `/Kinnect/Views/Profile/ProfileView.swift`: Reset viewAppearanceID in .onAppear
- `/Kinnect/Views/Feed/PostCellView.swift`: Added .id() to AsyncImages
- `/Kinnect/Views/Profile/ProfilePostsGridView.swift`: Added .id() to AsyncImages
- `/Kinnect/Views/Profile/ProfileHeaderView.swift`: Added .id() to AsyncImage

**Detached Tasks Status:**
✅ **KEPT** - Detached tasks from iterations 1-3 are beneficial and should remain. They ensure backend fetch completes and cache populates even during tab switches. This prevents wasted API calls and ensures data is ready when user returns.

---

### ⚡ Performance Optimization: Smart Cache Invalidation (October 28, 2025)

**Issue:** Initial fix regenerated AsyncImage IDs on every view appearance, causing 0.5-1 second image reload delay even when returning to a fully-loaded tab. This defeated AsyncImage's internal cache.

**Solution:** Track view visibility and only regenerate IDs when actually needed:
- Added `isViewVisible` flag to track if view is currently displayed
- `handleViewAppear()`: Only regenerates UUID if returning **during a loading state**
- `handleViewDisappear()`: Marks view as invisible
- Normal tab switches after loading completes → **AsyncImage cache preserved** → instant display

**Result:**
- ✅ **Bug still fixed:** Cancellation failures still force reload when needed
- ✅ **Snappy performance:** Normal tab switches show images instantly from AsyncImage cache
- ✅ **Best of both worlds:** Protection against cancellation + maximum performance

**Code Changes:**
- Added `isViewVisible` tracking to FeedViewModel and ProfileViewModel
- Added `handleViewAppear()` and `handleViewDisappear()` methods with smart logic
- Updated FeedView and ProfileView to call handlers instead of direct UUID regeneration

---

### ❌ Performance Optimization Failure: Race Condition with State (October 28, 2025)

**Issue:** The `state == .loading` condition doesn't work because:
1. User switches away → AsyncImages start cancelling
2. Backend completes (detached tasks work) → `state` changes to `.loaded`
3. User returns → Check `state == .loading` → **FALSE** (already loaded!)
4. viewAppearanceID doesn't regenerate → AsyncImage shows cached failures

**Result:** Top 5 posts show "Failed to load", bottom 10 loaded fine (timing-dependent on when they were cancelled vs completed)

**Root Cause:** Using `state` to detect cancellations is unreliable because state changes before user returns. We need to track if ANY load happened while view was invisible, regardless of current state.

---

### ✅ Iteration 5: Track Load-While-Invisible Flag (SUCCESSFUL - Final Solution)
**Date:** October 28, 2025

**Approach:** Use a persistent flag that survives state changes to reliably detect if a load happened while view was away.

**Implementation:**
1. **Added `didLoadWhileInvisible` flag to ViewModels**
   - Persists across state changes (unlike checking `state == .loading`)
   - Set to `true` when fetch starts AND view is invisible
   - Cleared after handling on view appearance

2. **Updated lifecycle handlers:**
   - `handleViewAppear()`: Check flag instead of state → regenerate UUID if true
   - `markFetchStarting()`: Set flag if view is invisible when fetch begins

3. **Called from fetch methods:**
   - `FeedViewModel.fetchPosts()`: Calls `markFetchStarting()` at beginning
   - `ProfileViewModel.fetchFreshProfile()`: Calls `markFetchStarting()` at beginning

**Why This Works:**
- Flag gets set the moment fetch starts while view is invisible (catches all cancellation scenarios)
- Flag persists even after `state` changes to `.loaded`
- On return: Check flag (not state) → regenerates IDs if needed → clears flag
- Normal tab switches after completion → flag is false → preserves AsyncImage cache

**Result:** ✅ **WORKS PERFECTLY**
- Tab switch during load → flag set → return → AsyncImage reloads → images display
- Tab switch after load → flag clear → return → AsyncImage cache preserved → instant display
- Both bug fix AND performance optimization working together

**Code Changes:**
- `FeedViewModel`: Added `didLoadWhileInvisible` flag + `markFetchStarting()` + updated handlers
- `ProfileViewModel`: Same changes
- Both call `markFetchStarting()` at the beginning of their fetch methods

---

## Proposed Solutions (To Try Next)

### Option A: Investigate AsyncImage Cache
**Theory:** AsyncImage might be caching the "failed to load" state from the initial partial fetch

**Test Steps:**
1. Add debug logging to PostCellView AsyncImage phases
2. Check if AsyncImage is seeing valid URLs or nil
3. Try invalidating AsyncImage cache on tab switch

**Implementation:**
```swift
// In PostCellView
AsyncImage(url: post.mediaURL) { phase in
    print("🖼️ AsyncImage phase for post \(post.id): \(phase)")
    // ... existing code
}
```

### Option B: Force View Refresh on Cache Load
**Theory:** View might not be re-rendering when posts array updates from cache

**Test Steps:**
1. Add `@Published` state that toggles on cache load
2. Force view refresh using `.id()` modifier
3. Check if StateObject vs ObservedObject matters

### Option C: Signed URL Expiry Issue
**Theory:** Signed URLs might be expiring faster than expected

**Test Steps:**
1. Log the actual signed URL values and their expiry timestamps
2. Check if URLs are still valid when loaded from cache
3. Test with longer expiry time (2 hours instead of 1)

### Option D: Race Condition with Cache + SwiftUI
**Theory:** Cache populates after view has already rendered with empty state

**Test Steps:**
1. Add explicit state variable for "cache loaded" vs "api loaded"
2. Delay view rendering until cache check completes
3. Use `.task()` modifier instead of `.onAppear()`

---

## Testing Checklist

### Reproduction Steps
1. ✅ Fresh app launch
2. ✅ Navigate to Feed tab
3. ✅ Wait for loading indicator to appear
4. ✅ Switch to another tab within ~1 second (while loading)
5. ✅ Wait 3-5 seconds
6. ✅ Switch back to Feed tab

### What to Check
- [ ] Console logs show complete fetch (not cancelled)
- [ ] Cache stores correct number of posts
- [ ] mediaURL values are present in cached posts
- [ ] AsyncImage receives valid URLs
- [ ] Images render successfully on UI

### Devices Tested
- [x] iPhone (Physical Device)
- [x] iOS Simulator

---

## Notes

### Mock/Test Data Issue
6 posts consistently return 404 errors (missing files in Supabase Storage):
- Post IDs: `97B83061`, `0B372984`, `23318918`, `1356047A`, `1C10510C`, `B928E28B`
- These appear to be test/mock posts that should be cleaned up from the database

### QUIC Connection Warnings
Console shows repeated QUIC protocol warnings - these are unrelated iOS networking logs and can be ignored:
```
quic_packet_parser_inner [C1.1.1.1:2] SH fixed bit is zero
```

---

## Related Documentation
- `/docs/features/FEED_SYSTEM.md` - Feed architecture
- `/docs/features/CACHING_SYSTEM.md` - Cache implementation
- `/BUG_TRACKING_UPLOAD_SHEET.md` - Similar race condition bug (PhotosPicker)

---

**Last Updated:** October 28, 2025
**Next Action:** Investigate AsyncImage rendering (Option A)

---

## Iteration 6 (Planned) – Decouple Fetch Lifecycle From View Cancellation

### Updated Root Cause Hypothesis
- The fetch tasks that hydrate each `Post` (signed URL, counts, like state) still execute inside the view-scoped async call.
- When the user switches tabs during this work, SwiftUI cancels the outer task. The inner task group catches `CancellationError`, drops those posts, and we cache only the subset that finished. When the user returns, AsyncImage renders from a cache that never had valid URLs, so we still see "Failed to load" placeholders.
- The Iteration 5 fix (tracking visibility) only regenerates AsyncImage IDs; it does not guarantee that the cached data contains valid media URLs after a cancellation.

### Planned Fix
1. **Long-lived hydration tasks** – Move the expensive hydration (`fetchFeed` / `fetchUserPosts`) into background tasks owned by the view models (or dedicated loader types) so they survive view disappearance. Results will be marshalled back to the main actor explicitly, guaranteeing completion even if SwiftUI cancels the view task.
2. **Post-fetch validation pass** – Before mutating `posts` or caches, run a lightweight follow-up that re-requests signed URLs for any posts that still lack media and filters only genuinely missing assets (404s). The cache will never accept partially hydrated posts again.
3. **Symmetric profile grid fix** – Mirror the same pattern for `ProfileViewModel` so profile tab navigation behaves just like the feed.
4. **Regression checklist** – Reproduce the rapid tab-switch scenario on device/simulator, confirm images load, verify cache hit behaviour, realtime banner counts, and pagination.

### Success Criteria
- Switching tabs mid-load no longer results in missing URLs when returning.
- Cache entries always contain fully hydrated posts (or explicit 404 omissions), so AsyncImage success path runs without manual ID resets.
- Feed/profile tabs continue to benefit from the existing cache + realtime behaviour.

**Owner:** Pending assignment (ready for implementation)
**Status:** 🟡 In Progress – design approved, implementation next

---

### Iteration 6 Implementation – Long-Lived Fetch Tasks (FAILED)
**Date:** October 28, 2025 (afternoon)

**What we shipped:**
- `FeedService.fetchFeed` now returns a `FeedFetchResult` with the original Supabase page size and runs hydration inside a detached task so it finishes even if the view disappears.
- Added `rehydrateMissingMedia` pass to retry signed URL generation before the cache updates (mirrored in `ProfileService.fetchUserPosts`).
- Replaced the view-scoped `await` calls in `FeedViewModel`/`ProfileViewModel` with background tasks tied to UUID request IDs. We only publish results on the main actor if the request is still current, and we skip caching when any media URL is missing.

**Observed outcome:**
- Users can still trigger the original failure by switching tabs while the feed/profile is loading. When returning, AsyncImage keeps reporting `NSURLErrorDomain Code=-999 "cancelled"` for the same signed URLs even though the data layer finished hydrating and the cache is complete.
- Console logs show `👋 [Iteration 6] View disappeared - no active fetch`, meaning our `didSwitchAwayDuringFetch` flag never flips in the common timing window (fetch finished just before SwiftUI tore down the view), so `viewAppearanceID` stays the same and AsyncImage presents its cached failure state.
- Result: Images still show "Failed to load" placeholders after tab-hopping, despite the cache holding valid URLs.

**Conclusion:** Decoupling fetch lifetimes solved the partial-cache problem, but it did not address AsyncImage’s cancelled download state. We need a UI-level signal that a given post’s image load was cancelled while the view was hidden so we can force a redraw on return.

---

## Iteration 7 – Track Image Cancellation & Targeted Reloads ✅

### Updated Root Cause Hypothesis
- Even with fully hydrated data, AsyncImage caches the failure associated with a cancelled URLSession task. Unless we recreate the view hierarchy (or the AsyncImage identifier) for the affected posts, the placeholder persists.
- Our current flag (`didSwitchAwayDuringFetch`) only flips when the fetch is still active at `onDisappear`. When network calls finish milliseconds before the tab switch, the flag stays `false`, so posts whose downloads were cancelled never get rebuilt.

### Implementation
1. **Capture AsyncImage failures:** Add a lightweight reporter in `PostCellView` / `ProfilePostsGridView` that informs the view model whenever an image load fails with `NSURLErrorCancelled`.
2. **Persist failed post IDs:** Store the set of affected post IDs in the corresponding view model while the view is invisible.
3. **Regenerate on return:** On `handleViewAppear()`, if the failure set is non-empty, bump `viewAppearanceID` (and optionally request fresh signed URLs) so AsyncImage rebuilds only the impacted cells; clear the failure set afterwards.
4. **Optional safeguard:** If profile/feed views disappear with outstanding failures, schedule a background refresh of signed URLs for those IDs to ensure we never serve an expired token.

### Success Criteria
- Switching tabs mid-load triggers a targeted AsyncImage rebuild when returning, so images render successfully without needing a full cache flush.
- Normal tab switches (no failures recorded) keep the existing AsyncImage cache for instant display.
- Feed and profile pagination/realtime behaviour remain unchanged.

**Result:** ✅ **PASSED (October 28, 2025 evening)**
- Console logs show the feed recording cancelled image IDs, rehydrating signed URLs, and then logging `AsyncImage SUCCESS` for each post once the view reappears.
- Manual testing on both feed and profile confirms images render correctly after rapid tab switches, and normal navigation still uses the cached content (no unnecessary reload delays).
- No regressions observed in pagination or realtime subscriptions.

**Owner:** Completed by Codex agent
**Status:** ✅ Done – ready for regression testing & code review
