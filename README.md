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
flutter run --dart-define-from-file=supabase/dart_defines.json
```

## GitHub Build

GitHub Actions builds the Flutter web app on every push or pull request to `main` or `master`. You can also run it manually from the repository's `Actions` tab by selecting `Flutter CI` and choosing `Run workflow`.

The workflow runs `flutter pub get`, `flutter analyze`, `flutter test`, and:

```powershell
flutter build web --release --dart-define-from-file=supabase/dart_defines.json
```

When the workflow finishes, download the `more-properties-web` artifact from the run summary.

## Supabase Setup

Open the Supabase SQL editor and run:

1. [supabase/schema.sql](supabase/schema.sql)
2. [supabase/seed.sql](supabase/seed.sql)

If the browser console shows a `404` for `/rest/v1/listings`, the app is connected to Supabase but the database tables have not been created in that project yet. Run the two SQL files above, refresh the app, and the live catalogue will replace the demo fallback.

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
