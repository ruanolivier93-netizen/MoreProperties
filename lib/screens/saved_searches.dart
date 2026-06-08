import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'search.dart';

class SavedSearchesScreen extends ConsumerWidget {
  const SavedSearchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searches = ref.watch(savedSearchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved searches & alerts')),
      body: searches.isEmpty
          ? EmptyState(
              icon: Icons.notifications_outlined,
              title: 'No alerts yet',
              subtitle:
                  'Save a search from the Search screen to get a push notification the moment a matching home is listed.',
              actionLabel: 'Open search',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              itemCount: searches.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final s = searches[i];
                return _SavedTile(search: s);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        onPressed: () {
          ref.read(savedSearchesProvider.notifier).add(
                SavedSearch(
                  id: 's-${DateTime.now().millisecondsSinceEpoch}',
                  name: 'New alert',
                  filters: ref.read(filtersProvider),
                ),
              );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved current search as alert')),
          );
        },
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('Save current search'),
      ),
    );
  }
}

class _SavedTile extends ConsumerWidget {
  const _SavedTile({required this.search});
  final SavedSearch search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = search.filters;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      search.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${f.mode.label} · ${f.city ?? f.province ?? 'All SA'} · ${ZAR.compact(f.minPrice)}–${ZAR.compact(f.maxPrice)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted),
                onPressed: () => ref
                    .read(savedSearchesProvider.notifier)
                    .remove(search.id),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                'Cadence: ${search.cadence}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _ToggleChip(
                icon: Icons.email_outlined,
                label: 'Email',
                value: search.alertEmail,
                onChanged: (v) {
                  search.alertEmail = v;
                  ref
                      .read(savedSearchesProvider.notifier)
                      .update(search);
                },
              ),
              const SizedBox(width: 8),
              _ToggleChip(
                icon: Icons.notifications_outlined,
                label: 'Push',
                value: search.alertPush,
                onChanged: (v) {
                  search.alertPush = v;
                  ref
                      .read(savedSearchesProvider.notifier)
                      .update(search);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(!value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value ? AppColors.primaryGlow : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value ? AppColors.primary : AppColors.outline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 12,
                color: value ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: value ? AppColors.primary : AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
