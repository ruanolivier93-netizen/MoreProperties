import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../core/sa_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'search.dart';

// =============================================================================
// Full-screen filter page
//
// Usage:
//   • From home  → FiltersScreen()               → "Find properties" pushReplaces to SearchScreen
//   • From search → FiltersScreen(fromSearch:true) → "Apply filters" pops back
// =============================================================================

class FiltersScreen extends ConsumerStatefulWidget {
  const FiltersScreen({super.key, this.fromSearch = false});

  /// When true the apply button pops instead of pushing SearchScreen.
  final bool fromSearch;

  @override
  ConsumerState<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends ConsumerState<FiltersScreen> {
  late FilterCriteria draft;

  @override
  void initState() {
    super.initState();
    draft = ref.read(filtersProvider);
  }

  void _apply() {
    ref.read(filtersProvider.notifier).state = draft;
    if (widget.fromSearch) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxPriceCap = draft.mode == ListingMode.rent ? 250000.0 : 50000000.0;
    final allListings = ref.watch(listingsProvider);
    final matchCount = applyFilters(allListings, draft).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filters'),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              draft = FilterCriteria(mode: draft.mode);
            }),
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _section('Looking to', _buildModes()),
          _section('Budget', _buildBudget(maxPriceCap)),
          _section('Bedrooms', _buildBedrooms()),
          _section('Bathrooms', _buildBaths()),
          _section('Parking', _buildParking()),
          _section('Property type', _buildPropertyTypes()),
          _section(
            'Resilience & off-grid',
            _buildAmenitySet(
              SaData.resilienceFeatures,
              draft.requiredResilience,
              (next) =>
                  setState(() => draft = draft.copyWith(requiredResilience: next)),
            ),
          ),
          _section(
            'Security',
            _buildAmenitySet(
              SaData.securityFeatures,
              draft.requiredSecurity,
              (next) =>
                  setState(() => draft = draft.copyWith(requiredSecurity: next)),
            ),
          ),
          _section(
            'Lifestyle',
            _buildAmenitySet(
              SaData.lifestyleFeatures,
              draft.requiredLifestyle,
              (next) =>
                  setState(() => draft = draft.copyWith(requiredLifestyle: next)),
            ),
          ),
          _section('Trust', _buildTrust()),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _apply,
              child: Text(
                widget.fromSearch
                    ? 'Show $matchCount propert${matchCount == 1 ? 'y' : 'ies'}'
                    : 'Find $matchCount propert${matchCount == 1 ? 'y' : 'ies'}',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section wrapper
  // ---------------------------------------------------------------------------

  Widget _section(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 4),
          const Divider(color: AppColors.outline),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filter builders
  // ---------------------------------------------------------------------------

  Widget _buildModes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final m in ListingMode.values)
          FilterChipMini(
            label: m.label,
            icon: m.icon,
            selected: draft.mode == m,
            onTap: () => setState(() => draft = draft.copyWith(mode: m)),
          ),
      ],
    );
  }

  Widget _buildBudget(double cap) {
    final values = RangeValues(
      draft.minPrice.toDouble().clamp(0, cap),
      draft.maxPrice.toDouble().clamp(0, cap),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              ZAR.compact(values.start),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Expanded(child: SizedBox()),
            Text(
              ZAR.compact(values.end),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        RangeSlider(
          values: values,
          min: 0,
          max: cap,
          divisions: 80,
          labels: RangeLabels(
            ZAR.compact(values.start),
            ZAR.compact(values.end),
          ),
          onChanged: (rv) => setState(
            () => draft = draft.copyWith(
              minPrice: rv.start.round(),
              maxPrice: rv.end.round(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBedrooms() {
    return _stepRow(
      values: const [0, 1, 2, 3, 4, 5],
      current: draft.minBeds,
      onChanged: (v) => setState(() => draft = draft.copyWith(minBeds: v)),
      formatter: (v) => v == 0 ? 'Any' : '$v+',
    );
  }

  Widget _buildBaths() {
    return _stepRow(
      values: const [0, 1, 2, 3, 4],
      current: draft.minBaths,
      onChanged: (v) => setState(() => draft = draft.copyWith(minBaths: v)),
      formatter: (v) => v == 0 ? 'Any' : '$v+',
    );
  }

  Widget _buildParking() {
    return _stepRow(
      values: const [0, 1, 2, 3, 4],
      current: draft.minParking,
      onChanged: (v) => setState(() => draft = draft.copyWith(minParking: v)),
      formatter: (v) => v == 0 ? 'Any' : '$v+',
    );
  }

  Widget _stepRow({
    required List<int> values,
    required int current,
    required void Function(int) onChanged,
    required String Function(int) formatter,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          FilterChipMini(
            label: formatter(v),
            selected: current == v,
            onTap: () => onChanged(v),
          ),
      ],
    );
  }

  Widget _buildPropertyTypes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final t in SaData.propertyTypes)
          FilterChipMini(
            label: t,
            selected: draft.propertyTypes.contains(t),
            onTap: () {
              final next = [...draft.propertyTypes];
              if (!next.remove(t)) next.add(t);
              setState(() => draft = draft.copyWith(propertyTypes: next));
            },
          ),
      ],
    );
  }

  Widget _buildAmenitySet(
    List<String> options,
    List<String> selected,
    void Function(List<String>) update,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          FilterChipMini(
            label: o,
            selected: selected.contains(o),
            onTap: () {
              final next = [...selected];
              if (!next.remove(o)) next.add(o);
              update(next);
            },
          ),
      ],
    );
  }

  Widget _buildTrust() {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.verifiedOnly,
          onChanged: (v) =>
              setState(() => draft = draft.copyWith(verifiedOnly: v)),
          title: const Text(
            'Verified agents only',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'PPRA registered & FICA compliant',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: draft.featuredOnly,
          onChanged: (v) =>
              setState(() => draft = draft.copyWith(featuredOnly: v)),
          title: const Text(
            'Featured properties only',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Editor-curated picks across SA',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
