import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/currency.dart';
import '../core/sa_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const FiltersSheet(),
  );
}

class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late FilterCriteria draft;

  @override
  void initState() {
    super.initState();
    draft = ref.read(filtersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final maxPriceCap = draft.mode == ListingMode.rent ? 250000 : 50000000;
    final cities = draft.province == null
        ? <String>[]
        : (SaData.citiesByProvince[draft.province!] ?? const <String>[]);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, controller) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outlineStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      draft = FilterCriteria(mode: draft.mode);
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    _section('Looking to', _buildModes()),
                    _section('Province', _buildProvinces()),
                    if (cities.isNotEmpty) _section('City', _buildCities(cities)),
                    _section(
                      'Budget',
                      _buildBudget(maxPriceCap.toDouble()),
                    ),
                    _section('Bedrooms', _buildBedrooms()),
                    _section('Bathrooms', _buildBaths()),
                    _section('Parking', _buildParking()),
                    _section('Property type', _buildPropertyTypes()),
                    _section('Resilience', _buildAmenitySet(
                      SaData.resilienceFeatures,
                      draft.requiredResilience,
                      (next) => setState(() => draft = draft.copyWith(
                            requiredResilience: next,
                          )),
                    )),
                    _section('Security', _buildAmenitySet(
                      SaData.securityFeatures,
                      draft.requiredSecurity,
                      (next) => setState(() => draft = draft.copyWith(
                            requiredSecurity: next,
                          )),
                    )),
                    _section('Lifestyle', _buildAmenitySet(
                      SaData.lifestyleFeatures,
                      draft.requiredLifestyle,
                      (next) => setState(() => draft = draft.copyWith(
                            requiredLifestyle: next,
                          )),
                    )),
                    _section('Trust', _buildTrust()),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          ref.read(filtersProvider.notifier).state = draft;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Show results (${draft.appliedCount} active)',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
        ],
      ),
    );
  }

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

  Widget _buildProvinces() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipMini(
          label: 'All SA',
          selected: draft.province == null,
          onTap: () => setState(
            () => draft = draft.copyWith(province: null, city: null),
          ),
        ),
        for (final p in SaData.provinces)
          FilterChipMini(
            label: p,
            selected: draft.province == p,
            onTap: () => setState(
              () => draft = draft.copyWith(province: p, city: null),
            ),
          ),
      ],
    );
  }

  Widget _buildCities(List<String> cities) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChipMini(
          label: 'All cities',
          selected: draft.city == null,
          onTap: () => setState(() => draft = draft.copyWith(city: null)),
        ),
        for (final c in cities)
          FilterChipMini(
            label: c,
            selected: draft.city == c,
            onTap: () => setState(() => draft = draft.copyWith(city: c)),
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
              style: const TextStyle(fontWeight: FontWeight.w800),
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
