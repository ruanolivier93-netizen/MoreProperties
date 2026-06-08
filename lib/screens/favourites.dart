import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'listing_detail.dart';

class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favIds = ref.watch(favouritesProvider);
    final all = ref.watch(listingsProvider);
    final favs = all.where((l) => favIds.contains(l.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: favs.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_border,
              title: 'No saved homes yet',
              subtitle:
                  'Tap the heart on any listing to save it here and compare later.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: favs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final l = favs[i];
                return ListingCard(
                  listing: l,
                  heroPrefix: 'fav',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ListingDetailScreen(listing: l),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
