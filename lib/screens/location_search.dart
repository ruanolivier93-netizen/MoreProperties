import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../core/sa_data.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'search.dart';

// =============================================================================
// Location search screen
// Tapped from the home hero field OR the location chip in SearchScreen's AppBar.
// =============================================================================

class LocationSearchScreen extends ConsumerStatefulWidget {
  const LocationSearchScreen({super.key, this.popOnSelect = false});

  /// When true, pops back to the caller (SearchScreen) after selection.
  /// When false (default), replaces this screen with SearchScreen.
  final bool popOnSelect;

  @override
  ConsumerState<LocationSearchScreen> createState() =>
      _LocationSearchScreenState();
}

class _LocationSearchScreenState
    extends ConsumerState<LocationSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  // Build the full suggestion list once
  static final List<_Location> _all = _buildAll();

  static List<_Location> _buildAll() {
    final out = <_Location>[];

    // Provinces first
    for (final p in SaData.provinces) {
      out.add(_Location(
          name: p, sub: 'Province', isProvince: true, province: p, city: null));
    }

    // Cities grouped by province
    SaData.citiesByProvince.forEach((province, cities) {
      for (final city in cities) {
        out.add(_Location(
            name: city,
            sub: province,
            isProvince: false,
            province: province,
            city: city));
      }
    });

    // Popular suburbs / lifestyle areas
    for (final suburb in SaData.featuredSuburbs) {
      out.add(_Location(
          name: suburb,
          sub: 'Popular area',
          isProvince: false,
          province: '',
          city: suburb));
    }

    return out;
  }

  List<_Location> get _filtered {
    if (_query.isEmpty) return _all;
    final q = _query.toLowerCase();
    return _all
        .where((l) =>
            l.name.toLowerCase().contains(q) ||
            l.sub.toLowerCase().contains(q))
        .toList();
  }

  void _select(_Location loc) {
    AppHaptics.tap();
    ref.read(filtersProvider.notifier).update((f) {
      if (loc.isProvince) {
        // Province selected — clear city so filters are at province level
        return f.copyWith(province: loc.province, city: null);
      } else if (loc.province.isNotEmpty) {
        // City selected — set both province and city
        return f.copyWith(province: loc.province, city: loc.city);
      } else {
        // Featured suburb with no province mapping — just set as city
        return f.copyWith(city: loc.city);
      }
    });

    if (widget.popOnSelect) {
      Navigator.of(context).pop();
    } else {
      // Coming from home — navigate to results, removing this screen from stack
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            hintText: 'Search city, suburb or area',
            border: InputBorder.none,
            hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 15),
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, i) => const Divider(
          height: 1,
          indent: 68,
          color: AppColors.outline,
        ),
        itemBuilder: (_, i) {
          final loc = items[i];
          return ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outline),
              ),
              child: Icon(
                loc.isProvince
                    ? Icons.map_outlined
                    : Icons.location_on_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
            title: _HighlightText(text: loc.name, query: _query),
            subtitle: Text(
              loc.sub,
              style: const TextStyle(
                color: AppColors.textFaint,
                fontSize: 12,
              ),
            ),
            onTap: () => _select(loc),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Data model
// =============================================================================

class _Location {
  const _Location({
    required this.name,
    required this.sub,
    required this.isProvince,
    required this.province,
    required this.city,
  });

  final String name;
  final String sub;
  final bool isProvince;
  final String province;
  final String? city;
}

// =============================================================================
// Highlighted text — green on matching substring
// =============================================================================

class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );
    }

    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final idx = lower.indexOf(lowerQ);

    if (idx == -1) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}
