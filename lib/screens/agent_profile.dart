import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'listing_detail.dart';

class AgentProfileScreen extends ConsumerWidget {
  const AgentProfileScreen({super.key, required this.agent});

  final Agent agent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref
        .watch(listingsProvider)
        .where((l) => l.agentId == agent.id)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Agent')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            gradient: AppColors.heroGradient,
            borderColor: AppColors.primary.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceHigh,
                      backgroundImage:
                          CachedNetworkImageProvider(agent.avatar),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            agent.agency,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            agent.area,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatPill(
                      icon: Icons.star_rate_rounded,
                      label: agent.rating.toStringAsFixed(1),
                    ),
                    StatPill(
                      icon: Icons.timer_outlined,
                      label: '${agent.responseMinutes} min response',
                      color: AppColors.info,
                    ),
                    StatPill(
                      icon: Icons.home_work_outlined,
                      label: '${agent.listingsActive} active',
                      color: AppColors.warning,
                    ),
                    if (agent.verified)
                      const StatPill(
                        icon: Icons.verified,
                        label: 'Verified',
                        color: AppColors.primarySoft,
                      ),
                  ],
                ),
                if (agent.ppraNumber != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'PPRA: ${agent.ppraNumber}',
                    style: const TextStyle(
                      color: AppColors.textFaint,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  agent.bio,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                        onPressed: () => launchUrl(
                          Uri.parse('tel:${agent.phone.replaceAll(' ', '')}'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.email_outlined),
                        label: const Text('Email'),
                        onPressed: () =>
                            launchUrl(Uri.parse('mailto:${agent.email}')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('Message on WhatsApp'),
                  onPressed: () {
                    final phone =
                        agent.phone.replaceAll(RegExp(r'[^0-9]'), '');
                    launchUrl(Uri.parse('https://wa.me/$phone'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: 'Active listings',
            subtitle: '${listings.length} on the market',
          ),
          const SizedBox(height: 12),
          if (listings.isEmpty)
            const EmptyState(
              icon: Icons.house_outlined,
              title: 'No active listings',
              subtitle: 'This agent has no listings live in the app right now.',
            )
          else
            ...[
              for (final l in listings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ListingCard(
                    listing: l,
                    heroPrefix: 'agt-${agent.id}',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: l),
                      ),
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }
}
