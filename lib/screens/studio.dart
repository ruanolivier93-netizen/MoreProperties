import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/currency.dart';
import '../core/haptics.dart';
import '../models/models.dart';
import '../state/auth.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'listing_editor.dart';
import 'listing_detail.dart';

/// Async snapshot of the data an agent's dashboard needs.
class StudioSnapshot {
  const StudioSnapshot({
    required this.listings,
    required this.leads,
    required this.appointments,
    required this.viewsLast30,
  });
  final List<PropertyListing> listings;
  final List<AgentLead> leads;
  final List<ViewingAppointment> appointments;
  final int viewsLast30;
}

final studioSnapshotProvider = FutureProvider.autoDispose<StudioSnapshot?>((
  ref,
) async {
  final repo = ref.watch(repositoryProvider);
  final agent = ref.watch(myAgentProvider).valueOrNull;
  if (repo == null || agent == null) return null;
  final since = DateTime.now().subtract(const Duration(days: 30));

  final listings = await repo.fetchListingsForAgent(agent.id);
  final leads = await repo.fetchLeadsForAgent(agent.id);
  final appointments = await repo.fetchAppointmentsForAgent(agent.id);

  // Sum views across the agent's listings in the last 30 days.
  final viewCounts = await Future.wait([
    for (final l in listings)
      repo.countListingViews(listingId: l.id, since: since),
  ]);
  final totalViews = viewCounts.fold<int>(0, (sum, v) => sum + v);

  return StudioSnapshot(
    listings: listings,
    leads: leads,
    appointments: appointments,
    viewsLast30: totalViews,
  );
});

class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agent = ref.watch(myAgentProvider).valueOrNull;
    final snapshotAsync = ref.watch(studioSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent studio'),
        actions: [
          if (agent != null)
            IconButton(
              tooltip: 'New listing',
              icon: const Icon(Icons.add_home_work_outlined),
              onPressed: () async {
                AppHaptics.tap();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingEditorScreen(agent: agent),
                  ),
                );
                ref.invalidate(studioSnapshotProvider);
              },
            ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(studioSnapshotProvider),
          ),
        ],
      ),
      body: agent == null
          ? const EmptyState(
              icon: Icons.shield_outlined,
              title: 'Studio is for verified agents',
              subtitle:
                  'Your sign-in is not linked to an agent record. Ask the More Properties team to upgrade your account.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(studioSnapshotProvider);
                await ref.read(studioSnapshotProvider.future);
              },
              child: snapshotAsync.when(
                loading: () => const StudioSkeleton(),
                error: (e, _) => EmptyState(
                  icon: Icons.error_outline,
                  title: 'Could not load Studio',
                  subtitle: e.toString(),
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(studioSnapshotProvider),
                ),
                data: (snapshot) => snapshot == null
                    ? const SizedBox.shrink()
                    : _StudioBody(agent: agent, snapshot: snapshot),
              ),
            ),
    );
  }
}

class _StudioBody extends ConsumerWidget {
  const _StudioBody({required this.agent, required this.snapshot});
  final Agent agent;
  final StudioSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = snapshot.listings.where((l) => l.isLive).length;
    final newLeads = snapshot.leads.where((l) => l.status == 'new').length;
    final requestedViewings = snapshot.appointments
        .where((a) => a.status == 'requested')
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        GlassCard(
          gradient: AppColors.heroGradient,
          borderColor: AppColors.primary.withValues(alpha: 0.35),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceHigh,
                backgroundImage: CachedNetworkImageProvider(agent.avatar),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agent.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      agent.area,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    if (agent.ppraNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TrustBadge(
                          label: agent.ppraNumber!,
                          icon: Icons.verified_user_outlined,
                          color: AppColors.info,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _Stat(
                label: 'Listings',
                value: '${snapshot.listings.length}',
                tag: '$activeCount active',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                label: 'Leads',
                value: '${snapshot.leads.length}',
                tag: '$newLeads new',
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stat(
                label: 'Viewings',
                value: '${snapshot.appointments.length}',
                tag: '$requestedViewings requested',
                color: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${snapshot.viewsLast30} listing views in the last 30 days',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'Viewing appointments',
          subtitle: 'Confirm, complete or cancel buyer requests',
        ),
        const SizedBox(height: 12),
        if (snapshot.appointments.isEmpty)
          const EmptyStateCard(
            icon: Icons.event_available_outlined,
            title: 'No viewing requests yet',
            subtitle:
                'When buyers request a time, it appears here with quick confirm, complete and cancel actions.',
            color: AppColors.warning,
          )
        else ...[
          for (final appointment in snapshot.appointments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AppointmentTile(
                appointment: appointment,
                onStatusChanged: (next) => _updateAppointmentStatus(
                  context,
                  ref,
                  appointment.id,
                  next,
                ),
              ),
            ),
        ],
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'Lead pipeline',
          subtitle: 'Move every enquiry to the next stage',
        ),
        const SizedBox(height: 12),
        if (snapshot.leads.isEmpty)
          const EmptyStateCard(
            icon: Icons.forum_outlined,
            title: 'No leads yet',
            subtitle:
                'Publish and share your active listings. Enquiries will arrive here with call, WhatsApp and email actions.',
            color: AppColors.info,
          )
        else ...[
          for (final lead in snapshot.leads)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeadTile(
                lead: lead,
                listing: _findListing(snapshot.listings, lead.listingId),
                onStatusChanged: (next) => _updateStatus(ref, lead.id, next),
              ),
            ),
        ],
        const SizedBox(height: 22),
        SectionHeader(
          title: 'My listings',
          subtitle: 'Create, edit and move stock through the sales workflow',
          trailing: FilledButton.icon(
            onPressed: () async {
              AppHaptics.tap();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingEditorScreen(agent: agent),
                ),
              );
              ref.invalidate(studioSnapshotProvider);
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('New'),
          ),
        ),
        const SizedBox(height: 12),
        if (snapshot.listings.isEmpty)
          EmptyStateCard(
            icon: Icons.add_home_work_outlined,
            title: 'Create your first listing',
            subtitle:
                'Start as a draft, upload polished media, then publish once the listing is ready for buyers.',
            actionLabel: 'New listing',
            onAction: () async {
              await AppHaptics.tap();
              if (!context.mounted) return;
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ListingEditorScreen(agent: agent),
                ),
              );
              ref.invalidate(studioSnapshotProvider);
            },
          )
        else ...[
          for (final l in snapshot.listings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudioListingTile(
                listing: l,
                onPreview: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: l),
                  ),
                ),
                onEdit: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ListingEditorScreen(agent: agent, listing: l),
                    ),
                  );
                  ref.invalidate(studioSnapshotProvider);
                },
                onStatusChanged: (status) =>
                    _updateListingStatus(context, ref, l.id, status),
              ),
            ),
        ],
      ],
    );
  }

  PropertyListing? _findListing(
    List<PropertyListing> listings,
    String? listingId,
  ) {
    if (listingId == null) return null;
    for (final l in listings) {
      if (l.id == listingId) return l;
    }
    return null;
  }

  Future<void> _updateStatus(
    WidgetRef ref,
    String leadId,
    String status,
  ) async {
    final repo = ref.read(repositoryProvider);
    if (repo == null) return;
    try {
      await repo.updateLeadStatus(leadId: leadId, status: status);
      ref.invalidate(studioSnapshotProvider);
    } catch (_) {
      // Silent — UI will show stale state until next refresh.
    }
  }

  Future<void> _updateListingStatus(
    BuildContext context,
    WidgetRef ref,
    String listingId,
    ListingStatus status,
  ) async {
    final repo = ref.read(repositoryProvider);
    if (repo == null) return;
    try {
      AppHaptics.light();
      await repo.updateListingStatus(
        listingId: listingId,
        status: status.dbValue,
      );
      ref.invalidate(studioSnapshotProvider);
      if (!context.mounted) return;
      AppHaptics.success();
      await showSuccessPulse(
        context,
        title: 'Listing updated',
        message: 'Moved to ${status.label}.',
        icon: status.icon,
      );
    } catch (_) {}
  }

  Future<void> _updateAppointmentStatus(
    BuildContext context,
    WidgetRef ref,
    String appointmentId,
    String status,
  ) async {
    final repo = ref.read(repositoryProvider);
    if (repo == null) return;
    try {
      AppHaptics.light();
      await repo.updateAppointmentStatus(
        appointmentId: appointmentId,
        status: status,
      );
      ref.invalidate(studioSnapshotProvider);
      if (!context.mounted) return;
      AppHaptics.success();
      await showSuccessPulse(
        context,
        title: appointmentStatusLabel(status),
        message: 'Viewing appointment updated successfully.',
        icon: Icons.event_available_outlined,
      );
    } catch (_) {}
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.tag,
    required this.color,
  });

  final String label;
  final String value;
  final String tag;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      borderColor: color.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            tag,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioListingTile extends StatelessWidget {
  const _StudioListingTile({
    required this.listing,
    required this.onPreview,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final PropertyListing listing;
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  final ValueChanged<ListingStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final color = _listingStatusColor(listing.status);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPreview,
            child: SizedBox(
              width: 84,
              height: 88,
              child: HeroImage(
                url: listing.heroImage,
                heroTag: 'studio-${listing.id}',
                height: 88,
                borderRadius: 12,
                listingId: listing.id,
                showFavourite: false,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        listing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Edit listing',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                  ],
                ),
                Text(
                  listing.regionLine,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: PriceTag(listing: listing, fontSize: 13)),
                    _ListingStatusPicker(
                      status: listing.status,
                      color: color,
                      onChanged: onStatusChanged,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.appointment,
    required this.onStatusChanged,
  });

  final ViewingAppointment appointment;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final color = _appointmentStatusColor(appointment.status);
    final date = DateFormat('EEE, d MMM').format(appointment.requestedFor);
    final time = DateFormat.Hm().format(appointment.requestedFor);
    return GlassCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.event_available_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.leadName ?? 'Viewing request',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      appointment.listingTitle ?? 'Listing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      '$date · $time',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _AppointmentStatusPicker(
                status: appointment.status,
                color: color,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              appointment.notes!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (appointment.leadPhone != null &&
                  appointment.leadPhone!.isNotEmpty) ...[
                _ActionChip(
                  icon: Icons.call,
                  label: 'Call',
                  onTap: () => launchUrl(
                    Uri.parse(
                      'tel:${appointment.leadPhone!.replaceAll(' ', '')}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () {
                    final phone = appointment.leadPhone!.replaceAll(
                      RegExp(r'[^0-9]'),
                      '',
                    );
                    launchUrl(Uri.parse('https://wa.me/$phone'));
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (appointment.leadEmail != null &&
                  appointment.leadEmail!.isNotEmpty)
                _ActionChip(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  onTap: () =>
                      launchUrl(Uri.parse('mailto:${appointment.leadEmail}')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListingStatusPicker extends StatelessWidget {
  const _ListingStatusPicker({
    required this.status,
    required this.color,
    required this.onChanged,
  });

  final ListingStatus status;
  final Color color;
  final ValueChanged<ListingStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ListingStatus>(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final next in ListingStatus.values)
          PopupMenuItem(
            value: next,
            child: Row(
              children: [
                Icon(next.icon, size: 16, color: _listingStatusColor(next)),
                const SizedBox(width: 10),
                Text(next.label, style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
      ],
      child: _StatusPill(icon: status.icon, label: status.label, color: color),
    );
  }
}

class _AppointmentStatusPicker extends StatelessWidget {
  const _AppointmentStatusPicker({
    required this.status,
    required this.color,
    required this.onChanged,
  });

  final String status;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final next in appointmentStatusFlow)
          PopupMenuItem(
            value: next,
            child: Row(
              children: [
                Icon(
                  next == status ? Icons.check : Icons.circle_outlined,
                  size: 15,
                  color: next == status
                      ? AppColors.primary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  appointmentStatusLabel(next),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
      child: _StatusPill(
        icon: Icons.event_available_outlined,
        label: appointmentStatusLabel(status),
        color: color,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

Color _listingStatusColor(ListingStatus status) {
  return switch (status) {
    ListingStatus.draft => AppColors.textMuted,
    ListingStatus.active => AppColors.primary,
    ListingStatus.underOffer => AppColors.warning,
    ListingStatus.sold => AppColors.info,
    ListingStatus.rented => AppColors.info,
    ListingStatus.archived => AppColors.textFaint,
  };
}

Color _appointmentStatusColor(String status) {
  return switch (status) {
    'requested' => AppColors.warning,
    'confirmed' => AppColors.primary,
    'completed' => AppColors.info,
    'cancelled' => AppColors.danger,
    _ => AppColors.textMuted,
  };
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({
    required this.lead,
    required this.listing,
    required this.onStatusChanged,
  });

  final AgentLead lead;
  final PropertyListing? listing;
  final ValueChanged<String> onStatusChanged;

  Color get _statusColor {
    switch (lead.status) {
      case 'new':
        return AppColors.primary;
      case 'contacted':
        return AppColors.info;
      case 'viewing_booked':
        return AppColors.warning;
      case 'qualified':
        return AppColors.primarySoft;
      case 'closed':
        return AppColors.primary;
      case 'lost':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(lead.createdAt);
    final ageLabel = age.inDays > 0
        ? '${age.inDays}d ago'
        : age.inHours > 0
        ? '${age.inHours}h ago'
        : '${age.inMinutes}m ago';
    return GlassCard(
      borderColor: _statusColor.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: Text(
                    lead.name.isEmpty ? '?' : lead.name[0].toUpperCase(),
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    if (listing != null)
                      Text(
                        listing!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    Text(
                      '$ageLabel · ${listing != null ? ZAR.compact(listing!.price) : '—'}',
                      style: const TextStyle(
                        color: AppColors.textFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPicker(
                status: lead.status,
                color: _statusColor,
                onChanged: onStatusChanged,
              ),
            ],
          ),
          if (lead.message != null && lead.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              lead.message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (lead.phone != null && lead.phone!.isNotEmpty) ...[
                _ActionChip(
                  icon: Icons.call,
                  label: 'Call',
                  onTap: () => launchUrl(
                    Uri.parse('tel:${lead.phone!.replaceAll(' ', '')}'),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionChip(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  onTap: () {
                    final phone = lead.phone!.replaceAll(RegExp(r'[^0-9]'), '');
                    launchUrl(Uri.parse('https://wa.me/$phone'));
                  },
                ),
                const SizedBox(width: 8),
              ],
              if (lead.email != null && lead.email!.isNotEmpty)
                _ActionChip(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  onTap: () => launchUrl(Uri.parse('mailto:${lead.email}')),
                ),
              const Spacer(),
              Text(
                DateFormat.MMMd().add_jm().format(lead.createdAt),
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPicker extends StatelessWidget {
  const _StatusPicker({
    required this.status,
    required this.color,
    required this.onChanged,
  });
  final String status;
  final Color color;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 36),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final s in leadStatusFlow)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(
                  s == status ? Icons.check : Icons.circle_outlined,
                  size: 14,
                  color: s == status ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  leadStatusLabel(s),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              leadStatusLabel(status),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: color, size: 16),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
