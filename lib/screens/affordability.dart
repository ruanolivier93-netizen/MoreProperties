import 'package:flutter/material.dart';

import '../core/calculators.dart';
import '../core/currency.dart';
import '../theme.dart';
import '../widgets/widgets.dart';

class AffordabilityScreen extends StatefulWidget {
  const AffordabilityScreen({super.key});

  @override
  State<AffordabilityScreen> createState() => _AffordabilityScreenState();
}

class _AffordabilityScreenState extends State<AffordabilityScreen> {
  double _income = 45000;
  double _expenses = 18000;
  double _debt = 6500;
  double _rate = SaCalculators.primeRate;
  int _term = 20;

  @override
  Widget build(BuildContext context) {
    final result = SaCalculators.affordability(
      grossMonthlyIncome: _income,
      monthlyExpenses: _expenses,
      monthlyDebt: _debt,
      interestPctAnnual: _rate,
      years: _term,
    );
    final healthy = result.netCashflow > result.monthlyRepayment;

    return Scaffold(
      appBar: AppBar(title: const Text('Affordability')),
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
                  'MAXIMUM QUALIFYING BOND',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ZAR.format(result.maxBond.clamp(0, double.infinity)),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Monthly instalment of ${ZAR.format(result.monthlyRepayment)} pm',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _slider(
            'Gross monthly income',
            ZAR.format(_income),
            Slider(
              value: _income,
              min: 5000,
              max: 500000,
              divisions: 200,
              onChanged: (v) => setState(() => _income = v.roundToDouble()),
            ),
          ),
          _slider(
            'Monthly living expenses',
            ZAR.format(_expenses),
            Slider(
              value: _expenses,
              min: 0,
              max: _income,
              divisions: 100,
              onChanged: (v) => setState(() => _expenses = v.roundToDouble()),
            ),
          ),
          _slider(
            'Other monthly debt',
            ZAR.format(_debt),
            Slider(
              value: _debt,
              min: 0,
              max: _income / 2,
              divisions: 100,
              onChanged: (v) => setState(() => _debt = v.roundToDouble()),
            ),
          ),
          _slider(
            'Interest rate',
            '${_rate.toStringAsFixed(2)}%',
            Slider(
              value: _rate,
              min: 6,
              max: 18,
              divisions: 120,
              onChanged: (v) => setState(() => _rate = v),
            ),
          ),
          _slider(
            'Term',
            '$_term years',
            Slider(
              value: _term.toDouble(),
              min: SaCalculators.minTermYears,
              max: SaCalculators.maxTermYears,
              divisions: 25,
              onChanged: (v) => setState(() => _term = v.round()),
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            borderColor: healthy
                ? AppColors.primary.withValues(alpha: 0.3)
                : AppColors.danger.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      healthy ? Icons.thumb_up_alt_outlined : Icons.warning_amber,
                      color: healthy ? AppColors.primary : AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      healthy
                          ? 'Looking healthy — your cashflow comfortably covers this instalment.'
                          : 'Tight squeeze — the bond instalment would consume most of your free cash.',
                      style: TextStyle(
                        color: healthy ? AppColors.primary : AppColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _statRow(
                  'Free cashflow / month',
                  ZAR.format(result.netCashflow.clamp(0, double.infinity)),
                ),
                _statRow(
                  'Bond instalment / month',
                  ZAR.format(result.monthlyRepayment),
                ),
                _statRow(
                  'Buffer after bond',
                  ZAR.format(
                    (result.netCashflow - result.monthlyRepayment)
                        .clamp(0, double.infinity),
                  ),
                  emphasise: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Banks apply additional checks — credit score, tenure, retirement age and deposit. Use this as a starting point.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _slider(String label, String value, Widget slider) {
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
