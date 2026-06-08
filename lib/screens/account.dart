import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/auth.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'agent_profile.dart';
import 'auth.dart';
import 'saved_searches.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agents = ref.watch(agentsProvider);
    final favCount = ref.watch(favouritesProvider).length;
    final searchCount = ref.watch(savedSearchesProvider).length;
    final configured = ref.watch(supabaseConfiguredProvider);
    final supabaseUser = ref.watch(currentUserProvider);
    final remoteProfile = ref.watch(profileProvider).valueOrNull;
    final localProfile = ref.watch(userProfileProvider);
    final isSignedIn = supabaseUser != null;

    final display = isSignedIn
        ? UserProfile(
            name: remoteProfile?.name ??
                supabaseUser.userMetadata?['full_name']?.toString() ??
                supabaseUser.email?.split('@').first ??
                'You',
            email: remoteProfile?.email ?? supabaseUser.email ?? '',
            phone: remoteProfile?.phone ?? '',
            preferredCity: remoteProfile?.preferredCity ?? 'Sandton',
            role: remoteProfile?.role ?? 'buyer',
            avatar: remoteProfile?.avatar,
          )
        : localProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          if (isSignedIn)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmSignOut(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          GlassCard(
            gradient: AppColors.heroGradient,
            borderColor: AppColors.primary.withValues(alpha: 0.3),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(display.name),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        display.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        display.email.isEmpty
                            ? (isSignedIn ? 'Signed in' : 'Browsing as guest')
                            : display.email,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TrustBadge(
                            label: isSignedIn ? 'SIGNED IN' : 'GUEST',
                            icon: isSignedIn
                                ? Icons.verified_user
                                : Icons.person_outline,
                            color: isSignedIn
                                ? AppColors.primary
                                : AppColors.warning,
                          ),
                          const TrustBadge(
                            label: 'FICA READY',
                            icon: Icons.shield_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!isSignedIn)
            GlassCard(
              borderColor: AppColors.primary.withValues(alpha: 0.4),
              onTap: () => _openAuth(context),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGlow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.login, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign in or create an account',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sync favourites, set push alerts and message agents.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          if (!isSignedIn) const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatBlock(label: 'Saved homes', value: '$favCount'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Active alerts',
                  value: '$searchCount',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBlock(
                  label: 'Preferred',
                  value: display.preferredCity,
                  small: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Inbox & alerts'),
          const SizedBox(height: 10),
          _LinkTile(
            icon: Icons.notifications_active_outlined,
            label: 'Saved searches & alerts',
            trailing: '$searchCount',
            onTap: () => _requireSignIn(
              context,
              ref,
              onSignedIn: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedSearchesScreen()),
              ),
            ),
          ),
          _LinkTile(
            icon: Icons.message_outlined,
            label: 'Conversations with agents',
            trailing: '${agents.length}',
            onTap: () => _requireSignIn(
              context,
              ref,
              onSignedIn: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Conversations are coming soon.'),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Trusted agents',
            subtitle: 'Independent PPRA-registered partners',
          ),
          const SizedBox(height: 12),
          ...agents.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AgentProfileScreen(agent: a),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.surfaceHigh,
                      backgroundImage: NetworkImage(a.avatar),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            a.area,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatPill(
                      icon: Icons.star_rate_rounded,
                      label: a.rating.toStringAsFixed(1),
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Preferences'),
          const SizedBox(height: 10),
          _LinkTile(
            icon: Icons.security_outlined,
            label: 'Privacy & POPIA consent',
            onTap: () {},
          ),
          _LinkTile(
            icon: Icons.payments_outlined,
            label: 'Bond originator partners',
            onTap: () {},
          ),
          _LinkTile(
            icon: Icons.help_outline,
            label: 'Help & contact',
            onTap: () {},
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderColor: (configured ? AppColors.primary : AppColors.warning)
                .withValues(alpha: 0.3),
            child: Row(
              children: [
                Icon(
                  configured ? Icons.cloud_done : Icons.cloud_off,
                  color: configured ? AppColors.primary : AppColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    configured
                        ? 'Connected to Supabase — live listings, leads & alerts.'
                        : 'Demo mode — Supabase keys not configured. Bond, transfer and search all work locally.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAuth(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  Future<void> _requireSignIn(
    BuildContext context,
    WidgetRef ref, {
    required VoidCallback onSignedIn,
  }) async {
    final configured = ref.read(supabaseConfiguredProvider);
    if (!configured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sign-in is unavailable in demo mode. Add Supabase keys first.',
          ),
        ),
      );
      return;
    }

    if (!ref.read(isSignedInProvider)) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
      if (!context.mounted) return;
      if (!ref.read(isSignedInProvider)) return;
    }

    onSignedIn();
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?'),
        content: const Text(
          'You will be returned to demo mode until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider).signOut();
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return 'U';
    return parts.take(2).map((s) => s[0].toUpperCase()).join();
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    this.small = false,
  });
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: small ? 14 : 22,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
