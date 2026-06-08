import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/sa_data.dart';
import '../models/models.dart';

/// Thin typed wrapper around the Supabase client. All reads gracefully
/// degrade and return empty collections / null when the backend is
/// unreachable so the UI can fall back to demo content.
class SupabaseRepository {
  SupabaseRepository(this._client);

  final SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Listings & agents
  // ---------------------------------------------------------------------------

  Future<List<PropertyListing>> fetchListings({int limit = 100}) async {
    final res = await _client
        .from('listings')
        .select()
        .eq('status', 'active')
        .order('is_featured', ascending: false)
        .order('published_at', ascending: false, nullsFirst: false)
        .limit(limit);
    return [for (final row in res) _listingFromRow(row)];
  }

  Future<List<Agent>> fetchAgents() async {
    final res = await _client.from('agents').select();
    return [for (final row in res) _agentFromRow(row)];
  }

  Future<MarketSnapshotData?> fetchLatestMarketSnapshot() async {
    final row = await _client
        .from('market_snapshot')
        .select()
        .eq('id', 'za')
        .maybeSingle();
    if (row == null) return null;
    return MarketSnapshotData.fromRow(row);
  }

  // ---------------------------------------------------------------------------
  // Favourites
  // ---------------------------------------------------------------------------

  Future<Set<String>> fetchFavourites(String userId) async {
    final res = await _client
        .from('favourites')
        .select('listing_id')
        .eq('user_id', userId);
    return {for (final row in res) row['listing_id'].toString()};
  }

  Future<void> addFavourite({
    required String userId,
    required String listingId,
  }) async {
    await _client.from('favourites').upsert({
      'user_id': userId,
      'listing_id': listingId,
    });
  }

  Future<void> removeFavourite({
    required String userId,
    required String listingId,
  }) async {
    await _client
        .from('favourites')
        .delete()
        .eq('user_id', userId)
        .eq('listing_id', listingId);
  }

  // ---------------------------------------------------------------------------
  // Saved searches
  // ---------------------------------------------------------------------------

  Future<List<SavedSearch>> fetchSavedSearches(String userId) async {
    final res = await _client
        .from('saved_searches')
        .select()
        .eq('user_id', userId)
        .order('created_at');
    return [
      for (final row in res)
        SavedSearch(
          id: row['id'].toString(),
          name: row['name']?.toString() ?? 'Saved search',
          filters: _criteriaFromRow(row['criteria']),
          alertEmail: row['email_enabled'] == true,
          alertPush: row['push_enabled'] == true,
          cadence: row['cadence']?.toString() ?? 'instant',
        ),
    ];
  }

  Future<SavedSearch> insertSavedSearch({
    required String userId,
    required SavedSearch search,
  }) async {
    final row = await _client
        .from('saved_searches')
        .insert({
          'user_id': userId,
          'name': search.name,
          'criteria': search.filters.toJson(),
          'cadence': search.cadence,
          'push_enabled': search.alertPush,
          'email_enabled': search.alertEmail,
        })
        .select()
        .single();
    return SavedSearch(
      id: row['id'].toString(),
      name: row['name']?.toString() ?? search.name,
      filters: search.filters,
      alertEmail: row['email_enabled'] == true,
      alertPush: row['push_enabled'] == true,
      cadence: row['cadence']?.toString() ?? search.cadence,
    );
  }

  Future<void> updateSavedSearch(SavedSearch search) async {
    await _client
        .from('saved_searches')
        .update({
          'name': search.name,
          'criteria': search.filters.toJson(),
          'cadence': search.cadence,
          'push_enabled': search.alertPush,
          'email_enabled': search.alertEmail,
        })
        .eq('id', search.id);
  }

  Future<void> deleteSavedSearch(String id) async {
    await _client.from('saved_searches').delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // Leads, profiles, view tracking
  // ---------------------------------------------------------------------------

  Future<void> submitLead({
    String? userId,
    required String listingId,
    String? agentId,
    required String name,
    String? email,
    String? phone,
    String? message,
  }) async {
    await _client.from('leads').insert({
      'user_id': userId,
      'listing_id': listingId,
      'agent_id': agentId,
      'name': name,
      'email': email,
      'phone': phone,
      'message': message,
      'source': 'mobile_app',
    });
  }

  Future<void> requestViewing({
    String? userId,
    required PropertyListing listing,
    required Agent? agent,
    required String name,
    String? email,
    String? phone,
    required DateTime requestedFor,
    String? notes,
  }) async {
    final lead = await _client
        .from('leads')
        .insert({
          'user_id': userId,
          'listing_id': listing.id,
          'agent_id': agent?.id.isEmpty == true ? null : agent?.id,
          'name': name,
          'email': email,
          'phone': phone,
          'message': notes == null || notes.trim().isEmpty
              ? 'Viewing requested for ${listing.title}.'
              : notes.trim(),
          'source': 'viewing_request',
          'status': 'viewing_booked',
        })
        .select('id')
        .single();

    await _client.from('viewing_appointments').insert({
      'lead_id': lead['id'],
      'listing_id': listing.id,
      'agent_id': agent?.id.isEmpty == true ? null : agent?.id,
      'requested_for': requestedFor.toIso8601String(),
      'status': 'requested',
      'notes': notes,
    });
  }

  Future<void> recordListingView({
    required String listingId,
    String? anonymousId,
  }) async {
    try {
      await _client.rpc(
        'record_listing_view',
        params: {
          'p_listing_id': listingId,
          'p_anonymous_id': anonymousId,
          'p_source': 'mobile_app',
        },
      );
    } catch (_) {
      // View counts are best-effort.
    }
  }

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile(
      name: row['full_name']?.toString() ?? 'New user',
      email: _client.auth.currentUser?.email ?? '',
      phone: row['phone']?.toString() ?? '',
      preferredCity: row['preferred_city']?.toString() ?? 'Sandton',
      avatar: row['avatar_url']?.toString(),
      role: row['role']?.toString() ?? 'buyer',
    );
  }

  Future<void> upsertProfile({
    required String userId,
    required UserProfile profile,
  }) async {
    await _client.from('profiles').upsert({
      'id': userId,
      'full_name': profile.name,
      'phone': profile.phone,
      'avatar_url': profile.avatar,
      'preferred_city': profile.preferredCity,
      'role': profile.role,
    });
  }

  // ---------------------------------------------------------------------------
  // Agent studio
  // ---------------------------------------------------------------------------

  /// Find the agent row linked to a signed-in user (if any).
  Future<Agent?> fetchAgentForUser(String userId) async {
    final row = await _client
        .from('agents')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return _agentFromRow(row);
  }

  Future<List<PropertyListing>> fetchListingsForAgent(String agentId) async {
    final res = await _client
        .from('listings')
        .select()
        .eq('agent_id', agentId)
        .order('created_at', ascending: false);
    return [for (final row in res) _listingFromRow(row)];
  }

  Future<List<AgentLead>> fetchLeadsForAgent(String agentId) async {
    final res = await _client
        .from('leads')
        .select()
        .eq('agent_id', agentId)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final row in res) _leadFromRow(row)];
  }

  Future<void> updateLeadStatus({
    required String leadId,
    required String status,
  }) async {
    await _client.from('leads').update({'status': status}).eq('id', leadId);
  }

  Future<void> updateListingStatus({
    required String listingId,
    required String status,
  }) async {
    await _client
        .from('listings')
        .update({'status': status})
        .eq('id', listingId);
  }

  Future<PropertyListing> createListingForAgent({
    required Agent agent,
    required Map<String, dynamic> values,
  }) async {
    final payload = {
      ...values,
      'agent_id': agent.id,
      if (agent.agency.isNotEmpty) 'agency_id': agent.agency,
      'slug': values['slug'] ?? _slug(values['title']?.toString() ?? 'listing'),
      'published_at': values['status'] == 'active'
          ? DateTime.now().toIso8601String()
          : null,
    };
    final row = await _client
        .from('listings')
        .insert(payload)
        .select()
        .single();
    return _listingFromRow(row);
  }

  Future<PropertyListing> updateListing({
    required String listingId,
    required Map<String, dynamic> values,
  }) async {
    final payload = {...values};
    if (payload['status'] == 'active' && payload['published_at'] == null) {
      payload['published_at'] = DateTime.now().toIso8601String();
    }
    final row = await _client
        .from('listings')
        .update(payload)
        .eq('id', listingId)
        .select()
        .single();
    return _listingFromRow(row);
  }

  Future<List<String>> uploadListingImages({
    required String agentId,
    required String listingId,
    required List<ListingImageUpload> images,
  }) async {
    final uploaded = <String>[];
    for (final image in images) {
      final extension = _extension(image.fileName);
      final safeName = '${DateTime.now().microsecondsSinceEpoch}-$extension';
      final path = '$agentId/$listingId/$safeName';
      await _client.storage
          .from('listing-media')
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: true,
            ),
          );
      uploaded.add(_client.storage.from('listing-media').getPublicUrl(path));
    }
    return uploaded;
  }

  Future<PropertyListing> setListingImages({
    required String listingId,
    required List<String> urls,
  }) async {
    final row = await _client
        .from('listings')
        .update({
          'hero_image_url': urls.isEmpty ? null : urls.first,
          'gallery_urls': urls.length <= 1 ? <String>[] : urls.skip(1).toList(),
        })
        .eq('id', listingId)
        .select()
        .single();
    return _listingFromRow(row);
  }

  Future<List<ViewingAppointment>> fetchAppointmentsForAgent(
    String agentId,
  ) async {
    final res = await _client
        .from('viewing_appointments')
        .select('*, leads(name,email,phone), listings(title)')
        .eq('agent_id', agentId)
        .order('requested_for', ascending: true)
        .limit(100);
    return [for (final row in res) _appointmentFromRow(row)];
  }

  Future<void> updateAppointmentStatus({
    required String appointmentId,
    required String status,
  }) async {
    await _client
        .from('viewing_appointments')
        .update({'status': status})
        .eq('id', appointmentId);
  }

  Future<int> countListingViews({
    required String listingId,
    required DateTime since,
  }) async {
    final res = await _client
        .from('listing_views')
        .select('id')
        .eq('listing_id', listingId)
        .gte('viewed_at', since.toIso8601String());
    return res.length;
  }

  // ---------------------------------------------------------------------------
  // Row mappers
  // ---------------------------------------------------------------------------

  PropertyListing _listingFromRow(Map<String, dynamic> row) {
    final gallery =
        (row['gallery_urls'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];
    return PropertyListing(
      id: row['id']?.toString() ?? row['slug']?.toString() ?? 'unknown',
      title: row['title']?.toString() ?? 'Untitled listing',
      mode: _modeFromString(row['mode']?.toString()),
      propertyType: row['property_type']?.toString() ?? 'House',
      price: (row['price'] as num?) ?? 0,
      province: row['province']?.toString() ?? '',
      city: row['city']?.toString() ?? '',
      suburb: row['suburb']?.toString() ?? '',
      beds: (row['bedrooms'] as num?)?.toInt() ?? 0,
      baths: (row['bathrooms'] as num?) ?? 0,
      parking: (row['parking'] as num?)?.toInt() ?? 0,
      floorSize: (row['floor_size'] as num?)?.toInt() ?? 0,
      erfSize: (row['erf_size'] as num?)?.toInt(),
      levy: row['levy'] as num?,
      rates: row['rates'] as num?,
      heroImage:
          row['hero_image_url']?.toString() ??
          'https://images.unsplash.com/photo-1505691938895-1758d7feb511?w=1400',
      gallery: gallery,
      description: row['description']?.toString() ?? '',
      agentId: row['agent_id']?.toString() ?? '',
      publishedAt:
          DateTime.tryParse(row['published_at']?.toString() ?? '') ??
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      status: ListingStatus.fromDb(row['status']?.toString()),
      lifestyleFeatures: _stringList(row['lifestyle_features']),
      securityFeatures: _stringList(row['security_features']),
      resilienceFeatures: _stringList(row['resilience_features']),
      isFeatured: row['is_featured'] == true,
      isVerified: row['is_verified'] != false,
      popi: row['popi_compliant'] != false,
      eaabRegistered: row['eaab_registered'] != false,
      energyRating: row['energy_rating']?.toString() ?? 'B',
      loadSheddingScore: (row['load_shedding_score'] as num?)?.toInt() ?? 7,
      safetyScore: (row['safety_score'] as num?)?.toInt() ?? 7,
      schoolScore: (row['school_score'] as num?)?.toInt() ?? 7,
      lifestyleScore: (row['lifestyle_score'] as num?)?.toInt() ?? 7,
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
    );
  }

  Agent _agentFromRow(Map<String, dynamic> row) {
    return Agent(
      id: row['id']?.toString() ?? '',
      name: row['display_name']?.toString() ?? 'Agent',
      agency: row['agency_id']?.toString() ?? '',
      area: row['area']?.toString() ?? '',
      phone: row['phone']?.toString() ?? '',
      email: row['email']?.toString() ?? '',
      avatar:
          row['avatar_url']?.toString() ??
          'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=600',
      rating: (row['rating'] as num?)?.toDouble() ?? 5.0,
      responseMinutes: (row['response_minutes'] as num?)?.toInt() ?? 30,
      listingsActive: (row['listings_active'] as num?)?.toInt() ?? 0,
      bio: row['bio']?.toString() ?? '',
      ppraNumber: row['ppra_number']?.toString(),
      verified: row['verified'] == true,
    );
  }

  FilterCriteria _criteriaFromRow(Object? raw) {
    if (raw is Map<String, dynamic>) return FilterCriteria.fromJson(raw);
    if (raw is Map) {
      return FilterCriteria.fromJson(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return const FilterCriteria();
  }

  AgentLead _leadFromRow(Map<String, dynamic> row) {
    return AgentLead(
      id: row['id']?.toString() ?? '',
      listingId: row['listing_id']?.toString(),
      name: row['name']?.toString() ?? 'Lead',
      email: row['email']?.toString(),
      phone: row['phone']?.toString(),
      message: row['message']?.toString(),
      status: row['status']?.toString() ?? 'new',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  ViewingAppointment _appointmentFromRow(Map<String, dynamic> row) {
    final lead = row['leads'] is Map ? row['leads'] as Map : const {};
    final listing = row['listings'] is Map ? row['listings'] as Map : const {};
    return ViewingAppointment(
      id: row['id']?.toString() ?? '',
      leadId: row['lead_id']?.toString(),
      listingId: row['listing_id']?.toString() ?? '',
      agentId: row['agent_id']?.toString() ?? '',
      requestedFor:
          DateTime.tryParse(row['requested_for']?.toString() ?? '') ??
          DateTime.now(),
      status: row['status']?.toString() ?? 'requested',
      notes: row['notes']?.toString(),
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
      leadName: lead['name']?.toString(),
      leadPhone: lead['phone']?.toString(),
      leadEmail: lead['email']?.toString(),
      listingTitle: listing['title']?.toString(),
    );
  }

  List<String> _stringList(Object? raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  ListingMode _modeFromString(String? raw) {
    switch (raw) {
      case 'rent':
        return ListingMode.rent;
      case 'developments':
        return ListingMode.developments;
      case 'commercial':
        return ListingMode.commercial;
      default:
        return ListingMode.buy;
    }
  }

  String _slug(String input) {
    final base = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${base.isEmpty ? 'listing' : base}-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _extension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == fileName || ext.length > 5) return 'jpg';
    return ext;
  }
}

class ListingImageUpload {
  const ListingImageUpload({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String contentType;
}
