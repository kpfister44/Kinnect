# Troubleshooting Guide

Common issues and their solutions for the Kinnect iOS app.

---

## PhotosPicker Sheet Presentation Race Condition

**Status:** FIXED (October 2025)

**Symptom:** First photo upload after app launch shows blank white sheet. User must swipe down to dismiss. Subsequent uploads work correctly. Issue reappears after closing and reopening app.

**Root Cause:** Race condition between two separate state variables (`showNewPostView` boolean and `selectedImage`). During SwiftUI's state update cycle on first app launch, these variables can desynchronize, causing the sheet to present before the image is available, resulting in blank content.

**Solution:**
Switched from `.sheet(isPresented:)` to `.sheet(item:)` using a single atomic state variable:

1. **Created IdentifiableImage wrapper** to make UIImage identifiable:
```swift
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}
```

2. **Replaced two state variables with one:**
```swift
// REMOVED:
@State private var showNewPostView = false
@State private var selectedImage: UIImage?

// ADDED:
@State private var selectedImageWrapper: IdentifiableImage?
```

3. **Changed sheet presentation to use `.sheet(item:)`:**
```swift
.sheet(item: $selectedImageWrapper, onDismiss: {
    // Reset state
    selectedItem = nil
    selectedImageWrapper = nil
    isProcessingImage = false
    errorMessage = nil
}) { imageWrapper in
    if let userId = currentUserId {
        NewPostView(selectedImage: imageWrapper.image, userId: userId)
    }
}
```

**Why This Works:** SwiftUI's `.sheet(item:)` modifier is atomic - it guarantees the sheet will only present when the bound item is non-nil. This eliminates any possibility of race conditions between separate state variables.

**Location:** `UploadView.swift` - Complete file
**Detailed Tracking:** See `/docs/bug-tracking/BUG_TRACKING_UPLOAD_SHEET.md` for iteration history

---

## Like Button Not Working on Random Posts (GeometryReader Hit-Testing Issue)

**Status:** FIXED

**Symptom:** Approximately 20% of posts have non-functional like buttons. Taps don't register at all (no console logs, no visual feedback). Other posts work perfectly. Issue persists across app restarts and affects random posts regardless of data or position.

**Root Cause:** GeometryReader in `imageView` was expanding unpredictably and overlapping the action buttons area below it. This blocked SwiftUI's hit-testing for the like button in certain cells, likely due to timing issues with AsyncImage loading and layout calculation creating a race condition.

**Solution:**
1. Remove GeometryReader from imageView completely
2. Use `.aspectRatio(1, contentMode: .fit)` directly on each AsyncImage phase instead
3. Let SwiftUI handle layout natively without manual geometry calculations

**Key Insight:** GeometryReader + AsyncImage can cause timing-based layout bugs where the reader expands to fill space before the image loads, causing overlap issues. SwiftUI's native `.aspectRatio()` modifier is more reliable for simple square aspect ratio constraints.

**Location:** `PostCellView.swift:imageView`

---

## Avatar Upload Failure in Simulator (iCloud Photo Library Error)

**Status:** MITIGATED (Simulator Limitation)

**Symptom:** Profile picture upload fails in iOS simulator with error: `CloudPhotoLibraryErrorDomain Code=1006` or `PHAssetExportRequestErrorDomain Code=4`. Console shows "Couldn't communicate with a helper application" and "Cannot load representation of type public.jpeg". Works fine on physical devices.

**Root Cause:** iOS Simulator cannot access photos stored in iCloud Photo Library. When PhotosPicker tries to load an image that's in iCloud (not fully downloaded locally), it fails with a helper application error. This is a known simulator limitation.

**Solution:**
1. Added error handling in `loadSelectedImage()` to detect iCloud-related errors
2. Display user-friendly error message: "Cannot access iCloud photos in simulator. Try using a local photo or test on a physical device."
3. Automatically reset picker selection on error to allow retry

**Workarounds for Development:**
- Add photos directly to simulator by dragging image files into the simulator window
- Disable iCloud Photo Library in simulator: Settings → Photos → iCloud Photos (off)
- Test avatar upload on physical devices where this issue doesn't occur

**Location:** `EditProfileView.swift:loadSelectedImage()`

---

## Feed/Profile Images Missing After Tab Switch (AsyncImage Cancellation)

**Status:** FIXED (October 2025)

**Symptom:** Switching tabs while the feed or profile grid is still loading causes several posts to show the "Failed to load" placeholder after returning.

**Root Cause:** When the view disappears, SwiftUI cancels in-flight `AsyncImage` downloads (`URLError.cancelled`). The cache already held valid signed URLs, but AsyncImage cached its failure state and never retried once the tab became visible again.

**Solution:** Feed and profile view models now track cancelled image IDs via `recordImageCancellation(for:)`. On the next `handleViewAppear()`, we regenerate the AsyncImage identifier and refresh signed URLs just for those posts (using `rehydrateMissingMedia`), ensuring they retry with fresh data while leaving the rest of the cache untouched.

**Location:** `FeedViewModel.swift`, `ProfileViewModel.swift`, `PostCellView.swift`, `ProfilePostsGridView.swift`
**Detailed Tracking:** See `/docs/bug-tracking/BUG_TRACKING_TAB_SWITCH_CACHE.md` (Iterations 1-7)

---

## General Debugging Tips

### AsyncImage Issues
- Always use `.aspectRatio()` directly on AsyncImage phases, not GeometryReader
- Track cancellations when views disappear and regenerate identifiers on reappear
- Use cache-busting query parameters for force-refresh scenarios

### SwiftUI Sheet Presentation
- Prefer `.sheet(item:)` over `.sheet(isPresented:)` to avoid race conditions
- Use identifiable wrappers for non-Identifiable types
- Ensure single atomic state variable controls sheet presentation

### Simulator Limitations
- iCloud Photo Library access doesn't work - use local photos
- Test critical photo/video features on physical devices
- Drag images into simulator for testing upload flows
