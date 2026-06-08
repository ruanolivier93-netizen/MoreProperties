import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/listing_map.dart';
import '../widgets/widgets.dart';
import 'compare.dart';
import 'filters_screen.dart';
import 'listing_detail.dart';
import 'location_search.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  bool _mapView = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(filtersProvider).query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(filteredListingsProvider);
    final filters = ref.watch(filtersProvider);
    final compare = ref.watch(compareProvider);

    final locationLabel = filters.cities.isNotEmpty
        ? filters.cities.join(', ')
        : filters.city ?? filters.province;

    return Scaffold(
      appBar: AppBar(
        title: locationLabel == null
            ? const Text('Search')
            : GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LocationSearchScreen(popOnSelect: true),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        locationLabel,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more_rounded,
                          size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
        actions: [
          IconButton(
            tooltip: _mapView ? 'Show list' : 'Show map',
            icon: Icon(_mapView ? Icons.view_list_outlined : Icons.map_outlined),
            onPressed: () => setState(() => _mapView = !_mapView),
          ),
          if (compare.isNotEmpty)
            IconButton(
              tooltip: 'Compare (${compare.length})',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.compare_arrows),
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${compare.length}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompareScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Edit filters',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FiltersScreen(fromSearch: true),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _controller,
              onChanged: (v) => ref
                  .read(filtersProvider.notifier)
                  .update((f) => f.copyWith(query: v)),
              decoration: const InputDecoration(
                hintText: 'Suburb, city, building name…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final m in ListingMode.values) ...[
                  FilterChipMini(
                    label: m.shortLabel,
                    icon: m.icon,
                    selected: filters.mode == m,
                    onTap: () => ref
                        .read(filtersProvider.notifier)
                        .update((f) => f.copyWith(mode: m)),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${results.length} result${results.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                _SortMenu(),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? EmptyState(
                    icon: Icons.search_off,
                    title: 'No matches',
                    subtitle:
                        'Try widening your budget, switching province, or relaxing required amenities.',
                    actionLabel: 'Reset filters',
                    onAction: () => ref
                        .read(filtersProvider.notifier)
                        .state = const FilterCriteria(),
                  )
                : _mapView
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        child: ListingMapView(
                          listings: results,
                          height: double.infinity,
                          zoom: 6,
                          onMarkerTap: (l) => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ListingDetailScreen(listing: l),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final l = results[i];
                          return _SearchResultCard(
                            listing: l,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ListingDetailScreen(listing: l),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(filtersProvider).sort;
    return PopupMenuButton<ListingSort>(
      color: AppColors.surfaceHigh,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tooltip: 'Sort',
      onSelected: (s) => ref
          .read(filtersProvider.notifier)
          .update((f) => f.copyWith(sort: s)),
      itemBuilder: (_) => [
        for (final s in ListingSort.values)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == sort ? Icons.check : Icons.circle_outlined,
                  size: 14,
                  color: s == sort ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(s.label, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.outline),
        ),
        child: Row(
          children: [
            const Icon(Icons.sort, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              sort.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultCard extends ConsumerWidget {
  const _SearchResultCard({required this.listing, required this.onTap});

  final PropertyListing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCompare = ref.watch(compareProvider).contains(listing.id);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 130,
            child: HeroImage(
              url: listing.heroImage,
              heroTag: 'search-${listing.id}',
              height: 130,
              borderRadius: 14,
              listingId: listing.id,
              showFavourite: false,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (listing.isFeatured)
                      const TrustBadge(
                        label: 'FEATURED',
                        icon: Icons.bolt_rounded,
                      ),
                    TrustBadge(
                      label: listing.mode.shortLabel.toUpperCase(),
                      icon: listing.mode.icon,
                      color: AppColors.primarySoft,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.regionLine,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                PriceTag(listing: listing, fontSize: 15),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (listing.beds > 0)
                            _InlineMeta(
                              icon: Icons.bed_outlined,
                              label: '${listing.beds}',
                            ),
                          _InlineMeta(
                            icon: Icons.bathtub_outlined,
                            label: '${listing.baths}',
                          ),
                          _InlineMeta(
                            icon: Icons.square_foot,
                            label: '${listing.floorSize}m²',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 30,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: inCompare ? 'Remove from compare' : 'Compare',
                      icon: Icon(
                        inCompare
                            ? Icons.compare_arrows
                            : Icons.compare_arrows_outlined,
                        color: inCompare
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 18,
                      ),
                      onPressed: () {
                        final ok = ref
                            .read(compareProvider.notifier)
                            .toggle(listing.id);
                        if (!ok && !inCompare) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Compare is limited to 3 listings'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
