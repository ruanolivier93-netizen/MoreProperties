# Supabase Manual Setup

Run these files in the Supabase SQL editor in order:

1. `schema.sql`
2. `seed.sql` if you want demo agencies, agents and listings

Then run the Flutter app with the checked-in anon-key define file:

```powershell
flutter run --dart-define-from-file=supabase/dart_defines.json
```

## What This Includes

- Auth-linked `profiles`
- Agencies and verified agents
- Buy, rent, development and commercial listings
- Listing images and public storage bucket policy
- Favourites and saved searches
- Lead capture from the mobile app
- Viewing appointments
- Listing views for analytics
- Full-text listing search function
- Row Level Security policies for public listings, private user data and agent lead access

## Recommended Supabase Settings

- Enable Email auth under Authentication > Providers.
- Add your app deep links later for magic links and password recovery.
- Create Edge Functions later for push alerts, lead routing, WhatsApp notifications and saved-search digests.
- Keep service-role keys server-side only. The Flutter app should use only the anon key.
