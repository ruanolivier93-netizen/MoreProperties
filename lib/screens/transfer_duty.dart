import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calculators.dart';
import '../core/sa_data.dart';
import '../core/currency.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

class TransferDutyScreen extends ConsumerStatefulWidget {
  const TransferDutyScreen({super.key, this.initialPrice});

  final double? initialPrice;

  @override
  ConsumerState<TransferDutyScreen> createState() => _TransferDutyScreenState();
}

class _TransferDutyScreenState extends ConsumerState<TransferDutyScreen> {
  late double _price;
  double _depositPct = 10;

  @override
  void initState() {
    super.initState();
    _price = widget.initialPrice ?? 2500000;
  }

  @override
  Widget build(BuildContext context) {
    final market = ref.watch(marketSnapshotProvider);
    final deposit = _price * _depositPct / 100;
    final bond = _price - deposit;
    final costs = SaCalculators.acquisitionCosts(
      purchasePrice: _price,
      bondAmount: bond,
      transferDutyBrackets: market.transferDutyBrackets,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer duty & costs')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          GlassCard(
            gradient: AppColors.heroGradient,
            borderColor: AppColors.primary.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL ONCE-OFF COSTS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ZAR.format(costs.total),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Excluding the ${ZAR.compact(deposit)} deposit on a ${ZAR.compact(_price)} property',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _slider(
            label: 'Purchase price',
            value: ZAR.compact(_price),
            slider: Slider(
              value: _price,
              min: 250000,
              max: 50000000,
              divisions: 200,
              onChanged: (v) => setState(() => _price = v.roundToDouble()),
            ),
          ),
          _slider(
            label: 'Deposit',
            value: '${_depositPct.toStringAsFixed(0)}% · ${ZAR.compact(deposit)}',
            slider: Slider(
              value: _depositPct,
              min: 0,
              max: 50,
              divisions: 50,
              onChanged: (v) => setState(() => _depositPct = v),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Breakdown (estimate)',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                _row(
                  'Transfer duty (${market.transferDutyEffectiveLabel})',
                  costs.transferDuty,
                ),
                _row('Transfer attorney fee (indicative)', costs.transferFee),
                _row('Bond registration fee (indicative)', costs.bondRegistration),
                _row('Deeds office fee (indicative)', costs.deedsOffice),
                const Divider(height: 24),
                _row('Total', costs.total, emphasise: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 16),
                    SizedBox(width: 8),
                    Text(
                      '${market.transferDutySource} brackets',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final bracket in market.transferDutyBrackets)
                  _bracket(_rangeLabel(bracket), _ruleLabel(bracket)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Transfer duty uses ${market.transferDutySource} (${market.transferDutyEffectiveLabel}). Attorney, bond registration and deeds amounts are indicative and may differ by firm, VAT and disbursements. Transfer duty is not payable on VAT-inclusive new developments.',
            style: const TextStyle(color: AppColors.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _slider({
    required String label,
    required String value,
    required Widget slider,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          slider,
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
              fontSize: emphasise ? 17 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bracket(String range, String rule) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              range,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              rule,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _rangeLabel(TransferDutyBracket bracket) {
    if (bracket.marginalRate == 0) {
      return 'Up to ${ZAR.compact(bracket.threshold)}';
    }
    if (bracket.maxValue == null) {
      return '${ZAR.compact(bracket.minValue)} +';
    }
    return '${ZAR.compact(bracket.minValue)} – ${ZAR.compact(bracket.maxValue!)}';
  }

  String _ruleLabel(TransferDutyBracket bracket) {
    final pct = (bracket.marginalRate * 100).toStringAsFixed(0);
    if (bracket.marginalRate == 0) return 'No duty payable';
    if (bracket.baseAmount == 0) {
      return '$pct% on amount above ${ZAR.compact(bracket.threshold)}';
    }
    return '${ZAR.format(bracket.baseAmount)} + $pct% on excess';
  }
}
