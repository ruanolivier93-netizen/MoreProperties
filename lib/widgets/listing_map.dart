import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/models.dart';
import '../theme.dart';

/// Lightweight OpenStreetMap view used on the listing detail and search
/// screens. Markers display ZAR-compact prices and tap-through to detail.
class ListingMapView extends StatelessWidget {
  const ListingMapView({
    super.key,
    required this.listings,
    this.center,
    this.zoom = 11,
    this.height = 280,
    this.interactive = true,
    this.onMarkerTap,
  });

  final List<PropertyListing> listings;
  final LatLng? center;
  final double zoom;
  final double height;
  final bool interactive;
  final void Function(PropertyListing listing)? onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final locatable = listings
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();

    if (locatable.isEmpty && center == null) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.outline),
        ),
        alignment: Alignment.center,
        child: const Text(
          'No mapped locations',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final mapCenter = center ??
        LatLng(locatable.first.latitude!, locatable.first.longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: zoom,
            interactionOptions: InteractionOptions(
              flags: interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'co.za.moreproperties',
              maxNativeZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final l in locatable)
                  Marker(
                    point: LatLng(l.latitude!, l.longitude!),
                    width: 110,
                    height: 36,
                    child: _PriceMarker(
                      listing: l,
                      onTap: onMarkerTap == null
                          ? null
                          : () => onMarkerTap!(l),
                    ),
                  ),
              ],
            ),
            // Attribution required by OpenStreetMap.
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({required this.listing, this.onTap});

  final PropertyListing listing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = _shortPrice(listing);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(listing.mode.icon, size: 12, color: Colors.black),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortPrice(PropertyListing l) {
    final v = l.price.toDouble();
    if (l.mode == ListingMode.rent) {
      return 'R${(v / 1000).toStringAsFixed(0)}k pm';
    }
    if (v >= 1000000) return 'R${(v / 1000000).toStringAsFixed(1)}m';
    if (v >= 1000) return 'R${(v / 1000).toStringAsFixed(0)}k';
    return 'R${v.toStringAsFixed(0)}';
  }
}
