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
- Live market snapshot table (`market_snapshot`) for prime rate + transfer-duty brackets
- Full-text listing search function
- Row Level Security policies for public listings, private user data and agent lead access

## Automated SARS/SARB Sync (Option 2)

This repo includes an Edge Function at `supabase/functions/sync-market-snapshot` that:

- Fetches SARB monetary-policy page for prime rate
- Fetches SARS transfer-duty rates page and validates current bracket patterns
- Upserts `public.market_snapshot` (row id: `za`)
- Falls back to existing DB values when parsing fails, so app data does not regress

### Deploy

```powershell
supabase functions deploy sync-market-snapshot
```

Set secrets (required):

```powershell
supabase secrets set MARKET_SYNC_TOKEN="replace-with-long-random-token"
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided automatically in Edge Functions.

### Run once manually

```powershell
curl -X POST "https://<project-ref>.supabase.co/functions/v1/sync-market-snapshot" ^
	-H "Authorization: Bearer <MARKET_SYNC_TOKEN>"
```

### Schedule

Create a daily schedule in Supabase Dashboard:

1. Go to Edge Functions > `sync-market-snapshot`.
2. Add schedule (for example: `0 5 * * *` UTC).
3. Include header `Authorization: Bearer <MARKET_SYNC_TOKEN>`.

This keeps app market stats current without redeploying Flutter.

## Recommended Supabase Settings

- Enable Email auth under Authentication > Providers.
- Enable Google and/or Apple providers if you want OAuth login buttons in-app.
- Add your app deep links later for magic links and password recovery.
- Create Edge Functions later for push alerts, lead routing, WhatsApp notifications and saved-search digests.
- Keep service-role keys server-side only. The Flutter app should use only the anon key.
