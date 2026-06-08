/// All data models used across the app. Kept in one file so the rest of
/// the codebase has a single import surface for shared types.
library;

import 'package:flutter/material.dart';

enum ListingMode {
  buy('For Sale', 'Buy', Icons.home_outlined),
  rent('To Rent', 'Rent', Icons.vpn_key_outlined),
  developments('New Developments', 'New Dev', Icons.location_city_outlined),
  commercial('Commercial', 'Commercial', Icons.storefront_outlined);

  const ListingMode(this.label, this.shortLabel, this.icon);
  final String label;
  final String shortLabel;
  final IconData icon;
}

enum ListingSort {
  recommended('Recommended'),
  newest('Newest'),
  priceLow('Price · low to high'),
  priceHigh('Price · high to low'),
  beds('Most bedrooms');

  const ListingSort(this.label);
  final String label;
}

enum ListingStatus {
  draft('Draft', Icons.edit_note_outlined),
  active('Active', Icons.public_outlined),
  underOffer('Under offer', Icons.handshake_outlined),
  sold('Sold', Icons.verified_outlined),
  rented('Rented', Icons.key_outlined),
  archived('Archived', Icons.inventory_2_outlined);

  const ListingStatus(this.label, this.icon);
  final String label;
  final IconData icon;

  String get dbValue => switch (this) {
    ListingStatus.underOffer => 'under_offer',
    _ => name,
  };

  static ListingStatus fromDb(String? raw) {
    return switch (raw) {
      'active' => ListingStatus.active,
      'under_offer' => ListingStatus.underOffer,
      'sold' => ListingStatus.sold,
      'rented' => ListingStatus.rented,
      'archived' => ListingStatus.archived,
      _ => ListingStatus.draft,
    };
  }
}

enum SettlementSpeed { instant, fast, standard }

/// A single property listing — covers buy, rent, developments and commercial.
class PropertyListing {
  const PropertyListing({
    required this.id,
    required this.title,
    required this.mode,
    required this.propertyType,
    required this.price,
    required this.province,
    required this.city,
    required this.suburb,
    required this.beds,
    required this.baths,
    required this.parking,
    required this.floorSize,
    required this.heroImage,
    required this.gallery,
    required this.description,
    required this.agentId,
    required this.publishedAt,
    this.status = ListingStatus.active,
    this.erfSize,
    this.levy,
    this.rates,
    this.lifestyleFeatures = const [],
    this.securityFeatures = const [],
    this.resilienceFeatures = const [],
    this.isFeatured = false,
    this.isVerified = true,
    this.popi = true,
    this.eaabRegistered = true,
    this.energyRating = 'B',
    this.loadSheddingScore = 7,
    this.safetyScore = 8,
    this.schoolScore = 7,
    this.lifestyleScore = 8,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String title;
  final ListingMode mode;
  final String propertyType;
  final num price;
  final String province;
  final String city;
  final String suburb;
  final int beds;
  final num baths;
  final int parking;
  final int floorSize; // m²
  final int? erfSize; // m²
  final num? levy;
  final num? rates;
  final String heroImage;
  final List<String> gallery;
  final String description;
  final String agentId;
  final DateTime publishedAt;
  final ListingStatus status;
  final List<String> lifestyleFeatures;
  final List<String> securityFeatures;
  final List<String> resilienceFeatures;
  final bool isFeatured;
  final bool isVerified;
  final bool popi;
  final bool eaabRegistered;
  final String energyRating;
  final int loadSheddingScore;
  final int safetyScore;
  final int schoolScore;
  final int lifestyleScore;
  final double? latitude;
  final double? longitude;

  String get fullLocation => '$suburb, $city';
  String get regionLine => '$suburb · $city · $province';

  List<String> get allImages => [heroImage, ...gallery];

  bool get isLive => status == ListingStatus.active;
}

class Agent {
  const Agent({
    required this.id,
    required this.name,
    required this.agency,
    required this.area,
    required this.phone,
    required this.email,
    required this.avatar,
    required this.rating,
    required this.responseMinutes,
    required this.listingsActive,
    required this.bio,
    this.ppraNumber,
    this.verified = true,
  });

  final String id;
  final String name;
  final String agency;
  final String area;
  final String phone;
  final String email;
  final String avatar;
  final double rating;
  final int responseMinutes;
  final int listingsActive;
  final String bio;
  final String? ppraNumber;
  final bool verified;
}

class SavedSearch {
  SavedSearch({
    required this.id,
    required this.name,
    required this.filters,
    this.alertEmail = true,
    this.alertPush = true,
    this.cadence = 'instant',
  });

  final String id;
  String name;
  FilterCriteria filters;
  bool alertEmail;
  bool alertPush;
  String cadence;
}

/// Filter state for the search screen.
class FilterCriteria {
  const FilterCriteria({
    this.mode = ListingMode.buy,
    this.query = '',
    this.province,
    this.city,
    this.cities = const [],
    this.minPrice = 0,
    this.maxPrice = 50000000,
    this.minBeds = 0,
    this.minBaths = 0,
    this.minParking = 0,
    this.propertyTypes = const [],
    this.requiredLifestyle = const [],
    this.requiredSecurity = const [],
    this.requiredResilience = const [],
    this.verifiedOnly = false,
    this.featuredOnly = false,
    this.sort = ListingSort.recommended,
  });

  final ListingMode mode;
  final String query;
  final String? province;
  final String? city;
  final List<String> cities;
  final num minPrice;
  final num maxPrice;
  final int minBeds;
  final int minBaths;
  final int minParking;
  final List<String> propertyTypes;
  final List<String> requiredLifestyle;
  final List<String> requiredSecurity;
  final List<String> requiredResilience;
  final bool verifiedOnly;
  final bool featuredOnly;
  final ListingSort sort;

  FilterCriteria copyWith({
    ListingMode? mode,
    String? query,
    Object? province = const _Sentinel(),
    Object? city = const _Sentinel(),
    List<String>? cities,
    num? minPrice,
    num? maxPrice,
    int? minBeds,
    int? minBaths,
    int? minParking,
    List<String>? propertyTypes,
    List<String>? requiredLifestyle,
    List<String>? requiredSecurity,
    List<String>? requiredResilience,
    bool? verifiedOnly,
    bool? featuredOnly,
    ListingSort? sort,
  }) {
    return FilterCriteria(
      mode: mode ?? this.mode,
      query: query ?? this.query,
      province: province is _Sentinel ? this.province : province as String?,
      city: city is _Sentinel ? this.city : city as String?,
      cities: cities ?? this.cities,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minBeds: minBeds ?? this.minBeds,
      minBaths: minBaths ?? this.minBaths,
      minParking: minParking ?? this.minParking,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      requiredLifestyle: requiredLifestyle ?? this.requiredLifestyle,
      requiredSecurity: requiredSecurity ?? this.requiredSecurity,
      requiredResilience: requiredResilience ?? this.requiredResilience,
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      featuredOnly: featuredOnly ?? this.featuredOnly,
      sort: sort ?? this.sort,
    );
  }

  int get appliedCount {
    var c = 0;
    if (province != null) c++;
    if (cities.isNotEmpty) {
      c += cities.length;
    } else if (city != null) {
      c++;
    }
    if (minPrice > 0) c++;
    if (maxPrice < 50000000) c++;
    if (minBeds > 0) c++;
    if (minBaths > 0) c++;
    if (minParking > 0) c++;
    c += propertyTypes.length;
    c += requiredLifestyle.length;
    c += requiredSecurity.length;
    c += requiredResilience.length;
    if (verifiedOnly) c++;
    if (featuredOnly) c++;
    return c;
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'query': query,
    'province': province,
    'city': city,
    'cities': cities,
    'minPrice': minPrice,
    'maxPrice': maxPrice,
    'minBeds': minBeds,
    'minBaths': minBaths,
    'minParking': minParking,
    'propertyTypes': propertyTypes,
    'requiredLifestyle': requiredLifestyle,
    'requiredSecurity': requiredSecurity,
    'requiredResilience': requiredResilience,
    'verifiedOnly': verifiedOnly,
    'featuredOnly': featuredOnly,
    'sort': sort.name,
  };

  static FilterCriteria fromJson(Map<String, dynamic> json) {
    List<String> readList(Object? raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const [];
    }

    ListingMode readMode(String? v) => ListingMode.values.firstWhere(
      (m) => m.name == v,
      orElse: () => ListingMode.buy,
    );
    ListingSort readSort(String? v) => ListingSort.values.firstWhere(
      (s) => s.name == v,
      orElse: () => ListingSort.recommended,
    );

    return FilterCriteria(
      mode: readMode(json['mode']?.toString()),
      query: json['query']?.toString() ?? '',
      province: json['province']?.toString(),
      city: json['city']?.toString(),
      cities: readList(json['cities']),
      minPrice: (json['minPrice'] as num?) ?? 0,
      maxPrice: (json['maxPrice'] as num?) ?? 50000000,
      minBeds: (json['minBeds'] as num?)?.toInt() ?? 0,
      minBaths: (json['minBaths'] as num?)?.toInt() ?? 0,
      minParking: (json['minParking'] as num?)?.toInt() ?? 0,
      propertyTypes: readList(json['propertyTypes']),
      requiredLifestyle: readList(json['requiredLifestyle']),
      requiredSecurity: readList(json['requiredSecurity']),
      requiredResilience: readList(json['requiredResilience']),
      verifiedOnly: json['verifiedOnly'] == true,
      featuredOnly: json['featuredOnly'] == true,
      sort: readSort(json['sort']?.toString()),
    );
  }
}

class _Sentinel {
  const _Sentinel();
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.preferredCity,
    this.avatar,
    this.role = 'buyer',
  });

  final String name;
  final String email;
  final String phone;
  final String preferredCity;
  final String? avatar;
  final String role;
}

/// A lead row owned by an agent — populated from the `leads` table.
class AgentLead {
  const AgentLead({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    this.listingId,
    this.email,
    this.phone,
    this.message,
  });

  final String id;
  final String? listingId;
  final String name;
  final String? email;
  final String? phone;
  final String? message;
  final String status;
  final DateTime createdAt;
}

/// Workflow statuses that match the `lead_status` enum in Supabase.
const leadStatusFlow = <String>[
  'new',
  'contacted',
  'viewing_booked',
  'qualified',
  'closed',
  'lost',
];

String leadStatusLabel(String status) {
  switch (status) {
    case 'new':
      return 'New';
    case 'contacted':
      return 'Contacted';
    case 'viewing_booked':
      return 'Viewing booked';
    case 'qualified':
      return 'Qualified';
    case 'closed':
      return 'Closed · won';
    case 'lost':
      return 'Closed · lost';
    default:
      return status;
  }
}

class ViewingAppointment {
  const ViewingAppointment({
    required this.id,
    required this.listingId,
    required this.agentId,
    required this.requestedFor,
    required this.status,
    required this.createdAt,
    this.leadId,
    this.notes,
    this.leadName,
    this.leadPhone,
    this.leadEmail,
    this.listingTitle,
  });

  final String id;
  final String? leadId;
  final String listingId;
  final String agentId;
  final DateTime requestedFor;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final String? leadName;
  final String? leadPhone;
  final String? leadEmail;
  final String? listingTitle;
}

const appointmentStatusFlow = <String>[
  'requested',
  'confirmed',
  'completed',
  'cancelled',
];

String appointmentStatusLabel(String status) {
  return switch (status) {
    'requested' => 'Requested',
    'confirmed' => 'Confirmed',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}
