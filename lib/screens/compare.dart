import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'listing_detail.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(compareProvider);
    final listings = ref
        .watch(listingsProvider)
        .where((l) => ids.contains(l.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare'),
        actions: [
          if (listings.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(compareProvider.notifier).clear(),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: listings.isEmpty
          ? const EmptyState(
              icon: Icons.compare_arrows_outlined,
              title: 'Nothing to compare',
              subtitle:
                  'Tap the compare icon on up to 3 listings to see them side-by-side here.',
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final l in listings)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _Column(listing: l),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _SpecTable(listings: listings),
                ],
              ),
            ),
    );
  }
}

class _Column extends ConsumerWidget {
  const _Column({required this.listing});
  final PropertyListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ListingDetailScreen(listing: listing),
        ),
      ),
      child: Column(
        children: [
          HeroImage(
            url: listing.heroImage,
            heroTag: 'cmp-${listing.id}',
            height: 100,
            borderRadius: 12,
            listingId: listing.id,
            showFavourite: false,
          ),
          const SizedBox(height: 10),
          Text(
            listing.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          PriceTag(listing: listing, fontSize: 14),
          const SizedBox(height: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ref.read(compareProvider.notifier).toggle(listing.id),
            icon: const Icon(
              Icons.close,
              color: AppColors.textMuted,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  const _SpecTable({required this.listings});
  final List<PropertyListing> listings;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, List<String>)>[
      ('Location', [for (final l in listings) l.fullLocation]),
      ('Type', [for (final l in listings) l.propertyType]),
      ('Beds', [for (final l in listings) '${l.beds}']),
      ('Baths', [for (final l in listings) '${l.baths}']),
      ('Parking', [for (final l in listings) '${l.parking}']),
      ('Floor', [for (final l in listings) '${l.floorSize}m²']),
      ('Erf', [for (final l in listings) l.erfSize == null ? '—' : '${l.erfSize}m²']),
      ('Levy', [for (final l in listings) l.levy == null ? '—' : ZAR.format(l.levy!)]),
      ('Rates', [for (final l in listings) l.rates == null ? '—' : ZAR.format(l.rates!)]),
      ('Energy', [for (final l in listings) l.energyRating]),
      ('Load shedding', [for (final l in listings) '${l.loadSheddingScore}/10']),
      ('Safety', [for (final l in listings) '${l.safetyScore}/10']),
      ('Schools', [for (final l in listings) '${l.schoolScore}/10']),
      ('Lifestyle', [for (final l in listings) '${l.lifestyleScore}/10']),
    ];
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i == rows.length - 1
                      ? BorderSide.none
                      : const BorderSide(color: AppColors.outline),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final v in rows[i].$2)
                    Expanded(
                      flex: 3,
                      child: Text(
                        v,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
