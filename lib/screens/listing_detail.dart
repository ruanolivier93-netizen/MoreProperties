import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/calculators.dart';
import '../core/currency.dart';
import '../core/haptics.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auth.dart';
import '../theme.dart';
import '../widgets/listing_map.dart';
import '../widgets/widgets.dart';
import 'agent_profile.dart';
import 'bond_calculator.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final PropertyListing listing;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  int _galleryIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(repositoryProvider);
      repo?.recordListingView(listingId: widget.listing.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.listing;
    final agent = findAgent(ref, l.agentId);
    final favourites = ref.watch(favouritesProvider);
    final inCompare = ref.watch(compareProvider).contains(l.id);
    final isFav = favourites.contains(l.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(
                images: l.allImages,
                onPage: (i) => setState(() => _galleryIndex = i),
                pageIndex: _galleryIndex,
                heroTagBuilder: (i) =>
                    i == 0 ? 'list-${l.id}' : 'gal-${l.id}-$i',
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share),
                onPressed: () => Share.share(
                  '${l.title} — ${ZAR.format(l.price)} in ${l.fullLocation}. View on More Properties.',
                ),
              ),
              IconButton(
                tooltip: isFav ? 'Saved' : 'Save',
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? AppColors.primary : Colors.white,
                ),
                onPressed: () =>
                    ref.read(favouritesProvider.notifier).toggle(l.id),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverList.list(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TrustBadge(
                          label: l.mode.shortLabel.toUpperCase(),
                          icon: l.mode.icon,
                          color: AppColors.primarySoft,
                        ),
                        const SizedBox(width: 6),
                        if (l.isFeatured)
                          const TrustBadge(
                            label: 'FEATURED',
                            icon: Icons.bolt_rounded,
                          ),
                        const SizedBox(width: 6),
                        if (l.eaabRegistered)
                          const TrustBadge(
                            label: 'PPRA',
                            icon: Icons.verified_user_outlined,
                            color: AppColors.info,
                          ),
                        const SizedBox(width: 6),
                        if (l.popi)
                          const TrustBadge(
                            label: 'POPIA',
                            icon: Icons.lock_outline,
                            color: AppColors.warning,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l.regionLine,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        PriceTag(listing: l, fontSize: 26),
                        const Spacer(),
                        Text(
                          'Listed ${DateFormat.MMMd().format(l.publishedAt)}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (l.mode == ListingMode.buy)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Indicative bond from ${ZAR.format(SaCalculators.monthlyBondRepayment(principal: l.price.toDouble() * 0.9, interestPctAnnual: SaCalculators.primeRate, years: 20))} pm',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _StatsGrid(listing: l),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ScoresCard(listing: l),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _DescriptionCard(text: l.description),
              ),
              if (l.latitude != null && l.longitude != null) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LocationCard(listing: l),
                ),
              ],
              const SizedBox(height: 18),
              if (l.resilienceFeatures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AmenitiesCard(
                    title: 'Load shedding ready',
                    icon: Icons.bolt_rounded,
                    color: AppColors.primary,
                    items: l.resilienceFeatures,
                  ),
                ),
              if (l.securityFeatures.isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AmenitiesCard(
                    title: 'Security',
                    icon: Icons.shield_outlined,
                    color: AppColors.info,
                    items: l.securityFeatures,
                  ),
                ),
              ],
              if (l.lifestyleFeatures.isNotEmpty) ...[
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AmenitiesCard(
                    title: 'Lifestyle',
                    icon: Icons.spa_outlined,
                    color: AppColors.warning,
                    items: l.lifestyleFeatures,
                  ),
                ),
              ],
              if (l.mode == ListingMode.buy) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CostsCard(listing: l),
                ),
              ],
              const SizedBox(height: 18),
              if (agent != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AgentCard(agent: agent),
                ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _CompareToggle(
                  inCompare: inCompare,
                  onTap: () {
                    final ok = ref.read(compareProvider.notifier).toggle(l.id);
                    if (!ok && !inCompare) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Compare is limited to 3 listings'),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(height: 140),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calculate_outlined),
                  label: const Text('Bond'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BondCalculatorScreen(
                        initialPrice: l.price.toDouble(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('View'),
                  onPressed: () => _showViewingSheet(context, l, agent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Enquire'),
                  onPressed: () => _showEnquireSheet(context, l, agent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEnquireSheet(
    BuildContext context,
    PropertyListing l,
    Agent? agent,
  ) {
    final user = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email);
    final messageCtrl = TextEditingController(
      text:
          "Hi${agent != null ? ' ${agent.name.split(' ').first}' : ''}, I'd like more information on ${l.title} in ${l.suburb}. Please call me back.",
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text(
                      'Send enquiry',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: messageCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Message'),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                          onPressed: agent == null
                              ? null
                              : () => launchUrl(
                                  Uri.parse(
                                    'tel:${agent.phone.replaceAll(' ', '')}',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp'),
                          onPressed: agent == null
                              ? null
                              : () {
                                  final phone = agent.phone.replaceAll(
                                    RegExp(r'[^0-9]'),
                                    '',
                                  );
                                  launchUrl(
                                    Uri.parse(
                                      'https://wa.me/$phone?text=${Uri.encodeComponent(messageCtrl.text)}',
                                    ),
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: () async {
                      AppHaptics.light();
                      final repo = ref.read(repositoryProvider);
                      final supabaseUser = ref.read(currentUserProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      final sheetNavigator = Navigator.of(sheetContext);
                      sheetNavigator.pop();
                      try {
                        await repo?.submitLead(
                          userId: supabaseUser?.id,
                          listingId: l.id,
                          agentId: agent?.id,
                          name: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          message: messageCtrl.text.trim(),
                        );
                      } catch (_) {
                        // Lead is best-effort; demo mode falls through silently.
                      }
                      AppHaptics.success();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            agent != null
                                ? 'Enquiry sent to ${agent.name}. They typically respond in ${agent.responseMinutes} min.'
                                : 'Enquiry sent.',
                          ),
                        ),
                      );
                    },
                    child: const Text('Send enquiry'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'By sending, you agree to share these details under the agent\'s POPIA notice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textFaint, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showViewingSheet(
    BuildContext context,
    PropertyListing listing,
    Agent? agent,
  ) {
    final user = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    final emailCtrl = TextEditingController(text: user.email);
    final notesCtrl = TextEditingController(
      text: 'I would like to view ${listing.title}.',
    );
    var selectedDate = DateTime.now().add(const Duration(days: 1));
    var selectedTime = const TimeOfDay(hour: 10, minute: 0);
    var saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final requestedFor = DateTime(
              selectedDate.year,
              selectedDate.month,
              selectedDate.day,
              selectedTime.hour,
              selectedTime.minute,
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Center(
                        child: Text(
                          'Request a viewing',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        listing.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                DateFormat('EEE, d MMM').format(selectedDate),
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(
                                          const Duration(days: 60),
                                        ),
                                        initialDate: selectedDate,
                                        builder: (context, child) => Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: Theme.of(context)
                                                .colorScheme
                                                .copyWith(
                                                  primary: AppColors.primary,
                                                ),
                                          ),
                                          child: child!,
                                        ),
                                      );
                                      if (picked != null) {
                                        setSheetState(
                                          () => selectedDate = picked,
                                        );
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.schedule_outlined),
                              label: Text(selectedTime.format(context)),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: selectedTime,
                                      );
                                      if (picked != null) {
                                        setSheetState(
                                          () => selectedTime = picked,
                                        );
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Mobile'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.black,
                                ),
                              )
                            : const Icon(Icons.event_available_outlined),
                        label: Text(
                          saving
                              ? 'Requesting…'
                              : 'Request ${DateFormat('EEE d MMM').format(requestedFor)}',
                        ),
                        onPressed: saving
                            ? null
                            : () async {
                                AppHaptics.light();
                                final repo = ref.read(repositoryProvider);
                                final supabaseUser = ref.read(
                                  currentUserProvider,
                                );
                                final messenger = ScaffoldMessenger.of(context);
                                final sheetNavigator = Navigator.of(
                                  sheetContext,
                                );
                                setSheetState(() => saving = true);
                                try {
                                  await repo?.requestViewing(
                                    userId: supabaseUser?.id,
                                    listing: listing,
                                    agent: agent,
                                    name: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    phone: phoneCtrl.text.trim(),
                                    requestedFor: requestedFor,
                                    notes: notesCtrl.text.trim(),
                                  );
                                  if (!mounted) return;
                                  sheetNavigator.pop();
                                  AppHaptics.success();
                                  if (!context.mounted) return;
                                  await showSuccessPulse(
                                    context,
                                    title: 'Viewing requested',
                                    message: agent == null
                                        ? 'The agent will respond soon.'
                                        : '${agent.name.split(' ').first} can now confirm or suggest another time.',
                                    icon: Icons.event_available_outlined,
                                  );
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        agent == null
                                            ? 'Viewing requested.'
                                            : 'Viewing requested with ${agent.name}.',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  setSheetState(() => saving = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Could not request viewing: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'The agent can confirm, complete or cancel this request from Studio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textFaint,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({
    required this.images,
    required this.onPage,
    required this.pageIndex,
    required this.heroTagBuilder,
  });

  final List<String> images;
  final ValueChanged<int> onPage;
  final int pageIndex;
  final String Function(int) heroTagBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: images.length,
          onPageChanged: onPage,
          itemBuilder: (_, i) => Hero(
            tag: heroTagBuilder(i),
            child: CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              placeholder: (_, _) =>
                  const ColoredBox(color: AppColors.surfaceHigh),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: AppColors.surfaceHigh),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Colors.transparent,
                    Color(0xAA000000),
                  ],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < images.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == pageIndex ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == pageIndex
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.listing});
  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    final stats = <(IconData, String, String)>[
      if (listing.beds > 0) (Icons.bed_outlined, '${listing.beds}', 'Beds'),
      (Icons.bathtub_outlined, '${listing.baths}', 'Baths'),
      (Icons.directions_car_outlined, '${listing.parking}', 'Parking'),
      (Icons.square_foot, '${listing.floorSize}m²', 'Floor'),
      if (listing.erfSize != null)
        (Icons.crop_landscape_outlined, '${listing.erfSize}m²', 'Erf'),
      (Icons.bolt_outlined, listing.energyRating, 'EPC'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (icon, value, label) in stats)
          Container(
            width: (MediaQuery.of(context).size.width - 60) / 3,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ScoresCard extends StatelessWidget {
  const _ScoresCard({required this.listing});
  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.insights, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text(
                'Suburb intelligence',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ScoreBar(
            label: 'Load shedding resilience',
            score: listing.loadSheddingScore,
          ),
          const SizedBox(height: 10),
          ScoreBar(
            label: 'Safety & security',
            score: listing.safetyScore,
            color: AppColors.info,
          ),
          const SizedBox(height: 10),
          ScoreBar(
            label: 'Schools nearby',
            score: listing.schoolScore,
            color: AppColors.warning,
          ),
          const SizedBox(height: 10),
          ScoreBar(
            label: 'Lifestyle & amenities',
            score: listing.lifestyleScore,
            color: AppColors.primarySoft,
          ),
        ],
      ),
    );
  }
}

class _DescriptionCard extends StatefulWidget {
  const _DescriptionCard({required this.text});
  final String text;

  @override
  State<_DescriptionCard> createState() => _DescriptionCardState();
}

class _DescriptionCardState extends State<_DescriptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About this property',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              maxLines: _expanded ? null : 4,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? 'Show less' : 'Read more'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenitiesCard extends StatelessWidget {
  const _AmenitiesCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final i in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: color, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        i,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostsCard extends ConsumerWidget {
  const _CostsCard({required this.listing});
  final PropertyListing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketSnapshotProvider);
    final price = listing.price.toDouble();
    final bond = price * 0.9;
    final costs = SaCalculators.acquisitionCosts(
      purchasePrice: price,
      bondAmount: bond,
      transferDutyBrackets: market.transferDutyBrackets,
    );
    return GlassCard(
      gradient: AppColors.heroGradient,
      borderColor: AppColors.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Estimated acquisition costs',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _row('Transfer duty (${market.transferDutySource})', costs.transferDuty),
          _row('Transfer attorney', costs.transferFee),
          _row('Bond registration', costs.bondRegistration),
          _row('Deeds office', costs.deedsOffice),
          const Divider(height: 22),
          _row('Total once-off', costs.total, emphasise: true),
          const SizedBox(height: 12),
          Text(
            'Assumes 10% deposit · 20-year bond at ${SaCalculators.primeRate.toStringAsFixed(2)}% prime.',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, num value, {bool emphasise = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasise ? Colors.white : AppColors.textSecondary,
                fontWeight: emphasise ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            ZAR.format(value),
            style: TextStyle(
              color: emphasise ? AppColors.primary : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: emphasise ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});
  final Agent agent;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AgentProfileScreen(agent: agent)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surfaceHigh,
            backgroundImage: CachedNetworkImageProvider(agent.avatar),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        agent.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (agent.verified)
                      const Icon(
                        Icons.verified,
                        color: AppColors.primary,
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${agent.agency} · ${agent.area}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    StatPill(
                      icon: Icons.star_rate_rounded,
                      label: agent.rating.toStringAsFixed(1),
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    StatPill(
                      icon: Icons.timer_outlined,
                      label: '${agent.responseMinutes}m',
                      color: AppColors.info,
                      compact: true,
                    ),
                    const SizedBox(width: 6),
                    StatPill(
                      icon: Icons.home_work_outlined,
                      label: '${agent.listingsActive}',
                      color: AppColors.warning,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _CompareToggle extends StatelessWidget {
  const _CompareToggle({required this.inCompare, required this.onTap});
  final bool inCompare;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      borderColor: inCompare ? AppColors.primary : AppColors.outline,
      child: Row(
        children: [
          Icon(
            inCompare ? Icons.compare_arrows : Icons.compare_arrows_outlined,
            color: inCompare ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              inCompare ? 'Added to compare list' : 'Add to compare list',
              style: TextStyle(
                color: inCompare ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.listing});
  final PropertyListing listing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.map_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location · ${listing.suburb}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListingMapView(
            listings: [listing],
            height: 220,
            zoom: 14,
            interactive: false,
          ),
        ],
      ),
    );
  }
}
