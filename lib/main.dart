import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

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
        ).apply(bodyColor: const Color(0xFFEAF8EF), displayColor: Colors.white),
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
  ListingMode mode = ListingMode.buy;

  List<PropertyListing> get filteredListings {
    final query = searchController.text.trim().toLowerCase();
    return demoListings.where((listing) {
      final matchesMode = listing.mode == mode;
      final matchesQuery =
          query.isEmpty ||
          listing.title.toLowerCase().contains(query) ||
          listing.suburb.toLowerCase().contains(query) ||
          listing.city.toLowerCase().contains(query) ||
          listing.propertyType.toLowerCase().contains(query);
      return matchesMode && matchesQuery;
    }).toList();
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
        mode: mode,
        onModeChanged: (value) => setState(() => mode = value),
        onSearchChanged: (_) => setState(() {}),
        onToggleFavourite: toggleFavourite,
        onOpenListing: openListing,
      ),
      SavedPage(
        listings: demoListings
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
}

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({
    super.key,
    required this.listings,
    required this.favourites,
    required this.searchController,
    required this.mode,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onToggleFavourite,
    required this.onOpenListing,
  });

  final List<PropertyListing> listings;
  final Set<String> favourites;
  final TextEditingController searchController;
  final ListingMode mode;
  final ValueChanged<ListingMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;
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
                const HeroPanel(),
                const SizedBox(height: 16),
                SearchBox(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 14),
                ModeSelector(mode: mode, onModeChanged: onModeChanged),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
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
                style: TextStyle(color: Color(0xFF9FB5A7), fontSize: 12),
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
    return Container(
      height: 208,
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x99000000), Color(0xEE020503)],
          ),
          border: Border.all(color: const Color(0x5512F58A)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Find the move before the market moves.',
              style: TextStyle(
                fontSize: 27,
                height: 1.02,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Verified listings, smart alerts, area signals, agent response tracking, and premium lead capture in one mobile app.',
              style: TextStyle(color: Color(0xFFD8EADF), height: 1.35),
            ),
          ],
        ),
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
        hintText: 'Search suburb, city, estate or property type',
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ListingMode.values.map((item) {
          final selected = item == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
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
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MarketPulse extends StatelessWidget {
  const MarketPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: marketPulses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final pulse = marketPulses[index];
          return Container(
            width: 154,
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
                  style: const TextStyle(
                    color: Color(0xFF9FB5A7),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  pulse.value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  pulse.delta,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${listing.suburb}, ${listing.city}',
                    style: const TextStyle(color: Color(0xFF9FB5A7)),
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
                          style: const TextStyle(
                            color: Color(0xFFD8EADF),
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
                    height: 320,
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
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          listing.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${listing.suburb}, ${listing.city}',
                          style: const TextStyle(color: Color(0xFFD8EADF)),
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
                      ],
                    ),
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
                        color: Color(0xFFD8EADF),
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
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            style: const TextStyle(color: Color(0xFF9FB5A7)),
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
    );
  }

  Future<void> submitLead() async {
    setState(() => busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
        await Supabase.instance.client.from('leads').insert({
          'listing_id': widget.listing.id,
          'agent_id': widget.listing.agent.id,
          'name': name.text.trim(),
          'email': email.text.trim(),
          'phone': phone.text.trim(),
          'message':
              'I would like to book a viewing for ${widget.listing.title}',
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
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
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
          style: TextStyle(color: Color(0xFF9FB5A7)),
        ),
        const SizedBox(height: 18),
        if (listings.isEmpty)
          const EmptyState(
            icon: Icons.favorite_border,
            title: 'No saved properties yet',
          )
        else
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
    );
  }
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

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
          style: TextStyle(color: Color(0xFF9FB5A7)),
        ),
        const SizedBox(height: 18),
        ...savedSearches.map(
          (search) => Container(
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
                        style: const TextStyle(
                          color: Color(0xFF9FB5A7),
                          fontSize: 12,
                        ),
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
                      style: const TextStyle(
                        color: Color(0xFF12F58A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
          style: TextStyle(color: Color(0xFF9FB5A7)),
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
          style: TextStyle(color: Color(0xFF9FB5A7)),
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
      ],
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
                  Text(title, style: const TextStyle(color: Color(0xFF9FB5A7))),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Text(
                delta,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF12F58A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  agent.agency,
                  style: const TextStyle(color: Color(0xFF9FB5A7)),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Color(0xFF12F58A)),
                    Text(
                      ' ${agent.rating} · ${agent.responseTime}',
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

extension ListingModeUi on ListingMode {
  String get label => switch (this) {
    ListingMode.buy => 'Buy',
    ListingMode.rent => 'Rent',
    ListingMode.developments => 'Developments',
    ListingMode.commercial => 'Commercial',
  };

  IconData get icon => switch (this) {
    ListingMode.buy => Icons.sell_outlined,
    ListingMode.rent => Icons.key_outlined,
    ListingMode.developments => Icons.apartment_outlined,
    ListingMode.commercial => Icons.store_mall_directory_outlined,
  };
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
  });

  final String id;
  final String name;
  final String agency;
  final String email;
  final String phone;
  final String avatarUrl;
  final double rating;
  final String responseTime;
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
  });

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
