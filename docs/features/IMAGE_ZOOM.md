# Image Zoom Feature

**Feature:** Pinch-to-zoom on post images in feed and profile views

**Status:** Implemented (November 2025)

---

## Overview

Users can pinch-to-zoom on post images in both the main feed and profile feed views, similar to Instagram. This provides a better viewing experience for image details without leaving the feed context.

---

## User Experience

**Zoom Gesture:**
- Two-finger pinch gesture on any post image
- Scales from 1x to 3x maximum
- Smooth, real-time scaling as user pinches

**Pan Gesture:**
- When zoomed in (scale > 1x), user can drag the image to view different areas
- Pan is only active while zoomed in

**Reset:**
- When user releases fingers, if scale is at or below 1x, image snaps back to original size
- Offset is reset when returning to 1x scale

**Scroll Blocking:**
- While zoomed in, feed scrolling is disabled
- Prevents accidental scroll while examining zoomed image
- Scrolling re-enables when user releases zoom

---

## Architecture

### ZoomableImageView Component

**Location:** `Kinnect/Views/Shared/ZoomableImageView.swift`

Reusable SwiftUI component that wraps AsyncImage with zoom capabilities:

**Properties:**
- `url: URL?` - Image URL to load
- `asyncImageID: String` - Unique ID for AsyncImage caching
- `isZooming: Binding<Bool>` - Two-way binding to communicate zoom state to parent
- `onImageFailure: ((Error) -> Void)?` - Callback for image load failures

**Gesture Handling:**
- `MagnificationGesture` - Handles pinch-to-zoom (scales from 1.0 to 3.0)
- `DragGesture` - Handles pan when zoomed in
- Both gestures use `.simultaneousGesture()` for smooth combined interaction

**State Management:**
- `currentScale` / `finalScale` - Track zoom level during and after gesture
- `currentOffset` / `finalOffset` - Track pan position during and after gesture
- Updates `isZooming` binding to signal parent views

### Integration

**PostCellView:**
- Accepts `@Binding var isZooming: Bool` from parent
- Replaces AsyncImage with ZoomableImageView
- Passes through existing AsyncImage failure handling for cancellation tracking

**FeedView & ProfileFeedView:**
- Maintain `@State private var isZooming = false`
- Pass binding down to PostCellView instances
- Use `.scrollDisabled(isZooming)` to block scrolling during zoom

---

## Implementation Details

### Gesture Bounds

**Scale:**
- Minimum: 1.0 (no zoom out beyond original size)
- Maximum: 3.0 (prevents excessive pixelation)
- Clamped in `onEnded` handler of MagnificationGesture

**Offset:**
- No artificial bounds (user can pan freely when zoomed)
- Reset to `.zero` when scale returns to 1.0

### Scroll Blocking

SwiftUI's `.scrollDisabled()` modifier is used on ScrollView:
```swift
ScrollView {
    // content
}
.scrollDisabled(isZooming)
```

This cleanly disables scroll interactions without affecting other gestures.

### AsyncImage Compatibility

ZoomableImageView preserves all existing AsyncImage patterns:
- Uses same `url` and `asyncImageID` parameters
- Supports `onImageFailure` callback for cancellation tracking
- Maintains aspect ratio and clipping behavior
- Works with existing cache-busting and rehydration logic

---

## Testing

### Unit Tests
**Location:** `KinnectTests/Views/ZoomableImageViewTests.swift`

Tests validate:
- Initial zoom state is false
- Scale clamping works correctly (1.0 to 3.0 bounds)
- Offset resets when scale returns to 1.0

### Integration Tests
**Location:** `KinnectTests/Views/PostCellViewIntegrationTests.swift`

Tests validate:
- PostCellView accepts isZooming binding
- FeedView can maintain and propagate zoom state

### UI Tests
**Location:** `KinnectUITests/KinnectUITests.swift`

Tests validate:
- Feed images exist and are interactive
- Profile feed images exist and are interactive
- ScrollView components are present

**Note:** XCTest does not support automated pinch gesture testing. Manual verification required for actual zoom behavior.

### Manual Testing Checklist

- ✓ Feed: Pinch-to-zoom works on post images
- ✓ Feed: Can pan zoomed images
- ✓ Feed: Zoom maxes out at 3x scale
- ✓ Feed: Image snaps back when released at 1x
- ✓ Feed: Scrolling is blocked while zoomed
- ✓ Feed: Scrolling works normally when not zoomed
- ✓ ProfileFeedView: All above behaviors work
- ✓ AsyncImage: Cancellation tracking still works after tab switching

---

## Known Limitations

1. **XCTest Gesture Automation:** Pinch gestures cannot be easily automated in XCTest UI tests. Manual testing is required for comprehensive verification.

2. **Pan Bounds:** There are no artificial limits on panning when zoomed. User can pan the image far off-screen if desired. This matches Instagram's behavior.

3. **Simulator Performance:** Zoom gestures on simulator may feel less smooth than on physical devices due to trackpad gesture translation.

---

## Future Enhancements

Potential improvements for future iterations:

- **Double-tap to zoom:** Quick zoom to 2x on double-tap (common Instagram pattern)
- **Zoom bounds for pan:** Limit panning to keep some portion of image visible
- **Haptic feedback:** Subtle haptic when reaching min/max zoom
- **Zoom persist:** Remember zoom state briefly if user switches tabs
- **Video zoom:** Extend zoom support to video posts

---

## Related Files

- `Kinnect/Views/Shared/ZoomableImageView.swift` - Zoom component
- `Kinnect/Views/Feed/PostCellView.swift` - Integration point
- `Kinnect/Views/Feed/FeedView.swift` - Scroll blocking
- `Kinnect/Views/Profile/ProfileFeedView.swift` - Scroll blocking
- `KinnectTests/Views/ZoomableImageViewTests.swift` - Unit tests
- `KinnectTests/Views/PostCellViewIntegrationTests.swift` - Integration tests
- `KinnectUITests/KinnectUITests.swift` - UI tests
