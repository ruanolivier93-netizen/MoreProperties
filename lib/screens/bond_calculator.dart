import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/calculators.dart';
import '../core/currency.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

class BondCalculatorScreen extends StatefulWidget {
  const BondCalculatorScreen({super.key, this.initialPrice});

  final double? initialPrice;

  @override
  State<BondCalculatorScreen> createState() => _BondCalculatorScreenState();
}

class _BondCalculatorScreenState extends State<BondCalculatorScreen> {
  late double _price;
  double _depositPct = 10;
  double _interest = SaCalculators.primeRate;
  int _years = 20;

  @override
  void initState() {
    super.initState();
    _price = widget.initialPrice ?? 2500000;
  }

  @override
  Widget build(BuildContext context) {
    final deposit = _price * _depositPct / 100;
    final bond = _price - deposit;
    final monthly = SaCalculators.monthlyBondRepayment(
      principal: bond,
      interestPctAnnual: _interest,
      years: _years,
    );
    final total = monthly * _years * 12;
    final interestPaid = total - bond;

    return Scaffold(
      appBar: AppBar(title: const Text('Bond calculator')),
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
                  'MONTHLY INSTALMENT',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ZAR.format(monthly),
                  style: const TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bond ${ZAR.format(bond)} over $_years years @ ${_interest.toStringAsFixed(2)}%',
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
          _slider(
            label: 'Interest rate',
            value: '${_interest.toStringAsFixed(2)}%',
            slider: Slider(
              value: _interest,
              min: 6,
              max: 18,
              divisions: 120,
              onChanged: (v) => setState(() => _interest = v),
            ),
          ),
          _slider(
            label: 'Term',
            value: '$_years years',
            slider: Slider(
              value: _years.toDouble(),
              min: SaCalculators.minTermYears,
              max: SaCalculators.maxTermYears,
              divisions: 25,
              onChanged: (v) => setState(() => _years = v.round()),
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cost split over the bond',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: [
                        PieChartSectionData(
                          color: AppColors.primary,
                          value: bond,
                          title: 'Capital',
                          radius: 70,
                          titleStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        PieChartSectionData(
                          color: AppColors.warning,
                          value: interestPaid,
                          title: 'Interest',
                          radius: 70,
                          titleStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _statRow('Capital repaid', ZAR.format(bond)),
                _statRow('Total interest', ZAR.format(interestPaid)),
                _statRow('Total cost of bond', ZAR.format(total),
                    emphasise: true),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Figures are indicative only. Quotes from ooba, BetterBond and the major banks may differ.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 11),
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

  Widget _statRow(String label, String value, {bool emphasise = false}) {
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
            value,
            style: TextStyle(
              color: emphasise ? AppColors.primary : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: emphasise ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
