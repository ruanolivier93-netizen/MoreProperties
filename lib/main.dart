import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const appTextPrimary = Colors.white;
const appTextSecondary = Color(0xCCFFFFFF);
const appTextMuted = Color(0xB3FFFFFF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(const MorePropertiesApp());
}

class MorePropertiesApp extends StatelessWidget {
  const MorePropertiesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'More Properties',
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF050806),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12F58A),
          brightness: Brightness.dark,
          surface: const Color(0xFF0A110D),
          primary: const Color(0xFF12F58A),
          secondary: const Color(0xFF7DFFC3),
        ),
        textTheme: GoogleFonts.interTextTheme(
          baseTheme.textTheme,
        ).apply(bodyColor: appTextPrimary, displayColor: appTextPrimary),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF12F58A),
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xF2070C09),
          indicatorColor: const Color(0x3312F58A),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int tabIndex = 0;
  final favourites = <String>{'clifton-edge'};
  final searchController = TextEditingController();
  List<PropertyListing> listings = demoListings;
  bool loadingListings = false;
  bool usingLiveListings = false;
  String? listingsError;
  ListingMode mode = ListingMode.buy;
  ListingSort sort = ListingSort.recommended;
  int maxBudget = 50000000;
  int minBedrooms = 0;
  bool verifiedOnly = false;

  List<PropertyListing> get filteredListings {
    final query = searchController.text.trim().toLowerCase();
    final results = listings.where((listing) {
      final matchesMode = listing.mode == mode;
      final matchesBudget = listing.price <= maxBudget;
      final matchesBedrooms = listing.beds >= minBedrooms;
      final matchesVerification = !verifiedOnly || listing.verifiedDocs;
      final matchesQuery =
          query.isEmpty ||
          listing.title.toLowerCase().contains(query) ||
          listing.suburb.toLowerCase().contains(query) ||
          listing.city.toLowerCase().contains(query) ||
          listing.propertyType.toLowerCase().contains(query);
      return matchesMode &&
          matchesBudget &&
          matchesBedrooms &&
          matchesVerification &&
          matchesQuery;
    }).toList();

    results.sort((left, right) {
      return switch (sort) {
        ListingSort.recommended => right.matchScore.compareTo(left.matchScore),
        ListingSort.priceLow => left.price.compareTo(right.price),
        ListingSort.priceHigh => right.price.compareTo(left.price),
        ListingSort.newest => left.daysOnMarket.compareTo(right.daysOnMarket),
      };
    });
    return results;
  }

  @override
  void initState() {
    super.initState();
    loadListings();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DiscoverPage(
        listings: filteredListings,
        favourites: favourites,
        searchController: searchController,
        loadingListings: loadingListings,
        usingLiveListings: usingLiveListings,
        listingsError: listingsError,
        mode: mode,
        sort: sort,
        maxBudget: maxBudget,
        minBedrooms: minBedrooms,
        verifiedOnly: verifiedOnly,
        onModeChanged: (value) => setState(() {
          mode = value;
        }),
        onSearchChanged: (_) => setState(() {}),
        onOpenFilters: openFilters,
        onOpenValuation: openValuation,
        onApplyBuyerBudget: applyBuyerBudget,
        onToggleFavourite: toggleFavourite,
        onOpenListing: openListing,
      ),
      SavedPage(
        listings: listings
            .where((listing) => favourites.contains(listing.slug))
            .toList(),
        onOpenListing: openListing,
        onToggleFavourite: toggleFavourite,
      ),
      const AlertsPage(),
      const AgentsPage(),
      const StudioPage(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tabIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tabIndex,
        onDestinationSelected: (index) => setState(() => tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_user_outlined),
            selectedIcon: Icon(Icons.verified_user),
            label: 'Agents',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize),
            label: 'Studio',
          ),
        ],
      ),
    );
  }

  void toggleFavourite(String slug) {
    setState(() {
      favourites.contains(slug)
          ? favourites.remove(slug)
          : favourites.add(slug);
    });
  }

  Future<void> loadListings() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) return;

    setState(() {
      loadingListings = true;
      listingsError = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('listings')
          .select(
            '*, agents(id, display_name, email, phone, avatar_url, rating, response_minutes, verified, agencies(name))',
          )
          .eq('status', 'active')
          .order('is_featured', ascending: false)
          .order('published_at', ascending: false);
      final liveListings = rows
          .map(
            (row) =>
                PropertyListing.fromSupabase(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        listings = liveListings.isEmpty ? demoListings : liveListings;
        usingLiveListings = liveListings.isNotEmpty;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        listings = demoListings;
        usingLiveListings = false;
        listingsError =
            'Supabase tables not found yet. Run schema.sql, then seed.sql.';
      });
    } finally {
      if (mounted) setState(() => loadingListings = false);
    }
  }

  void openListing(PropertyListing listing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListingDetailSheet(
        listing: listing,
        isFavourite: favourites.contains(listing.slug),
        onToggleFavourite: () => toggleFavourite(listing.slug),
      ),
    );
  }

  void openValuation() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF08100B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const ValuationLeadForm(),
    );
  }

  void applyBuyerBudget(int budget) {
    setState(() {
      tabIndex = 0;
      mode = ListingMode.buy;
      maxBudget = budget;
      sort = ListingSort.recommended;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Showing homes up to ${compactCurrency(budget)}.'),
      ),
    );
  }

  void openFilters() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF08100B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => FilterSheet(
        sort: sort,
        maxBudget: maxBudget,
        minBedrooms: minBedrooms,
        verifiedOnly: verifiedOnly,
        onApply:
            ({
              required selectedSort,
              required selectedMaxBudget,
              required selectedMinBedrooms,
              required selectedVerifiedOnly,
            }) {
              setState(() {
                sort = selectedSort;
                maxBudget = selectedMaxBudget;
                minBedrooms = selectedMinBedrooms;
                verifiedOnly = selectedVerifiedOnly;
              });
            },
      ),
    );
  }
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({
    super.key,
    required this.listings,
    required this.favourites,
    required this.searchController,
    required this.loadingListings,
    required this.usingLiveListings,
    required this.listingsError,
    required this.mode,
    required this.sort,
    required this.maxBudget,
    required this.minBedrooms,
    required this.verifiedOnly,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onOpenFilters,
    required this.onOpenValuation,
    required this.onApplyBuyerBudget,
    required this.onToggleFavourite,
    required this.onOpenListing,
  });

  final List<PropertyListing> listings;
  final Set<String> favourites;
  final TextEditingController searchController;
  final bool loadingListings;
  final bool usingLiveListings;
  final String? listingsError;
  final ListingMode mode;
  final ListingSort sort;
  final int maxBudget;
  final int minBedrooms;
  final bool verifiedOnly;
  final ValueChanged<ListingMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onOpenValuation;
  final ValueChanged<int> onApplyBuyerBudget;
  final ValueChanged<String> onToggleFavourite;
  final ValueChanged<PropertyListing> onOpenListing;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandHeader(),
                const SizedBox(height: 18),
                CatalogueStatus(
                  loading: loadingListings,
                  usingLiveListings: usingLiveListings,
                  error: listingsError,
                ),
                const SizedBox(height: 12),
                const HeroPanel(),
                const SizedBox(height: 16),
                SearchBox(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 14),
                ModeSelector(mode: mode, onModeChanged: onModeChanged),
                const SizedBox(height: 12),
                DiscoveryCommandBar(
                  sort: sort,
                  maxBudget: maxBudget,
                  minBedrooms: minBedrooms,
                  verifiedOnly: verifiedOnly,
                  onOpenFilters: onOpenFilters,
                ),
                const SizedBox(height: 18),
                const BuyerEdgePanel(),
                const SizedBox(height: 18),
                BuyerAffordabilityPlanner(onApplyBudget: onApplyBuyerBudget),
                const SizedBox(height: 18),
                const BuyerJourneyPanel(),
                const SizedBox(height: 18),
                SellerValuationPanel(onStart: onOpenValuation),
                const SizedBox(height: 18),
                const MarketPulse(),
                const SizedBox(height: 18),
                SectionTitle(
                  title: '${listings.length} curated matches',
                  action: 'Map view',
                  onTap: () => showMapPreview(context, listings),
                ),
              ],
            ),
          ),
        ),
        SliverList.separated(
          itemCount: listings.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final listing = listings[index];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                0,
                18,
                index == listings.length - 1 ? 28 : 0,
              ),
              child: PropertyCard(
                listing: listing,
                isFavourite: favourites.contains(listing.slug),
                onFavourite: () => onToggleFavourite(listing.slug),
                onTap: () => onOpenListing(listing),
              ),
            );
          },
        ),
      ],
    );
  }
}

void showMapPreview(BuildContext context, List<PropertyListing> listings) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF08100B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live area intelligence',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Listing coordinates and suburb analytics are Supabase-ready. Add Mapbox or Google Maps keys when you want the live map layer.',
            style: TextStyle(color: appTextMuted),
          ),
          const SizedBox(height: 18),
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF0C2317), Color(0xFF111612)],
              ),
              border: Border.all(color: const Color(0x3312F58A)),
            ),
            child: Stack(
              children: List.generate(listings.length, (index) {
                return Positioned(
                  left: 32.0 + (index * 57) % 250,
                  top: 28.0 + (index * 43) % 150,
                  child: StatusPill(
                    text: compactCurrency(listings[index].price),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ),
  );
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF12F58A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.roofing_rounded, color: Colors.black),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'More Properties',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              Text(
                'South Africa, elevated',
                style: TextStyle(color: appTextMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.tune)),
      ],
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;
        return Container(
          height: compact ? 260 : 208,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            image: const DecorationImage(
              image: CachedNetworkImageProvider(
                'https://images.unsplash.com/photo-1600607687920-4e2a09cf159d?auto=format&fit=crop&w=1400&q=80',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            padding: EdgeInsets.all(compact ? 16 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x99000000), Color(0xEE020503)],
              ),
              border: Border.all(color: const Color(0x5512F58A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Find the move before the market moves.',
                  maxLines: compact ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 21 : 27,
                    height: compact ? 1.08 : 1.02,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Verified listings, smart alerts, area signals, agent response tracking, and premium lead capture in one mobile app.',
                  maxLines: compact ? 4 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appTextSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CatalogueStatus extends StatelessWidget {
  const CatalogueStatus({
    super.key,
    required this.loading,
    required this.usingLiveListings,
    required this.error,
  });

  final bool loading;
  final bool usingLiveListings;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = loading
        ? 'Syncing live listings'
        : usingLiveListings
        ? 'Live Supabase catalogue'
        : error ?? 'Demo catalogue active';
    final icon = loading
        ? Icons.sync
        : usingLiveListings
        ? Icons.cloud_done_outlined
        : Icons.offline_bolt_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x2212F58A)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF12F58A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search suburb, city or type',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: () {
            controller.clear();
            onChanged('');
          },
          icon: const Icon(Icons.close),
        ),
        filled: true,
        fillColor: const Color(0xFF0A110D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x2212F58A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0x2212F58A)),
        ),
      ),
    );
  }
}

class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final ListingMode mode;
  final ValueChanged<ListingMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ListingMode.values.map((item) {
        final selected = item == mode;
        return ChoiceChip(
          selected: selected,
          label: Text(item.label),
          avatar: Icon(item.icon, size: 18),
          onSelected: (_) => onModeChanged(item),
          selectedColor: const Color(0xFF12F58A),
          backgroundColor: const Color(0xFF0A110D),
          labelStyle: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w800,
          ),
          side: const BorderSide(color: Color(0x3312F58A)),
        );
      }).toList(),
    );
  }
}

class DiscoveryCommandBar extends StatelessWidget {
  const DiscoveryCommandBar({
    super.key,
    required this.sort,
    required this.maxBudget,
    required this.minBedrooms,
    required this.verifiedOnly,
    required this.onOpenFilters,
  });

  final ListingSort sort;
  final int maxBudget;
  final int minBedrooms;
  final bool verifiedOnly;
  final VoidCallback onOpenFilters;

  @override
  Widget build(BuildContext context) {
    final filters = [
      sort.label,
      'Up to ${compactCurrency(maxBudget)}',
      if (minBedrooms > 0) '$minBedrooms+ beds',
      if (verifiedOnly) 'Verified docs',
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FactChip(icon: Icons.bolt_outlined, label: filter),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onOpenFilters,
          icon: const Icon(Icons.tune),
          tooltip: 'Filters',
        ),
      ],
    );
  }
}

class BuyerEdgePanel extends StatelessWidget {
  const BuyerEdgePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFF12F58A),
            child: Icon(Icons.workspace_premium_outlined, color: Colors.black),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buyer edge active',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'Listings are ranked by mandate quality, agent speed, buyer demand and price signal.',
                  style: TextStyle(color: appTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuyerAffordabilityPlanner extends StatefulWidget {
  const BuyerAffordabilityPlanner({super.key, required this.onApplyBudget});

  final ValueChanged<int> onApplyBudget;

  @override
  State<BuyerAffordabilityPlanner> createState() =>
      _BuyerAffordabilityPlannerState();
}

class _BuyerAffordabilityPlannerState extends State<BuyerAffordabilityPlanner> {
  double monthlyIncome = 65000;
  double deposit = 300000;

  int get monthlyRepaymentGuide => (monthlyIncome * 0.3).round();

  int get estimatedBudget => ((monthlyRepaymentGuide / 0.01) + deposit)
      .round()
      .clamp(500000, 50000000);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(Icons.savings_outlined, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Buyer budget check',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estimated buying power ${compactCurrency(estimatedBudget)}',
                      style: const TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          BudgetSlider(
            label: 'Monthly household income',
            value: monthlyIncome,
            min: 25000,
            max: 250000,
            divisions: 45,
            onChanged: (value) => setState(() => monthlyIncome = value),
          ),
          const SizedBox(height: 10),
          BudgetSlider(
            label: 'Available deposit',
            value: deposit,
            min: 0,
            max: 5000000,
            divisions: 50,
            onChanged: (value) => setState(() => deposit = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MiniMetric(
                label: 'Repayment guide',
                value: currency(monthlyRepaymentGuide),
              ),
              MiniMetric(label: 'Deposit', value: currency(deposit.round())),
              MiniMetric(
                label: 'Search ceiling',
                value: compactCurrency(estimatedBudget),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => widget.onApplyBudget(estimatedBudget),
              icon: const Icon(Icons.manage_search_outlined),
              label: const Text('Show homes I can buy'),
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetSlider extends StatelessWidget {
  const BudgetSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              currency(value.round()),
              style: const TextStyle(color: appTextSecondary),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: currency(value.round()),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class BuyerJourneyPanel extends StatelessWidget {
  const BuyerJourneyPanel({super.key});

  @override
  Widget build(BuildContext context) {
    const steps = [
      BuyerStepData(
        icon: Icons.account_balance_outlined,
        title: 'Pre-qualify',
        detail: 'Know your ceiling before falling in love with a home.',
      ),
      BuyerStepData(
        icon: Icons.fact_check_outlined,
        title: 'Inspect properly',
        detail: 'Check levy, rates, defects, security and transfer costs.',
      ),
      BuyerStepData(
        icon: Icons.edit_document,
        title: 'Offer smart',
        detail: 'Use demand, days live and agent speed to time the offer.',
      ),
      BuyerStepData(
        icon: Icons.key_outlined,
        title: 'Transfer',
        detail: 'Track bond approval, attorneys, guarantees and occupation.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buyer roadmap',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'A simple path from browsing to keys, built for first-time and repeat buyers.',
            style: TextStyle(color: appTextMuted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...steps.map((step) => BuyerStep(step: step)),
        ],
      ),
    );
  }
}

class BuyerStep extends StatelessWidget {
  const BuyerStep({super.key, required this.step});

  final BuyerStepData step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.icon, color: const Color(0xFF12F58A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BuyerStepData {
  const BuyerStepData({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class SellerValuationPanel extends StatelessWidget {
  const SellerValuationPanel({super.key, required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(Icons.home_work_outlined, color: Colors.black),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Own a property?',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Get a pricing opinion, demand snapshot and agent plan before you list.',
                      style: TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              FactChip(icon: Icons.trending_up, label: 'Price pulse'),
              FactChip(icon: Icons.groups_outlined, label: 'Buyer demand'),
              FactChip(icon: Icons.verified_outlined, label: 'Agent plan'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.calculate_outlined),
              label: const Text('Request valuation'),
            ),
          ),
        ],
      ),
    );
  }
}

class ValuationLeadForm extends StatefulWidget {
  const ValuationLeadForm({super.key});

  @override
  State<ValuationLeadForm> createState() => _ValuationLeadFormState();
}

class _ValuationLeadFormState extends State<ValuationLeadForm> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  String city = 'Cape Town';
  String timeline = 'Just exploring';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request valuation',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'A verified agent can turn this into a listing plan, pricing range and buyer demand report.',
              style: TextStyle(color: appTextMuted),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: name,
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: phone,
              label: 'Mobile number',
              icon: Icons.phone_iphone,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: address,
              label: 'Property address',
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),
            const Text('City', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Cape Town', 'Johannesburg', 'Durban', 'Stellenbosch']
                  .map(
                    (item) => ChoiceChip(
                      selected: city == item,
                      label: Text(item),
                      onSelected: (_) => setState(() => city = item),
                      selectedColor: const Color(0xFF12F58A),
                      backgroundColor: const Color(0xFF0A110D),
                      labelStyle: TextStyle(
                        color: city == item ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      side: const BorderSide(color: Color(0x3312F58A)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Timeline',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Just exploring', '0-3 months', '3-6 months']
                  .map(
                    (item) => ChoiceChip(
                      selected: timeline == item,
                      label: Text(item),
                      onSelected: (_) => setState(() => timeline = item),
                      selectedColor: const Color(0xFF12F58A),
                      backgroundColor: const Color(0xFF0A110D),
                      labelStyle: TextStyle(
                        color: timeline == item ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                      side: const BorderSide(color: Color(0x3312F58A)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : submitValuationLead,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send valuation request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submitValuationLead() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (name.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add your name, phone and property address.'),
        ),
      );
      return;
    }

    setState(() => busy = true);
    final leadMessage = [
      'Owner valuation request.',
      'Address: ${address.text.trim()}, $city.',
      'Timeline: $timeline.',
      'Suggested next step: send CMA and seller plan.',
    ].join(' ');
    try {
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        await Supabase.instance.client.from('leads').insert({
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'message': leadMessage,
          'source': 'seller_valuation',
          'status': 'new',
        });
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            supabaseUrl.isEmpty
                ? 'Demo valuation request captured locally.'
                : 'Valuation request sent. An agent can follow up from Supabase.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send valuation request: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

typedef FilterApplyCallback =
    void Function({
      required ListingSort selectedSort,
      required int selectedMaxBudget,
      required int selectedMinBedrooms,
      required bool selectedVerifiedOnly,
    });

class FilterSheet extends StatefulWidget {
  const FilterSheet({
    super.key,
    required this.sort,
    required this.maxBudget,
    required this.minBedrooms,
    required this.verifiedOnly,
    required this.onApply,
  });

  final ListingSort sort;
  final int maxBudget;
  final int minBedrooms;
  final bool verifiedOnly;
  final FilterApplyCallback onApply;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ListingSort sort = widget.sort;
  late double maxBudget = widget.maxBudget.toDouble();
  late int minBedrooms = widget.minBedrooms;
  late bool verifiedOnly = widget.verifiedOnly;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tune your search',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ListingSort.values.map((item) {
                return ChoiceChip(
                  selected: item == sort,
                  label: Text(item.label),
                  onSelected: (_) => setState(() => sort = item),
                  selectedColor: const Color(0xFF12F58A),
                  backgroundColor: const Color(0xFF0A110D),
                  labelStyle: TextStyle(
                    color: item == sort ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0x3312F58A)),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Budget ceiling: ${compactCurrency(maxBudget.round())}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Slider(
              value: maxBudget,
              min: 1000000,
              max: 50000000,
              divisions: 49,
              label: compactCurrency(maxBudget.round()),
              onChanged: (value) => setState(() => maxBudget = value),
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Minimum bedrooms',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Any')),
                      ButtonSegment(value: 2, label: Text('2+')),
                      ButtonSegment(value: 3, label: Text('3+')),
                      ButtonSegment(value: 4, label: Text('4+')),
                    ],
                    selected: {minBedrooms},
                    onSelectionChanged: (values) {
                      setState(() => minBedrooms = values.first);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Only verified mandates',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: const Text(
                'Documents, agent and media quality checked',
              ),
              value: verifiedOnly,
              onChanged: (value) => setState(() => verifiedOnly = value),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  widget.onApply(
                    selectedSort: sort,
                    selectedMaxBudget: maxBudget.round(),
                    selectedMinBedrooms: minBedrooms,
                    selectedVerifiedOnly: verifiedOnly,
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check),
                label: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MarketPulse extends StatelessWidget {
  const MarketPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: marketPulses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final pulse = marketPulses[index];
          return Container(
            width: 170,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A110D),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x2212F58A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pulse.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  pulse.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  pulse.delta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF12F58A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ),
        if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
      ],
    );
  }
}

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.listing,
    required this.isFavourite,
    required this.onFavourite,
    required this.onTap,
  });

  final PropertyListing listing;
  final bool isFavourite;
  final VoidCallback onFavourite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A110D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0x2212F58A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: listing.imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: StatusPill(text: listing.badge),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: StatusPill(text: '${listing.matchScore}% match'),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: IconButton.filled(
                      onPressed: onFavourite,
                      icon: Icon(
                        isFavourite ? Icons.favorite : Icons.favorite_border,
                        color: isFavourite
                            ? const Color(0xFF12F58A)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currency(listing.price),
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${listing.suburb}, ${listing.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: appTextMuted),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FactChip(
                        icon: Icons.local_fire_department_outlined,
                        label: '${listing.demandScore}/100 demand',
                      ),
                      FactChip(
                        icon: Icons.visibility_outlined,
                        label: '${listing.viewsThisWeek} views',
                      ),
                      if (listing.verifiedDocs)
                        const FactChip(
                          icon: Icons.verified_outlined,
                          label: 'Verified',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FactChip(
                        icon: Icons.king_bed_outlined,
                        label: '${listing.beds} beds',
                      ),
                      FactChip(
                        icon: Icons.bathtub_outlined,
                        label: '${listing.baths} baths',
                      ),
                      FactChip(
                        icon: Icons.directions_car_outlined,
                        label: '${listing.parking} parking',
                      ),
                      FactChip(
                        icon: Icons.square_foot,
                        label: '${listing.floorSize} m2',
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: CachedNetworkImageProvider(
                          listing.agent.avatarUrl,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '${listing.agent.name} · ${listing.agent.responseTime}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: appTextSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingDetailSheet extends StatelessWidget {
  const ListingDetailSheet({
    super.key,
    required this.listing,
    required this.isFavourite,
    required this.onToggleFavourite,
  });

  final PropertyListing listing;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.62,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF050806),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: listing.imageUrl,
                    height: 360,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    top: 14,
                    child: IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  Positioned(
                    right: 14,
                    top: 14,
                    child: Row(
                      children: [
                        IconButton.filled(
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text:
                                  '${listing.title} in ${listing.suburb}: ${currency(listing.price)}',
                            ),
                          ),
                          icon: const Icon(Icons.ios_share),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: onToggleFavourite,
                          icon: Icon(
                            isFavourite
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(text: listing.badge),
                        const SizedBox(height: 10),
                        Text(
                          currency(listing.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          listing.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${listing.suburb}, ${listing.city}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: appTextSecondary),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusPill(text: '${listing.matchScore}% match'),
                            StatusPill(
                              text: '${listing.daysOnMarket} days live',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FactChip(
                          icon: Icons.king_bed_outlined,
                          label: '${listing.beds} bedrooms',
                        ),
                        FactChip(
                          icon: Icons.bathtub_outlined,
                          label: '${listing.baths} bathrooms',
                        ),
                        FactChip(
                          icon: Icons.garage_outlined,
                          label: '${listing.parking} parking',
                        ),
                        FactChip(
                          icon: Icons.square_foot,
                          label: '${listing.floorSize} m2 floor',
                        ),
                        FactChip(
                          icon: Icons.landscape_outlined,
                          label: '${listing.erfSize} m2 erf',
                        ),
                        FactChip(
                          icon: Icons.payments_outlined,
                          label: '${currency(listing.monthlyBond)} est. bond',
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    ListingSignalGrid(listing: listing),
                    const SizedBox(height: 22),
                    BuyerPlanPanel(listing: listing),
                    const SizedBox(height: 22),
                    AreaIntelligencePanel(listing: listing),
                    const SizedBox(height: 22),
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      listing.description,
                      style: const TextStyle(
                        color: appTextSecondary,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Highlights',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...listing.highlights.map(
                      (highlight) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF12F58A),
                              size: 19,
                            ),
                            const SizedBox(width: 9),
                            Expanded(child: Text(highlight)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    AgentPanel(agent: listing.agent),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => showLeadSheet(context, listing),
                            icon: const Icon(Icons.mark_email_unread_outlined),
                            label: const Text('Enquire'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () => launchUrl(
                            Uri.parse('tel:${listing.agent.phone}'),
                          ),
                          icon: const Icon(Icons.call),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void showLeadSheet(BuildContext context, PropertyListing listing) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF08100B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => LeadForm(listing: listing),
  );
}

class LeadForm extends StatefulWidget {
  const LeadForm({super.key, required this.listing});

  final PropertyListing listing;

  @override
  State<LeadForm> createState() => _LeadFormState();
}

class _LeadFormState extends State<LeadForm> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final message = TextEditingController();
  String readiness = 'Viewing soon';
  String viewingWindow = 'This week';
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send enquiry',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              widget.listing.title,
              style: const TextStyle(color: appTextMuted),
            ),
            const SizedBox(height: 16),
            AppField(
              controller: name,
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: email,
              label: 'Email address',
              icon: Icons.alternate_email,
            ),
            const SizedBox(height: 10),
            AppField(
              controller: phone,
              label: 'Mobile number',
              icon: Icons.phone_iphone,
            ),
            const SizedBox(height: 14),
            const Text(
              'Buyer intent',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['Viewing soon', 'Need finance', 'Cash buyer'].map((
                item,
              ) {
                return ChoiceChip(
                  selected: readiness == item,
                  label: Text(item),
                  onSelected: (_) => setState(() => readiness = item),
                  selectedColor: const Color(0xFF12F58A),
                  backgroundColor: const Color(0xFF0A110D),
                  labelStyle: TextStyle(
                    color: readiness == item ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0x3312F58A)),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Preferred time',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['This week', 'Weekend', 'After hours'].map((item) {
                return ChoiceChip(
                  selected: viewingWindow == item,
                  label: Text(item),
                  onSelected: (_) => setState(() => viewingWindow = item),
                  selectedColor: const Color(0xFF12F58A),
                  backgroundColor: const Color(0xFF0A110D),
                  labelStyle: TextStyle(
                    color: viewingWindow == item ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  side: const BorderSide(color: Color(0x3312F58A)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            AppField(
              controller: message,
              label: 'Message to agent',
              icon: Icons.chat_bubble_outline,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : submitLead,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Request viewing'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> submitLead() async {
    final messenger = ScaffoldMessenger.of(context);
    final contact =
        email.text.trim().isNotEmpty || phone.text.trim().isNotEmpty;
    if (name.text.trim().isEmpty || !contact) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add your name and at least one contact detail.'),
        ),
      );
      return;
    }

    setState(() => busy = true);
    final navigator = Navigator.of(context);
    final leadMessage = [
      if (message.text.trim().isNotEmpty) message.text.trim(),
      'Interested in ${widget.listing.title}.',
      'Intent: $readiness.',
      'Preferred viewing: $viewingWindow.',
      'Listing signal: ${widget.listing.matchScore}% match, ${widget.listing.demandScore}/100 demand.',
    ].join(' ');
    try {
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        await Supabase.instance.client.from('leads').insert({
          'listing_id': widget.listing.id,
          'agent_id': widget.listing.agent.id,
          'name': name.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'message': leadMessage,
          'source': 'mobile_app',
          'status': 'new',
        });
      }
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            supabaseUrl.isEmpty
                ? 'Demo enquiry captured locally. Add Supabase keys to send it live.'
                : 'Enquiry sent to ${widget.listing.agent.name}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not send enquiry: $error')),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFF0D1711),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class SavedPage extends StatelessWidget {
  const SavedPage({
    super.key,
    required this.listings,
    required this.onOpenListing,
    required this.onToggleFavourite,
  });

  final List<PropertyListing> listings;
  final ValueChanged<PropertyListing> onOpenListing;
  final ValueChanged<String> onToggleFavourite;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const BrandHeader(),
        const SizedBox(height: 22),
        const Text(
          'Saved homes',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Shortlist, compare, share and convert favourites into viewing requests.',
          style: TextStyle(color: appTextMuted),
        ),
        const SizedBox(height: 18),
        if (listings.isEmpty)
          const EmptyState(
            icon: Icons.favorite_border,
            title: 'No saved properties yet',
          )
        else ...[
          ShortlistComparisonPanel(listings: listings),
          const SizedBox(height: 16),
          ...listings.map(
            (listing) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PropertyCard(
                listing: listing,
                isFavourite: true,
                onFavourite: () => onToggleFavourite(listing.slug),
                onTap: () => onOpenListing(listing),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class ShortlistComparisonPanel extends StatelessWidget {
  const ShortlistComparisonPanel({super.key, required this.listings});

  final List<PropertyListing> listings;

  @override
  Widget build(BuildContext context) {
    final bestMatch = listings.reduce(
      (left, right) => left.matchScore >= right.matchScore ? left : right,
    );
    final lowestMonthly = listings.reduce(
      (left, right) => left.monthlyBond <= right.monthlyBond ? left : right,
    );
    final averagePrice =
        listings.map((listing) => listing.price).reduce((a, b) => a + b) ~/
        listings.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(Icons.compare_arrows, color: Colors.black),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Shortlist intelligence',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${listings.length} saved · avg ${currency(averagePrice)}',
                      style: const TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: _shortlistShareText(listings)),
                ),
                icon: const Icon(Icons.ios_share),
                tooltip: 'Share shortlist',
              ),
            ],
          ),
          const SizedBox(height: 14),
          ComparisonRow(
            icon: Icons.workspace_premium_outlined,
            label: 'Best match',
            value: '${bestMatch.title} · ${bestMatch.matchScore}%',
          ),
          ComparisonRow(
            icon: Icons.payments_outlined,
            label: 'Lowest monthly',
            value:
                '${lowestMonthly.title} · ${currency(lowestMonthly.monthlyBond)}',
          ),
          ComparisonRow(
            icon: Icons.speed_outlined,
            label: 'Fastest agent',
            value: _fastestAgent(listings),
          ),
        ],
      ),
    );
  }

  String _shortlistShareText(List<PropertyListing> listings) {
    final lines = listings
        .map((listing) {
          return '${listing.title} - ${currency(listing.price)} in ${listing.suburb}';
        })
        .join('\n');
    return 'My More Properties shortlist:\n$lines';
  }

  String _fastestAgent(List<PropertyListing> listings) {
    final fastest = listings.reduce(
      (left, right) => left.agent.responseMinutes <= right.agent.responseMinutes
          ? left
          : right,
    );
    return '${fastest.agent.name} · ${fastest.agent.responseTime}';
  }
}

class ComparisonRow extends StatelessWidget {
  const ComparisonRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF12F58A), size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late final alerts = savedSearches.toList();
  ListingMode mode = ListingMode.buy;
  String city = 'Cape Town';
  String cadence = 'Instant';
  bool pushEnabled = true;
  bool emailEnabled = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const BrandHeader(),
        const SizedBox(height: 22),
        const Text(
          'Smart alerts',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Saved searches become Supabase rows and can power email, push, or WhatsApp notifications.',
          style: TextStyle(color: appTextMuted),
        ),
        const SizedBox(height: 18),
        AlertBuilderPanel(
          mode: mode,
          city: city,
          cadence: cadence,
          pushEnabled: pushEnabled,
          emailEnabled: emailEnabled,
          onModeChanged: (value) => setState(() => mode = value),
          onCityChanged: (value) => setState(() => city = value),
          onCadenceChanged: (value) => setState(() => cadence = value),
          onPushChanged: (value) => setState(() => pushEnabled = value),
          onEmailChanged: (value) => setState(() => emailEnabled = value),
          onCreate: createAlert,
        ),
        const SizedBox(height: 18),
        ...alerts.map((search) => AlertSearchCard(search: search)),
      ],
    );
  }

  void createAlert() {
    final name = '$city ${mode.label.toLowerCase()} watchlist';
    final channels = [
      if (pushEnabled) 'push',
      if (emailEnabled) 'email',
    ].join(' + ');
    setState(() {
      alerts.insert(
        0,
        SavedSearchData(
          name: name,
          criteria:
              '${mode.label} · ${compactCurrency(50000000)} max · $channels',
          matches: 18 + alerts.length,
          cadence: cadence,
        ),
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Alert created: $name')));
  }
}

class AlertBuilderPanel extends StatelessWidget {
  const AlertBuilderPanel({
    super.key,
    required this.mode,
    required this.city,
    required this.cadence,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.onModeChanged,
    required this.onCityChanged,
    required this.onCadenceChanged,
    required this.onPushChanged,
    required this.onEmailChanged,
    required this.onCreate,
  });

  final ListingMode mode;
  final String city;
  final String cadence;
  final bool pushEnabled;
  final bool emailEnabled;
  final ValueChanged<ListingMode> onModeChanged;
  final ValueChanged<String> onCityChanged;
  final ValueChanged<String> onCadenceChanged;
  final ValueChanged<bool> onPushChanged;
  final ValueChanged<bool> onEmailChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(
                  Icons.notification_add_outlined,
                  color: Colors.black,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a live alert',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Catch price drops, new mandates and fast-moving suburbs.',
                      style: TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ListingMode.values.map((item) {
              final selected = item == mode;
              return ChoiceChip(
                selected: selected,
                label: Text(item.label),
                onSelected: (_) => onModeChanged(item),
                selectedColor: const Color(0xFF12F58A),
                backgroundColor: const Color(0xFF111B15),
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.w800,
                ),
                side: const BorderSide(color: Color(0x3312F58A)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Cape Town', 'Johannesburg', 'Durban', 'Stellenbosch']
                .map(
                  (item) => ChoiceChip(
                    selected: item == city,
                    label: Text(item),
                    onSelected: (_) => onCityChanged(item),
                    selectedColor: const Color(0xFF12F58A),
                    backgroundColor: const Color(0xFF111B15),
                    labelStyle: TextStyle(
                      color: item == city ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    side: const BorderSide(color: Color(0x3312F58A)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Instant', 'Daily', 'Weekly']
                .map(
                  (item) => ChoiceChip(
                    selected: item == cadence,
                    label: Text(item),
                    onSelected: (_) => onCadenceChanged(item),
                    selectedColor: const Color(0xFF12F58A),
                    backgroundColor: const Color(0xFF111B15),
                    labelStyle: TextStyle(
                      color: item == cadence ? Colors.black : Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    side: const BorderSide(color: Color(0x3312F58A)),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Push notifications'),
            value: pushEnabled,
            onChanged: onPushChanged,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email digest'),
            value: emailEnabled,
            onChanged: onEmailChanged,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.radar),
              label: const Text('Create alert'),
            ),
          ),
        ],
      ),
    );
  }
}

class AlertSearchCard extends StatelessWidget {
  const AlertSearchCard({super.key, required this.search});

  final SavedSearchData search;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2212F58A)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF12F58A),
            child: Icon(Icons.radar, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  search.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  search.criteria,
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${search.matches}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                search.cadence,
                style: const TextStyle(color: Color(0xFF12F58A), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const BrandHeader(),
        const SizedBox(height: 22),
        const Text(
          'Verified agents',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        const Text(
          'Rank by response speed, area authority, mandate quality and buyer feedback.',
          style: TextStyle(color: appTextMuted),
        ),
        const SizedBox(height: 18),
        ...demoAgents.map(
          (agent) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: AgentPanel(agent: agent),
          ),
        ),
      ],
    );
  }
}

class StudioPage extends StatelessWidget {
  const StudioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: const [
        BrandHeader(),
        SizedBox(height: 22),
        Text(
          'Agent studio',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 8),
        Text(
          'A mobile control room for mandates, enquiries, listing quality, scheduled viewings and performance.',
          style: TextStyle(color: appTextMuted),
        ),
        SizedBox(height: 18),
        StudioMetric(
          title: 'New leads',
          value: '38',
          delta: '+14% this week',
          icon: Icons.mark_email_unread_outlined,
        ),
        StudioMetric(
          title: 'Avg response',
          value: '11m',
          delta: 'Top 8% in area',
          icon: Icons.speed,
        ),
        StudioMetric(
          title: 'Listing health',
          value: '92%',
          delta: 'Photos and docs verified',
          icon: Icons.verified_outlined,
        ),
        StudioMetric(
          title: 'Viewings booked',
          value: '17',
          delta: '9 confirmed, 8 pending',
          icon: Icons.calendar_month_outlined,
        ),
        SizedBox(height: 6),
        LeadPipelineBoard(),
        SizedBox(height: 18),
        StudioActionList(),
      ],
    );
  }
}

class LeadPipelineBoard extends StatelessWidget {
  const LeadPipelineBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Lead pipeline',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 12),
          PipelineStage(label: 'New', value: 38, color: Color(0xFF12F58A)),
          PipelineStage(
            label: 'Contacted',
            value: 24,
            color: Color(0xFF7DFFC3),
          ),
          PipelineStage(
            label: 'Viewing booked',
            value: 17,
            color: Color(0xFFFFD166),
          ),
          PipelineStage(label: 'Qualified', value: 9, color: Color(0xFFFF7A7A)),
        ],
      ),
    );
  }
}

class PipelineStage extends StatelessWidget {
  const PipelineStage({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: appTextMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: value / 40,
                backgroundColor: const Color(0xFF111B15),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class StudioActionList extends StatelessWidget {
  const StudioActionList({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Today\'s action list',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 10),
        StudioActionTile(
          icon: Icons.phone_in_talk_outlined,
          title: 'Call 6 hot leads',
          detail: 'Prioritise buyers who viewed twice today.',
        ),
        StudioActionTile(
          icon: Icons.camera_alt_outlined,
          title: 'Improve 2 listing galleries',
          detail: 'Add exterior dusk shots and floor-plan images.',
        ),
        StudioActionTile(
          icon: Icons.fact_check_outlined,
          title: 'Verify mandate documents',
          detail: '3 listings need FICA and signed authority checks.',
        ),
      ],
    );
  }
}

class StudioActionTile extends StatelessWidget {
  const StudioActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2212F58A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF12F58A)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: appTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudioMetric extends StatelessWidget {
  const StudioMetric({
    super.key,
    required this.title,
    required this.value,
    required this.delta,
    required this.icon,
  });

  final String title;
  final String value;
  final String delta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A110D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x2212F58A)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF12F58A),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: appTextMuted)),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    delta,
                    style: const TextStyle(
                      color: Color(0xFF12F58A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingSignalGrid extends StatelessWidget {
  const ListingSignalGrid({super.key, required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final signals = [
      SignalData(
        icon: Icons.analytics_outlined,
        label: 'Price signal',
        value: listing.priceSignal,
      ),
      SignalData(
        icon: Icons.trending_up,
        label: 'Growth case',
        value: listing.roiNote,
      ),
      SignalData(
        icon: Icons.groups_outlined,
        label: 'Buyer demand',
        value: '${listing.demandScore}/100 · ${listing.viewsThisWeek} views',
      ),
      SignalData(
        icon: Icons.verified_outlined,
        label: 'Trust layer',
        value: listing.verifiedDocs ? 'Verified mandate' : 'Agent supplied',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 430;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: signals.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: singleColumn ? 1 : 2,
            mainAxisExtent: singleColumn ? 104 : 132,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) => SignalTile(signal: signals[index]),
        );
      },
    );
  }
}

class BuyerPlanPanel extends StatelessWidget {
  const BuyerPlanPanel({super.key, required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final deposit = listing.mode == ListingMode.rent
        ? listing.price * 2
        : (listing.price * 0.1).round();
    final transferBuffer = listing.mode == ListingMode.buy
        ? (listing.price * 0.035).round()
        : 0;
    final incomeNeeded = (listing.monthlyBond / 0.3).round();
    final actionLabel = listing.mode == ListingMode.rent
        ? 'Rental readiness'
        : 'Buyer readiness';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Fast estimate before you speak to the agent.',
                      style: TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MiniMetric(
                label: listing.mode == ListingMode.rent
                    ? 'Deposit'
                    : '10% deposit',
                value: currency(deposit),
              ),
              MiniMetric(
                label: listing.mode == ListingMode.rent
                    ? 'Monthly rent'
                    : 'Est. bond',
                value: currency(listing.monthlyBond),
              ),
              MiniMetric(label: 'Income guide', value: currency(incomeNeeded)),
              if (transferBuffer > 0)
                MiniMetric(
                  label: 'Transfer buffer',
                  value: currency(transferBuffer),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class AreaIntelligencePanel extends StatelessWidget {
  const AreaIntelligencePanel({super.key, required this.listing});

  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final insights = _areaInsights(listing);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x3312F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CircleAvatar(
                backgroundColor: Color(0xFF12F58A),
                child: Icon(Icons.insights_outlined, color: Colors.black),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Area intelligence',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Local signals to check before booking a viewing.',
                      style: TextStyle(color: appTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...insights.map(
            (insight) => ComparisonRow(
              icon: insight.icon,
              label: insight.label,
              value: insight.value,
            ),
          ),
        ],
      ),
    );
  }

  List<SignalData> _areaInsights(PropertyListing listing) {
    final growth = switch (listing.city) {
      'Cape Town' => 'Low stock and high semigration pressure',
      'Johannesburg' => 'Strong node demand near work hubs',
      'Durban' => 'Coastal lifestyle and corporate rental depth',
      'Stellenbosch' => 'Education, wine estate and security-led demand',
      _ => 'Demand depends on suburb quality and pricing',
    };
    return [
      SignalData(
        icon: Icons.trending_up,
        label: 'Demand driver',
        value: growth,
      ),
      SignalData(
        icon: Icons.shield_outlined,
        label: 'Risk check',
        value: listing.verifiedDocs
            ? 'Mandate, agent and listing details verified'
            : 'Confirm mandate and documents with the agent',
      ),
      SignalData(
        icon: Icons.schedule_outlined,
        label: 'Viewing urgency',
        value: listing.demandScore > 85
            ? 'Book within 24 hours'
            : 'Compare with similar stock this week',
      ),
    ];
  }
}

class MiniMetric extends StatelessWidget {
  const MiniMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111B15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: appTextMuted, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class SignalTile extends StatelessWidget {
  const SignalTile({super.key, required this.signal});

  final SignalData signal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x2212F58A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(signal.icon, color: const Color(0xFF12F58A), size: 20),
          const SizedBox(height: 8),
          Text(
            signal.label,
            style: const TextStyle(color: appTextMuted, fontSize: 12),
          ),
          const Spacer(),
          Text(
            signal.value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class AgentPanel extends StatelessWidget {
  const AgentPanel({super.key, required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x2212F58A)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: CachedNetworkImageProvider(agent.avatarUrl),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  agent.agency,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: appTextMuted),
                ),
                const SizedBox(height: 5),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFF12F58A)),
                    Text(
                      '${agent.rating} · ${agent.responseTime}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => launchUrl(Uri.parse('mailto:${agent.email}')),
            icon: const Icon(Icons.mail_outline),
          ),
        ],
      ),
    );
  }
}

class FactChip extends StatelessWidget {
  const FactChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111B15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF12F58A)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF12F58A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF0A110D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: const Color(0xFF12F58A)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

enum ListingMode { buy, rent, developments, commercial }

enum ListingSort { recommended, priceLow, priceHigh, newest }

extension ListingModeUi on ListingMode {
  String get label => switch (this) {
    ListingMode.buy => 'Buy',
    ListingMode.rent => 'Rent',
    ListingMode.developments => 'New Builds',
    ListingMode.commercial => 'Commercial',
  };

  IconData get icon => switch (this) {
    ListingMode.buy => Icons.sell_outlined,
    ListingMode.rent => Icons.key_outlined,
    ListingMode.developments => Icons.apartment_outlined,
    ListingMode.commercial => Icons.store_mall_directory_outlined,
  };
}

extension ListingSortUi on ListingSort {
  String get label => switch (this) {
    ListingSort.recommended => 'Recommended',
    ListingSort.priceLow => 'Lowest price',
    ListingSort.priceHigh => 'Highest price',
    ListingSort.newest => 'Newest',
  };
}

class SignalData {
  const SignalData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class Agent {
  const Agent({
    required this.id,
    required this.name,
    required this.agency,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.rating,
    required this.responseTime,
    required this.responseMinutes,
  });

  final String id;
  final String name;
  final String agency;
  final String email;
  final String phone;
  final String avatarUrl;
  final double rating;
  final String responseTime;
  final int responseMinutes;
}

class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.slug,
    required this.title,
    required this.mode,
    required this.propertyType,
    required this.price,
    required this.suburb,
    required this.city,
    required this.beds,
    required this.baths,
    required this.parking,
    required this.floorSize,
    required this.erfSize,
    required this.imageUrl,
    required this.badge,
    required this.description,
    required this.highlights,
    required this.agent,
    required this.matchScore,
    required this.demandScore,
    required this.daysOnMarket,
    required this.viewsThisWeek,
    required this.verifiedDocs,
    required this.priceSignal,
    required this.roiNote,
    required this.monthlyBond,
  });

  factory PropertyListing.fromSupabase(Map<String, dynamic> row) {
    final agentRow = Map<String, dynamic>.from(row['agents'] as Map? ?? {});
    final agencyRow = Map<String, dynamic>.from(
      agentRow['agencies'] as Map? ?? {},
    );
    final price = _readInt(row['price']);
    final features = _readStringList(row['features']);
    final amenities = _readStringList(row['amenities']);
    final isFeatured = row['is_featured'] == true;
    final responseMinutes = _readInt(
      agentRow['response_minutes'],
      fallback: 30,
    );
    final daysOnMarket = _daysSince(row['published_at']);
    final demandScore = _clampScore(
      72 +
          (isFeatured ? 9 : 0) +
          (responseMinutes <= 12 ? 8 : 0) -
          daysOnMarket,
    );
    final matchScore = _clampScore(
      demandScore +
          (row['mode'] == 'buy' ? 4 : 0) +
          (agentRow['verified'] == true ? 3 : 0),
    );

    return PropertyListing(
      id: row['id']?.toString() ?? '',
      slug: row['slug']?.toString() ?? '',
      title: row['title']?.toString() ?? 'Untitled listing',
      mode: ListingMode.values.firstWhere(
        (item) => item.name == row['mode']?.toString(),
        orElse: () => ListingMode.buy,
      ),
      propertyType: row['property_type']?.toString() ?? 'Property',
      price: price,
      suburb: row['suburb']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      beds: _readInt(row['bedrooms']),
      baths: _readInt(row['bathrooms']),
      parking: _readInt(row['parking']),
      floorSize: _readInt(row['floor_size']),
      erfSize: _readInt(row['erf_size']),
      imageUrl:
          row['hero_image_url']?.toString() ?? demoListings.first.imageUrl,
      badge: isFeatured ? 'Featured mandate' : 'Verified listing',
      description: row['description']?.toString() ?? '',
      highlights: features.isEmpty ? amenities : features,
      agent: Agent(
        id: agentRow['id']?.toString() ?? '',
        name: agentRow['display_name']?.toString() ?? 'More Properties Agent',
        agency: agencyRow['name']?.toString() ?? 'More Properties',
        email: agentRow['email']?.toString() ?? 'hello@moreproperties.co.za',
        phone: agentRow['phone']?.toString() ?? '+27000000000',
        avatarUrl:
            agentRow['avatar_url']?.toString() ?? demoAgents.first.avatarUrl,
        rating: _readDouble(agentRow['rating'], fallback: 4.8),
        responseTime: '$responseMinutes min response',
        responseMinutes: responseMinutes,
      ),
      matchScore: matchScore,
      demandScore: demandScore,
      daysOnMarket: daysOnMarket,
      viewsThisWeek: 70 + (matchScore * 2) + (isFeatured ? 35 : 0),
      verifiedDocs: agentRow['verified'] == true || isFeatured,
      priceSignal: _priceSignal(row['mode']?.toString(), isFeatured),
      roiNote: _roiNote(row['mode']?.toString(), row['city']?.toString() ?? ''),
      monthlyBond: row['mode'] == 'rent' || row['mode'] == 'commercial'
          ? price
          : (price * 0.01).round(),
    );
  }

  final String id;
  final String slug;
  final String title;
  final ListingMode mode;
  final String propertyType;
  final int price;
  final String suburb;
  final String city;
  final int beds;
  final int baths;
  final int parking;
  final int floorSize;
  final int erfSize;
  final String imageUrl;
  final String badge;
  final String description;
  final List<String> highlights;
  final Agent agent;
  final int matchScore;
  final int demandScore;
  final int daysOnMarket;
  final int viewsThisWeek;
  final bool verifiedDocs;
  final String priceSignal;
  final String roiNote;
  final int monthlyBond;
}

class SavedSearchData {
  const SavedSearchData({
    required this.name,
    required this.criteria,
    required this.matches,
    required this.cadence,
  });

  final String name;
  final String criteria;
  final int matches;
  final String cadence;
}

class PulseData {
  const PulseData({
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;
}

final currencyFormat = NumberFormat.currency(
  locale: 'en_ZA',
  symbol: 'R',
  decimalDigits: 0,
);

String currency(int value) => currencyFormat.format(value);

String compactCurrency(int value) {
  if (value >= 1000000) return 'R${(value / 1000000).toStringAsFixed(1)}m';
  return 'R${(value / 1000).round()}k';
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _readStringList(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}

int _daysSince(Object? value) {
  final publishedAt = DateTime.tryParse(value?.toString() ?? '');
  if (publishedAt == null) return 14;
  return DateTime.now().difference(publishedAt).inDays.clamp(1, 90).toInt();
}

int _clampScore(int value) => value.clamp(58, 98).toInt();

String _priceSignal(String? mode, bool isFeatured) {
  return switch (mode) {
    'rent' => 'High-intent rental demand',
    'commercial' => 'Negotiable lease economics',
    'developments' => 'Launch-phase pricing window',
    _ => isFeatured ? 'Priority mandate pricing' : 'Comparable-market aligned',
  };
}

String _roiNote(String? mode, String city) {
  return switch (mode) {
    'rent' => 'Income-ready lifestyle stock',
    'commercial' => 'Tenant retention upside',
    'developments' => 'Early-phase entry advantage',
    _ => '$city demand supports resale depth',
  };
}

const demoAgents = [
  Agent(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Ava Mokoena',
    agency: 'More Prime Atlantic',
    email: 'ava@moreproperties.co.za',
    phone: '+27821234567',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
    rating: 4.9,
    responseTime: '9 min response',
    responseMinutes: 9,
  ),
  Agent(
    id: '22222222-2222-4222-8222-222222222222',
    name: 'Liam Naidoo',
    agency: 'More Urban Gauteng',
    email: 'liam@moreproperties.co.za',
    phone: '+27829876543',
    avatarUrl:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=80',
    rating: 4.8,
    responseTime: '14 min response',
    responseMinutes: 14,
  ),
  Agent(
    id: '33333333-3333-4333-8333-333333333333',
    name: 'Mia Jacobs',
    agency: 'More Coastal Living',
    email: 'mia@moreproperties.co.za',
    phone: '+27827654321',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    rating: 4.9,
    responseTime: '7 min response',
    responseMinutes: 7,
  ),
];

final demoListings = [
  PropertyListing(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    slug: 'clifton-edge',
    title: 'Architectural villa above the Atlantic',
    mode: ListingMode.buy,
    propertyType: 'House',
    price: 38900000,
    suburb: 'Clifton',
    city: 'Cape Town',
    beds: 5,
    baths: 5,
    parking: 4,
    floorSize: 612,
    erfSize: 970,
    imageUrl:
        'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1400&q=80',
    badge: 'Exclusive mandate',
    description:
        'A cinematic coastal home with layered entertainment decks, glass-wrapped living spaces, smart security, backup power and uninterrupted Atlantic views.',
    highlights: [
      'Private lift and four-car garage',
      'Battery backup with solar-ready infrastructure',
      'Designer kitchen and temperature-controlled wine room',
    ],
    agent: demoAgents[0],
    matchScore: 97,
    demandScore: 91,
    daysOnMarket: 6,
    viewsThisWeek: 184,
    verifiedDocs: true,
    priceSignal: 'Rare Clifton inventory',
    roiNote: 'Scarcity-led capital preservation',
    monthlyBond: 389000,
  ),
  PropertyListing(
    id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    slug: 'rosebank-skyline',
    title: 'High-floor apartment with city views',
    mode: ListingMode.buy,
    propertyType: 'Apartment',
    price: 3260000,
    suburb: 'Rosebank',
    city: 'Johannesburg',
    beds: 2,
    baths: 2,
    parking: 2,
    floorSize: 119,
    erfSize: 0,
    imageUrl:
        'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=1400&q=80',
    badge: 'New this week',
    description:
        'A lock-up-and-go apartment in a concierge building, walking distance to the Gautrain, offices, galleries and restaurants.',
    highlights: [
      'Concierge lobby and biometric access',
      'Generator-backed common areas',
      'Walkable business and lifestyle precinct',
    ],
    agent: demoAgents[1],
    matchScore: 89,
    demandScore: 86,
    daysOnMarket: 3,
    viewsThisWeek: 241,
    verifiedDocs: true,
    priceSignal: 'Below nearby new-build stock',
    roiNote: 'Strong rental depth near Gautrain',
    monthlyBond: 32600,
  ),
  PropertyListing(
    id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    slug: 'umhlanga-rent',
    title: 'Furnished coastal rental near the promenade',
    mode: ListingMode.rent,
    propertyType: 'Apartment',
    price: 34500,
    suburb: 'Umhlanga Rocks',
    city: 'Durban',
    beds: 3,
    baths: 2,
    parking: 2,
    floorSize: 148,
    erfSize: 0,
    imageUrl:
        'https://images.unsplash.com/photo-1600607688969-a5bfcd646154?auto=format&fit=crop&w=1400&q=80',
    badge: 'Available now',
    description:
        'A furnished rental with ocean-facing balcony, fibre, hotel-style amenities and secure parking minutes from beaches and business nodes.',
    highlights: [
      'Furnished and fibre-ready',
      'Sea-facing balcony',
      'Pool, gym and 24-hour security',
    ],
    agent: demoAgents[2],
    matchScore: 92,
    demandScore: 88,
    daysOnMarket: 2,
    viewsThisWeek: 167,
    verifiedDocs: true,
    priceSignal: 'Premium furnished rental band',
    roiNote: 'Corporate tenant appeal',
    monthlyBond: 34500,
  ),
  PropertyListing(
    id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
    slug: 'stellenbosch-estate',
    title: 'Boutique estate development release',
    mode: ListingMode.developments,
    propertyType: 'Development',
    price: 4895000,
    suburb: 'Paradyskloof',
    city: 'Stellenbosch',
    beds: 3,
    baths: 3,
    parking: 2,
    floorSize: 221,
    erfSize: 382,
    imageUrl:
        'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=1400&q=80',
    badge: 'No transfer duty',
    description:
        'A limited collection of energy-efficient homes with mountain views, private gardens and direct access to schools, trails and wine farms.',
    highlights: [
      'Transfer-duty inclusive pricing',
      'Solar, inverter and water-wise landscaping',
      'Phase launch with occupation tracking',
    ],
    agent: demoAgents[0],
    matchScore: 94,
    demandScore: 83,
    daysOnMarket: 9,
    viewsThisWeek: 129,
    verifiedDocs: true,
    priceSignal: 'Launch pricing window',
    roiNote: 'No transfer duty improves entry cost',
    monthlyBond: 48950,
  ),
  PropertyListing(
    id: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    slug: 'sandton-commercial',
    title: 'Flexible office floor in green-rated tower',
    mode: ListingMode.commercial,
    propertyType: 'Commercial',
    price: 188000,
    suburb: 'Sandton Central',
    city: 'Johannesburg',
    beds: 0,
    baths: 6,
    parking: 28,
    floorSize: 940,
    erfSize: 0,
    imageUrl:
        'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=1400&q=80',
    badge: 'Tenant-ready',
    description:
        'A premium commercial floor with flexible fit-out, backup power, boardrooms, fibre redundancy and direct access to transport routes.',
    highlights: [
      'Green-rated building',
      'Backup power and fibre redundancy',
      'Flexible lease and fit-out support',
    ],
    agent: demoAgents[1],
    matchScore: 87,
    demandScore: 79,
    daysOnMarket: 11,
    viewsThisWeek: 96,
    verifiedDocs: false,
    priceSignal: 'Competitive per-square metre lease',
    roiNote: 'Flexible floor supports tenant retention',
    monthlyBond: 188000,
  ),
];

const savedSearches = [
  SavedSearchData(
    name: 'Atlantic Seaboard family homes',
    criteria: 'R18m-R45m · 4+ beds · sea views',
    matches: 12,
    cadence: 'Instant',
  ),
  SavedSearchData(
    name: 'Rosebank lock-up-and-go',
    criteria: 'Apartments · R2m-R4m · parking',
    matches: 28,
    cadence: 'Daily',
  ),
  SavedSearchData(
    name: 'Cape Winelands launches',
    criteria: 'New developments · no transfer duty',
    matches: 7,
    cadence: 'Weekly',
  ),
];

const marketPulses = [
  PulseData(label: 'Median Cape Town', value: 'R3.9m', delta: '+6.2% YoY'),
  PulseData(label: 'Hot suburb', value: 'Rosebank', delta: '42 new leads'),
  PulseData(label: 'Avg response', value: '12m', delta: 'Verified agents'),
  PulseData(label: 'New today', value: '184', delta: 'Across SA'),
];
