import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculators.dart';
import '../core/sa_data.dart';
import '../data/demo_listings.dart';
import '../models/models.dart';
import 'auth.dart';

// =============================================================================
// Listings & agents — hydrated from Supabase when available, demo otherwise.
// =============================================================================

/// All listings the app knows about. Defaults to curated demo data and
/// is replaced when Supabase results land.
final listingsProvider =
    StateNotifierProvider<ListingsNotifier, List<PropertyListing>>(
  (ref) => ListingsNotifier(),
);

class ListingsNotifier extends StateNotifier<List<PropertyListing>> {
  ListingsNotifier() : super(DemoData.listings);

  void replaceAll(List<PropertyListing> next) =>
      state = List.unmodifiable(next);
}

/// Agents directory — replaced when Supabase results land.
final agentsProvider = StateNotifierProvider<AgentsNotifier, List<Agent>>(
  (ref) => AgentsNotifier(),
);

class AgentsNotifier extends StateNotifier<List<Agent>> {
  AgentsNotifier() : super(DemoData.agents);

  void replaceAll(List<Agent> next) => state = List.unmodifiable(next);
}

Agent? findAgent(WidgetRef ref, String id) {
  for (final a in ref.read(agentsProvider)) {
    if (a.id == id) return a;
  }
  return null;
}

// =============================================================================
// Filters & search
// =============================================================================

final filtersProvider = StateProvider<FilterCriteria>(
  (_) => const FilterCriteria(),
);

/// Returns all listings that match [f], without sorting.
/// Used by both [filteredListingsProvider] and [FiltersScreen] for live counts.
List<PropertyListing> applyFilters(
    List<PropertyListing> all, FilterCriteria f) {
  final query = f.query.toLowerCase();
  return all.where((l) {
    if (l.mode != f.mode) return false;
    if (l.price < f.minPrice || l.price > f.maxPrice) return false;
    if (l.beds < f.minBeds) return false;
    if (l.baths < f.minBaths) return false;
    if (l.parking < f.minParking) return false;
    if (f.province != null && l.province != f.province) return false;
    if (f.cities.isNotEmpty) {
      if (!f.cities.any((c) => l.city == c || l.suburb == c)) return false;
    } else if (f.city != null && l.city != f.city) {
      return false;
    }
    if (f.propertyTypes.isNotEmpty &&
        !f.propertyTypes.contains(l.propertyType)) {
      return false;
    }
    if (f.verifiedOnly && !l.isVerified) return false;
    if (f.featuredOnly && !l.isFeatured) return false;
    for (final r in f.requiredLifestyle) {
      if (!l.lifestyleFeatures.contains(r)) return false;
    }
    for (final r in f.requiredSecurity) {
      if (!l.securityFeatures.contains(r)) return false;
    }
    for (final r in f.requiredResilience) {
      if (!l.resilienceFeatures.contains(r)) return false;
    }
    if (query.isNotEmpty) {
      final hay =
          '${l.title} ${l.suburb} ${l.city} ${l.province} ${l.propertyType}'
              .toLowerCase();
      if (!hay.contains(query)) return false;
    }
    return true;
  }).toList();
}

final filteredListingsProvider = Provider<List<PropertyListing>>((ref) {
  final all = ref.watch(listingsProvider);
  final f = ref.watch(filtersProvider);

  final result = applyFilters(all, f);

  switch (f.sort) {
    case ListingSort.recommended:
      result.sort((a, b) {
        final byFeatured = (b.isFeatured ? 1 : 0) - (a.isFeatured ? 1 : 0);
        if (byFeatured != 0) return byFeatured;
        return b.publishedAt.compareTo(a.publishedAt);
      });
      break;
    case ListingSort.newest:
      result.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      break;
    case ListingSort.priceLow:
      result.sort((a, b) => a.price.compareTo(b.price));
      break;
    case ListingSort.priceHigh:
      result.sort((a, b) => b.price.compareTo(a.price));
      break;
    case ListingSort.beds:
      result.sort((a, b) => b.beds.compareTo(a.beds));
      break;
  }
  return result;
});

final featuredListingsProvider = Provider<List<PropertyListing>>((ref) {
  return ref
      .watch(listingsProvider)
      .where((l) => l.isFeatured)
      .toList(growable: false);
});

// =============================================================================
// Favourites — write-through to Supabase when signed in.
// =============================================================================

final favouritesProvider =
    StateNotifierProvider<FavouritesNotifier, Set<String>>(
  (ref) => FavouritesNotifier(ref),
);

class FavouritesNotifier extends StateNotifier<Set<String>> {
  FavouritesNotifier(this._ref)
      : super({'clifton-edge', 'sandhurst-mansion'}) {
    _ref.listen(currentUserProvider, (_, _) => _hydrate(), fireImmediately: true);
  }

  final Ref _ref;

  Future<void> _hydrate() async {
    final user = _ref.read(currentUserProvider);
    final repo = _ref.read(repositoryProvider);
    if (user == null || repo == null) return;
    try {
      state = await repo.fetchFavourites(user.id);
    } catch (_) {
      // Keep demo defaults on failure.
    }
  }

  Future<void> toggle(String id) async {
    final user = _ref.read(currentUserProvider);
    final repo = _ref.read(repositoryProvider);
    final next = {...state};
    final wasFav = !next.add(id);
    if (wasFav) next.remove(id);
    state = next;

    if (user == null || repo == null) return;
    try {
      if (wasFav) {
        await repo.removeFavourite(userId: user.id, listingId: id);
      } else {
        await repo.addFavourite(userId: user.id, listingId: id);
      }
    } catch (_) {
      // Optimistic update remains in place; ignore network failure.
    }
  }

  bool contains(String id) => state.contains(id);
}

// =============================================================================
// Compare list — capped at 3 listings (local-only).
// =============================================================================

final compareProvider = StateNotifierProvider<CompareNotifier, List<String>>(
  (ref) => CompareNotifier(),
);

class CompareNotifier extends StateNotifier<List<String>> {
  CompareNotifier() : super(const []);

  bool toggle(String id) {
    if (state.contains(id)) {
      state = state.where((e) => e != id).toList();
      return false;
    }
    if (state.length >= 3) return false;
    state = [...state, id];
    return true;
  }

  void clear() => state = const [];
}

// =============================================================================
// Saved searches — write-through to Supabase when signed in.
// =============================================================================

final savedSearchesProvider =
    StateNotifierProvider<SavedSearchNotifier, List<SavedSearch>>(
  (ref) => SavedSearchNotifier(ref),
);

class SavedSearchNotifier extends StateNotifier<List<SavedSearch>> {
  SavedSearchNotifier(this._ref) : super(_demoSearches) {
    _ref.listen(currentUserProvider, (_, _) => _hydrate(), fireImmediately: true);
  }

  final Ref _ref;

  static final _demoSearches = <SavedSearch>[
    SavedSearch(
      id: 's1',
      name: 'Atlantic Seaboard · R10m–R25m',
      filters: const FilterCriteria(
        mode: ListingMode.buy,
        city: 'Cape Town',
        minPrice: 10000000,
        maxPrice: 25000000,
        minBeds: 3,
        requiredSecurity: ['24h estate security'],
      ),
      cadence: 'instant',
    ),
    SavedSearch(
      id: 's2',
      name: 'Sandton rentals · 2-bed · backup power',
      filters: const FilterCriteria(
        mode: ListingMode.rent,
        city: 'Sandton',
        maxPrice: 45000,
        minBeds: 2,
        requiredResilience: ['Inverter & batteries'],
      ),
      cadence: 'daily',
    ),
  ];

  Future<void> _hydrate() async {
    final user = _ref.read(currentUserProvider);
    final repo = _ref.read(repositoryProvider);
    if (user == null || repo == null) {
      state = _demoSearches;
      return;
    }
    try {
      state = await repo.fetchSavedSearches(user.id);
    } catch (_) {
      // Keep current state on failure.
    }
  }

  Future<void> add(SavedSearch s) async {
    final user = _ref.read(currentUserProvider);
    final repo = _ref.read(repositoryProvider);
    if (user == null || repo == null) {
      state = [...state, s];
      return;
    }
    try {
      final inserted = await repo.insertSavedSearch(userId: user.id, search: s);
      state = [...state, inserted];
    } catch (_) {
      state = [...state, s];
    }
  }

  Future<void> remove(String id) async {
    state = state.where((s) => s.id != id).toList();
    final repo = _ref.read(repositoryProvider);
    if (repo == null) return;
    try {
      await repo.deleteSavedSearch(id);
    } catch (_) {
      // Local removal stands.
    }
  }

  Future<void> update(SavedSearch s) async {
    state = [for (final e in state) if (e.id == s.id) s else e];
    final repo = _ref.read(repositoryProvider);
    if (repo == null) return;
    try {
      await repo.updateSavedSearch(s);
    } catch (_) {
      // Local update stands.
    }
  }
}

// =============================================================================
// User profile — Supabase-backed when signed in, local demo when not.
// =============================================================================

final userProfileProvider = StateProvider<UserProfile>(
  (_) => const UserProfile(
    name: 'Lebo Khumalo',
    email: 'lebo@example.co.za',
    phone: '+27 82 555 0042',
    preferredCity: 'Sandton',
    role: 'buyer',
  ),
);

/// True when the onboarding flow has been seen this session.
final onboardingSeenProvider = StateProvider<bool>((_) => false);

/// Market metrics + transfer duty brackets used by calculators and insights UI.
final marketSnapshotProvider = StateProvider<MarketSnapshotData>(
  (_) => MarketSnapshotData.fallback(),
);

// =============================================================================
// One-shot hydration helper invoked from main.
// =============================================================================

/// Quietly attempt to hydrate live Supabase listings + agents if configured.
Future<void> hydrateLiveData(WidgetRef ref) async {
  final repo = ref.read(repositoryProvider);
  if (repo == null) return;

  try {
    final listings = await repo.fetchListings();
    if (listings.isNotEmpty) {
      ref.read(listingsProvider.notifier).replaceAll(listings);
    }
  } catch (_) {
    // Demo data remains in place.
  }

  try {
    final agents = await repo.fetchAgents();
    if (agents.isNotEmpty) {
      ref.read(agentsProvider.notifier).replaceAll(agents);
    }
  } catch (_) {
    // Demo data remains in place.
  }

  try {
    final market = await repo.fetchLatestMarketSnapshot();
    if (market != null) {
      ref.read(marketSnapshotProvider.notifier).state = market;
      SaCalculators.setPrimeRate(market.primeRate);
    }
  } catch (_) {
    // Fall back to bundled market defaults.
  }
}
