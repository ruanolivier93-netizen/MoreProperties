import 'dart:math' as math;

import 'sa_data.dart';

/// South African real-estate maths: bond repayments, transfer duty,
/// bond registration, attorney fees, affordability and rent-vs-buy.
///
/// Brackets are aligned with the 2025/26 SARS transfer duty table
/// and current ooba/bond originator industry guidance.
class SaCalculators {
  /// Standard South African prime lending rate published by SARB.
  /// Update when the MPC moves; defaults are used for app calculators.
  static double _primeRate = SaMarketSnapshot.primeRate;
  static double get primeRate => _primeRate;
  static void setPrimeRate(double value) {
    if (value > 0) _primeRate = value;
  }
  static const double minTermYears = 5;
  static const double maxTermYears = 30;

  /// Monthly bond repayment using the standard amortisation formula.
  /// `interestPctAnnual` is in percent (e.g. 11.75), `years` integer.
  static double monthlyBondRepayment({
    required double principal,
    required double interestPctAnnual,
    required int years,
  }) {
    if (principal <= 0) return 0;
    final n = years * 12;
    final r = interestPctAnnual / 100 / 12;
    if (r == 0) return principal / n;
    return principal * r * math.pow(1 + r, n) / (math.pow(1 + r, n) - 1);
  }

  static double totalBondCost({
    required double principal,
    required double interestPctAnnual,
    required int years,
  }) =>
      monthlyBondRepayment(
        principal: principal,
        interestPctAnnual: interestPctAnnual,
        years: years,
      ) *
      years *
      12;

  /// SARS transfer duty (2025/26). Returns zero for primary tier and is
  /// not payable on VAT-able new developments.
  static double transferDuty(
    double purchasePrice, {
    List<TransferDutyBracket>? brackets,
  }) {
    final dutyBrackets = brackets ?? MarketSnapshotData.fallback().transferDutyBrackets;
    for (final bracket in dutyBrackets) {
      final max = bracket.maxValue;
      final inRange = max == null
          ? purchasePrice >= bracket.minValue
          : purchasePrice >= bracket.minValue && purchasePrice <= max;
      if (inRange) {
        return bracket.calculate(purchasePrice);
      }
    }
    return 0;
  }

  /// Indicative bond registration fee using a published South African
  /// attorneys' tariff guideline. Real quotes vary by firm.
  static double bondRegistrationFee(double bondAmount) {
    final tiers = <(double, double, double)>[
      (500000, 5500, 0),
      (1000000, 7000, 0),
      (2000000, 10500, 0),
      (3000000, 14000, 0),
      (5000000, 21000, 0),
      (10000000, 35000, 0),
    ];
    for (final (cap, base, _) in tiers) {
      if (bondAmount <= cap) return base;
    }
    // Above R10m: scale linearly.
    return 35000 + (bondAmount - 10000000) * 0.0025;
  }

  /// Indicative transfer (conveyancing) attorney fee.
  static double transferAttorneyFee(double purchasePrice) {
    final tiers = <(double, double)>[
      (500000, 9500),
      (1000000, 13500),
      (2000000, 19500),
      (3000000, 27000),
      (5000000, 40000),
      (10000000, 64000),
    ];
    for (final (cap, base) in tiers) {
      if (purchasePrice <= cap) return base;
    }
    return 64000 + (purchasePrice - 10000000) * 0.004;
  }

  /// Deeds office registration fee — flat indicative amount per slab.
  static double deedsOfficeFee(double purchasePrice) {
    if (purchasePrice <= 500000) return 700;
    if (purchasePrice <= 1000000) return 1000;
    if (purchasePrice <= 2000000) return 1400;
    if (purchasePrice <= 5000000) return 1700;
    return 2200;
  }

  /// Total once-off cost of acquiring a property (excluding deposit).
  static CostBreakdown acquisitionCosts({
    required double purchasePrice,
    required double bondAmount,
    List<TransferDutyBracket>? transferDutyBrackets,
  }) {
    final duty = transferDuty(
      purchasePrice,
      brackets: transferDutyBrackets,
    );
    final transfer = transferAttorneyFee(purchasePrice);
    final bondReg = bondRegistrationFee(bondAmount);
    final deeds = deedsOfficeFee(purchasePrice);
    return CostBreakdown(
      transferDuty: duty,
      transferFee: transfer,
      bondRegistration: bondReg,
      deedsOffice: deeds,
    );
  }

  /// Banks typically qualify a buyer up to 30% of gross monthly income
  /// for the bond instalment. We subtract other monthly debt commitments.
  static AffordabilityResult affordability({
    required double grossMonthlyIncome,
    required double monthlyExpenses,
    required double monthlyDebt,
    double? interestPctAnnual,
    int years = 20,
    double maxBondRatio = 0.30,
  }) {
    final rate = interestPctAnnual ?? primeRate;
    final qualifyingInstalment =
        (grossMonthlyIncome * maxBondRatio) - monthlyDebt;
    final available =
        qualifyingInstalment.clamp(0, double.infinity).toDouble();
    final n = years * 12;
    final r = rate / 100 / 12;
    double maxBond = 0;
    if (r > 0) {
      maxBond = available *
          (math.pow(1 + r, n) - 1) /
          (r * math.pow(1 + r, n));
    } else if (r == 0) {
      maxBond = available * n;
    }
    final netCashflow = grossMonthlyIncome - monthlyExpenses - monthlyDebt;
    return AffordabilityResult(
      maxBond: maxBond.toDouble(),
      monthlyRepayment: available.toDouble(),
      netCashflow: netCashflow,
    );
  }

  /// Naive rent-vs-buy compare over `years`. Returns the wealth delta
  /// of buying vs renting assuming the deposit was otherwise invested.
  static RentVsBuyResult rentVsBuy({
    required double purchasePrice,
    required double deposit,
    required double monthlyRent,
    double? interestPctAnnual,
    int years = 10,
    double propertyAppreciationPct = 6,
    double rentEscalationPct = 7,
    double investmentReturnPct = 9,
  }) {
    final rate = interestPctAnnual ?? primeRate;
    final bond = purchasePrice - deposit;
    final monthly = monthlyBondRepayment(
      principal: bond,
      interestPctAnnual: rate,
      years: 20,
    );
    final months = years * 12;
    final futureValueProperty =
        purchasePrice * math.pow(1 + propertyAppreciationPct / 100, years);
    // Outstanding bond after `years` of payments on a 20-year amortisation.
    final r = rate / 100 / 12;
    final remainingMonths = (20 - years) * 12;
    double outstandingBond = 0;
    if (r > 0 && remainingMonths > 0) {
      outstandingBond = monthly *
          (1 - math.pow(1 + r, -remainingMonths)) /
          r;
    }
    final buyEquity = futureValueProperty - outstandingBond;

    // Rent scenario: deposit invested, plus the monthly difference between
    // bond payment and rent (if positive) also invested.
    double portfolio = deposit;
    double currentRent = monthlyRent;
    final monthlyReturn = investmentReturnPct / 100 / 12;
    final escalationMonthly = rentEscalationPct / 100 / 12;
    for (var m = 1; m <= months; m++) {
      portfolio *= (1 + monthlyReturn);
      final diff = monthly - currentRent;
      if (diff > 0) {
        portfolio += diff;
        portfolio *= (1 + monthlyReturn);
      }
      currentRent *= (1 + escalationMonthly);
    }

    return RentVsBuyResult(
      buyEquity: buyEquity.toDouble(),
      rentPortfolio: portfolio,
      monthlyBond: monthly,
    );
  }
}

class CostBreakdown {
  const CostBreakdown({
    required this.transferDuty,
    required this.transferFee,
    required this.bondRegistration,
    required this.deedsOffice,
  });

  final double transferDuty;
  final double transferFee;
  final double bondRegistration;
  final double deedsOffice;

  double get total =>
      transferDuty + transferFee + bondRegistration + deedsOffice;
}

class AffordabilityResult {
  const AffordabilityResult({
    required this.maxBond,
    required this.monthlyRepayment,
    required this.netCashflow,
  });

  final double maxBond;
  final double monthlyRepayment;
  final double netCashflow;
}

class RentVsBuyResult {
  const RentVsBuyResult({
    required this.buyEquity,
    required this.rentPortfolio,
    required this.monthlyBond,
  });

  final double buyEquity;
  final double rentPortfolio;
  final double monthlyBond;

  double get delta => buyEquity - rentPortfolio;
}
