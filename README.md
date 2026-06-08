# More Properties — South Africa

**More Properties** is a premium South African real-estate marketplace built with Flutter and Supabase, in a black-and-electric-green design language. It is fully usable out of the box in demo mode (no backend) and seamlessly upgrades to live Supabase data when keys are provided.

## What's inside

- **Discover** — featured hero carousel, province quick-browse, rentals with backup power, new developments, trending lifestyle homes.
- **Search** — Mode switcher (Buy / Rent / Developments / Commercial), full-text search, sort, infinite-scrollable results, compare list.
- **Filters** — Province → city drill-down, ZAR budget range, beds/baths/parking, property types, **resilience** (solar, inverter, generator, borehole…), **security** (24h, armed response, biometric…), **lifestyle** (pool, sea view, wine cellar…), verified-only & featured-only.
- **Listing detail** — Gallery, trust badges (PPRA, POPIA, FICA), key stats grid, suburb intelligence scores (load shedding, safety, schools, lifestyle), feature groups, indicative bond from the SARB prime rate, full SARS-based acquisition cost breakdown, agent card, WhatsApp / call / email enquiry.
- **Tools** — Three SA-specific calculators:
  - **Bond calculator** — Monthly instalment, capital vs interest pie chart, term & rate sliders.
  - **Transfer duty & costs** — SARS 2025/26 bracket-by-bracket plus transfer attorney, bond registration and deeds office fees.
  - **Affordability** — Bank-style 30% qualifying ratio, cashflow buffer, term & rate inputs.
- **Saved searches & alerts** — Push & email toggles, instant / daily / weekly cadences.
- **Favourites & Compare** — Side-by-side spec table for up to 3 properties.
- **Agent profile** — PPRA number, rating, average response time, live listings.
- **Account** — Profile, agent directory, POPIA & FICA badges, connection-status indicator.
- **Onboarding** — Four-slide intro explaining discovery, load-shedding readiness, calculators, and verified agents.

## Tech

- Flutter 3.38+
- Riverpod 2.6 for state management
- Supabase Flutter 2.12 (auth, Postgres, RLS, storage)
- `cached_network_image`, `google_fonts`, `intl`, `url_launcher`, `share_plus`, `fl_chart`

## Run locally

Install dependencies:

```powershell
flutter pub get
```

Demo mode (no Supabase):

```powershell
flutter run
```

Live mode (Supabase keys provided):

```powershell
flutter run --dart-define-from-file=supabase/dart_defines.json
```

The app silently hydrates `listings` from Supabase on launch when keys are configured, falling back to the curated demo dataset on any failure so the UX always works.

## Build

```powershell
flutter analyze
flutter test
flutter build web --release
flutter build apk --release --dart-define-from-file=supabase/dart_defines.json
flutter build appbundle --release --dart-define-from-file=supabase/dart_defines.json
```

## Supabase schema

`supabase/schema.sql` defines the production-grade schema: profiles, agencies, agents, listings (with `tsvector` full-text search), listing images, favourites, saved searches, leads, viewing appointments and listing views — all behind row-level security policies. Run it once in the Supabase SQL editor and seed with `supabase/seed.sql` if you'd like sample data.

## Notes on South African context

- All pricing displayed in **ZAR** with locale-correct grouping (`R 1 250 000`).
- Bond maths use the published **SARB prime rate** (currently 10.75%).
- Transfer duty uses the **SARS 2025/26 brackets** — six tiers from R0 up to R13.31m and beyond.
- Trust badges call out **PPRA** (Property Practitioners Regulatory Authority) registration, **POPIA** consent and **FICA** verification.
- Listing filters include **load-shedding resilience** (solar, inverter, generator, borehole, JoJo tanks, EV charger), reflecting the realities of buying property in SA today.

## Windows path workaround

If your project path contains a space (e.g. `C:\Users\Marketing3 FinFix\Music\more properties`), `flutter test` may try to compile the `objective_c` package's `build.dart` hook and fail because the Flutter tool does not quote the path correctly. The pubspec pins `objective_c: 4.1.0` via `dependency_overrides` to a version that does not run the broken hook. Remove the override on platforms without spaces in their paths.
