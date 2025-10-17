# Adding Supabase Swift SDK via Swift Package Manager

Follow these steps to add the Supabase Swift SDK to your Xcode project.

---

## Step 1: Open Package Dependencies

1. Open `Kinnect.xcodeproj` in Xcode
2. Select the **Kinnect** project in the Project Navigator (top of the sidebar)
3. Select the **Kinnect** target
4. Click on the **"Package Dependencies"** tab
5. Click the **"+"** button at the bottom

---

## Step 2: Add Supabase Package

1. In the search bar, enter:
   ```
   https://github.com/supabase/supabase-swift
   ```

2. Click **"Add Package"**

3. Xcode will resolve the package. When it's done, you'll see a list of libraries.

4. Select the following libraries to add:
   - **Supabase** (main library)
   - **Auth** (authentication)
   - **PostgREST** (database queries)
   - **Storage** (file storage)
   - **Realtime** (realtime subscriptions)

5. Make sure they're all set to be added to the **Kinnect** target

6. Click **"Add Package"**

---

## Step 3: Verify Installation

1. The packages will download and be added to your project
2. You should see them listed under **"Package Dependencies"** in the Project Navigator
3. Build the project (`Cmd + B`) to verify everything compiles

---

## Step 4: Import in Code

You can now import Supabase modules in your Swift files:

```swift
import Supabase
import Auth
import PostgREST
import Storage
import Realtime
```

---

## Troubleshooting

### "Failed to resolve package"
- Check your internet connection
- Make sure the URL is correct: `https://github.com/supabase/supabase-swift`
- Try clicking "Reset Package Caches" in Xcode's File menu

### Build errors after adding package
- Clean build folder: `Product > Clean Build Folder` (Shift + Cmd + K)
- Restart Xcode
- Make sure you're targeting iOS 17+ in your deployment target

---

## Next Steps

Once the SDK is installed:
1. Complete your Supabase backend setup (see `SUPABASE_SETUP.md`)
2. Create your `Secrets.plist` file with your Supabase credentials
3. Test the connection by running the app

The `SupabaseService` singleton is already configured and ready to use!
