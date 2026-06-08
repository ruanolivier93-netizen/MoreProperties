import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';
import 'affordability.dart';
import 'bond_calculator.dart';
import 'transfer_duty.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final market = ref.watch(marketSnapshotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TrustBadge(
              label: 'PRIME ${market.primeRate.toStringAsFixed(2)}%',
              icon: Icons.percent,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const SectionHeader(
            title: 'Plan your purchase',
            subtitle: 'SA-specific calculators built on SARS & SARB data',
          ),
          const SizedBox(height: 16),
          _ToolTile(
            icon: Icons.calculate_rounded,
            color: AppColors.primary,
            title: 'Bond repayment',
            subtitle:
                'Monthly instalment, total interest, amortisation breakdown.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BondCalculatorScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolTile(
            icon: Icons.receipt_long_rounded,
            color: AppColors.info,
            title: 'Transfer duty & costs',
            subtitle:
                'SARS 2025/26 brackets + attorney, bond reg & deeds office fees.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TransferDutyScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ToolTile(
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.warning,
            title: 'Affordability check',
            subtitle: 'Banks qualify ~30% of gross income — see your max bond.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AffordabilityScreen()),
            ),
          ),
          const SizedBox(height: 26),
          const SectionHeader(
            title: 'Stay informed',
            subtitle: 'Live SA market & regulation context',
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.policy_outlined, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'POPIA & PPRA at a glance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Every enquiry on More Properties is routed to a PPRA registered agent and processed under POPIA — only the information you choose is shared, and you can revoke consent at any time.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    TrustBadge(
                      label: 'PPRA REGISTERED',
                      icon: Icons.verified_user_outlined,
                      color: AppColors.info,
                    ),
                    TrustBadge(
                      label: 'POPIA COMPLIANT',
                      icon: Icons.lock_outline,
                      color: AppColors.warning,
                    ),
                    TrustBadge(
                      label: 'FICA SAFEGUARDED',
                      icon: Icons.shield_outlined,
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

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    );
  }
}
