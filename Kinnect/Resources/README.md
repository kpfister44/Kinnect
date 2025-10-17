# Resources Setup

## Secrets.plist Configuration

To configure the app with your Supabase credentials:

1. Copy `Secrets.plist.template` to `Secrets.plist`
2. Replace the placeholder values with your actual Supabase credentials
3. The `Secrets.plist` file is gitignored and will not be committed

### Getting Your Supabase Credentials

1. Go to your Supabase project dashboard
2. Navigate to Settings > API
3. Copy the following values:
   - **Project URL** → Use this for `SupabaseURL`
   - **anon public** key → Use this for `SupabaseAnonKey`

### Example Secrets.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>SupabaseURL</key>
	<string>https://yourproject.supabase.co</string>
	<key>SupabaseAnonKey</key>
	<string>eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...</string>
</dict>
</plist>
```

**Important:** Never commit `Secrets.plist` to version control!
