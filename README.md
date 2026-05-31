# More Properties

More Properties is a mobile-first Flutter and Supabase real estate marketplace for South Africa. It is designed around the major workflows users expect from a premium property platform: discovery, search, buy/rent/development/commercial categories, listing detail sheets, favourites, saved alerts, verified agents, enquiry capture and an agent performance studio.

The visual direction is black and electric green with a sleek, modern app feel.

## Tech Stack

- Flutter for Android, iOS and web
- Supabase Auth, Postgres, Row Level Security and Storage
- `supabase_flutter` for live data writes
- `cached_network_image`, `google_fonts`, `intl`, `url_launcher` and `share_plus`

## Run Locally

Install dependencies:

```powershell
flutter pub get
```

Run in demo mode without Supabase keys:

```powershell
flutter run
```

Run connected to Supabase:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

## Supabase Setup

Open the Supabase SQL editor and run:

1. [supabase/schema.sql](supabase/schema.sql)
2. [supabase/seed.sql](supabase/seed.sql)

The schema includes profiles, agencies, agents, listings, listing images, favourites, saved searches, leads, appointments, listing views, storage policies and RLS.

## Current App Screens

- Discover: mobile search, listing category chips, market pulse and property cards
- Listing detail: premium bottom sheet with facts, highlights, agent contact and enquiry form
- Saved: favourite properties and comparison-ready shortlist flow
- Alerts: saved-search concepts ready for push/email/WhatsApp automation
- Agents: verified agent profiles with contact actions
- Studio: agent dashboard metrics for leads, response time, listing health and viewings

## Notes

This project intentionally does not copy proprietary branding, assets or code from another site. It builds an original app with comparable real estate marketplace workflows, using the requested black and green design language.
