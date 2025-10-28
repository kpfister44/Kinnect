# Bug Tracking: Upload Sheet Presentation Issue

## Problem Statement

**Symptom:**
- First photo upload after app launch shows blank white sheet
- User must swipe down to dismiss
- Subsequent uploads work perfectly
- Issue reappears after closing and reopening app

**User Impact:** Poor first-impression experience, confusing UX

---

## Root Cause Analysis

The issue occurs due to a race condition between:
1. Sheet presentation trigger (`showNewPostView = true`)
2. Sheet content availability (`selectedImage`)

Even with the 0.5 second delay, SwiftUI's state synchronization can fail on first launch, causing:
- Sheet presents (`showNewPostView = true`)
- But content is nil/empty (`if let image = selectedImage` fails)
- Result: Blank white sheet

**Why subsequent attempts work:** App state is "warm" - SwiftUI's state management is fully initialized and synchronized.

---

## Attempted Solutions

### Iteration 1: Current Implementation (FAILED)
**Approach:** Use separate boolean flag + delay
```swift
@State private var showNewPostView = false
@State private var selectedImage: UIImage?

// After loading image:
await MainActor.run {
    selectedImage = uiImage
}
try? await Task.sleep(nanoseconds: 500_000_000)
await MainActor.run {
    showNewPostView = true
}

// Sheet presentation:
.sheet(isPresented: $showNewPostView) {
    if let image = selectedImage, let userId = currentUserId {
        NewPostView(selectedImage: image, userId: userId)
    }
}
```

**Result:** ❌ Still fails on first launch
**Why:** Separate state variables can desynchronize; sheet can present before content check passes

---

### Iteration 2: Direct Image Binding (IMPLEMENTED ✅)
**Approach:** Use selectedImage directly as sheet trigger - no separate boolean

**Theory:**
- Sheet only presents when selectedImage is non-nil
- Eliminates race condition between two state variables
- SwiftUI's `.sheet(item:)` ensures content exists before presentation

**Implementation:**
```swift
// 1. Created IdentifiableImage wrapper
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// 2. Changed state variable
@State private var selectedImageWrapper: IdentifiableImage?
// REMOVED: @State private var showNewPostView = false

// 3. Updated onChange handler
await MainActor.run {
    selectedImageWrapper = IdentifiableImage(image: uiImage)
    errorMessage = nil
    isProcessingImage = false
}

// 4. Changed sheet presentation from .sheet(isPresented:) to .sheet(item:)
.sheet(item: $selectedImageWrapper) { imageWrapper in
    if let userId = currentUserId {
        NewPostView(selectedImage: imageWrapper.image, userId: userId)
    }
} onDismiss: {
    selectedItem = nil
    selectedImageWrapper = nil
    isProcessingImage = false
    errorMessage = nil
}
```

**Key Changes:**
- Removed `showNewPostView` boolean completely
- Sheet now triggered by non-nil `selectedImageWrapper`
- SwiftUI's `.sheet(item:)` guarantees image exists before sheet presents
- Single state variable = no desynchronization possible

**Expected Result:** Sheet cannot present unless image is loaded ✅

---

## Next Steps If Iteration 2 Fails

### Iteration 3: Double MainActor Pass
- Set selectedImage
- Force SwiftUI layout pass with small delay (100ms)
- Set showNewPostView
- Longer delay before sheet (750ms-1000ms)

### Iteration 4: NavigationLink Approach
- Replace sheet with NavigationLink
- Push instead of present
- More reliable state synchronization

### Iteration 5: Full Manual Delay
- Increase delay to 1 second
- Add explicit DispatchQueue.main.async
- Nuclear option - poor UX but guaranteed to work

---

## Testing Protocol

**Steps to reproduce:**
1. Force quit app completely (swipe up in app switcher)
2. Relaunch app from home screen
3. Sign in (if needed)
4. Navigate to Upload tab
5. Tap "Select Photo"
6. Select any photo from library
7. Observe sheet presentation behavior

**Success criteria:**
- ✅ No blank sheet on first upload after fresh app launch
- ✅ NewPostView presents immediately with image visible and ready
- ✅ No regressions in subsequent uploads
- ✅ Sheet dismissal and re-selection works normally

**Test on:**
- Physical device (preferred - no iCloud issues)
- Simulator with local photos (drag images to simulator)

---

## What Changed (Summary)

**Before (Iteration 1):**
```swift
@State var showNewPostView = false  // Separate boolean
@State var selectedImage: UIImage? // Separate image

// Two state changes that can desync:
selectedImage = image              // State change 1
showNewPostView = true             // State change 2 (can race!)
```

**After (Iteration 2):**
```swift
@State var selectedImageWrapper: IdentifiableImage? // Single state

// One atomic state change:
selectedImageWrapper = IdentifiableImage(image: image) // ✅ Atomic
```

**Why it works:** SwiftUI's `.sheet(item:)` is designed for this exact scenario - it won't present the sheet until the item is guaranteed non-nil.

---

---

## RESULT: ✅ FIXED - Iteration 2 Successful!

**Date Resolved:** October 28, 2025
**Testing:** Confirmed working on physical device after fresh app launch

**What Fixed It:**
Switched from `.sheet(isPresented:)` with two separate state variables to `.sheet(item:)` with a single atomic state variable.

**Root Cause Confirmed:**
The race condition was exactly as theorized - two separate state variables (`showNewPostView` boolean and `selectedImage`) could desynchronize during SwiftUI's state update cycle, causing the sheet to present before the image was available.

**Technical Detail:**
SwiftUI's `.sheet(item:)` modifier is **atomic** - it won't present the sheet until the bound item is guaranteed non-nil. This eliminates any possibility of race conditions.

---

**Last Updated:** October 28, 2025
**Status:** ✅ RESOLVED - Iteration 2 successful, bug fixed permanently
