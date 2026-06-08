import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    final firstName = profile?.name.split(' ').first ?? 'there';
    final initials = profile == null
        ? '?'
        : profile.name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

    final recentlySorted = [...all]..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final recent = recentlySorted.take(8).toList();

    // Use first featured listing image as hero backdrop — fallback to a curated Unsplash shot
    final heroImageUrl = featured.isNotEmpty
        ? featured.first.heroImage
        : 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=1400';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Full-bleed hero with image ─────────────────────────────────────
          SliverToBoxAdapter(
            child: _HeroSection(
              greeting: greeting,
              firstName: firstName,
              initials: initials,
              heroImageUrl: heroImageUrl,
              totalListings: all.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── Quick-tool cards ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Property tools',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Calculate, plan, compare',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const _ToolRow(),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 36)),

          // ── Featured ──────────────────────────────────────────────────────
          if (featured.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                height: 378,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  itemCount: featured.length,
                  itemBuilder: (_, i) {
                    final l = featured[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: ListingCard(
                        listing: l,
                        heroPrefix: 'home-feat',
                        width: 248,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],

          // ── Recently added ─────────────────────────────────────────────────
          if (recent.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                height: 378,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  itemCount: recent.length,
                  itemBuilder: (_, i) {
                    final l = recent[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: ListingCard(
                        listing: l,
                        heroPrefix: 'home-rec',
                        width: 248,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: l)),
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
// Hero section — full-bleed property photo + search card
// =============================================================================

class _HeroSection extends ConsumerStatefulWidget {
  const _HeroSection({
    required this.greeting,
    required this.firstName,
    required this.initials,
    required this.heroImageUrl,
    required this.totalListings,
  });

  final String greeting;
  final String firstName;
  final String initials;
  final String heroImageUrl;
  final int totalListings;

  @override
  ConsumerState<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<_HeroSection> {
  final TextEditingController _locCtrl = TextEditingController();
  final FocusNode _locFocus = FocusNode();
  List<SaPlace> _suggestions = [];
  List<SaPlace> _selected = [];
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    final f = ref.read(filtersProvider);
    if (f.cities.isNotEmpty) {
      _selected = f.cities
          .map((n) => SaPlaces.all.firstWhere((p) => p.name == n, orElse: () => SaPlace(n, '')))
          .toList();
    }
    ref.listenManual(filtersProvider, (prev, next) {
      if (!mounted) return;
      final newNames = next.cities;
      final currentNames = _selected.map((p) => p.name).toList();
      if (newNames.join() != currentNames.join()) {
        setState(() {
          _selected = newNames
              .map((n) => SaPlaces.all.firstWhere((p) => p.name == n, orElse: () => SaPlace(n, '')))
              .toList();
          if (_selected.isEmpty) _locCtrl.clear();
        });
      }
    });
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
    _dismissTimer?.cancel();
    AppHaptics.tap();
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
    final provinces = _selected.map((p) => p.province).where((pr) => pr.isNotEmpty).toSet();
    final province = provinces.length == 1 ? provinces.first : null;
    ref.read(filtersProvider.notifier).update((f) => f.copyWith(
          cities: names,
          province: province,
          city: null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final statusH = MediaQuery.of(context).padding.top;
    final filters = ref.watch(filtersProvider);
    final hasSelected = _selected.isNotEmpty;
    final hasSuggestions = _suggestions.isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Full-bleed photo ──────────────────────────────────────────────────
        SizedBox(
          height: 420 + statusH,
          width: double.infinity,
          child: CachedNetworkImage(
            imageUrl: widget.heroImageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: AppColors.surfaceHigh),
            errorWidget: (_, _, _) => Container(color: AppColors.surfaceHigh),
          ),
        ),

        // ── Multi-layer scrim — bottom heavier so text is legible ─────────────
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.10),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.90),
                  AppColors.background,
                ],
                stops: const [0.0, 0.25, 0.55, 0.80, 1.0],
              ),
            ),
          ),
        ),

        // ── Top bar — greeting + avatar ────────────────────────────────────────
        Positioned(
          top: statusH + 12,
          left: 20,
          right: 20,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.greeting,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      widget.firstName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.initials,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Main headline ─────────────────────────────────────────────────────
        Positioned(
          bottom: 236,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find your\nnext address.',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -1.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${widget.totalListings} properties across South Africa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Search card pinned to bottom of hero ──────────────────────────────
        Positioned(
          bottom: 0,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outlineStrong),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mode tabs
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
                            ref.read(filtersProvider.notifier).update((f) => f.copyWith(mode: m));
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  m.shortLabel,
                                  style: TextStyle(
                                    color: sel ? AppColors.textPrimary : AppColors.textFaint,
                                    fontSize: 14,
                                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
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

                const Divider(height: 1, thickness: 1, color: AppColors.outline),

                // Selected area chips
                if (hasSelected)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selected.map((place) {
                        return Container(
                          padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 12, color: AppColors.primary),
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
                                child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                // Location TextField
                Padding(
                  padding: EdgeInsets.fromLTRB(14, hasSelected ? 8 : 12, 14, 0),
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
                      hintText: hasSelected ? 'Add another area…' : 'City, suburb or area in SA',
                      hintStyle: const TextStyle(
                        color: AppColors.textFaint,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 2),
                        child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                      ),
                      suffixIcon: _locCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
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
                        borderSide: const BorderSide(color: AppColors.outlineStrong),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outlineStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                ),

                // Suggestions dropdown
                if (hasSuggestions)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 210),
                    margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, i) =>
                          const Divider(height: 1, indent: 48, color: AppColors.outline),
                      itemBuilder: (_, i) {
                        final place = _suggestions[i];
                        final added = _selected.any((p) => p.name == place.name);
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          leading: Icon(
                            place.isProvince ? Icons.map_outlined : Icons.location_on_outlined,
                            size: 18,
                            color: added ? AppColors.primary : AppColors.textMuted,
                          ),
                          title: _HighlightText(text: place.name, query: _locCtrl.text),
                          subtitle: Text(
                            place.label,
                            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
                          ),
                          trailing: added
                              ? const Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
                              : null,
                          onTap: () => _selectPlace(place),
                        );
                      },
                    ),
                  ),

                // CTA button
                Padding(
                  padding: EdgeInsets.fromLTRB(14, hasSuggestions ? 8 : 12, 14, 14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: () async {
                        AppHaptics.light();
                        _locFocus.unfocus();
                        setState(() => _suggestions = []);
                        final nav = Navigator.of(context);
                        await nav.push(MaterialPageRoute(builder: (_) => const FiltersScreen()));
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            hasSelected
                                ? 'Search in ${_selected.length} area${_selected.length == 1 ? '' : 's'}'
                                : 'Search listings',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Highlight matching text
// =============================================================================

class _HighlightText extends StatelessWidget {
  const _HighlightText({required this.text, required this.query});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
    final lower = text.toLowerCase();
    final lowerQ = query.toLowerCase();
    final idx = lower.indexOf(lowerQ);
    if (idx == -1) return Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        children: [
          if (idx > 0) TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
          ),
          if (idx + query.length < text.length) TextSpan(text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// =============================================================================
// Tool row — horizontal cards for bond calc, pay faster, affordability
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
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BondCalculatorScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolButton(
            icon: Icons.trending_up_rounded,
            title: 'Pay off\nfaster',
            accent: AppColors.info,
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BondCalculatorScreen()));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ToolButton(
            icon: Icons.account_balance_outlined,
            title: 'Can I\nafford it?',
            accent: AppColors.warning,
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AffordabilityScreen()));
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: accent.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
