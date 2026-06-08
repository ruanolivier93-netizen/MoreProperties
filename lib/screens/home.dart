import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/haptics.dart';
import '../core/sa_places.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auth.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'affordability.dart';
import 'bond_calculator.dart';
import 'filters_screen.dart';
import 'listing_detail.dart';
import 'search.dart';

// =============================================================================
// Home screen
// =============================================================================

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final featured = ref.watch(featuredListingsProvider);
    final all = ref.watch(listingsProvider);

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    final firstName = profile?.name.split(' ').first ?? 'there';
    final initials = profile == null
        ? '?'
        : profile.name
            .split(' ')
            .map((p) => p.isNotEmpty ? p[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    final recentlySorted = [...all]
      ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final recent = recentlySorted.take(8).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _HeroSection(
              greeting: greeting,
              firstName: firstName,
              initials: initials,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _ToolRow(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          if (featured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SectionHeader(
                  title: 'Featured',
                  subtitle: '${featured.length} hand-picked properties',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    child: const Text('See all'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 365,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  itemCount: featured.length,
                  itemBuilder: (_, i) {
                    final l = featured[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ListingCard(
                        listing: l,
                        heroPrefix: 'home-feat',
                        width: 240,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listing: l),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],

          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SectionHeader(
                  title: 'Recently added',
                  subtitle: '${all.length} listings available',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    child: const Text('See all'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 365,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  itemCount: recent.length,
                  itemBuilder: (_, i) {
                    final l = recent[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ListingCard(
                        listing: l,
                        heroPrefix: 'home-rec',
                        width: 240,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ListingDetailScreen(listing: l),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

// =============================================================================
// Hero section — dark gradient + inline location autocomplete with multi-select
// =============================================================================

class _HeroSection extends ConsumerStatefulWidget {
  const _HeroSection({
    required this.greeting,
    required this.firstName,
    required this.initials,
  });

  final String greeting;
  final String firstName;
  final String initials;

  @override
  ConsumerState<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<_HeroSection> {
  final TextEditingController _locCtrl = TextEditingController();
  final FocusNode _locFocus = FocusNode();
  List<SaPlace> _suggestions = [];
  List<SaPlace> _selected = [];   // multi-selected areas
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    // Seed selection chips from any existing provider state
    final f = ref.read(filtersProvider);
    if (f.cities.isNotEmpty) {
      _selected = f.cities
          .map((n) => SaPlaces.all.firstWhere(
                (p) => p.name == n,
                orElse: () => SaPlace(n, ''),
              ))
          .toList();
    }

    // When another screen changes the cities list, sync our chips
    ref.listenManual(filtersProvider, (prev, next) {
      if (!mounted) return;
      final newNames = next.cities;
      final currentNames = _selected.map((p) => p.name).toList();
      if (newNames.join() != currentNames.join()) {
        setState(() {
          _selected = newNames
              .map((n) => SaPlaces.all.firstWhere(
                    (p) => p.name == n,
                    orElse: () => SaPlace(n, ''),
                  ))
              .toList();
          if (_selected.isEmpty) _locCtrl.clear();
        });
      }
    });

    // Delay suggestion dismissal so a tap on a list item can register first
    _locFocus.addListener(() {
      if (!_locFocus.hasFocus && mounted) {
        _dismissTimer?.cancel();
        _dismissTimer = Timer(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _suggestions = []);
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _locCtrl.dispose();
    _locFocus.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _dismissTimer?.cancel();
    setState(() => _suggestions = SaPlaces.search(query));
  }

  void _selectPlace(SaPlace place) {
    // Cancel the pending dismiss so the tap is not swallowed
    _dismissTimer?.cancel();
    AppHaptics.tap();

    // Avoid duplicates
    if (_selected.any((p) => p.name == place.name)) {
      _locCtrl.clear();
      setState(() => _suggestions = []);
      return;
    }

    setState(() {
      _selected.add(place);
      _suggestions = [];
    });
    _locCtrl.clear();
    _locFocus.unfocus();
    _updateProvider();
  }

  void _removeSelected(SaPlace place) {
    AppHaptics.tap();
    setState(() => _selected.removeWhere((p) => p.name == place.name));
    _updateProvider();
  }

  void _updateProvider() {
    final names = _selected.map((p) => p.name).toList();
    final provinces = _selected
        .map((p) => p.province)
        .where((pr) => pr.isNotEmpty)
        .toSet();
    // Only auto-set province if every selected area is in the same province
    final province = provinces.length == 1 ? provinces.first : null;

    ref.read(filtersProvider.notifier).update((f) => f.copyWith(
          cities: names,
          province: province,   // null clears the Sentinel-guarded field
          city: null,           // null clears city
        ));
  }

  @override
  Widget build(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    final filters = ref.watch(filtersProvider);
    final hasSuggestions = _suggestions.isNotEmpty;
    final hasSelected = _selected.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0C2E1B), Color(0xFF071510), Color(0xFF050806)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Greeting row
          Padding(
            padding: EdgeInsets.fromLTRB(20, statusH + 16, 20, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.greeting}, ${widget.firstName}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Find your next\naddress.',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.initials,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineStrong),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode underline tabs
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ListingMode.values.map((m) {
                          final sel = m == filters.mode;
                          return GestureDetector(
                            onTap: () {
                              AppHaptics.tap();
                              ref
                                  .read(filtersProvider.notifier)
                                  .update((f) => f.copyWith(mode: m));
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    m.shortLabel,
                                    style: TextStyle(
                                      color: sel
                                          ? AppColors.textPrimary
                                          : AppColors.textFaint,
                                      fontSize: 15,
                                      fontWeight: sel
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    height: 2.5,
                                    width: sel ? 22.0 : 0.0,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const Divider(
                      height: 1, thickness: 1, color: AppColors.outline),

                  // Selected area chips
                  if (hasSelected)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _selected.map((place) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_rounded,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  place.name,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeSelected(place),
                                  child: const Icon(Icons.close_rounded,
                                      size: 14, color: AppColors.primary),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Location text field — live autocomplete
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, hasSelected ? 8 : 14, 16, 0),
                    child: TextField(
                      controller: _locCtrl,
                      focusNode: _locFocus,
                      onChanged: _onChanged,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: hasSelected
                            ? 'Add another area…'
                            : 'City, suburb or area in SA',
                        hintStyle: const TextStyle(
                          color: AppColors.textFaint,
                          fontWeight: FontWeight.w400,
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        suffixIcon: _locCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 16, color: AppColors.textMuted),
                                onPressed: () {
                                  _locCtrl.clear();
                                  setState(() => _suggestions = []);
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.outlineStrong),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.outlineStrong),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),

                  // Suggestion list — expands inline as user types
                  if (hasSuggestions)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, i) => const Divider(
                          height: 1,
                          indent: 48,
                          color: AppColors.outline,
                        ),
                        itemBuilder: (_, i) {
                          final place = _suggestions[i];
                          final alreadyAdded =
                              _selected.any((p) => p.name == place.name);
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            leading: Icon(
                              place.isProvince
                                  ? Icons.map_outlined
                                  : Icons.location_on_outlined,
                              size: 18,
                              color: alreadyAdded
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                            title: _HighlightText(
                              text: place.name,
                              query: _locCtrl.text,
                            ),
                            subtitle: Text(
                              place.label,
                              style: const TextStyle(
                                color: AppColors.textFaint,
                                fontSize: 11,
                              ),
                            ),
                            trailing: alreadyAdded
                                ? const Icon(Icons.check_rounded,
                                    size: 16, color: AppColors.primary)
                                : null,
                            onTap: () => _selectPlace(place),
                          );
                        },
                      ),
                    ),

                  // Search → go to FiltersScreen
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, hasSuggestions ? 10 : 14, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          AppHaptics.light();
                          _locFocus.unfocus();
                          setState(() => _suggestions = []);
                          final nav = Navigator.of(context);
                          await nav.push(
                            MaterialPageRoute(
                              builder: (_) => const FiltersScreen(),
                            ),
                          );
                        },
                        child: Text(
                          hasSelected
                              ? 'Search in ${_selected.length} area${_selected.length == 1 ? '' : 's'}'
                              : 'Search listings',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Highlight matching text in primary colour
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
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );
    }
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final idx = lower.indexOf(lowerQ);
    if (idx == -1) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
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

// =============================================================================
// Tool row — quick calculator shortcuts
// =============================================================================

class _ToolRow extends StatelessWidget {
  const _ToolRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ToolButton(
            icon: Icons.calculate_outlined,
            title: 'Bond\ncalculator',
            accent: AppColors.primary,
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const BondCalculatorScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolButton(
            icon: Icons.trending_up_rounded,
            title: 'Pay off\nfaster',
            accent: const Color(0xFF60D8FF),
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const BondCalculatorScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolButton(
            icon: Icons.account_balance_outlined,
            title: 'Can I\nafford it?',
            accent: const Color(0xFFFFB547),
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AffordabilityScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.title,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (end of file)
