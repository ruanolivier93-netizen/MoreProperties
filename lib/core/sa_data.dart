/// South African geographic reference data used across filters and demo content.
class SaData {
  static const List<String> provinces = [
    'Gauteng',
    'Western Cape',
    'KwaZulu-Natal',
    'Eastern Cape',
    'Free State',
    'Limpopo',
    'Mpumalanga',
    'North West',
    'Northern Cape',
  ];

  /// Province → flagship metros surfaced in the location picker.
  static const Map<String, List<String>> citiesByProvince = {
    'Gauteng': [
      'Johannesburg',
      'Sandton',
      'Pretoria',
      'Centurion',
      'Midrand',
      'Roodepoort',
      'Soweto',
      'Benoni',
    ],
    'Western Cape': [
      'Cape Town',
      'Stellenbosch',
      'Paarl',
      'Somerset West',
      'Hermanus',
      'George',
      'Knysna',
    ],
    'KwaZulu-Natal': [
      'Durban',
      'Umhlanga',
      'Ballito',
      'Pietermaritzburg',
      'Hillcrest',
      'Westville',
    ],
    'Eastern Cape': ['Gqeberha', 'East London', 'Jeffreys Bay', 'Makhanda'],
    'Free State': ['Bloemfontein', 'Welkom', 'Sasolburg'],
    'Limpopo': ['Polokwane', 'Tzaneen', 'Bela-Bela'],
    'Mpumalanga': ['Nelspruit', 'White River', 'Witbank'],
    'North West': ['Rustenburg', 'Potchefstroom', 'Klerksdorp'],
    'Northern Cape': ['Kimberley', 'Upington'],
  };

  /// Lifestyle suburbs frequently featured in demo data.
  static const List<String> featuredSuburbs = [
    'Clifton',
    'Camps Bay',
    'Sandhurst',
    'Hyde Park',
    'Umhlanga Ridge',
    'Waterfall Estate',
    'Bryanston',
    'Constantia',
    'Bishopscourt',
    'Steyn City',
    'Dainfern',
    'Zimbali',
    'Llandudno',
    'Atlantic Seaboard',
  ];

  /// SA listing types — sectional title, freehold, lifestyle estates etc.
  static const List<String> propertyTypes = [
    'Apartment',
    'House',
    'Townhouse',
    'Cluster',
    'Penthouse',
    'Estate Home',
    'Smallholding',
    'Farm',
    'Vacant Land',
    'Industrial',
    'Retail',
    'Office',
  ];

  /// Load-shedding / off-grid amenities that buyers actively filter on.
  static const List<String> resilienceFeatures = [
    'Solar PV',
    'Inverter & batteries',
    'Generator',
    'Gas hob',
    'Gas geyser',
    'Borehole',
    'JoJo tanks',
    'Greywater system',
    'EV charger',
  ];

  /// Security amenities — table-stakes in SA.
  static const List<String> securityFeatures = [
    '24h estate security',
    'Electric fencing',
    'Beams & sensors',
    'Armed response',
    'Boomed-off precinct',
    'Biometric access',
    'CCTV monitored',
  ];

  /// Lifestyle amenities used in filters & detail screens.
  static const List<String> lifestyleFeatures = [
    'Pool',
    'Garden',
    'Sea view',
    'Mountain view',
    'Pet friendly',
    'Domestic quarters',
    'Wine cellar',
    'Home office',
    'Gym',
    'Concierge',
  ];
}

/// Central market figures used in UI cards and calculators.
///
/// Keep this in sync with official publications and include an as-of date so
/// users can trust the numbers they are seeing.
class SaMarketSnapshot {
  static const double primeRate = 10.50;
  static const String primeRateAsOf = '08 Jun 2026';
  static const String primeRateSource = 'SARB current market rates';

  static const String capeTownHousePriceYoY = '+8.4%';
  static const String capeTownSource = 'House price index';

  static const String gautengRentalsYoY = '+5.1%';
  static const String gautengSource = 'PayProp rental index';
}

class TransferDutyBracket {
  const TransferDutyBracket({
    required this.minValue,
    this.maxValue,
    required this.baseAmount,
    required this.marginalRate,
    required this.threshold,
  });

  final double minValue;
  final double? maxValue;
  final double baseAmount;
  final double marginalRate;
  final double threshold;

  double calculate(double purchasePrice) {
    if (purchasePrice <= threshold) return 0;
    return baseAmount + (purchasePrice - threshold) * marginalRate;
  }

  Map<String, dynamic> toJson() => {
    'min_value': minValue,
    'max_value': maxValue,
    'base_amount': baseAmount,
    'marginal_rate': marginalRate,
    'threshold': threshold,
  };

  static TransferDutyBracket fromJson(Map<String, dynamic> json) {
    return TransferDutyBracket(
      minValue: (json['min_value'] as num?)?.toDouble() ?? 0,
      maxValue: (json['max_value'] as num?)?.toDouble(),
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0,
      marginalRate: (json['marginal_rate'] as num?)?.toDouble() ?? 0,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MarketSnapshotData {
  const MarketSnapshotData({
    required this.primeRate,
    required this.primeRateAsOf,
    required this.primeRateSource,
    required this.capeTownHousePriceYoY,
    required this.capeTownSource,
    required this.gautengRentalsYoY,
    required this.gautengSource,
    required this.transferDutyEffectiveLabel,
    required this.transferDutySource,
    required this.transferDutyBrackets,
    required this.lastSyncedAt,
  });

  final double primeRate;
  final String primeRateAsOf;
  final String primeRateSource;
  final String capeTownHousePriceYoY;
  final String capeTownSource;
  final String gautengRentalsYoY;
  final String gautengSource;
  final String transferDutyEffectiveLabel;
  final String transferDutySource;
  final List<TransferDutyBracket> transferDutyBrackets;
  final DateTime? lastSyncedAt;

  static MarketSnapshotData fallback() {
    return MarketSnapshotData(
      primeRate: SaMarketSnapshot.primeRate,
      primeRateAsOf: SaMarketSnapshot.primeRateAsOf,
      primeRateSource: SaMarketSnapshot.primeRateSource,
      capeTownHousePriceYoY: SaMarketSnapshot.capeTownHousePriceYoY,
      capeTownSource: SaMarketSnapshot.capeTownSource,
      gautengRentalsYoY: SaMarketSnapshot.gautengRentalsYoY,
      gautengSource: SaMarketSnapshot.gautengSource,
      transferDutyEffectiveLabel: 'SARS 2025/26',
      transferDutySource: 'SARS transfer duty rates',
      transferDutyBrackets: const [
        TransferDutyBracket(
          minValue: 1,
          maxValue: 1210000,
          baseAmount: 0,
          marginalRate: 0,
          threshold: 1210000,
        ),
        TransferDutyBracket(
          minValue: 1210001,
          maxValue: 1663800,
          baseAmount: 0,
          marginalRate: 0.03,
          threshold: 1210000,
        ),
        TransferDutyBracket(
          minValue: 1663801,
          maxValue: 2329300,
          baseAmount: 13614,
          marginalRate: 0.06,
          threshold: 1663800,
        ),
        TransferDutyBracket(
          minValue: 2329301,
          maxValue: 2994800,
          baseAmount: 53544,
          marginalRate: 0.08,
          threshold: 2329300,
        ),
        TransferDutyBracket(
          minValue: 2994801,
          maxValue: 13310000,
          baseAmount: 106784,
          marginalRate: 0.11,
          threshold: 2994800,
        ),
        TransferDutyBracket(
          minValue: 13310001,
          maxValue: null,
          baseAmount: 1241456,
          marginalRate: 0.13,
          threshold: 13310000,
        ),
      ],
      lastSyncedAt: null,
    );
  }

  static MarketSnapshotData fromRow(Map<String, dynamic> row) {
    final fallbackData = fallback();
    final rawBrackets = row['transfer_duty_brackets'];
    final parsedBrackets = rawBrackets is List
        ? rawBrackets
              .whereType<Map>()
              .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
              .map(TransferDutyBracket.fromJson)
              .toList(growable: false)
        : fallbackData.transferDutyBrackets;

    return MarketSnapshotData(
      primeRate: (row['prime_rate'] as num?)?.toDouble() ?? fallbackData.primeRate,
      primeRateAsOf:
          row['prime_rate_as_of']?.toString() ?? fallbackData.primeRateAsOf,
      primeRateSource:
          row['prime_rate_source']?.toString() ?? fallbackData.primeRateSource,
      capeTownHousePriceYoY:
          row['cape_town_house_price_yoy']?.toString() ??
          fallbackData.capeTownHousePriceYoY,
      capeTownSource:
          row['cape_town_source']?.toString() ?? fallbackData.capeTownSource,
      gautengRentalsYoY:
          row['gauteng_rentals_yoy']?.toString() ??
          fallbackData.gautengRentalsYoY,
      gautengSource:
          row['gauteng_source']?.toString() ?? fallbackData.gautengSource,
      transferDutyEffectiveLabel:
          row['transfer_duty_effective_label']?.toString() ??
          fallbackData.transferDutyEffectiveLabel,
      transferDutySource:
          row['transfer_duty_source']?.toString() ??
          fallbackData.transferDutySource,
      transferDutyBrackets:
          parsedBrackets.isEmpty ? fallbackData.transferDutyBrackets : parsedBrackets,
      lastSyncedAt: DateTime.tryParse(row['synced_at']?.toString() ?? ''),
    );
  }
}
